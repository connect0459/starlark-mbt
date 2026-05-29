///|
priv enum LookupResult {
  LFound(@value.Value)
  LUnbound(String)
  LNotFound
}

///|
priv struct EvalEnv {
  locals : Map[String, @value.Value]
  known_locals : Array[String]
  parent : EvalEnv?
  is_module_scope : Bool
}

///|
priv struct EvalContext {
  thread : Thread
  opts : Options
  global_env : EvalEnv
  load_bound_names : Array[String]
  mut toplevel_frame_idx : Int
}

///|
fn EvalEnv::new() -> EvalEnv {
  { locals: {}, known_locals: [], parent: None, is_module_scope: true }
}

///|
fn EvalEnv::for_module(parent : EvalEnv) -> EvalEnv {
  { locals: {}, known_locals: [], parent: Some(parent), is_module_scope: true }
}

///|
fn EvalEnv::with_parent(parent : EvalEnv) -> EvalEnv {
  { locals: {}, known_locals: [], parent: Some(parent), is_module_scope: false }
}

///|
fn EvalEnv::with_parent_and_known_locals(
  parent : EvalEnv,
  known_locals : Array[String],
) -> EvalEnv {
  { locals: {}, known_locals, parent: Some(parent), is_module_scope: false }
}

///|
fn EvalEnv::lookup(self : EvalEnv, name : String) -> LookupResult {
  match self.locals.get(name) {
    Some(v) => LFound(v)
    None =>
      if !self.is_module_scope && self.known_locals.contains(name) {
        LUnbound(name)
      } else {
        match self.parent {
          None => LNotFound
          Some(p) => p.lookup(name)
        }
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
) -> Array[(Map[String, @value.Value], Array[String])] {
  let scopes : Array[(Map[String, @value.Value], Array[String])] = []
  let mut current = self
  while !current.is_module_scope {
    scopes.push((current.locals, current.known_locals))
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
  base.bind("None", @value.Value::None)
  base.bind("True", @value.Value::Bool(true))
  base.bind("False", @value.Value::Bool(false))
  for name in builtin_names {
    base.bind(
      name,
      @value.Value::Builtin(@value.StarlarkBuiltinFunc::dispatch(name)),
    )
  }
  let global_env = EvalEnv::for_module(base)
  { thread, opts, global_env, load_bound_names: [], toplevel_frame_idx: -1 }
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
        match ctx.thread.on_max_steps {
          Some(cb) => {
            cb(ctx.thread)
            match ctx.thread.cancel_reason {
              Some(reason) =>
                raise EvalErr(
                  make_eval_error(
                    ctx,
                    "Starlark computation cancelled: \{reason}",
                  ),
                )
              None => ()
            }
          }
          None => raise EvalErr(make_eval_error(ctx, "step budget exceeded"))
        }
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
