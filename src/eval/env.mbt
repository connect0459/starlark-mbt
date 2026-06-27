///|
/// The runtime error raised during evaluation, wrapping a structured
/// `@errors.EvalError` (message + call-stack backtrace).
priv suberror EvalErr {
  EvalErr(@errors.EvalError)
}

///|
/// A two-level name environment: per-execution bindings (a custom universe,
/// per-call predeclared values, or an expression `env`) layered over a base of
/// the universal constants and the builtins. Used only to resolve predeclared
/// and universal names for the VM; module globals live in the VM's own slot
/// array, not here.
priv struct EvalEnv {
  locals : Map[String, @value.Value]
  parent : EvalEnv?
}

///|
priv struct EvalContext {
  thread : Thread
  opts : Options
  global_env : EvalEnv
  // The bytecode VM driving execution, so a builtin that calls back into a
  // compiled function (e.g. `sorted(iterable, key)`) re-enters the VM.
  mut vm : VM?
}

///|
fn EvalEnv::new() -> EvalEnv {
  { locals: {}, parent: None }
}

///|
fn EvalEnv::for_module(parent : EvalEnv) -> EvalEnv {
  { locals: {}, parent: Some(parent) }
}

///|
/// Resolves `name`, searching this environment then its parent; `None` if
/// unbound.
fn EvalEnv::lookup(self : EvalEnv, name : String) -> @value.Value? {
  match self.locals.get(name) {
    Some(v) => Some(v)
    None =>
      match self.parent {
        Some(p) => p.lookup(name)
        None => None
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
  { thread, opts, global_env, vm: None }
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
          None => {
            ctx.thread.cancel("too many steps")
            raise EvalErr(
              make_eval_error(
                ctx, "Starlark computation cancelled: too many steps",
              ),
            )
          }
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
fn[T] check_pfx(
  ctx : EvalContext,
  prefix : String,
  r : Result[T, String],
) -> T raise EvalErr {
  match r {
    Ok(v) => v
    Err(msg) => raise EvalErr(make_eval_error(ctx, "\{prefix}: \{msg}"))
  }
}

///|
fn require_seq(
  ctx : EvalContext,
  name : String,
  v : @value.Value,
) -> @value.StarlarkIterator raise EvalErr {
  match @value.iterate(v) {
    Ok(it) => it
    Err(_) =>
      raise EvalErr(
        make_eval_error(
          ctx,
          "\{name}: for parameter 1: got \{v.type_name()}, want iterable",
        ),
      )
  }
}

///|
/// Raises a graceful error when `v` is a `Range` whose length would exceed the
/// backend-specific allocation cap (`max_alloc_elems`). Must be called before
/// any `require_seq(…).collect()` or equivalent unbounded collect loop so that
/// oversized ranges fail gracefully instead of triggering an OS overcommit
/// page-fault on the native backend.
fn guard_range_alloc(
  ctx : EvalContext,
  caller : String,
  v : @value.Value,
) -> Unit raise EvalErr {
  if v is @value.Value::Range(r) {
    let len = r.length()
    if len < 0L {
      raise EvalErr(
        make_eval_error(
          ctx,
          "\{caller}: excessive sequence (range length overflows)",
        ),
      )
    }
    if len >= max_alloc_elems.to_int64() {
      raise EvalErr(
        make_eval_error(ctx, "\{caller}: excessive sequence (\{len} elements)"),
      )
    }
  }
}

///|
/// Raises a graceful error when `current_len` — the current element count of
/// an accumulator container — has reached the backend-specific allocation cap
/// (`max_alloc_elems`). Call sites differ by opcode semantics:
///
/// - `Append`: called unconditionally, because every append grows the list.
/// - `SetAdd` / `SetDict`: called only when the element or key is absent,
///   so that updating an existing entry does not trigger a spurious guard
///   error.
/// - `SetDictUniq`: the duplicate-key check runs first; this guard is called
///   only after confirming the key is absent (i.e., when the dict will
///   actually grow).
fn guard_accum_alloc(
  ctx : EvalContext,
  caller : String,
  current_len : Int,
) -> Unit raise EvalErr {
  if current_len >= max_alloc_elems {
    raise EvalErr(
      make_eval_error(
        ctx,
        "\{caller}: excessive sequence (\{current_len + 1} elements)",
      ),
    )
  }
}
