///|
/// The result of evaluating a single REPL input line.
pub enum ReplOutput {
  Value(String)
  Empty
  EvalError(@errors.EvalError)
}

///|
pub impl Show for ReplOutput with fn output(self, logger) {
  match self {
    Value(s) => logger.write_string("Value(\{s})")
    Empty => logger.write_string("Empty")
    EvalError(e) => logger.write_string("EvalError(\{e.msg()})")
  }
}

///|
/// Evaluates a single REPL input string in the given `globals` environment.
/// A bare expression is evaluated and its repr returned as `Value(_)`;
/// statements produce `Empty` on success; syntax/eval errors produce
/// `EvalError(_)`.
///
/// Parameters:
///
/// - `thread` : The evaluation thread providing the execution context.
/// - `globals` : The global variable dictionary for the REPL session.
/// - `input` : The raw source text entered by the user.
/// - `opts` : Feature flags controlling which dialect features are active.
///
/// Returns the evaluation result as a `ReplOutput` variant.
pub fn eval_input(
  thread : @eval.Thread,
  globals : @value.StringDict,
  input : String,
  opts? : @eval.Options = @eval.Options::default(),
) -> ReplOutput {
  let file = match @parser.parse_file("<repl>", input) {
    Ok(f) => f
    Err(e) => return EvalError(@errors.EvalError::simple(e.to_string()))
  }
  let stmts = file.stmts()
  // Only a lone bare expression is echoed back; anything else (multiple
  // statements, or a single non-expression statement) runs as a chunk.
  if stmts.length() == 1 && stmts[0] is @syntax.Stmt::SExpr(_) {
    match @eval.eval_expr_with_opts(thread, "<repl>", input, opts, globals) {
      Ok(v) =>
        if v is @value.Value::None {
          Empty
        } else {
          // Bind the last expression's value to `_`, matching the Python REPL.
          globals.set("_", v)
          Value(v.repr())
        }
      Err(e) => EvalError(e)
    }
  } else {
    match @eval.exec_repl_chunk(thread, "<repl>", input, globals, opts) {
      Ok(_) => Empty
      Err(e) => EvalError(e)
    }
  }
}

///|
/// Formats an `EvalError` as a human-readable string for REPL display.
///
/// Parameters:
///
/// - `err` : The evaluation error to format.
///
/// Returns the error's human-readable message string.
pub fn format_error(err : @errors.EvalError) -> String {
  err.msg()
}

///|
/// Returns a load function that resolves load paths relative to `base_dir`
/// and caches previously loaded modules. Nested loads are handled recursively
/// with their own cache; cycle detection uses a sentinel error.
///
/// Parameters:
///
/// - `base_dir` : The filesystem directory used as the resolution root for
///   relative load paths.
///
/// Returns a load handler compatible with `@eval.Thread::with_loader`.
pub fn make_load(
  base_dir : String,
) -> (@eval.Thread, String) -> Result[@eval.Module, @errors.EvalError] {
  let cache : Map[String, Result[@eval.Module, @errors.EvalError]] = {}
  fn(_thread, load_path) {
    let resolved = if load_path.has_prefix("/") ||
      load_path.has_prefix("./") ||
      load_path.has_prefix("../") {
      load_path
    } else {
      base_dir + "/" + load_path
    }
    match cache.get(resolved) {
      Some(cached) => cached
      None => {
        cache[resolved] = Err(@errors.EvalError::simple("cycle in load graph"))
        let inner_dir = dir_of(resolved)
        let inner_thread = @eval.Thread::with_loader(
          "load:\{load_path}",
          make_load(inner_dir),
        )
        let result = load_file(inner_thread, resolved)
        cache[resolved] = result
        result
      }
    }
  }
}

///|
fn dir_of(path : String) -> String {
  match path.rev_find("/") {
    Some(i) => path[:i].to_owned()
    None => "."
  }
}

///|
/// Runs an interactive REPL loop, reading input from stdin and printing
/// results. Multi-line compound statements and unclosed brackets/strings are
/// gathered under a `...` continuation prompt until the chunk is complete.
/// Exits when stdin is closed (a mid-chunk buffer is discarded).
///
/// Ctrl-C has two distinct roles. During evaluation it interrupts the running
/// computation (via the SIGINT handler and step poll). During interactive line
/// editing it is handled by the line editor, which clears the current line and
/// returns an empty string (not EOF). At the primary `>>>` prompt that is a
/// no-op; within a pending multi-line chunk the empty string is indistinguishable
/// from a blank-line terminator, so it ends the chunk (which is then evaluated or
/// reported as an error) rather than discarding it.
///
/// Parameters:
///
/// - `thread` : The evaluation thread used for all input evaluation.
/// - `globals` : The global variable dictionary shared across all REPL inputs.
/// - `opts` : Feature flags controlling which dialect features are active.
pub fn run(
  thread : @eval.Thread,
  globals : @value.StringDict,
  opts? : @eval.Options = @eval.Options::default(),
) -> Unit {
  let state = ReplState::new()
  init_editor()
  setup_interrupt(thread)
  // Prompts are only useful at a terminal; when stdin is piped (e.g.
  // `cat script.star | starlark`) they would just be noise on stderr, so they
  // are suppressed, matching starlark-go and the Python REPL.
  let interactive = is_terminal()
  while true {
    let prompt = if !interactive {
      ""
    } else if state.pending() {
      "... "
    } else {
      ">>> "
    }
    match read_line(prompt) {
      None =>
        // A null read means end of input: Ctrl-D at a terminal, or genuine EOF
        // when piped. Interactive Ctrl-C never lands here — the line editor
        // cancels the line and returns an empty string instead. The interrupt
        // flag can still be set when a signal interrupts a piped read, in which
        // case the partial chunk is discarded and the loop continues.
        if interrupted() {
          state.discard()
          write_err_line("")
          continue
        } else {
          break
        }
      Some(raw) =>
        // Trailing whitespace is insignificant; leading indentation is not, so
        // only the right side is trimmed before feeding the state machine.
        match state.feed(raw.trim_end().to_owned()) {
          NeedMore => continue
          Complete(src) =>
            if src != "" {
              // Re-arm the thread after any prior cancellation and drop a stale
              // interrupt signalled while idle, so Ctrl-C only aborts the
              // evaluation it is pressed during.
              thread.uncancel()
              thread.reset_steps()
              interrupted() |> ignore
              match eval_input(thread, globals, src, opts~) {
                Value(s) => println(s)
                Empty => ()
                EvalError(e) => write_err_line(e.backtrace())
              }
            }
          Invalid(e) => write_err_line(e.backtrace())
        }
    }
  }
}
