///|
pub type Thread = @eval.Thread

///|
pub type Module = @eval.Module

///|
pub type Options = @eval.Options

///|
pub type Universe = @eval.Universe

///|
pub type Predeclared = @eval.Predeclared

///|
pub type Value = @value.Value

///|
pub type StarlarkDict = @value.StarlarkDict

///|
pub type EvalError = @errors.EvalError

///|
pub type SyntaxError = @errors.SyntaxError

///|
pub type ResolveError = @errors.ResolveError

///|
pub type Position = @errors.Position

///|
pub fn exec_file(
  thread : Thread,
  filename : String,
  src : String,
  opts : Options,
) -> Result[Module, EvalError] {
  @eval.exec_file(thread, filename, src, opts)
}

///|
pub fn exec_file_with_predeclared(
  thread : Thread,
  filename : String,
  src : String,
  opts : Options,
  predeclared : Predeclared,
) -> Result[Module, EvalError] {
  @eval.exec_file_with_predeclared(thread, filename, src, opts, predeclared)
}

///|
pub fn eval_expr(
  thread : Thread,
  filename : String,
  src : String,
  env : StarlarkDict,
) -> Result[Value, EvalError] {
  @eval.eval_expr(thread, filename, src, env)
}

///|
pub fn module_get(m : Module, name : String) -> Value? {
  m.get(name)
}

///|
pub fn repr(v : Value) -> String {
  @value.repr(v)
}

///|
pub fn to_str(v : Value) -> String {
  @value.to_str(v)
}

///|
pub fn type_name(v : Value) -> String {
  @value.type_name(v)
}

///|
pub fn truth(v : Value) -> Bool {
  @value.truth(v)
}

///|
pub fn starlark_equals(a : Value, b : Value) -> Bool {
  @value.starlark_equals(a, b)
}
