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
/// Parses the CLI arguments into the script path, an optional inline program
/// (from `-c`), and the evaluation options.
///
/// Supported flags (each also spelled with a leading `--`, matching
/// starlark-go) toggle non-standard dialect features, all disabled by default:
///
/// - `-recursion` enables recursive function calls.
/// - `-globalreassign` enables top-level reassignment, `while` loops, and
///   `if`/`for`/`while` statements at top level — the same trio starlark-go's
///   legacy `-globalreassign` flag controls.
/// - `-c <prog>` or `-c=<prog>` provides an inline program string to execute
///   instead of a file.
///
/// Each boolean flag accepts the Go forms `-flag`, `-flag=true`, and
/// `-flag=false`. A bare `--` stops flag parsing so later arguments are
/// treated as positional. Returns `Err` for an invalid flag value or a `-c`
/// flag with no argument.
///
/// The return tuple is `(filepath, expr, opts)` where `filepath` is the
/// positional script path, `expr` is the `-c` program string, and `opts`
/// contains the resolved feature flags.
pub fn parse_cli_args(
  args : Array[String],
) -> Result[(String?, String?, @eval.Options), String] {
  let mut filepath : String? = None
  let mut expr : String? = None
  let mut opts = @eval.Options::default()
  let mut flags_done = false
  fn set_global_reassign(o : @eval.Options, b : Bool) -> @eval.Options {
    o
    .with_allow_global_reassign(b)
    .with_allow_while(b)
    .with_allow_top_level_control(b)
  }

  let mut i = 1
  while i < args.length() {
    let arg = args[i]
    i += 1
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
    } else if arg == "-c" || arg == "--c" {
      if i < args.length() {
        expr = Some(args[i])
        i += 1
      } else {
        return Err("-c requires an argument")
      }
    } else if arg.has_prefix("-c=") || arg.has_prefix("--c=") {
      expr = Some(arg[arg.find("=").unwrap() + 1:].to_owned())
    } else if filepath is None {
      filepath = Some(arg)
    }
  }
  Ok((filepath, expr, opts))
}

///|
fn cli_universe() -> @eval.Universe {
  let u = @eval.Universe::standard()
  u.set("json", @json.json_module())
  u.set("math", @math.math_module())
  u.set("time", @time.time_module())
  u
}

///|
fn make_loader_with_cache(
  base_dir : String,
  opts : @eval.Options,
  cache : Map[String, Result[@eval.Module, @errors.EvalError]],
  universe : @eval.Universe,
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
        let err = Err(@errors.EvalError::simple(msg))
        cache[resolved] = err
        return err
      }
    }
    let inner_dir = dir_of(resolved)
    let load_thread = @eval.Thread::with_loader(
      "load:\{load_path}",
      make_loader_with_cache(inner_dir, opts, cache, universe),
    )
    let result = @eval.exec_file_with_universe(
      load_thread, resolved, load_src, opts, universe,
    )
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
/// - `opts` : Feature flags forwarded to `exec_file_with_universe` for each
///   loaded module.
/// - `universe` : Predeclared bindings (including lib modules) forwarded to
///   every loaded module.
///
/// Returns a load handler compatible with `@eval.Thread::with_loader`.
fn make_loader(
  base_dir : String,
  opts : @eval.Options,
  universe : @eval.Universe,
) -> (@eval.Thread, String) -> Result[@eval.Module, @errors.EvalError] {
  let cache : Map[String, Result[@eval.Module, @errors.EvalError]] = {}
  make_loader_with_cache(base_dir, opts, cache, universe)
}

///|
pub fn run_file(filepath : String, opts : @eval.Options) -> Int {
  let src = @fs.read_file_to_string(filepath) catch {
    @fs.IOError(msg) => {
      println("starlark: \{msg}")
      return 1
    }
  }
  let universe = cli_universe()
  let base_dir = dir_of(filepath)
  let thread = @eval.Thread::with_loader(
    filepath,
    make_loader(base_dir, opts, universe),
  )
  match @eval.exec_file_with_universe(thread, filepath, src, opts, universe) {
    Ok(_) => 0
    Err(e) => {
      println(e.backtrace())
      1
    }
  }
}

///|
/// Executes an inline Starlark program supplied via the `-c` flag.
/// Uses the CLI universe so that `json`, `math`, and `time` are available
/// without an explicit `load`.  The filename reported in error messages is
/// `"cmdline"`.
pub fn run_expr(expr : String, opts : @eval.Options) -> Int {
  let universe = cli_universe()
  let thread = @eval.Thread::new("exec cmdline")
  match @eval.exec_file_with_universe(thread, "cmdline", expr, opts, universe) {
    Ok(_) => 0
    Err(e) => {
      println(e.backtrace())
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
