///|
priv struct EvalEnv {
  locals : Map[String, @value.Value]
  parent : EvalEnv?
}

///|
priv struct EvalContext {
  thread : Thread
  opts : Options
  global_env : EvalEnv
}

///|
fn EvalEnv::new() -> EvalEnv {
  { locals: {}, parent: None }
}

///|
fn EvalEnv::with_parent(parent : EvalEnv) -> EvalEnv {
  { locals: {}, parent: Some(parent) }
}

///|
fn EvalEnv::lookup(self : EvalEnv, name : String) -> @value.Value? {
  match self.locals.get(name) {
    Some(v) => Some(v)
    None =>
      match self.parent {
        None => None
        Some(p) => p.lookup(name)
      }
  }
}

///|
fn EvalEnv::bind(self : EvalEnv, name : String, v : @value.Value) -> Unit {
  self.locals[name] = v
}

///|
fn EvalContext::new(thread : Thread, opts : Options) -> EvalContext {
  let base = EvalEnv::new()
  base.bind("None", @value.Value::NoneVal)
  base.bind("True", @value.Value::BoolVal(true))
  base.bind("False", @value.Value::BoolVal(false))
  let builtin_names = [
    "print", "len", "str", "repr", "type", "range", "list", "tuple", "dict", "bool",
    "int", "float", "abs", "min", "max", "set", "enumerate", "zip", "sorted", "reversed",
    "hasattr", "getattr", "fail", "any", "all", "hash", "dir", "chr", "ord", "bytes",
    "module",
  ]
  for name in builtin_names {
    base.bind(name, @value.Value::BuiltinFuncVal({ name, }))
  }
  let global_env = EvalEnv::with_parent(base)
  { thread, opts, global_env }
}

///|
fn make_eval_error(ctx : EvalContext, msg : String) -> @errors.EvalError {
  let frames : Array[@errors.CallFrame] = []
  for frame in ctx.thread.call_stack {
    frames.push(frame)
  }
  { msg, call_stack: @errors.CallStack::new(frames), cause: None }
}

///|
fn[T] check(ctx : EvalContext, r : Result[T, String]) -> T raise EvalErr {
  match r {
    Ok(v) => v
    Err(msg) => raise EvalErr(make_eval_error(ctx, msg))
  }
}
