///|
fn dir_of(filepath : String) -> String {
  @path.Path(filepath).dirname().to_string()
}

///|
fn resolve_load(base_dir : String, load_path : String) -> String {
  if @path.Path(load_path).is_absolute() {
    load_path
  } else {
    @path.Path(base_dir).join(@path.Path(load_path)).to_string()
  }
}

///|
/// Parses the CLI arguments into the script path (if any) and the evaluation
/// options. `--recursion` (or `-recursion`, matching starlark-go) enables
/// recursive function calls, which are disabled by default.
fn parse_cli_args(args : Array[String]) -> (String?, @eval.Options) {
  let mut filepath : String? = None
  let mut opts = @eval.Options::default()
  for i in 1..<args.length() {
    let arg = args[i]
    if arg == "--recursion" || arg == "-recursion" {
      opts = opts.with_allow_recursion(true)
    } else if filepath is None {
      filepath = Some(arg)
    }
  }
  (filepath, opts)
}

///|
fn make_loader(
  base_dir : String,
  opts : @eval.Options,
) -> (@eval.Thread, String) -> Result[@eval.Module, @errors.EvalError] {
  fn(_thread, load_path) {
    let resolved = resolve_load(base_dir, load_path)
    let load_src = @fs.read_file_to_string(resolved) catch {
      @fs.IOError(msg) =>
        return Err(
          @errors.EvalError::simple("cannot load \"\{load_path}\": \{msg}"),
        )
    }
    let inner_dir = dir_of(resolved)
    let load_thread = @eval.Thread::with_loader(
      "load:\{load_path}",
      make_loader(inner_dir, opts),
    )
    match @eval.exec_file(load_thread, resolved, load_src, opts) {
      Ok(m) => Ok(m)
      Err(e) =>
        Err(
          @errors.EvalError::simple("cannot load \"\{load_path}\": \{e.msg()}"),
        )
    }
  }
}

///|
fn run_file(filepath : String, opts : @eval.Options) -> Int {
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
fn run_repl() -> Unit {
  let thread = @eval.Thread::with_loader("REPL", @repl.make_load("."))
  let globals = @value.StringDict::new()
  if @repl.is_terminal() {
    println("Welcome to Starlark (connect0459/starlark)")
  }
  @repl.run(thread, globals)
  if @repl.is_terminal() {
    println("")
  }
}

///|
fn main {
  let args = @sys.get_cli_args()
  let (filepath, opts) = parse_cli_args(args)
  match filepath {
    None => run_repl()
    Some(fp) => {
      let exit_code = run_file(fp, opts)
      if exit_code != 0 {
        @sys.exit(exit_code)
      }
    }
  }
}
