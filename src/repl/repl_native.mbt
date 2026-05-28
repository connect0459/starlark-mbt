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
fn read_line(prompt : String) -> String? {
  let n = prompt.length()
  let arr : Array[Byte] = Array::make(n, b'\x00')
  let mut i = 0
  prompt
  .iter()
  .each(fn(c) {
    arr[i] = c.to_int().to_byte()
    i += 1
  })
  match read_line_ffi(Bytes::from_array(arr)) {
    None => None
    Some(bytes) => Some(bytes.to_unchecked_string())
  }
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
