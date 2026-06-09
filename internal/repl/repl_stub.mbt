///|
pub fn is_terminal() -> Bool {
  false
}

///|
fn _use_fs(_e : @fs.IOError) -> Unit {
  ignore(_e)
}

///|
fn read_line(_prompt : String) -> String? {
  None
}

///|
/// No-op on backends without a stderr surface. The interactive `run` loop never
/// reaches this on these targets because `read_line` returns `None` immediately.
fn write_err_line(_s : String) -> Unit {

}

///|
/// No-op: these backends have no signal handling. The interactive loop is
/// unreachable because `read_line` returns `None`.
fn setup_interrupt(_thread : @eval.Thread) -> Unit {

}

///|
/// Always false: no interrupt source on these backends.
fn interrupted() -> Bool {
  false
}

///|
fn load_file(
  _thread : @eval.Thread,
  path : String,
) -> Result[@eval.Module, @errors.EvalError] {
  Err(
    @errors.EvalError::simple(
      "cannot load \"\{path}\": file I/O not available on this target",
    ),
  )
}
