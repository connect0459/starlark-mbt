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
pub type StarlarkList = @value.StarlarkList

///|
pub type StarlarkString = @value.StarlarkString

///|
pub type StarlarkIterator = @value.StarlarkIterator

///|
pub type EvalError = @errors.EvalError

///|
pub type SyntaxError = @errors.SyntaxError

///|
pub type ResolveError = @errors.ResolveError

///|
pub type Position = @errors.Position

///|
pub type CallFrame = @errors.CallFrame

///|
pub type CallStack = @errors.CallStack

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

///|
pub fn equal(a : Value, b : Value) -> Result[Bool, EvalError] {
  Ok(@value.starlark_equals(a, b))
}

///|
pub fn number_to_int(v : Value) -> Int64? {
  match v {
    @value.Value::Int(n) => Some(n)
    @value.Value::Float(f) => Some(f.to_int64())
    _ => None
  }
}

///|
pub fn as_float(v : Value) -> (Double, Bool) {
  match v {
    @value.Value::Float(f) => (f, true)
    @value.Value::Int(n) => (n.to_double(), true)
    _ => (0.0, false)
  }
}

///|
pub fn as_string(v : Value) -> (String, Bool) {
  match v {
    @value.Value::String(s) => (s.raw(), true)
    _ => ("", false)
  }
}

///|
pub fn len_of(v : Value) -> Int {
  match @value.length_of(v) {
    Ok(n) => n
    Err(_) => -1
  }
}

///|
pub fn iterate(v : Value) -> Result[StarlarkIterator, EvalError] {
  match @value.iterate(v) {
    Ok(it) => Ok(it)
    Err(msg) => Err(@errors.EvalError::simple(msg))
  }
}

///|
pub fn call(
  thread : Thread,
  func : Value,
  args : Array[Value],
  kwargs : Array[(String, Value)],
) -> Result[Value, EvalError] {
  @eval.call(thread, func, args, kwargs)
}
