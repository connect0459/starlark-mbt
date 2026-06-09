///|
extern "C" fn isatty_ffi() -> Int = "starlark_repl_isatty"

///|
#borrow(prompt)
extern "C" fn read_line_ffi(prompt : Bytes) -> Bytes? = "starlark_repl_read_line"

///|
#borrow(s)
extern "C" fn write_stderr_ffi(s : Bytes) = "starlark_repl_write_stderr"

///|
extern "C" fn setup_interrupt_ffi() = "starlark_repl_setup_interrupt"

///|
extern "C" fn interrupted_ffi() -> Int = "starlark_repl_interrupted"

///|
extern "C" fn init_editor_ffi() = "starlark_repl_init_editor"

///|
/// Configures the line editor (history, prompt marker) once before the loop.
fn init_editor() -> Unit {
  init_editor_ffi()
}

///|
/// Step interval between interrupt polls. The evaluation step counter is reset
/// every interval, so the REPL imposes no step ceiling and relies on Ctrl-C to
/// stop a runaway computation, as starlark-go does.
let poll_interval : Int = 100_000

///|
pub fn is_terminal() -> Bool {
  isatty_ffi() != 0
}

///|
/// Writes `s` followed by a newline to stderr, so diagnostics stay separate
/// from value output on stdout.
fn write_err_line(s : String) -> Unit {
  write_stderr_ffi(@utf8.encode(s + "\n"))
}

///|
/// Installs the SIGINT handler and arms a step-budget poll that cancels the
/// thread when an interrupt has been signalled, otherwise re-arms the budget.
fn setup_interrupt(thread : @eval.Thread) -> Unit {
  setup_interrupt_ffi()
  thread.set_max_steps(poll_interval)
  thread.set_on_max_steps(fn(th) {
    if interrupted_ffi() != 0 {
      th.cancel("interrupted")
    } else {
      th.reset_steps()
    }
  })
}

///|
/// Reads and clears the pending-interrupt flag.
fn interrupted() -> Bool {
  interrupted_ffi() != 0
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
    Some(bytes) => Some(@utf8.decode_lossy(bytes[:]))
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
