///|
fn dir_of(filepath : String) -> String {
  @path.Path(filepath).dirname().to_string()
}

///|
fn resolve_load(base_dir : String, load_path : String) -> String {
  @path.Path(base_dir).join(@path.Path(load_path)).normalize().to_string()
}

///|
/// Parses a Go-style boolean flag value (`strconv.ParseBool` set).
fn parse_bool_flag(value : String) -> Bool? {
  match value {
    "1" | "t" | "T" | "true" | "TRUE" | "True" => Some(true)
    "0" | "f" | "F" | "false" | "FALSE" | "False" => Some(false)
    _ => None
  }
}

///|
/// Parses the CLI arguments into the script path (if any) and the evaluation
/// options. Two boolean flags (each also spelled with a leading `--`, matching
/// starlark-go) toggle non-standard dialect features, all disabled by default:
///
/// - `-recursion` enables recursive function calls.
/// - `-globalreassign` enables top-level reassignment, `while` loops, and
///   `if`/`for`/`while` statements at top level — the same trio starlark-go's
///   legacy `-globalreassign` flag controls.
///
/// Each accepts the Go forms `-flag`, `-flag=true`, and `-flag=false`. A bare
/// `--` stops flag parsing so later arguments are treated as positional.
/// Returns `Err` for an invalid flag value.
pub fn parse_cli_args(
  args : Array[String],
) -> Result[(String?, @eval.Options), String] {
  let mut filepath : String? = None
  let mut opts = @eval.Options::default()
  let mut flags_done = false
  // Apply starlark-go's legacy `-globalreassign`, which conflates three
  // FileOptions: top-level reassignment, `while` loops, and top-level control.
  fn set_global_reassign(o : @eval.Options, b : Bool) -> @eval.Options {
    o
    .with_allow_global_reassign(b)
    .with_allow_while(b)
    .with_allow_top_level_control(b)
  }

  for i in 1..<args.length() {
    let arg = args[i]
    if flags_done {
      if filepath is None {
        filepath = Some(arg)
      }
      continue
    }
    if arg == "--" {
      flags_done = true
    } else if arg == "--recursion" || arg == "-recursion" {
      opts = opts.with_allow_recursion(true)
    } else if arg.has_prefix("--recursion=") || arg.has_prefix("-recursion=") {
      let value = arg[arg.find("=").unwrap() + 1:].to_owned()
      match parse_bool_flag(value) {
        Some(b) => opts = opts.with_allow_recursion(b)
        None => return Err("invalid boolean value \"\{value}\" for -recursion")
      }
    } else if arg == "--globalreassign" || arg == "-globalreassign" {
      opts = set_global_reassign(opts, true)
    } else if arg.has_prefix("--globalreassign=") ||
      arg.has_prefix("-globalreassign=") {
      let value = arg[arg.find("=").unwrap() + 1:].to_owned()
      match parse_bool_flag(value) {
        Some(b) => opts = set_global_reassign(opts, b)
        None =>
          return Err("invalid boolean value \"\{value}\" for -globalreassign")
      }
    } else if filepath is None {
      filepath = Some(arg)
    }
  }
  Ok((filepath, opts))
}

///|
fn make_loader_with_cache(
  base_dir : String,
  opts : @eval.Options,
  cache : Map[String, Result[@eval.Module, @errors.EvalError]],
) -> (@eval.Thread, String) -> Result[@eval.Module, @errors.EvalError] {
  fn(_thread, load_path) {
    let resolved = resolve_load(base_dir, load_path)
    match cache.get(resolved) {
      Some(cached) => return cached
      None => ()
    }
    cache[resolved] = Err(@errors.EvalError::simple("cycle in load graph"))
    let load_src = @fs.read_file_to_string(resolved) catch {
      @fs.IOError(msg) => {
        let err = Err(
          @errors.EvalError::simple("cannot load \"\{resolved}\": \{msg}"),
        )
        cache[resolved] = err
        return err
      }
    }
    let inner_dir = dir_of(resolved)
    let load_thread = @eval.Thread::with_loader(
      "load:\{load_path}",
      make_loader_with_cache(inner_dir, opts, cache),
    )
    let result = match @eval.exec_file(load_thread, resolved, load_src, opts) {
      Ok(m) => Ok(m)
      Err(e) =>
        Err(
          @errors.EvalError::simple("cannot load \"\{resolved}\": \{e.msg()}"),
        )
    }
    cache[resolved] = result
    result
  }
}

///|
/// Returns a load function that resolves load paths relative to `base_dir`
/// and caches previously loaded modules. A shared cache is maintained across
/// all nesting levels so that diamond dependencies load each module once and
/// cross-directory cycles are detected cleanly.
///
/// Parameters:
///
/// - `base_dir` : The filesystem directory used as the resolution root for
///   relative load paths.
/// - `opts` : Feature flags forwarded to `exec_file` for each loaded module.
///
/// Returns a load handler compatible with `@eval.Thread::with_loader`.
fn make_loader(
  base_dir : String,
  opts : @eval.Options,
) -> (@eval.Thread, String) -> Result[@eval.Module, @errors.EvalError] {
  let cache : Map[String, Result[@eval.Module, @errors.EvalError]] = {}
  make_loader_with_cache(base_dir, opts, cache)
}

///|
pub fn run_file(filepath : String, opts : @eval.Options) -> Int {
  let src = @fs.read_file_to_string(filepath) catch {
    @fs.IOError(msg) => {
      println("starlark: \{msg}")
      return 1
    }
  }
  let base_dir = dir_of(filepath)
  let thread = @eval.Thread::with_loader(filepath, make_loader(base_dir, opts))
  match @eval.exec_file(thread, filepath, src, opts) {
    Ok(_) => 0
    Err(e) => {
      println(e.msg())
      1
    }
  }
}

///|
pub fn run_repl(opts : @eval.Options) -> Int {
  if !@repl.repl_available() {
    println(
      "starlark: interactive REPL is not available on this build target; rebuild with `--target native`",
    )
    return 1
  }
  let thread = @eval.Thread::with_loader("REPL", @repl.make_load("."))
  let globals = @value.StringDict::new()
  if @repl.is_terminal() {
    println("Welcome to Starlark (connect0459/starlark)")
  }
  @repl.run(thread, globals, opts~)
  if @repl.is_terminal() {
    println("")
  }
  0
}
