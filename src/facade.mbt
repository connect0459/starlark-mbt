///|
pub using @value {type Value}

///|
pub using @eval {type Module}

///|
pub using @errors {type EvalError}

///|
/// Executes Starlark source as a module using a default thread and the
/// default dialect options, returning the resulting frozen module.
///
/// This is the zero-ceremony entry point; embedders needing custom threads,
/// options, predeclared bindings, or loaders should use the `eval` package
/// directly.
pub fn exec(
  src : String,
  filename? : String = "<expr>",
) -> Result[Module, EvalError] {
  let thread = @eval.Thread::new("main")
  @eval.exec_file(thread, filename, src, @eval.Options::default())
}

///|
/// Evaluates a single Starlark expression using a default thread, the default
/// dialect options, and an empty environment, returning its value.
pub fn eval(
  src : String,
  filename? : String = "<expr>",
) -> Result[Value, EvalError] {
  let thread = @eval.Thread::new("main")
  @eval.eval_expr(thread, filename, src, @value.StringDict::new())
}
