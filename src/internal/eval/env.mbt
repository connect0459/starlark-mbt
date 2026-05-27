///|
priv struct EvalEnv {
  locals : Map[String, @value.Value]
  parent : EvalEnv?
  is_module_scope : Bool
}

///|
priv struct EvalContext {
  thread : Thread
  opts : Options
  global_env : EvalEnv
  load_bound_names : Array[String]
}

///|
fn EvalEnv::new() -> EvalEnv {
  { locals: {}, parent: None, is_module_scope: true }
}

///|
fn EvalEnv::for_module(parent : EvalEnv) -> EvalEnv {
  { locals: {}, parent: Some(parent), is_module_scope: true }
}

///|
fn EvalEnv::with_parent(parent : EvalEnv) -> EvalEnv {
  { locals: {}, parent: Some(parent), is_module_scope: false }
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
fn EvalEnv::collect_local_scopes(
  self : EvalEnv,
) -> Array[Map[String, @value.Value]] {
  let scopes : Array[Map[String, @value.Value]] = []
  let mut current = self
  while !current.is_module_scope {
    scopes.push(current.locals)
    match current.parent {
      None => break
      Some(p) => current = p
    }
  }
  scopes.rev_in_place()
  scopes
}

///|
fn EvalContext::new(thread : Thread, opts : Options) -> EvalContext {
  let base = EvalEnv::new()
  base.bind("None", @value.Value::NoneVal)
  base.bind("True", @value.Value::BoolVal(true))
  base.bind("False", @value.Value::BoolVal(false))
  for name in builtin_names {
    base.bind(
      name,
      @value.Value::BuiltinFuncVal(@value.StarlarkBuiltinFunc::dispatch(name)),
    )
  }
  let global_env = EvalEnv::for_module(base)
  { thread, opts, global_env, load_bound_names: [] }
}

///|
fn make_eval_error(ctx : EvalContext, msg : String) -> @errors.EvalError {
  let frames : Array[@errors.CallFrame] = []
  for frame in ctx.thread.call_stack {
    frames.push(frame)
  }
  @errors.EvalError::with_stack(msg, @errors.CallStack::new(frames))
}

///|
fn check_steps(ctx : EvalContext) -> Unit raise EvalErr {
  match ctx.thread.cancel_reason {
    Some(reason) =>
      raise EvalErr(
        make_eval_error(ctx, "Starlark computation cancelled: \{reason}"),
      )
    None => ()
  }
  ctx.thread.steps += 1
  match ctx.thread.max_steps {
    None => ()
    Some(max) =>
      if ctx.thread.steps > max {
        raise EvalErr(make_eval_error(ctx, "step budget exceeded"))
      }
  }
}

///|
fn[T] check(ctx : EvalContext, r : Result[T, String]) -> T raise EvalErr {
  match r {
    Ok(v) => v
    Err(msg) => raise EvalErr(make_eval_error(ctx, msg))
  }
}

///|
fn require_seq(
  ctx : EvalContext,
  v : @value.Value,
) -> @value.StarlarkIterator raise EvalErr {
  match @value.iterate(v) {
    Ok(it) => it
    Err(_) =>
      raise EvalErr(
        make_eval_error(ctx, "got \{@value.type_name(v)}, want iterable"),
      )
  }
}
