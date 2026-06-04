// A minimal build system that processes Starlark BUILD files.
//
// Demonstrates:
//   - Universe: registering MoonBit functions as Starlark built-ins
//   - Loaders: resolving load("//rules:defs.bzl", ...) to Starlark macro files
//   - Value extraction: reading keyword arguments from builtin call contexts
//   - Macro expansion: how a .bzl macro expands into lower-level rules

///|
struct Rule {
  name : String
  kind : String
  srcs : Array[String]
  deps : Array[String]
}

///|
fn get_str_kwarg(kws : Array[(String, @value.Value)], key : String) -> String? {
  for kw in kws {
    if kw.0 == key {
      match kw.1 {
        @value.Value::String(s) => return Some(s.raw())
        _ => return None
      }
    }
  }
  None
}

///|
fn get_list_kwarg(
  kws : Array[(String, @value.Value)],
  key : String,
) -> Array[String] {
  for kw in kws {
    if kw.0 == key {
      match kw.1 {
        @value.Value::List(lst) => {
          let result : Array[String] = []
          for item in lst.iter() {
            match item {
              @value.Value::String(s) => result.push(s.raw())
              _ => ()
            }
          }
          return result
        }
        _ => ()
      }
    }
  }
  []
}

///|
fn join_strs(arr : Array[String], sep : String) -> String {
  if arr.is_empty() {
    return ""
  }
  let mut result = arr[0]
  let mut i = 1
  while i < arr.length() {
    result = result + sep + arr[i]
    i = i + 1
  }
  result
}

///|
fn strip_colon(dep : String) -> String {
  if dep.has_prefix(":") {
    dep[1:].to_owned()
  } else {
    dep
  }
}

// Topological sort via repeated scanning.  Rules with no pending local deps
// are emitted in their original registration order each pass.

///|
fn build_order(rules : Array[Rule]) -> Array[Rule] {
  let result : Array[Rule] = []
  let done : Array[String] = []
  let pending : Array[Rule] = []
  for r in rules {
    pending.push(r)
  }
  while !pending.is_empty() {
    let mut made_progress = false
    let next : Array[Rule] = []
    for rule in pending {
      let mut ready = true
      for raw_dep in rule.deps {
        let dep = strip_colon(raw_dep)
        let mut is_local = false
        for r in rules {
          if r.name == dep {
            is_local = true
            break
          }
        }
        if is_local {
          let mut satisfied = false
          for d in done {
            if d == dep {
              satisfied = true
              break
            }
          }
          if !satisfied {
            ready = false
            break
          }
        }
      }
      if ready {
        result.push(rule)
        done.push(rule.name)
        made_progress = true
      } else {
        next.push(rule)
      }
    }
    pending.clear()
    for r in next {
      pending.push(r)
    }
    if !made_progress {
      // Cyclic or unresolvable deps — emit as-is
      for r in pending {
        result.push(r)
      }
      break
    }
  }
  result
}

///|
fn main {
  // --- Rule registry (shared mutable state captured by closures) ---
  let rules : Array[Rule] = []

  // --- Universe: register Starlark rule functions backed by MoonBit ---
  let universe = @eval.Universe::new()
  let rule_kinds = [
    "cc_library", "cc_binary", "cc_test", "go_library", "go_binary", "filegroup",
  ]
  for kind in rule_kinds {
    let k = kind // capture loop variable
    universe.set(
      k,
      @value.Value::new_builtin(k, fn(_ctx, _pos, kws) {
        match get_str_kwarg(kws, "name") {
          Some(name) => {
            rules.push({
              name,
              kind: k,
              srcs: get_list_kwarg(kws, "srcs"),
              deps: get_list_kwarg(kws, "deps"),
            })
            Ok(@value.Value::None)
          }
          None => Err("rule: missing required attribute 'name'")
        }
      }),
    )
  }

  // --- Loader: maps load("//rules:*.bzl", ...) to Starlark source strings ---
  //
  // The macro library shows Starlark-level abstraction:
  //   versioned_cc_library expands into a cc_library with a "_vN" name suffix.
  let defs_bzl_src =
    #|def versioned_cc_library(name, version, srcs=[], deps=[]):
    #|    """Creates a cc_library whose target name includes a version suffix."""
    #|    cc_library(
    #|        name = name + "_v" + str(version),
    #|        srcs = srcs,
    #|        deps = deps,
    #|    )
  let bzl_sources : Map[String, String] = { "//rules:defs.bzl": defs_bzl_src }

  let loader = fn(
    _t : @eval.Thread,
    path : String,
  ) -> Result[@eval.Module, @errors.EvalError] {
    match bzl_sources.get(path) {
      Some(src) => {
        // Give each .bzl file its own thread; share the same Universe so
        // macros can call cc_library / cc_binary / etc. directly.
        let lt = @eval.Thread::new("load:\{path}")
        @eval.exec_file_with_universe(
          lt,
          path,
          src,
          @eval.Options::default(),
          universe,
        )
      }
      None => Err(@errors.EvalError::simple("module not found: \{path}"))
    }
  }

  // --- Thread ---
  let thread = @eval.Thread::with_loader("build", loader)

  // --- BUILD file: the script a build system user would write ---
  let build_src =
    #|load("//rules:defs.bzl", "versioned_cc_library")
    #|
    #|cc_library(
    #|    name = "math",
    #|    srcs = ["add.c", "mul.c"],
    #|)
    #|
    #|cc_library(
    #|    name = "string_utils",
    #|    srcs = ["string_utils.c"],
    #|    deps = [":math"],
    #|)
    #|
    #|# Macro expands to cc_library(name="crypto_v2", ...)
    #|versioned_cc_library(
    #|    name = "crypto",
    #|    version = 2,
    #|    srcs = ["crypto.c"],
    #|    deps = [":math"],
    #|)
    #|
    #|cc_binary(
    #|    name = "server",
    #|    srcs = ["main.c"],
    #|    deps = [":math", ":string_utils", ":crypto_v2"],
    #|)

  // --- Execute ---
  match
    @eval.exec_file_with_universe(
      thread,
      "BUILD",
      build_src,
      @eval.Options::default(),
      universe,
    ) {
    Ok(_) => {
      println("=== Registered Rules ===")
      for rule in rules {
        let src_part = if rule.srcs.is_empty() {
          ""
        } else {
          let src_str = join_strs(rule.srcs, ", ")
          "  srcs: [\{src_str}]"
        }
        let dep_part = if rule.deps.is_empty() {
          ""
        } else {
          let dep_str = join_strs(rule.deps, ", ")
          "  deps: [\{dep_str}]"
        }
        println("  \{rule.kind}(name=\"\{rule.name}\")\{src_part}\{dep_part}")
      }
      println("")
      println("=== Build Order ===")
      let ordered = build_order(rules)
      let mut idx = 1
      for rule in ordered {
        let arrow = if rule.deps.is_empty() {
          ""
        } else {
          let names = rule.deps.map(strip_colon)
          " <- " + join_strs(names, ", ")
        }
        println("  \{idx}. \{rule.name}\{arrow}")
        idx = idx + 1
      }
    }
    Err(e) => println("Build error: \{e.msg()}")
  }
}
