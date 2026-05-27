///|
extern "C" fn isatty_ffi() -> Int = "starlark_repl_isatty"

///|
#borrow(prompt)
extern "C" fn read_line_ffi(prompt : Bytes) -> Bytes? = "starlark_repl_read_line"

///|
pub fn is_terminal() -> Bool {
  isatty_ffi() != 0
}

///|
fn read_line(_prompt : String) -> String? {
  match read_line_ffi(b"") {
    None => None
    Some(bytes) => Some(String::from_bytes(bytes))
  }
}

///|
fn write_prompt(prompt : String) -> Unit {
  print(prompt)
}

///|
fn load_file(
  thread : @eval.Thread,
  path : String,
) -> Result[@eval.Module, @errors.EvalError] {
  let src = @fs.read_file_to_string(path) catch {
    _ =>
      return Err(
        @errors.EvalError::simple("cannot load \"\{path}\": file not found"),
      )
  }
  @eval.exec_file(thread, path, src, @eval.Options::default())
}
