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
fn make_loader(
  base_dir : String,
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
      make_loader(inner_dir),
    )
    match
      @eval.exec_file(load_thread, resolved, load_src, @eval.Options::default()) {
      Ok(m) => Ok(m)
      Err(e) =>
        Err(
          @errors.EvalError::simple("cannot load \"\{load_path}\": \{e.msg()}"),
        )
    }
  }
}

///|
fn run_file(filepath : String) -> Int {
  let src = @fs.read_file_to_string(filepath) catch {
    @fs.IOError(msg) => {
      println("starlark: \{msg}")
      return 1
    }
  }
  let base_dir = dir_of(filepath)
  let thread = @eval.Thread::with_loader(filepath, make_loader(base_dir))
  match @eval.exec_file(thread, filepath, src, @eval.Options::default()) {
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
  if args.length() < 2 {
    run_repl()
    return
  }
  let filepath = args[1]
  let exit_code = run_file(filepath)
  if exit_code != 0 {
    @sys.exit(exit_code)
  }
}
