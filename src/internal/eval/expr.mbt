///|
fn eval_literal(lit : @syntax.LiteralVal) -> @value.Value {
  match lit {
    @syntax.LiteralVal::LitNone => @value.Value::None
    @syntax.LiteralVal::LitBool(b) => @value.Value::Bool(b)
    @syntax.LiteralVal::LitInt(n) => @value.Value::Int(n)
    @syntax.LiteralVal::LitFloat(f) => @value.Value::Float(f)
    @syntax.LiteralVal::LitString(s) =>
      @value.Value::String(@value.StarlarkString::new(s))
    @syntax.LiteralVal::LitBytes(b) => @value.Value::Bytes(b)
  }
}

///|
fn eval_exprs(
  ctx : EvalContext,
  env : EvalEnv,
  elems : Array[@syntax.Expr],
) -> Array[@value.Value] raise EvalErr {
  let items : Array[@value.Value] = []
  for e in elems {
    items.push(eval_expr_node(ctx, env, e))
  }
  items
}

///|
fn eval_expr_node(
  ctx : EvalContext,
  env : EvalEnv,
  expr : @syntax.Expr,
) -> @value.Value raise EvalErr {
  check_steps(ctx)
  match expr {
    @syntax.Expr::ELiteral(lit, _) => eval_literal(lit)
    @syntax.Expr::EIdent(name, pos) =>
      match env.lookup(name) {
        LFound(v) => v
        LUnbound(varname) =>
          raise EvalErr(
            make_eval_error(
              ctx,
              "local variable \{varname} referenced before assignment",
            ),
          )
        LUnboundModule(varname, is_load_local) => {
          let kind = if is_load_local { "local" } else { "global" }
          raise EvalErr(
            make_eval_error(
              ctx,
              "\{kind} variable \{varname} referenced before assignment",
            ),
          )
        }
        LNotFound =>
          raise EvalErr(
            make_eval_error(ctx, "\{pos.to_string()}: undefined: \{name}"),
          )
      }
    @syntax.Expr::EUnary(op, e, pos) => {
      let v = eval_expr_node(ctx, env, e)
      eval_unary(ctx, op, v, pos)
    }
    @syntax.Expr::EBinary(l, @syntax.BinaryOp::OpAnd, r, _) => {
      let lv = eval_expr_node(ctx, env, l)
      if !@value.truth(lv) {
        lv
      } else {
        eval_expr_node(ctx, env, r)
      }
    }
    @syntax.Expr::EBinary(l, @syntax.BinaryOp::OpOr, r, _) => {
      let lv = eval_expr_node(ctx, env, l)
      if @value.truth(lv) {
        lv
      } else {
        eval_expr_node(ctx, env, r)
      }
    }
    @syntax.Expr::EBinary(l, op, r, pos) => {
      let lv = eval_expr_node(ctx, env, l)
      let rv = eval_expr_node(ctx, env, r)
      eval_binary(ctx, lv, op, rv, pos)
    }
    @syntax.Expr::ECond(then_e, cond_e, else_e, _) => {
      let cv = eval_expr_node(ctx, env, cond_e)
      if @value.truth(cv) {
        eval_expr_node(ctx, env, then_e)
      } else {
        eval_expr_node(ctx, env, else_e)
      }
    }
    @syntax.Expr::EList(elems, _) =>
      @value.Value::List(@value.StarlarkList::new(eval_exprs(ctx, env, elems)))
    @syntax.Expr::ETuple(elems, _) =>
      @value.Value::Tuple(eval_exprs(ctx, env, elems))
    @syntax.Expr::EDict(pairs, _) => {
      let d = @value.StarlarkDict::new()
      for pair in pairs {
        let (k_expr, v_expr) = pair
        let k = eval_expr_node(ctx, env, k_expr)
        let v = eval_expr_node(ctx, env, v_expr)
        match check(ctx, d.get(k)) {
          Some(_) =>
            raise EvalErr(
              make_eval_error(ctx, "duplicate key: \{@value.repr(k)}"),
            )
          None => check(ctx, d.set(k, v))
        }
      }
      @value.Value::Dict(d)
    }
    @syntax.Expr::ESet(elems, _) => {
      let s = @value.StarlarkSet::new()
      for e in elems {
        let v = eval_expr_node(ctx, env, e)
        check(ctx, s.add(v))
      }
      @value.Value::Set(s)
    }
    @syntax.Expr::EIndex(e, idx, pos) => {
      let obj = eval_expr_node(ctx, env, e)
      let idx_v = eval_expr_node(ctx, env, idx)
      eval_index(ctx, obj, idx_v, pos)
    }
    @syntax.Expr::ESlice(e, lo_expr, hi_expr, step_expr, _pos) => {
      let obj = eval_expr_node(ctx, env, e)
      let lo_val = match lo_expr {
        None => @value.Value::None
        Some(ex) => eval_expr_node(ctx, env, ex)
      }
      let hi_val = match hi_expr {
        None => @value.Value::None
        Some(ex) => eval_expr_node(ctx, env, ex)
      }
      let step_val = match step_expr {
        None => @value.Value::None
        Some(ex) => eval_expr_node(ctx, env, ex)
      }
      let step = match step_val {
        @value.Value::None => None
        @value.Value::Int(n) =>
          if n > max_int32 || n < min_int32 {
            raise EvalErr(
              make_eval_error(ctx, "invalid slice step: \{n} out of range"),
            )
          } else {
            Some(n.to_int())
          }
        _ =>
          raise EvalErr(
            make_eval_error(
              ctx,
              "invalid slice step: got \{@value.type_name(step_val)}, want int",
            ),
          )
      }
      let lo = match lo_val {
        @value.Value::None => None
        @value.Value::Int(n) =>
          if n > max_int32 || n < min_int32 {
            raise EvalErr(
              make_eval_error(ctx, "invalid start index: \{n} out of range"),
            )
          } else {
            Some(n.to_int())
          }
        _ =>
          raise EvalErr(
            make_eval_error(
              ctx,
              "invalid start index: got \{@value.type_name(lo_val)}, want int",
            ),
          )
      }
      let hi = match hi_val {
        @value.Value::None => None
        @value.Value::Int(n) =>
          if n > max_int32 || n < min_int32 {
            raise EvalErr(
              make_eval_error(ctx, "invalid end index: \{n} out of range"),
            )
          } else {
            Some(n.to_int())
          }
        _ =>
          raise EvalErr(
            make_eval_error(
              ctx,
              "invalid end index: got \{@value.type_name(hi_val)}, want int",
            ),
          )
      }
      eval_slice(ctx, obj, lo, hi, step)
    }
    @syntax.Expr::EDot(obj_expr, attr, pos) => {
      let obj = eval_expr_node(ctx, env, obj_expr)
      eval_getattr(ctx, obj, attr, pos)
    }
    @syntax.Expr::ECall(f_expr, args, pos) =>
      eval_call(ctx, env, f_expr, args, pos)
    @syntax.Expr::ELambda(params, body_expr, pos) => {
      let defaults = eval_defaults(ctx, env, params)
      let body_stmt = @syntax.Stmt::SReturn(Some(body_expr), pos)
      let captured_scope = env.collect_local_scopes()
      let func = @value.StarlarkFunction::new(
        "lambda",
        params,
        [body_stmt],
        defaults,
        captured_scope,
        pos,
      ).with_module_globals(ctx.global_env.locals)
      @value.Value::Function(func)
    }
    @syntax.Expr::EListComp(body_expr, clauses, _) => {
      let result : Array[@value.Value] = []
      let comp_vars = collect_comp_target_names(clauses)
      let comp_env = EvalEnv::with_parent_and_known_locals(env, comp_vars)
      eval_comp_clauses(ctx, env, comp_env, clauses, 0, fn(
        inner_env,
      ) raise EvalErr {
        result.push(eval_expr_node(ctx, inner_env, body_expr))
      })
      @value.Value::List(@value.StarlarkList::new(result))
    }
    @syntax.Expr::ESetComp(body_expr, clauses, _) => {
      let s = @value.StarlarkSet::new()
      let comp_vars = collect_comp_target_names(clauses)
      let comp_env = EvalEnv::with_parent_and_known_locals(env, comp_vars)
      eval_comp_clauses(ctx, env, comp_env, clauses, 0, fn(
        inner_env,
      ) raise EvalErr {
        let v = eval_expr_node(ctx, inner_env, body_expr)
        check(ctx, s.add(v))
      })
      @value.Value::Set(s)
    }
    @syntax.Expr::EDictComp(key_expr, val_expr, clauses, _) => {
      let d = @value.StarlarkDict::new()
      let comp_vars = collect_comp_target_names(clauses)
      let comp_env = EvalEnv::with_parent_and_known_locals(env, comp_vars)
      eval_comp_clauses(ctx, env, comp_env, clauses, 0, fn(
        inner_env,
      ) raise EvalErr {
        let k = eval_expr_node(ctx, inner_env, key_expr)
        let v = eval_expr_node(ctx, inner_env, val_expr)
        check(ctx, d.set(k, v))
      })
      @value.Value::Dict(d)
    }
  }
}

///|
fn eval_defaults(
  ctx : EvalContext,
  env : EvalEnv,
  params : Array[@syntax.Param],
) -> Array[@value.Value?] raise EvalErr {
  let defaults : Array[@value.Value?] = []
  for param in params {
    match param {
      @syntax.Param::ParamDefault(_, default_expr, _) => {
        let dv = eval_expr_node(ctx, env, default_expr)
        defaults.push(Some(dv))
      }
      _ => defaults.push(None)
    }
  }
  defaults
}

///|
fn builtin_type_methods(v : @value.Value) -> Array[String]? {
  match v {
    @value.Value::String(_) =>
      Some([
        "capitalize", "codepoint_ords", "codepoints", "count", "elem_ords", "elems",
        "endswith", "find", "format", "index", "isalnum", "isalpha", "isdigit", "islower",
        "isspace", "istitle", "isupper", "join", "lower", "lstrip", "partition",
        "removeprefix", "removesuffix", "replace", "rfind", "rindex", "rpartition",
        "rsplit", "rstrip", "split", "splitlines", "startswith", "strip", "title",
        "upper",
      ])
    @value.Value::List(_) =>
      Some(["append", "clear", "extend", "index", "insert", "pop", "remove"])
    @value.Value::Dict(_) =>
      Some([
        "clear", "get", "items", "keys", "pop", "popitem", "setdefault", "update",
        "values",
      ])
    @value.Value::Set(_) =>
      Some([
        "add", "clear", "difference", "discard", "intersection", "issubset", "issuperset",
        "pop", "remove", "symmetric_difference", "union", "update",
      ])
    @value.Value::Bytes(_) => Some(["elems"])
    _ => None
  }
}

///|
fn eval_getattr(
  ctx : EvalContext,
  obj : @value.Value,
  attr : String,
  _pos : @errors.Position,
) -> @value.Value raise EvalErr {
  match obj {
    @value.Value::String(_)
    | @value.Value::List(_)
    | @value.Value::Dict(_)
    | @value.Value::Set(_)
    | @value.Value::Bytes(_) => {
      let methods = (builtin_type_methods(obj) : Array[String]?)
      match methods {
        Some(ms) =>
          if ms.contains(attr) {
            @value.Value::BoundMethod(
              @value.StarlarkBoundMethod::new(obj, attr),
            )
          } else {
            let hint = match @utf8util.spell_nearest(attr, ms) {
              "" => ""
              s => " (did you mean .\{s}?)"
            }
            raise EvalErr(
              make_eval_error(
                ctx,
                "\{@value.type_name(obj)} has no .\{attr} field or method\{hint}",
              ),
            )
          }
        None =>
          @value.Value::BoundMethod(@value.StarlarkBoundMethod::new(obj, attr))
      }
    }
    @value.Value::Module(m) =>
      match m.get(attr) {
        Some(v) => v
        None => {
          let candidates = m.attr_names()
          let hint = match @utf8util.spell_nearest(attr, candidates) {
            "" => ""
            s => " (did you mean .\{s}?)"
          }
          raise EvalErr(
            make_eval_error(
              ctx,
              "module has no .\{attr} field or method\{hint}",
            ),
          )
        }
      }
    @value.Value::ExtVal(c) =>
      match c.get_attr(attr) {
        Ok(Some(v)) => v
        Ok(None) =>
          raise EvalErr(
            make_eval_error(
              ctx,
              "\{@value.type_name(obj)} has no .\{attr} field or method",
            ),
          )
        Err(e) => raise EvalErr(make_eval_error(ctx, e))
      }
    _ =>
      raise EvalErr(
        make_eval_error(
          ctx,
          "\{@value.type_name(obj)} has no attribute '\{attr}'",
        ),
      )
  }
}

///|
fn eval_call(
  ctx : EvalContext,
  env : EvalEnv,
  f_expr : @syntax.Expr,
  args : Array[@syntax.Arg],
  pos : @errors.Position,
) -> @value.Value raise EvalErr {
  let func_val = eval_expr_node(ctx, env, f_expr)
  let (pos_args, kw_args) = eval_args(ctx, env, args)
  call_value(ctx, func_val, pos_args, kw_args, pos)
}

///|
fn eval_args(
  ctx : EvalContext,
  env : EvalEnv,
  args : Array[@syntax.Arg],
) -> (Array[@value.Value], Array[(String, @value.Value)]) raise EvalErr {
  let pos_args : Array[@value.Value] = []
  let kw_args : Array[(String, @value.Value)] = []
  for arg in args {
    match arg {
      @syntax.Arg::ArgPos(e) => pos_args.push(eval_expr_node(ctx, env, e))
      @syntax.Arg::ArgKw(name, e, _) =>
        kw_args.push((name, eval_expr_node(ctx, env, e)))
      @syntax.Arg::ArgStarArgs(e) => {
        let v = eval_expr_node(ctx, env, e)
        let it = match @value.iterate(v) {
          Ok(it) => it
          Err(_) =>
            raise EvalErr(
              make_eval_error(
                ctx,
                "argument after * must be iterable, not \{@value.type_name(v)}",
              ),
            )
        }
        while true {
          match it.next() {
            None => {
              it.done()
              break
            }
            Some(item) => pos_args.push(item)
          }
        }
      }
      @syntax.Arg::ArgKwArgs(e) => {
        let v = eval_expr_node(ctx, env, e)
        match v {
          @value.Value::Dict(d) =>
            for entry in d.to_entries() {
              let (k, val) = entry
              match k {
                @value.Value::String(s) => kw_args.push((s.raw(), val))
                _ =>
                  raise EvalErr(
                    make_eval_error(
                      ctx,
                      "keywords must be strings, not \{@value.type_name(k)}",
                    ),
                  )
              }
            }
          _ =>
            raise EvalErr(
              make_eval_error(
                ctx,
                "argument after ** must be a mapping, not \{@value.type_name(v)}",
              ),
            )
        }
      }
    }
  }
  (pos_args, kw_args)
}

///|
fn call_value(
  ctx : EvalContext,
  func_val : @value.Value,
  pos_args : Array[@value.Value],
  kw_args : Array[(String, @value.Value)],
  pos : @errors.Position,
) -> @value.Value raise EvalErr {
  let depth = ctx.thread.call_stack.length()
  if depth > 0 {
    let caller = ctx.thread.call_stack[depth - 1]
    ctx.thread.call_stack[depth - 1] = @errors.CallFrame::new(
      caller.name(),
      pos,
    )
  }
  match func_val {
    @value.Value::Function(f) => call_func(ctx, f, pos_args, kw_args, pos)
    @value.Value::Builtin(f) => {
      let builtin_frame = @errors.CallFrame::new(
        f.name(),
        @errors.Position::new("<builtin>", 0, 0),
      )
      ctx.thread.call_stack.push(builtin_frame)
      let call_ctx = @value.BuiltinCallCtx::new(
        fn(f2, args, kwargs) {
          Ok(call_value(ctx, f2, args, kwargs, pos)) catch {
            EvalErr(e) => Err(e.msg())
          }
        },
        get_local=fn(k) { ctx.thread.get_local(k) },
      )
      let result : @value.Value = try {
        match f.call_body(call_ctx, pos_args, kw_args) {
          Some(Ok(v)) => v
          Some(Err(msg)) => raise EvalErr(make_eval_error(ctx, msg))
          None => call_builtin(ctx, f.name(), pos_args, kw_args, pos)
        }
      } catch {
        EvalErr(e) => {
          ignore(ctx.thread.call_stack.pop())
          raise EvalErr(e)
        }
      }
      ignore(ctx.thread.call_stack.pop())
      result
    }
    @value.Value::BoundMethod(m) => {
      let builtin_frame = @errors.CallFrame::new(
        m.method_name(),
        @errors.Position::new("<builtin>", 0, 0),
      )
      ctx.thread.call_stack.push(builtin_frame)
      let result : @value.Value = call_method(
        ctx,
        m.recv(),
        m.method_name(),
        pos_args,
        kw_args,
        pos,
      ) catch {
        EvalErr(e) => {
          ignore(ctx.thread.call_stack.pop())
          raise EvalErr(e)
        }
      }
      ignore(ctx.thread.call_stack.pop())
      result
    }
    @value.Value::ExtVal(c) =>
      match c.do_call(pos_args, kw_args) {
        Some(Ok(v)) => v
        Some(Err(msg)) => raise EvalErr(make_eval_error(ctx, msg))
        None =>
          raise EvalErr(
            make_eval_error(
              ctx,
              "invalid call of non-function (\{c.get_type_name()})",
            ),
          )
      }
    _ =>
      raise EvalErr(
        make_eval_error(
          ctx,
          "invalid call of non-function (\{@value.type_name(func_val)})",
        ),
      )
  }
}

///|
fn call_func(
  ctx : EvalContext,
  f : @value.StarlarkFunction,
  pos_args : Array[@value.Value],
  kw_args : Array[(String, @value.Value)],
  pos : @errors.Position,
) -> @value.Value raise EvalErr {
  if !ctx.opts.allow_recursion {
    let fpos = f.position()
    for frame in ctx.thread.debug_stack {
      match frame.func_val {
        @value.Value::Function(g) => {
          let gpos = g.position()
          if fpos.line() == gpos.line() &&
            fpos.col() == gpos.col() &&
            fpos.filename() == gpos.filename() {
            raise EvalErr(
              make_eval_error(ctx, "function \{f.name()} called recursively"),
            )
          }
        }
        _ => ()
      }
    }
  }
  if ctx.thread.call_stack.length() >= ctx.thread.max_recursion_depth {
    raise EvalErr(make_eval_error(ctx, "maximum recursion depth exceeded"))
  }
  let frame : @errors.CallFrame = @errors.CallFrame::new(f.name(), pos)
  ctx.thread.call_stack.push(frame)
  try {
    let mut parent = ctx.global_env
    for pair in f.captured_scope() {
      let scope_env : EvalEnv = {
        locals: pair.0,
        known_locals: pair.1,
        known_module_globals: {},
        parent: Some(parent),
        is_module_scope: false,
      }
      parent = scope_env
    }
    let known_locals = collect_assigned_names(f.body())
    let func_env = EvalEnv::with_parent_and_known_locals(parent, known_locals)
    let all_local_names = collect_all_local_names(f, known_locals)
    ctx.thread.debug_stack.push(ActiveCallFrame::{
      func_val: @value.Value::Function(f),
      all_local_names,
      locals_map: func_env.locals,
    })
    bind_args(ctx, f, pos_args, kw_args, func_env, pos)
    let sig = exec_stmts(ctx, func_env, f.body())
    ignore(ctx.thread.call_stack.pop())
    ignore(ctx.thread.debug_stack.pop())
    match sig {
      Signal::SigReturn(v) => v
      _ => @value.Value::None
    }
  } catch {
    EvalErr(e) => {
      ignore(ctx.thread.call_stack.pop())
      ignore(ctx.thread.debug_stack.pop())
      raise EvalErr(e)
    }
  }
}

///|
fn count_max_positional(params : Array[@syntax.Param]) -> Int {
  let mut n = 0
  for p in params {
    match p {
      @syntax.Param::ParamIdent(_, _) | @syntax.Param::ParamDefault(_, _, _) =>
        n += 1
      @syntax.Param::ParamStarBare(_) | @syntax.Param::ParamStarIdent(_, _) =>
        break
      _ => ()
    }
  }
  n
}

///|
fn has_optional_pos(params : Array[@syntax.Param]) -> Bool {
  for p in params {
    match p {
      @syntax.Param::ParamDefault(_, _, _) => return true
      @syntax.Param::ParamStarBare(_) | @syntax.Param::ParamStarIdent(_, _) =>
        break
      _ => ()
    }
  }
  false
}

///|
fn pos_arg_count_msg(max_pos : Int, given : Int, has_opt : Bool) -> String {
  let atmost = if has_opt { "at most " } else { "" }
  let arg_word = if max_pos == 1 { "argument" } else { "arguments" }
  "\{atmost}\{max_pos} positional \{arg_word} (\{given} given)"
}

///|
fn bind_args(
  ctx : EvalContext,
  f : @value.StarlarkFunction,
  pos_args : Array[@value.Value],
  kw_args : Array[(String, @value.Value)],
  func_env : EvalEnv,
  _pos : @errors.Position,
) -> Unit raise EvalErr {
  let params = f.params()
  if params.length() == 0 {
    let nactual = pos_args.length() + kw_args.length()
    if nactual > 0 {
      raise EvalErr(
        make_eval_error(
          ctx,
          "function \{f.name()} accepts no arguments (\{nactual} given)",
        ),
      )
    }
    return
  }
  let kw_map : Map[String, @value.Value] = {}
  for kw_pair in kw_args {
    let (kw_name, kw_val) = kw_pair
    if kw_map.contains(kw_name) {
      raise EvalErr(
        make_eval_error(
          ctx,
          "function \{f.name()} got multiple values for parameter \"\{kw_name}\"",
        ),
      )
    }
    kw_map[kw_name] = kw_val
  }
  let defaults = f.defaults()
  let mut pos_idx = 0
  let mut param_idx = 0
  let mut passed_star = false
  let mut had_kwargs_param = false
  let missing_required : Array[String] = []
  while param_idx < params.length() {
    match params[param_idx] {
      @syntax.Param::ParamIdent(name, _) =>
        if pos_idx < pos_args.length() && !passed_star {
          if kw_map.contains(name) {
            raise EvalErr(
              make_eval_error(
                ctx,
                "function \{f.name()} got multiple values for parameter \"\{name}\"",
              ),
            )
          }
          func_env.bind(name, pos_args[pos_idx])
          pos_idx += 1
          param_idx += 1
        } else if kw_map.contains(name) {
          func_env.bind(name, kw_map[name])
          kw_map.remove(name)
          param_idx += 1
        } else if param_idx < defaults.length() &&
          defaults[param_idx] is Some(dv) {
          func_env.bind(name, dv)
          param_idx += 1
        } else {
          missing_required.push(name)
          param_idx += 1
        }
      @syntax.Param::ParamDefault(name, _, _) =>
        if pos_idx < pos_args.length() && !passed_star {
          if kw_map.contains(name) {
            raise EvalErr(
              make_eval_error(
                ctx,
                "function \{f.name()} got multiple values for parameter \"\{name}\"",
              ),
            )
          }
          func_env.bind(name, pos_args[pos_idx])
          pos_idx += 1
          param_idx += 1
        } else if kw_map.contains(name) {
          func_env.bind(name, kw_map[name])
          kw_map.remove(name)
          param_idx += 1
        } else if param_idx < defaults.length() {
          match defaults[param_idx] {
            Some(dv) => func_env.bind(name, dv)
            None => missing_required.push(name)
          }
          param_idx += 1
        } else {
          param_idx += 1
        }
      @syntax.Param::ParamStarIdent(name, _) => {
        passed_star = true
        let rest : Array[@value.Value] = []
        while pos_idx < pos_args.length() {
          rest.push(pos_args[pos_idx])
          pos_idx += 1
        }
        func_env.bind(name, @value.Value::Tuple(rest))
        param_idx += 1
      }
      @syntax.Param::ParamStarBare(_) => {
        passed_star = true
        let max_pos = count_max_positional(params)
        if pos_idx < pos_args.length() {
          let has_opt = has_optional_pos(params)
          raise EvalErr(
            make_eval_error(
              ctx,
              "function \{f.name()} accepts \{pos_arg_count_msg(max_pos, pos_args.length(), has_opt)}",
            ),
          )
        }
        param_idx += 1
      }
      @syntax.Param::ParamKwIdent(name, _) => {
        had_kwargs_param = true
        let kw_dict = @value.StarlarkDict::new()
        kw_map.each(fn(kw_name, kw_val) {
          let key = @value.Value::String(@value.StarlarkString::new(kw_name))
          ignore(kw_dict.set(key, kw_val))
        })
        kw_map.clear()
        func_env.bind(name, @value.Value::Dict(kw_dict))
        param_idx += 1
      }
    }
  }
  if pos_idx < pos_args.length() && !passed_star {
    let max_pos = count_max_positional(params)
    let has_opt = has_optional_pos(params)
    raise EvalErr(
      make_eval_error(
        ctx,
        "function \{f.name()} accepts \{pos_arg_count_msg(max_pos, pos_args.length(), has_opt)}",
      ),
    )
  }
  if !had_kwargs_param && kw_map.length() > 0 {
    let mut first_key = ""
    kw_map.each(fn(k, _) { if first_key == "" { first_key = k } })
    let valid_names : Array[String] = []
    for p in f.params() {
      match p {
        @syntax.Param::ParamIdent(name, _) => valid_names.push(name)
        @syntax.Param::ParamDefault(name, _, _) => valid_names.push(name)
        _ => ()
      }
    }
    let hint = match @utf8util.spell_nearest(first_key, valid_names) {
      "" => ""
      s => " (did you mean \{s}?)"
    }
    raise EvalErr(
      make_eval_error(
        ctx,
        "function \{f.name()} got an unexpected keyword argument \"\{first_key}\"\{hint}",
      ),
    )
  }
  if !missing_required.is_empty() {
    let n = missing_required.length()
    let names = missing_required.join(", ")
    let arg_word = if n == 1 { "argument" } else { "arguments" }
    raise EvalErr(
      make_eval_error(
        ctx,
        "function \{f.name()} missing \{n} \{arg_word} (\{names})",
      ),
    )
  }
}

///|
fn call_builtin(
  ctx : EvalContext,
  name : String,
  pos_args : Array[@value.Value],
  kw_args : Array[(String, @value.Value)],
  _pos : @errors.Position,
) -> @value.Value raise EvalErr {
  match name {
    "print" => {
      let sep = {
        let mut found = " "
        for kv in kw_args {
          let (k, v) = kv
          match k {
            "sep" =>
              match v {
                @value.Value::String(s) => found = s.raw()
                _ =>
                  raise EvalErr(
                    make_eval_error(
                      ctx,
                      "print: for parameter \"\{k}\": got \{@value.type_name(v)}, want string",
                    ),
                  )
              }
            other =>
              raise EvalErr(
                make_eval_error(
                  ctx,
                  "print: unexpected keyword argument \"\{other}\"",
                ),
              )
          }
        }
        found
      }
      let buf = StringBuilder::new()
      let mut first = true
      for arg in pos_args {
        if !first {
          buf.write_string(sep)
        }
        first = false
        match arg {
          @value.Value::Bytes(b) =>
            buf.write_string(@value.StarlarkString::from_bytes(b).raw())
          _ => buf.write_string(@value.to_str(arg))
        }
      }
      (ctx.thread.print_fn)(ctx.thread, buf.to_string())
      @value.Value::None
    }
    "len" => {
      check_positional(ctx, "len", pos_args, kw_args, 1, 1)
      let n = check(ctx, @value.length_of(pos_args[0]))
      @value.Value::Int(BigInt::from_int(n))
    }
    "str" =>
      if pos_args.length() == 0 {
        raise EvalErr(
          make_eval_error(ctx, "str: got 0 arguments, want exactly 1"),
        )
      } else if pos_args.length() == 1 {
        match pos_args[0] {
          @value.Value::Bytes(b) =>
            @value.Value::String(
              @value.StarlarkString::new(
                @value.StarlarkString::from_bytes(b).raw(),
              ),
            )
          v =>
            @value.Value::String(@value.StarlarkString::new(@value.to_str(v)))
        }
      } else {
        raise EvalErr(
          make_eval_error(
            ctx,
            "str: got \{pos_args.length()} arguments, want exactly 1",
          ),
        )
      }
    "repr" => {
      check_positional(ctx, "repr", pos_args, kw_args, 1, 1)
      @value.Value::String(@value.StarlarkString::new(@value.repr(pos_args[0])))
    }
    "type" => {
      reject_kwargs(ctx, "type", kw_args)
      if pos_args.length() != 1 {
        raise EvalErr(make_eval_error(ctx, "type() takes exactly one argument"))
      }
      @value.Value::String(
        @value.StarlarkString::new(@value.type_name(pos_args[0])),
      )
    }
    "bool" => {
      check_positional(ctx, "bool", pos_args, kw_args, 0, 1)
      if pos_args.length() == 0 {
        @value.Value::Bool(false)
      } else {
        @value.Value::Bool(@value.truth(pos_args[0]))
      }
    }
    "int" => {
      if pos_args.length() > 2 {
        raise EvalErr(
          make_eval_error(
            ctx,
            "int: got \{pos_args.length()} arguments, want at most 2",
          ),
        )
      }
      let mut x_from_kw : @value.Value? = None
      let mut base_from_kw : @value.Value? = None
      for kv in kw_args {
        match kv.0 {
          "x" => {
            if pos_args.length() >= 1 {
              raise EvalErr(
                make_eval_error(
                  ctx, "int: got multiple values for keyword argument x",
                ),
              )
            }
            x_from_kw = Some(kv.1)
          }
          "base" => base_from_kw = Some(kv.1)
          name =>
            raise EvalErr(
              make_eval_error(ctx, "int: unexpected keyword argument \{name}"),
            )
        }
      }
      let x_val = match x_from_kw {
        Some(v) => v
        None =>
          if pos_args.length() >= 1 {
            pos_args[0]
          } else {
            raise EvalErr(make_eval_error(ctx, "int: missing argument for x"))
          }
      }
      let base_arg : @value.Value? = match base_from_kw {
        Some(v) => Some(v)
        None => if pos_args.length() >= 2 { Some(pos_args[1]) } else { None }
      }
      match x_val {
        @value.Value::String(s) => {
          let base = match base_arg {
            None => 10
            Some(@value.Value::Int(b)) => b.to_int()
            Some(v) =>
              raise EvalErr(
                make_eval_error(
                  ctx,
                  "int: for base, got \{@value.type_name(v)}, want int",
                ),
              )
          }
          if base != 0 && (base < 2 || base > 36) {
            raise EvalErr(
              make_eval_error(ctx, "int: base must be an integer >= 2 && <= 36"),
            )
          }
          let n = match parse_int_str(s.raw(), base) {
            Ok(n) => n
            Err(msg) => raise EvalErr(make_eval_error(ctx, "int: " + msg))
          }
          @value.Value::Int(n)
        }
        other =>
          match base_arg {
            Some(_) =>
              raise EvalErr(
                make_eval_error(
                  ctx, "int: can't convert non-string with explicit base",
                ),
              )
            None =>
              match other {
                @value.Value::Int(n) => @value.Value::Int(n)
                @value.Value::Float(f) =>
                  if f.is_nan() {
                    raise EvalErr(
                      make_eval_error(
                        ctx, "int: cannot convert float NaN to integer",
                      ),
                    )
                  } else if f.is_inf() {
                    raise EvalErr(
                      make_eval_error(
                        ctx, "int: cannot convert float infinity to integer",
                      ),
                    )
                  } else {
                    @value.Value::Int(@value.double_to_bigint(f.trunc()))
                  }
                @value.Value::Bool(b) =>
                  @value.Value::Int(if b { 1N } else { 0N })
                v =>
                  raise EvalErr(
                    make_eval_error(
                      ctx,
                      "int: cannot convert \{@value.type_name(v)} to int",
                    ),
                  )
              }
          }
      }
    }
    "float" => {
      if kw_args.length() > 0 {
        raise EvalErr(
          make_eval_error(ctx, "float does not accept keyword arguments"),
        )
      }
      if pos_args.length() > 1 {
        raise EvalErr(
          make_eval_error(
            ctx,
            "float got \{pos_args.length()} arguments, wants 1",
          ),
        )
      }
      if pos_args.length() == 0 {
        @value.Value::Float(0.0)
      } else {
        match pos_args[0] {
          @value.Value::Float(f) => @value.Value::Float(f)
          @value.Value::Int(n) =>
            match @value.bigint_to_finite_double(n) {
              Ok(f) => @value.Value::Float(f)
              Err(msg) => raise EvalErr(make_eval_error(ctx, msg))
            }
          @value.Value::Bool(b) =>
            @value.Value::Float(if b { 1.0 } else { 0.0 })
          @value.Value::String(s) => {
            let raw = s.raw()
            if raw.length() == 0 {
              raise EvalErr(make_eval_error(ctx, "float: empty string"))
            }
            let f = match raw.to_lower() {
              "inf" | "+inf" | "infinity" | "+infinity" => @double.infinity
              "-inf" | "-infinity" => @double.neg_infinity
              "nan" | "+nan" | "-nan" => @double.not_a_number
              _ => {
                let parsed = @string.parse_double(raw) catch {
                  _ => {
                    let msg = if is_float_syntax(raw) {
                      "floating-point number too large"
                    } else {
                      "invalid float literal: \{raw}"
                    }
                    raise EvalErr(make_eval_error(ctx, msg))
                  }
                }
                if parsed.is_inf() {
                  raise EvalErr(
                    make_eval_error(ctx, "floating-point number too large"),
                  )
                }
                parsed
              }
            }
            @value.Value::Float(f)
          }
          v =>
            raise EvalErr(
              make_eval_error(
                ctx,
                "float got \{@value.type_name(v)}, want number or string",
              ),
            )
        }
      }
    }
    "abs" => {
      check_positional(ctx, "abs", pos_args, kw_args, 1, 1)
      match pos_args[0] {
        @value.Value::Int(n) => @value.Value::Int(if n < 0N { -n } else { n })
        @value.Value::Float(f) => @value.Value::Float(f.abs())
        v =>
          raise EvalErr(
            make_eval_error(
              ctx,
              "got \{@value.type_name(v)}, want int or float",
            ),
          )
      }
    }
    "range" => builtin_range(ctx, pos_args, kw_args)
    "list" => {
      check_positional(ctx, "list", pos_args, kw_args, 0, 1)
      builtin_list(ctx, pos_args)
    }
    "tuple" => {
      check_positional(ctx, "tuple", pos_args, kw_args, 0, 1)
      builtin_tuple(ctx, pos_args)
    }
    "dict" => builtin_dict(ctx, pos_args, kw_args)
    "set" => {
      check_positional(ctx, "set", pos_args, kw_args, 0, 1)
      builtin_set(ctx, pos_args)
    }
    "bytes" => {
      reject_kwargs(ctx, "bytes", kw_args)
      builtin_bytes(ctx, pos_args)
    }
    "min" => builtin_minmax(ctx, pos_args, kw_args, false)
    "max" => builtin_minmax(ctx, pos_args, kw_args, true)
    "enumerate" => builtin_enumerate(ctx, pos_args, kw_args)
    "sorted" => builtin_sorted(ctx, pos_args, kw_args)
    "reversed" => {
      check_positional(ctx, "reversed", pos_args, kw_args, 1, 1)
      builtin_reversed(ctx, pos_args)
    }
    "zip" => {
      reject_kwargs(ctx, "zip", kw_args)
      builtin_zip(ctx, pos_args)
    }
    "any" => {
      check_positional(ctx, "any", pos_args, kw_args, 1, 1)
      builtin_any_all(ctx, pos_args, true)
    }
    "all" => {
      check_positional(ctx, "all", pos_args, kw_args, 1, 1)
      builtin_any_all(ctx, pos_args, false)
    }
    "hash" => {
      check_positional(ctx, "hash", pos_args, kw_args, 1, 1)
      match pos_args[0] {
        @value.Value::String(s) =>
          @value.Value::Int(
            BigInt::from_int64(@value.java_string_hash(s).to_int64()),
          )
        @value.Value::Bytes(b) => {
          let h = check(ctx, @value.starlark_hash(@value.Value::Bytes(b)))
          @value.Value::Int(BigInt::from_int64(h.to_int64()))
        }
        v =>
          raise EvalErr(
            make_eval_error(
              ctx,
              "hash: got \{@value.type_name(v)}, want string or bytes",
            ),
          )
      }
    }
    "dir" => {
      reject_kwargs(ctx, "dir", kw_args)
      if pos_args.length() != 1 {
        raise EvalErr(
          make_eval_error(
            ctx,
            "dir: got \{pos_args.length()} arguments, want 1",
          ),
        )
      }
      let names : Array[String] = match pos_args[0] {
        @value.Value::String(_) =>
          [
            "capitalize", "codepoint_ords", "codepoints", "count", "elem_ords", "elems",
            "endswith", "find", "format", "index", "isalnum", "isalpha", "isdigit",
            "islower", "isspace", "istitle", "isupper", "join", "lower", "lstrip",
            "partition", "removeprefix", "removesuffix", "replace", "rfind", "rindex",
            "rpartition", "rsplit", "rstrip", "split", "splitlines", "startswith",
            "strip", "title", "upper",
          ]
        @value.Value::List(_) =>
          ["append", "clear", "extend", "index", "insert", "pop", "remove"]
        @value.Value::Dict(_) =>
          [
            "clear", "get", "items", "keys", "pop", "popitem", "setdefault", "update",
            "values",
          ]
        @value.Value::Set(_) =>
          [
            "add", "clear", "difference", "discard", "intersection", "issubset",
            "issuperset", "pop", "remove", "symmetric_difference", "union", "update",
          ]
        @value.Value::Bytes(_) => ["elems"]
        @value.Value::Module(m) => {
          let keys : Array[String] = m.attr_names()
          keys.sort_by(fn(a, b) {
            let av = @value.Value::String(@value.StarlarkString::new(a))
            let bv = @value.Value::String(@value.StarlarkString::new(b))
            match @value.compare_values(av, bv) {
              Ok(c) => c
              Err(_) => 0
            }
          })
          keys
        }
        @value.Value::ExtVal(c) =>
          match c.get_attr_names() {
            Some(names) => {
              names.sort_by(fn(a, b) {
                let av = @value.Value::String(@value.StarlarkString::new(a))
                let bv = @value.Value::String(@value.StarlarkString::new(b))
                match @value.compare_values(av, bv) {
                  Ok(cmp) => cmp
                  Err(_) => 0
                }
              })
              names
            }
            None => []
          }
        _ => []
      }
      let items = names.map(fn(n) {
        @value.Value::String(@value.StarlarkString::new(n))
      })
      @value.Value::List(@value.StarlarkList::new(items))
    }
    "chr" => {
      reject_kwargs(ctx, "chr", kw_args)
      if pos_args.length() != 1 {
        raise EvalErr(
          make_eval_error(
            ctx,
            "chr: got \{pos_args.length()} arguments, want 1",
          ),
        )
      }
      match pos_args[0] {
        @value.Value::Int(n) => {
          if n < 0N {
            raise EvalErr(
              make_eval_error(
                ctx,
                "chr: Unicode code point \{n} out of range (<0)",
              ),
            )
          } else if n > unicode_max_cp_bigint {
            raise EvalErr(
              make_eval_error(
                ctx,
                "chr: Unicode code point U+\{int64_to_hex(n, true)} out of range (>0x10FFFF)",
              ),
            )
          }
          let c = n.to_int().unsafe_to_char()
          let buf = StringBuilder::new()
          buf.write_char(c)
          @value.Value::String(@value.StarlarkString::new(buf.to_string()))
        }
        v =>
          raise EvalErr(
            make_eval_error(ctx, "chr: got \{@value.type_name(v)}, want int"),
          )
      }
    }
    "ord" => {
      reject_kwargs(ctx, "ord", kw_args)
      if pos_args.length() != 1 {
        raise EvalErr(
          make_eval_error(
            ctx,
            "ord: got \{pos_args.length()} arguments, want 1",
          ),
        )
      }
      match pos_args[0] {
        @value.Value::String(s) => {
          let chars = s.raw().to_array()
          if chars.length() != 1 {
            raise EvalErr(
              make_eval_error(
                ctx,
                "ord: string encodes \{chars.length()} Unicode code points, want 1",
              ),
            )
          }
          @value.Value::Int(BigInt::from_int(chars[0].to_int()))
        }
        @value.Value::Bytes(b) => {
          if b.length() != 1 {
            raise EvalErr(
              make_eval_error(
                ctx,
                "ord: bytes has length \{b.length()}, want 1",
              ),
            )
          }
          @value.Value::Int(BigInt::from_int(b[0].to_int()))
        }
        v =>
          raise EvalErr(
            make_eval_error(
              ctx,
              "ord: got \{@value.type_name(v)}, want string or bytes",
            ),
          )
      }
    }
    "fail" => {
      let sep = {
        let mut s = " "
        for kv in kw_args {
          let (k, v) = kv
          match k {
            "sep" =>
              match v {
                @value.Value::String(sv) => s = sv.raw()
                _ =>
                  raise EvalErr(
                    make_eval_error(
                      ctx,
                      "fail: for parameter \"sep\": got \{@value.type_name(v)}, want string",
                    ),
                  )
              }
            other =>
              raise EvalErr(
                make_eval_error(
                  ctx,
                  "fail: unexpected keyword argument \"\{other}\"",
                ),
              )
          }
        }
        s
      }
      let body = if pos_args.length() > 0 {
        pos_args.map(@value.to_str).join(sep)
      } else {
        ""
      }
      raise EvalErr(make_eval_error(ctx, "fail: \{body}"))
    }
    "hasattr" => {
      check_positional(ctx, "hasattr", pos_args, kw_args, 2, 2)
      let s = arg_as_string(ctx, "hasattr", pos_args, 1)
      let dummy_pos = @errors.Position::new("<hasattr>", 0, 0)
      let found = try {
        ignore(eval_getattr(ctx, pos_args[0], s.raw(), dummy_pos))
        true
      } catch {
        EvalErr(_) => false
      }
      @value.Value::Bool(found)
    }
    "getattr" => {
      check_positional(ctx, "getattr", pos_args, kw_args, 2, 3)
      let s = arg_as_string(ctx, "getattr", pos_args, 1)
      let dummy_pos = @errors.Position::new("<getattr>", 0, 0)
      eval_getattr(ctx, pos_args[0], s.raw(), dummy_pos) catch {
        EvalErr(_) =>
          if pos_args.length() >= 3 {
            pos_args[2]
          } else {
            raise EvalErr(
              make_eval_error(
                ctx,
                "getattr: \{@value.type_name(pos_args[0])} has no .\{s.raw()} field or method",
              ),
            )
          }
      }
    }
    "module" => builtin_module(ctx, pos_args, kw_args)
    _ =>
      raise EvalErr(make_eval_error(ctx, "unknown built-in function '\{name}'"))
  }
}

///|
fn builtin_module(
  ctx : EvalContext,
  pos_args : Array[@value.Value],
  kw_args : Array[(String, @value.Value)],
) -> @value.Value raise EvalErr {
  let mod_name = if pos_args.length() > 0 {
    match pos_args[0] {
      @value.Value::String(s) => s.raw()
      _ =>
        raise EvalErr(
          make_eval_error(ctx, "module() name argument must be a string"),
        )
    }
  } else {
    ""
  }
  let attrs : Map[String, @value.Value] = {}
  for pair in kw_args {
    let (k, v) = pair
    attrs[k] = v
  }
  @value.Value::Module(@value.StarlarkModule::new(mod_name, attrs))
}

///|
fn range_arg_to_int64(ctx : EvalContext, b : BigInt) -> Int64 raise EvalErr {
  if b.compare_int64(@int64.MAX_VALUE) > 0 ||
    b.compare_int64(@int64.MIN_VALUE) < 0 {
    raise EvalErr(
      make_eval_error(
        ctx,
        "\{b} out of range (want value in signed 64-bit range)",
      ),
    )
  }
  b.to_int64()
}

///|
fn builtin_range(
  ctx : EvalContext,
  pos_args : Array[@value.Value],
  kw_args : Array[(String, @value.Value)],
) -> @value.Value raise EvalErr {
  check_positional(ctx, "range", pos_args, kw_args, 1, 3)
  let param = fn(i : Int) -> Int64 raise EvalErr {
    match pos_args[i] {
      @value.Value::Int(n) => range_arg_to_int64(ctx, n)
      v =>
        raise EvalErr(
          make_eval_error(
            ctx,
            "range: for parameter \{i + 1}: got \{@value.type_name(v)}, want int",
          ),
        )
    }
  }
  let (start, stop, step) = match pos_args.length() {
    1 => (0L, param(0), 1L)
    2 => (param(0), param(1), 1L)
    _ => (param(0), param(1), param(2))
  }
  if step == 0L {
    raise EvalErr(make_eval_error(ctx, "range: step argument must not be zero"))
  }
  @value.Value::Range(@value.StarlarkRange::new(start, stop, step))
}

///|
fn builtin_list(
  ctx : EvalContext,
  pos_args : Array[@value.Value],
) -> @value.Value raise EvalErr {
  if pos_args.length() == 0 {
    return @value.Value::List(@value.StarlarkList::new([]))
  }
  match pos_args[0] {
    @value.Value::List(l) => {
      let items : Array[@value.Value] = []
      for v in l.iter() {
        items.push(v)
      }
      @value.Value::List(@value.StarlarkList::new(items))
    }
    v => {
      let items : Array[@value.Value] = []
      let it = require_seq(ctx, "list", v)
      while true {
        match it.next() {
          None => {
            it.done()
            break
          }
          Some(item) => items.push(item)
        }
      }
      @value.Value::List(@value.StarlarkList::new(items))
    }
  }
}

///|
fn builtin_tuple(
  ctx : EvalContext,
  pos_args : Array[@value.Value],
) -> @value.Value raise EvalErr {
  if pos_args.length() == 0 {
    return @value.Value::Tuple([])
  }
  let items : Array[@value.Value] = []
  let it = require_seq(ctx, "tuple", pos_args[0])
  while true {
    match it.next() {
      None => {
        it.done()
        break
      }
      Some(item) => items.push(item)
    }
  }
  @value.Value::Tuple(items)
}

///|
// Common implementation of the builtin `dict` function and the `dict.update`
// method. `name` ("dict" or "update") prefixes every error message.
// Precondition: pos_args.length() <= 1.
fn update_dict(
  ctx : EvalContext,
  name : String,
  d : @value.StarlarkDict,
  pos_args : Array[@value.Value],
  kw_args : Array[(String, @value.Value)],
) -> Unit raise EvalErr {
  if pos_args.length() == 1 {
    match pos_args[0] {
      @value.Value::Dict(src) => {
        let pairs : Array[(@value.Value, @value.Value)] = []
        src.each(fn(k, v) { pairs.push((k, v)) })
        for pair in pairs {
          let (k, v) = pair
          check(ctx, d.set(k, v))
        }
      }
      v => {
        let it = match @value.iterate(v) {
          Ok(i) => i
          Err(_) =>
            raise EvalErr(
              make_eval_error(
                ctx,
                "\{name}: got \{@value.type_name(v)}, want iterable",
              ),
            )
        }
        let mut i = 0
        while true {
          match it.next() {
            None => {
              it.done()
              break
            }
            Some(pair) => {
              let pair_it = match @value.iterate(pair) {
                Ok(pi) => pi
                Err(_) => {
                  it.done()
                  raise EvalErr(
                    make_eval_error(
                      ctx,
                      "\{name}: dictionary update sequence element #\{i} is not iterable (\{@value.type_name(pair)})",
                    ),
                  )
                }
              }
              let elems : Array[@value.Value] = []
              while true {
                match pair_it.next() {
                  None => {
                    pair_it.done()
                    break
                  }
                  Some(e) => elems.push(e)
                }
              }
              if elems.length() != 2 {
                it.done()
                raise EvalErr(
                  make_eval_error(
                    ctx,
                    "\{name}: dictionary update sequence element #\{i} has length \{elems.length()}, want 2",
                  ),
                )
              }
              check(ctx, d.set(elems[0], elems[1]))
              i = i + 1
            }
          }
        }
      }
    }
  }
  let kw_seen : Array[String] = []
  for kw_pair in kw_args {
    let (kw_name, kw_val) = kw_pair
    if kw_seen.contains(kw_name) {
      raise EvalErr(
        make_eval_error(ctx, "\{name}: duplicate keyword arg: \"\{kw_name}\""),
      )
    }
    kw_seen.push(kw_name)
    let key = @value.Value::String(@value.StarlarkString::new(kw_name))
    check(ctx, d.set(key, kw_val))
  }
}

///|
fn builtin_dict(
  ctx : EvalContext,
  pos_args : Array[@value.Value],
  kw_args : Array[(String, @value.Value)],
) -> @value.Value raise EvalErr {
  if pos_args.length() > 1 {
    raise EvalErr(
      make_eval_error(
        ctx,
        "dict: got \{pos_args.length()} arguments, want at most 1",
      ),
    )
  }
  let d = @value.StarlarkDict::new()
  update_dict(ctx, "dict", d, pos_args, kw_args)
  @value.Value::Dict(d)
}

///|
fn builtin_set(
  ctx : EvalContext,
  pos_args : Array[@value.Value],
) -> @value.Value raise EvalErr {
  let s = @value.StarlarkSet::new()
  if pos_args.length() == 0 {
    return @value.Value::Set(s)
  }
  let iterable = pos_args[0]
  let it = match @value.iterate(iterable) {
    Err(_) =>
      raise EvalErr(
        make_eval_error(
          ctx,
          "set: for parameter 1: got \{@value.type_name(iterable)}, want iterable",
        ),
      )
    Ok(it) => it
  }
  while true {
    match it.next() {
      None => {
        it.done()
        break
      }
      Some(v) => check(ctx, s.add(v))
    }
  }
  @value.Value::Set(s)
}

///|
fn builtin_minmax(
  ctx : EvalContext,
  pos_args : Array[@value.Value],
  kw_args : Array[(String, @value.Value)],
  want_max : Bool,
) -> @value.Value raise EvalErr {
  let fn_name = if want_max { "max" } else { "min" }
  if pos_args.length() == 0 {
    raise EvalErr(
      make_eval_error(
        ctx,
        "\{fn_name} requires at least one positional argument",
      ),
    )
  }
  let key_fn : @value.Value? = {
    let mut found : @value.Value? = None
    for kv in kw_args {
      match kv {
        ("key", f) => {
          found = Some(f)
          break
        }
        _ => ()
      }
    }
    found
  }
  for kv in kw_args {
    let (kw_name, _) = kv
    if kw_name != "key" {
      let hint = match @utf8util.spell_nearest(kw_name, ["key"]) {
        "" => ""
        s => " (did you mean \{s}?)"
      }
      raise EvalErr(
        make_eval_error(
          ctx,
          "\{fn_name}: unexpected keyword argument \"\{kw_name}\"\{hint}",
        ),
      )
    }
  }
  match key_fn {
    Some(f) =>
      match f {
        @value.Value::Function(_)
        | @value.Value::Builtin(_)
        | @value.Value::BoundMethod(_)
        | @value.Value::ExtVal(_) => ()
        v =>
          raise EvalErr(
            make_eval_error(
              ctx,
              "\{fn_name}: for parameter \"key\": got \{@value.type_name(v)}, want callable",
            ),
          )
      }
    None => ()
  }
  let items : Array[@value.Value] = []
  if pos_args.length() == 1 {
    let it = match @value.iterate(pos_args[0]) {
      Ok(it) => it
      Err(_) =>
        raise EvalErr(
          make_eval_error(
            ctx,
            "\{fn_name}: \{@value.type_name(pos_args[0])} value is not iterable",
          ),
        )
    }
    while true {
      match it.next() {
        None => {
          it.done()
          break
        }
        Some(v) => items.push(v)
      }
    }
    if items.is_empty() {
      raise EvalErr(
        make_eval_error(ctx, "\{fn_name}: argument is an empty sequence"),
      )
    }
  } else {
    for v in pos_args {
      items.push(v)
    }
  }
  let key_of : (@value.Value) -> @value.Value raise EvalErr = fn(
    v,
  ) raise EvalErr {
    match key_fn {
      None => v
      Some(f) =>
        call_value(ctx, f, [v], [], @errors.Position::new("<builtin>", 0, 0))
    }
  }
  let mut result = items[0]
  let mut result_key = key_of(result)
  for i in 1..<items.length() {
    let item_key = key_of(items[i])
    let c = check(ctx, @value.compare_values(item_key, result_key))
    if (want_max && c > 0) || (!want_max && c < 0) {
      result = items[i]
      result_key = item_key
    }
  }
  result
}

///|
fn builtin_enumerate(
  ctx : EvalContext,
  pos_args : Array[@value.Value],
  kw_args : Array[(String, @value.Value)],
) -> @value.Value raise EvalErr {
  check_positional(ctx, "enumerate", pos_args, kw_args, 1, 2)
  let start = if pos_args.length() >= 2 {
    BigInt::from_int(arg_as_int(ctx, "enumerate", pos_args, 1))
  } else {
    0N
  }
  let result : Array[@value.Value] = []
  let it = match @value.iterate(pos_args[0]) {
    Ok(it) => it
    Err(_) =>
      raise EvalErr(
        make_eval_error(
          ctx,
          "enumerate: for parameter 1: got \{@value.type_name(pos_args[0])}, want iterable",
        ),
      )
  }
  let mut idx = start
  while true {
    match it.next() {
      None => {
        it.done()
        break
      }
      Some(v) => {
        result.push(@value.Value::Tuple([@value.Value::Int(idx), v]))
        idx = idx + 1N
      }
    }
  }
  @value.Value::List(@value.StarlarkList::new(result))
}

///|
fn builtin_sorted(
  ctx : EvalContext,
  pos_args : Array[@value.Value],
  kw_args : Array[(String, @value.Value)],
) -> @value.Value raise EvalErr {
  if pos_args.length() > 3 {
    raise EvalErr(
      make_eval_error(
        ctx,
        "sorted: got \{pos_args.length()} arguments, want at most 3",
      ),
    )
  }
  // Python's sorted permits iterable, key, and reverse to be positional or
  // keyword, thus so do we. Track whether each was bound via kwarg so error
  // messages can quote kwargs names (starlark-go UnpackArgs parity).
  let mut iterable_val : @value.Value? = if pos_args.length() >= 1 {
    Some(pos_args[0])
  } else {
    None
  }
  let mut iterable_set = pos_args.length() >= 1
  let mut iterable_from_kwarg = false
  let mut key_fn : @value.Value? = if pos_args.length() >= 2 {
    Some(pos_args[1])
  } else {
    None
  }
  let mut key_set = pos_args.length() >= 2
  let mut key_from_kwarg = false
  let mut reverse_arg : @value.Value? = if pos_args.length() >= 3 {
    Some(pos_args[2])
  } else {
    None
  }
  let mut reverse_set = pos_args.length() >= 3
  let mut reverse_from_kwarg = false
  for kv in kw_args {
    match kv.0 {
      "iterable" => {
        if iterable_set {
          raise EvalErr(
            make_eval_error(
              ctx, "sorted: got multiple values for keyword argument iterable",
            ),
          )
        }
        iterable_val = Some(kv.1)
        iterable_set = true
        iterable_from_kwarg = true
      }
      "key" => {
        if key_set {
          raise EvalErr(
            make_eval_error(
              ctx, "sorted: got multiple values for keyword argument key",
            ),
          )
        }
        key_fn = Some(kv.1)
        key_set = true
        key_from_kwarg = true
      }
      "reverse" => {
        if reverse_set {
          raise EvalErr(
            make_eval_error(
              ctx, "sorted: got multiple values for keyword argument reverse",
            ),
          )
        }
        reverse_arg = Some(kv.1)
        reverse_set = true
        reverse_from_kwarg = true
      }
      other => {
        let hint = match
          @utf8util.spell_nearest(other, ["key", "reverse", "iterable"]) {
          "" => ""
          s => " (did you mean \{s}?)"
        }
        raise EvalErr(
          make_eval_error(
            ctx,
            "sorted: unexpected keyword argument \"\{other}\"\{hint}",
          ),
        )
      }
    }
  }
  let iterable = match iterable_val {
    Some(v) => v
    None =>
      raise EvalErr(
        make_eval_error(ctx, "sorted: missing argument for iterable"),
      )
  }
  // starlark-go order: check iterable type first, then key, then reverse.
  // Kwarg names are quoted in error messages; positional names are not.
  let items : Array[@value.Value] = []
  let it = match @value.iterate(iterable) {
    Ok(it) => it
    Err(_) => {
      let pname = if iterable_from_kwarg { "\"iterable\"" } else { "iterable" }
      raise EvalErr(
        make_eval_error(
          ctx,
          "sorted: for parameter \{pname}: got \{@value.type_name(iterable)}, want iterable",
        ),
      )
    }
  }
  while true {
    match it.next() {
      None => {
        it.done()
        break
      }
      Some(v) => items.push(v)
    }
  }
  match key_fn {
    Some(f) =>
      match f {
        @value.Value::Function(_)
        | @value.Value::Builtin(_)
        | @value.Value::BoundMethod(_)
        | @value.Value::ExtVal(_) => ()
        v => {
          let pname = if key_from_kwarg { "\"key\"" } else { "key" }
          raise EvalErr(
            make_eval_error(
              ctx,
              "sorted: for parameter \{pname}: got \{@value.type_name(v)}, want callable",
            ),
          )
        }
      }
    None => ()
  }
  let reverse = match reverse_arg {
    None => false
    Some(@value.Value::Bool(b)) => b
    Some(v) => {
      let pname = if reverse_from_kwarg { "\"reverse\"" } else { "reverse" }
      raise EvalErr(
        make_eval_error(
          ctx,
          "sorted: for parameter \{pname}: got \{@value.type_name(v)}, want bool",
        ),
      )
    }
  }
  let keys : Array[@value.Value] = match key_fn {
    None => items
    Some(@value.Value::None) =>
      raise EvalErr(
        make_eval_error(
          ctx, "sorted: for parameter key: got NoneType, want callable",
        ),
      )
    Some(f) =>
      items.map(fn(v) raise EvalErr {
        call_value(ctx, f, [v], [], @errors.Position::new("<builtin>", 0, 0))
      })
  }
  let indices : Array[Int] = Array::make(items.length(), 0)
  for i in 0..<items.length() {
    indices[i] = i
  }
  let mut sort_err : @errors.EvalError? = None
  indices.sort_by(fn(a, b) {
    match @value.compare_values(keys[a], keys[b]) {
      Err(msg) => {
        sort_err = Some(make_eval_error(ctx, msg))
        0
      }
      Ok(c) => {
        let cc = if reverse { -c } else { c }
        // Break ties by original index so the sort is stable regardless of the
        // underlying sort_by's stability; reverse keeps equal-key order (not
        // reversed).
        if cc != 0 {
          cc
        } else {
          a - b
        }
      }
    }
  })
  match sort_err {
    Some(e) => raise EvalErr(e)
    None => {
      let result : Array[@value.Value] = indices.map(fn(i) { items[i] })
      @value.Value::List(@value.StarlarkList::new(result))
    }
  }
}

///|
fn builtin_reversed(
  ctx : EvalContext,
  pos_args : Array[@value.Value],
) -> @value.Value raise EvalErr {
  let items : Array[@value.Value] = []
  let it = require_seq(ctx, "reversed", pos_args[0])
  while true {
    match it.next() {
      None => {
        it.done()
        break
      }
      Some(v) => items.push(v)
    }
  }
  let n = items.length()
  let rev : Array[@value.Value] = Array::make(n, @value.Value::None)
  for i in 0..<n {
    rev[i] = items[n - 1 - i]
  }
  @value.Value::List(@value.StarlarkList::new(rev))
}

///|
fn builtin_zip(
  ctx : EvalContext,
  pos_args : Array[@value.Value],
) -> @value.Value raise EvalErr {
  if pos_args.length() == 0 {
    return @value.Value::List(@value.StarlarkList::new([]))
  }
  let iterators : Array[@value.StarlarkIterator] = []
  for i, arg in pos_args {
    match @value.iterate(arg) {
      Err(_) => {
        for it in iterators {
          it.done()
        }
        raise EvalErr(
          make_eval_error(
            ctx,
            "zip: argument #\{i + 1} is not iterable: \{@value.type_name(arg)}",
          ),
        )
      }
      Ok(it) => iterators.push(it)
    }
  }
  let result : Array[@value.Value] = []
  while true {
    let tuple_items : Array[@value.Value] = []
    let mut done = false
    for it in iterators {
      match it.next() {
        None => {
          done = true
          break
        }
        Some(v) => tuple_items.push(v)
      }
    }
    if done {
      for it in iterators {
        it.done()
      }
      break
    }
    result.push(@value.Value::Tuple(tuple_items))
  }
  @value.Value::List(@value.StarlarkList::new(result))
}

///|
fn builtin_any_all(
  ctx : EvalContext,
  pos_args : Array[@value.Value],
  any_mode : Bool,
) -> @value.Value raise EvalErr {
  let it = require_seq(ctx, if any_mode { "any" } else { "all" }, pos_args[0])
  let mut result = !any_mode
  while true {
    match it.next() {
      None => {
        it.done()
        break
      }
      Some(v) => {
        let t = @value.truth(v)
        if any_mode && t {
          it.done()
          result = true
          break
        } else if !any_mode && !t {
          it.done()
          result = false
          break
        }
      }
    }
  }
  @value.Value::Bool(result)
}

///|
fn call_method(
  ctx : EvalContext,
  recv : @value.Value,
  method_name : String,
  pos_args : Array[@value.Value],
  kw_args : Array[(String, @value.Value)],
  _pos : @errors.Position,
) -> @value.Value raise EvalErr {
  match recv {
    @value.Value::List(l) =>
      call_list_method(ctx, l, method_name, pos_args, kw_args)
    @value.Value::Dict(d) =>
      call_dict_method(ctx, d, method_name, pos_args, kw_args)
    @value.Value::String(s) =>
      call_str_method(ctx, s, method_name, pos_args, kw_args)
    @value.Value::Set(s) =>
      call_set_method(ctx, s, method_name, pos_args, kw_args)
    @value.Value::Bytes(b) => call_bytes_method(ctx, b, method_name, pos_args)
    _ =>
      raise EvalErr(
        make_eval_error(
          ctx,
          "'\{@value.type_name(recv)}' has no method '\{method_name}'",
        ),
      )
  }
}

///|
fn call_list_method(
  ctx : EvalContext,
  l : @value.StarlarkList,
  method_name : String,
  pos_args : Array[@value.Value],
  kw_args : Array[(String, @value.Value)],
) -> @value.Value raise EvalErr {
  match method_name {
    "append" => {
      check_positional(ctx, "append", pos_args, kw_args, 1, 1)
      check(ctx, l.push(pos_args[0]))
      @value.Value::None
    }
    "extend" => {
      check_positional(ctx, "extend", pos_args, kw_args, 1, 1)
      if pos_args[0] is @value.Value::List(src) {
        let snapshot = src.copy_items()
        check(ctx, l.check_mutable("extend"))
        for item in snapshot {
          l.push(item) |> ignore
        }
      } else {
        check(ctx, l.check_mutable("extend"))
        let it = require_seq(ctx, "extend", pos_args[0])
        while true {
          match it.next() {
            None => {
              it.done()
              break
            }
            Some(v) => l.push(v) |> ignore
          }
        }
      }
      @value.Value::None
    }
    "pop" => {
      check_positional(ctx, "pop", pos_args, kw_args, 0, 1)
      let n = l.length()
      let i = if pos_args.length() == 1 {
        match pos_args[0] {
          @value.Value::Int(b) => {
            if b.compare_int64(@int64.MAX_VALUE) > 0 ||
              b.compare_int64(@int64.MIN_VALUE) < 0 {
              raise EvalErr(
                make_eval_error(
                  ctx,
                  "pop: for parameter 1: \{b} out of range (want value in signed 64-bit range)",
                ),
              )
            }
            b
          }
          v =>
            raise EvalErr(
              make_eval_error(
                ctx,
                "pop: for parameter 1: got \{@value.type_name(v)}, want int",
              ),
            )
        }
      } else {
        BigInt::from_int(n - 1)
      }
      let idx = match adjust_index(i, n, "list") {
        Ok(j) => j
        Err(msg) => raise EvalErr(make_eval_error(ctx, "pop: " + msg))
      }
      check(ctx, l.pop_at(idx, verb="pop from"))
    }
    "remove" => {
      check_positional(ctx, "remove", pos_args, kw_args, 1, 1)
      let item = pos_args[0]
      let mut found = -1
      for i in 0..<l.length() {
        if @value.starlark_equals(l.get(i), item) {
          found = i
          break
        }
      }
      if found < 0 {
        raise EvalErr(make_eval_error(ctx, "remove: element not found"))
      }
      check(ctx, l.pop_at(found)) |> ignore
      @value.Value::None
    }
    "insert" => {
      check_positional(ctx, "insert", pos_args, kw_args, 2, 2)
      match pos_args[0] {
        @value.Value::Int(i) => {
          if i.compare_int64(@int64.MAX_VALUE) > 0 ||
            i.compare_int64(@int64.MIN_VALUE) < 0 {
            raise EvalErr(
              make_eval_error(
                ctx,
                "insert: for parameter 1: \{i} out of range (want value in signed 64-bit range)",
              ),
            )
          }
          let len = l.length()
          let j = {
            let len64 = BigInt::from_int(len)
            let jj = if i < 0N { i + len64 } else { i }
            if jj < 0N {
              0
            } else if jj > len64 {
              len
            } else {
              jj.to_int()
            }
          }
          check(ctx, l.insert(j, pos_args[1])) |> ignore
          @value.Value::None
        }
        v =>
          raise EvalErr(
            make_eval_error(
              ctx,
              "insert: for parameter 1: got \{@value.type_name(v)}, want int",
            ),
          )
      }
    }
    "clear" => {
      check_positional(ctx, "clear", pos_args, kw_args, 0, 0)
      check(ctx, l.clear()) |> ignore
      @value.Value::None
    }
    "index" => {
      check_positional(ctx, "index", pos_args, kw_args, 1, 3)
      let item = pos_args[0]
      let n = l.length()
      let start = if pos_args.length() >= 2 {
        match pos_args[1] {
          @value.Value::Int(i) => {
            let s = i.to_int()
            let j = if s < 0 { s + n } else { s }
            if j < 0 {
              0
            } else if j > n {
              n
            } else {
              j
            }
          }
          @value.Value::None => 0
          v =>
            raise EvalErr(
              make_eval_error(
                ctx,
                "index: invalid start index: got \{@value.type_name(v)}, want int",
              ),
            )
        }
      } else {
        0
      }
      let end = if pos_args.length() >= 3 {
        match pos_args[2] {
          @value.Value::Int(i) => {
            let e = i.to_int()
            let j = if e < 0 { e + n } else { e }
            if j < 0 {
              0
            } else if j > n {
              n
            } else {
              j
            }
          }
          @value.Value::None => n
          v =>
            raise EvalErr(
              make_eval_error(
                ctx,
                "index: invalid end index: got \{@value.type_name(v)}, want int",
              ),
            )
        }
      } else {
        n
      }
      for i in start..<end {
        if @value.starlark_equals(l.get(i), item) {
          return @value.Value::Int(BigInt::from_int(i))
        }
      }
      raise EvalErr(make_eval_error(ctx, "index: value not in list"))
    }
    _ =>
      raise EvalErr(make_eval_error(ctx, "list has no method '\{method_name}'"))
  }
}

///|
fn call_dict_method(
  ctx : EvalContext,
  d : @value.StarlarkDict,
  method_name : String,
  pos_args : Array[@value.Value],
  kw_args : Array[(String, @value.Value)],
) -> @value.Value raise EvalErr {
  match method_name {
    "get" => {
      check_positional(ctx, "get", pos_args, kw_args, 1, 2)
      let default_val = if pos_args.length() >= 2 {
        pos_args[1]
      } else {
        @value.Value::None
      }
      match check(ctx, d.get(pos_args[0])) {
        None => default_val
        Some(v) => v
      }
    }
    "keys" => {
      check_positional(ctx, "keys", pos_args, kw_args, 0, 0)
      let keys = d.keys()
      @value.Value::List(@value.StarlarkList::new(keys))
    }
    "values" => {
      check_positional(ctx, "values", pos_args, kw_args, 0, 0)
      let vals : Array[@value.Value] = []
      d.each(fn(_k, v) { vals.push(v) })
      @value.Value::List(@value.StarlarkList::new(vals))
    }
    "items" => {
      check_positional(ctx, "items", pos_args, kw_args, 0, 0)
      let items : Array[@value.Value] = []
      d.each(fn(k, v) { items.push(@value.Value::Tuple([k, v])) })
      @value.Value::List(@value.StarlarkList::new(items))
    }
    "pop" => {
      check_positional(ctx, "pop", pos_args, kw_args, 1, 2)
      let key = pos_args[0]
      match check(ctx, d.get(key)) {
        None =>
          if pos_args.length() >= 2 {
            pos_args[1]
          } else {
            raise EvalErr(make_eval_error(ctx, "pop: missing key"))
          }
        Some(v) => {
          ignore(check(ctx, d.delete(key)))
          v
        }
      }
    }
    "update" => {
      if pos_args.length() > 1 {
        raise EvalErr(
          make_eval_error(
            ctx,
            "update: got \{pos_args.length()} arguments, want at most 1",
          ),
        )
      }
      update_dict(ctx, "update", d, pos_args, kw_args)
      @value.Value::None
    }
    "clear" => {
      check_positional(ctx, "clear", pos_args, kw_args, 0, 0)
      check(ctx, d.clear())
      @value.Value::None
    }
    "popitem" => {
      check_positional(ctx, "popitem", pos_args, kw_args, 0, 0)
      match check(ctx, d.popitem()) {
        None => raise EvalErr(make_eval_error(ctx, "popitem: empty dict"))
        Some((k, v)) => @value.Value::Tuple([k, v])
      }
    }
    "setdefault" => {
      check_positional(ctx, "setdefault", pos_args, kw_args, 1, 2)
      let key = pos_args[0]
      let default_val = if pos_args.length() >= 2 {
        pos_args[1]
      } else {
        @value.Value::None
      }
      match check(ctx, d.get(key)) {
        Some(v) => v
        None => {
          check(ctx, d.set(key, default_val))
          default_val
        }
      }
    }
    _ =>
      raise EvalErr(make_eval_error(ctx, "dict has no method '\{method_name}'"))
  }
}

///|
fn call_str_method(
  ctx : EvalContext,
  s : @value.StarlarkString,
  method_name : String,
  pos_args : Array[@value.Value],
  kw_args : Array[(String, @value.Value)],
) -> @value.Value raise EvalErr {
  match method_name {
    "upper" =>
      @value.Value::String(
        @value.StarlarkString::new(
          map_string_runes(s.raw(), @utf8util.to_upper_rune),
        ),
      )
    "lower" =>
      @value.Value::String(
        @value.StarlarkString::new(
          map_string_runes(s.raw(), @utf8util.to_lower_rune),
        ),
      )
    "strip" | "lstrip" | "rstrip" => {
      check_positional(ctx, method_name, pos_args, kw_args, 0, 1)
      let chars_opt = if pos_args.length() > 0 {
        let c = arg_as_string(ctx, method_name, pos_args, 0)
        if c.raw().length() > 0 {
          Some(c.raw())
        } else {
          None
        }
      } else {
        None
      }
      let from_left = method_name != "rstrip"
      let from_right = method_name != "lstrip"
      let result = match chars_opt {
        None => strip_whitespace(s.raw(), from_left, from_right)
        Some(chars) => strip_chars(s.raw(), chars, from_left, from_right)
      }
      @value.Value::String(@value.StarlarkString::new(result))
    }
    "startswith" => {
      check_positional(ctx, "startswith", pos_args, kw_args, 1, 3)
      let slen = s.byte_len()
      let i = parse_search_index(
        ctx, "startswith", pos_args, 1, slen, 0, "start",
      )
      let j = parse_search_index(
        ctx, "startswith", pos_args, 2, slen, slen, "end",
      )
      let sub = str_byte_slice(s, i, j)
      let check_prefix = fn(prefix : @value.StarlarkString) -> Bool {
        bytes_has_prefix(sub, prefix)
      }
      match pos_args[0] {
        @value.Value::String(prefix) => @value.Value::Bool(check_prefix(prefix))
        @value.Value::Tuple(t) => {
          let mut found = false
          for idx, item in t {
            match item {
              @value.Value::String(p) =>
                if check_prefix(p) {
                  found = true
                  break
                }
              v =>
                raise EvalErr(
                  make_eval_error(
                    ctx,
                    "startswith: want string, got \{@value.type_name(v)}, for element \{idx}",
                  ),
                )
            }
          }
          @value.Value::Bool(found)
        }
        v =>
          raise EvalErr(
            make_eval_error(
              ctx,
              "startswith: got \{@value.type_name(v)}, want string or tuple of string",
            ),
          )
      }
    }
    "endswith" => {
      check_positional(ctx, "endswith", pos_args, kw_args, 1, 3)
      let slen = s.byte_len()
      let i = parse_search_index(ctx, "endswith", pos_args, 1, slen, 0, "start")
      let j = parse_search_index(
        ctx, "endswith", pos_args, 2, slen, slen, "end",
      )
      let sub = str_byte_slice(s, i, j)
      let check_suffix = fn(suffix : @value.StarlarkString) -> Bool {
        bytes_has_suffix(sub, suffix)
      }
      match pos_args[0] {
        @value.Value::String(suffix) => @value.Value::Bool(check_suffix(suffix))
        @value.Value::Tuple(t) => {
          let mut found = false
          for idx, item in t {
            match item {
              @value.Value::String(p) =>
                if check_suffix(p) {
                  found = true
                  break
                }
              v =>
                raise EvalErr(
                  make_eval_error(
                    ctx,
                    "endswith: want string, got \{@value.type_name(v)}, for element \{idx}",
                  ),
                )
            }
          }
          @value.Value::Bool(found)
        }
        v =>
          raise EvalErr(
            make_eval_error(
              ctx,
              "endswith: got \{@value.type_name(v)}, want string or tuple of string",
            ),
          )
      }
    }
    "find" => {
      check_positional(ctx, "find", pos_args, kw_args, 1, 3)
      let sub = arg_as_string(ctx, "find", pos_args, 0)
      let slen = s.byte_len()
      let start = parse_search_index(ctx, "find", pos_args, 1, slen, 0, "start")
      let end = parse_search_index(ctx, "find", pos_args, 2, slen, slen, "end")
      let result = if start <= end {
        bytes_index_in(s, start, end, sub)
      } else {
        -1
      }
      @value.Value::Int(BigInt::from_int(result))
    }
    "count" => {
      check_positional(ctx, "count", pos_args, kw_args, 1, 3)
      let sub = arg_as_string(ctx, "count", pos_args, 0)
      let slen = s.byte_len()
      let start = parse_search_index(
        ctx, "count", pos_args, 1, slen, 0, "start",
      )
      let end = parse_search_index(ctx, "count", pos_args, 2, slen, slen, "end")
      let result = if start <= end {
        bytes_count_in(s, start, end, sub)
      } else {
        0
      }
      @value.Value::Int(BigInt::from_int(result))
    }
    "replace" => {
      check_positional(ctx, "replace", pos_args, kw_args, 2, 3)
      let old = arg_as_string(ctx, "replace", pos_args, 0)
      let new_s = arg_as_string(ctx, "replace", pos_args, 1)
      let max_count = if pos_args.length() >= 3 {
        arg_as_int(ctx, "replace", pos_args, 2)
      } else {
        -1
      }
      let result = if max_count < 0 {
        s.raw().replace_all(old=old.raw(), new=new_s.raw())
      } else {
        str_replace_count(s.raw(), old.raw(), new_s.raw(), max_count)
      }
      @value.Value::String(@value.StarlarkString::new(result))
    }
    "split" | "rsplit" => {
      check_positional(ctx, method_name, pos_args, kw_args, 0, 2)
      let sep_opt = if pos_args.length() == 0 {
        None
      } else {
        match pos_args[0] {
          @value.Value::None => None
          @value.Value::String(sep) => {
            if sep.raw().length() == 0 {
              raise EvalErr(make_eval_error(ctx, "split: empty separator"))
            }
            Some(sep.raw())
          }
          v =>
            raise EvalErr(
              make_eval_error(
                ctx,
                "split: got \{@value.type_name(v)} for separator, want string",
              ),
            )
        }
      }
      let maxsplit = if pos_args.length() >= 2 {
        arg_as_int(ctx, method_name, pos_args, 1)
      } else {
        -1
      }
      if method_name == "split" {
        match sep_opt {
          None => to_value_list(split_whitespace(s.raw(), maxsplit))
          Some(sep_str) =>
            to_value_list(split_by_sep(s.raw(), sep_str, maxsplit))
        }
      } else {
        match sep_opt {
          None => to_value_list(rsplit_whitespace(s.raw(), maxsplit))
          Some(sep_str) =>
            to_value_list(rsplit_by_sep(s.raw(), sep_str, maxsplit))
        }
      }
    }
    "join" => {
      check_positional(ctx, "join", pos_args, kw_args, 1, 1)
      let parts : Array[String] = []
      let it = match @value.iterate(pos_args[0]) {
        Ok(it) => it
        Err(_) =>
          raise EvalErr(
            make_eval_error(
              ctx,
              "join: for parameter 1: got \{@value.type_name(pos_args[0])}, want iterable",
            ),
          )
      }
      while true {
        match it.next() {
          None => {
            it.done()
            break
          }
          Some(@value.Value::String(part)) => parts.push(part.raw())
          Some(v) => {
            it.done()
            raise EvalErr(
              make_eval_error(
                ctx,
                "join: in list, want string, got \{@value.type_name(v)}",
              ),
            )
          }
        }
      }
      let buf = StringBuilder::new()
      let mut first = true
      for part in parts {
        if !first {
          buf.write_string(s.raw())
        }
        first = false
        buf.write_string(part)
      }
      @value.Value::String(@value.StarlarkString::new(buf.to_string()))
    }
    "format" => str_format(ctx, s.raw(), pos_args, kw_args)
    "capitalize" => {
      let raw = s.raw()
      if raw.length() == 0 {
        @value.Value::String(s)
      } else {
        let buf = StringBuilder::new()
        let mut is_first = true
        for c in raw {
          let cp = c.to_int()
          if is_first {
            buf.write_char(@utf8util.to_title_rune(cp).unsafe_to_char())
            is_first = false
          } else {
            buf.write_char(@utf8util.to_lower_rune(cp).unsafe_to_char())
          }
        }
        @value.Value::String(@value.StarlarkString::new(buf.to_string()))
      }
    }
    "index" => {
      check_positional(ctx, "index", pos_args, [], 1, 3)
      let sub = arg_as_string(ctx, "index", pos_args, 0)
      let slen = s.byte_len()
      let start = parse_search_index(
        ctx, "index", pos_args, 1, slen, 0, "start",
      )
      let end = parse_search_index(ctx, "index", pos_args, 2, slen, slen, "end")
      let result = if start <= end {
        bytes_index_in(s, start, end, sub)
      } else {
        -1
      }
      if result < 0 {
        raise EvalErr(make_eval_error(ctx, "index: substring not found"))
      }
      @value.Value::Int(BigInt::from_int(result))
    }
    "rfind" => {
      check_positional(ctx, "rfind", pos_args, kw_args, 1, 3)
      let sub = arg_as_string(ctx, "rfind", pos_args, 0)
      let slen = s.byte_len()
      let start = parse_search_index(
        ctx, "rfind", pos_args, 1, slen, 0, "start",
      )
      let end = parse_search_index(ctx, "rfind", pos_args, 2, slen, slen, "end")
      let result = if start <= end {
        bytes_last_index_in(s, start, end, sub)
      } else {
        -1
      }
      @value.Value::Int(BigInt::from_int(result))
    }
    "rindex" => {
      check_positional(ctx, "rindex", pos_args, kw_args, 1, 3)
      let sub = arg_as_string(ctx, "rindex", pos_args, 0)
      let slen = s.byte_len()
      let start = parse_search_index(
        ctx, "rindex", pos_args, 1, slen, 0, "start",
      )
      let end = parse_search_index(
        ctx, "rindex", pos_args, 2, slen, slen, "end",
      )
      let result = if start <= end {
        bytes_last_index_in(s, start, end, sub)
      } else {
        -1
      }
      if result < 0 {
        raise EvalErr(make_eval_error(ctx, "rindex: substring not found"))
      }
      @value.Value::Int(BigInt::from_int(result))
    }
    "isalpha" => {
      if s.raw().length() == 0 {
        return @value.Value::Bool(false)
      }
      let mut result = true
      for c in s.raw().to_array() {
        let n = c.to_int()
        if !((n >= 'A'.to_int() && n <= 'Z'.to_int()) ||
          (n >= 'a'.to_int() && n <= 'z'.to_int())) {
          result = false
          break
        }
      }
      @value.Value::Bool(result)
    }
    "isdigit" => {
      if s.raw().length() == 0 {
        return @value.Value::Bool(false)
      }
      let mut result = true
      for c in s.raw().to_array() {
        let n = c.to_int()
        if n < '0'.to_int() || n > '9'.to_int() {
          result = false
          break
        }
      }
      @value.Value::Bool(result)
    }
    "isalnum" => {
      if s.raw().length() == 0 {
        return @value.Value::Bool(false)
      }
      let mut result = true
      for c in s.raw().to_array() {
        let n = c.to_int()
        if !((n >= 'A'.to_int() && n <= 'Z'.to_int()) ||
          (n >= 'a'.to_int() && n <= 'z'.to_int()) ||
          (n >= '0'.to_int() && n <= '9'.to_int())) {
          result = false
          break
        }
      }
      @value.Value::Bool(result)
    }
    "islower" => {
      let raw = s.raw()
      let has_cased = raw
        .iter()
        .any(fn(c) { @utf8util.is_cased_rune(c.to_int()) })
      @value.Value::Bool(
        has_cased && raw == map_string_runes(raw, @utf8util.to_lower_rune),
      )
    }
    "isupper" => {
      let raw = s.raw()
      let has_cased = raw
        .iter()
        .any(fn(c) { @utf8util.is_cased_rune(c.to_int()) })
      @value.Value::Bool(
        has_cased && raw == map_string_runes(raw, @utf8util.to_upper_rune),
      )
    }
    "isspace" => {
      if s.raw().length() == 0 {
        return @value.Value::Bool(false)
      }
      let mut result = true
      for c in s.raw() {
        if !is_whitespace(c) {
          result = false
          break
        }
      }
      @value.Value::Bool(result)
    }
    "title" => {
      let buf = StringBuilder::new()
      let mut prev_cased = false
      for c in s.raw() {
        let cp = c.to_int()
        let mapped = if prev_cased {
          @utf8util.to_lower_rune(cp)
        } else {
          @utf8util.to_title_rune(cp)
        }
        buf.write_char(mapped.unsafe_to_char())
        prev_cased = @utf8util.is_cased_rune(mapped)
      }
      @value.Value::String(@value.StarlarkString::new(buf.to_string()))
    }
    "partition" => {
      check_positional(ctx, "partition", pos_args, kw_args, 1, 1)
      let sep = arg_as_string(ctx, "partition", pos_args, 0)
      if sep.byte_len() == 0 {
        raise EvalErr(make_eval_error(ctx, "partition: empty separator"))
      }
      let idx = bytes_index_in(s, 0, s.byte_len(), sep)
      if idx < 0 {
        @value.Value::Tuple([
          @value.Value::String(s),
          @value.Value::String(@value.StarlarkString::new("")),
          @value.Value::String(@value.StarlarkString::new("")),
        ])
      } else {
        let before = str_byte_slice(s, 0, idx)
        let after = str_byte_slice(s, idx + sep.byte_len(), s.byte_len())
        @value.Value::Tuple([
          @value.Value::String(before),
          @value.Value::String(sep),
          @value.Value::String(after),
        ])
      }
    }
    "rpartition" => {
      check_positional(ctx, "rpartition", pos_args, kw_args, 1, 1)
      let sep = arg_as_string(ctx, "rpartition", pos_args, 0)
      if sep.byte_len() == 0 {
        raise EvalErr(make_eval_error(ctx, "rpartition: empty separator"))
      }
      let idx = bytes_last_index_in(s, 0, s.byte_len(), sep)
      if idx < 0 {
        @value.Value::Tuple([
          @value.Value::String(@value.StarlarkString::new("")),
          @value.Value::String(@value.StarlarkString::new("")),
          @value.Value::String(s),
        ])
      } else {
        let before = str_byte_slice(s, 0, idx)
        let after = str_byte_slice(s, idx + sep.byte_len(), s.byte_len())
        @value.Value::Tuple([
          @value.Value::String(before),
          @value.Value::String(sep),
          @value.Value::String(after),
        ])
      }
    }
    "removeprefix" => {
      check_positional(ctx, "removeprefix", pos_args, kw_args, 1, 1)
      let prefix = arg_as_string(ctx, "removeprefix", pos_args, 0)
      if s.raw().has_prefix(prefix.raw()) {
        let rest = s.raw()[prefix.raw().length():].to_owned()
        @value.Value::String(@value.StarlarkString::new(rest))
      } else {
        @value.Value::String(s)
      }
    }
    "removesuffix" => {
      check_positional(ctx, "removesuffix", pos_args, kw_args, 1, 1)
      let suffix = arg_as_string(ctx, "removesuffix", pos_args, 0)
      if s.raw().has_suffix(suffix.raw()) {
        let rest = s.raw()[0:s.raw().length() - suffix.raw().length()].to_owned()
        @value.Value::String(@value.StarlarkString::new(rest))
      } else {
        @value.Value::String(s)
      }
    }
    "splitlines" => {
      let keepends = if pos_args.length() > 0 {
        match pos_args[0] {
          @value.Value::Bool(b) => b
          _ =>
            raise EvalErr(
              make_eval_error(
                ctx,
                "splitlines: for parameter 1: got \{@value.type_name(pos_args[0])}, want bool",
              ),
            )
        }
      } else {
        false
      }
      let parts : Array[@value.Value] = []
      let chars = s.raw().to_array()
      let n = chars.length()
      let buf = StringBuilder::new()
      let mut i = 0
      while i < n {
        let c = chars[i]
        if c.to_int() == '\n'.to_int() {
          if keepends {
            buf.write_char(c)
          }
          parts.push(
            @value.Value::String(@value.StarlarkString::new(buf.to_string())),
          )
          buf.reset()
        } else {
          buf.write_char(c)
        }
        i += 1
      }
      if buf.to_string().length() > 0 {
        parts.push(
          @value.Value::String(@value.StarlarkString::new(buf.to_string())),
        )
      }
      @value.Value::List(@value.StarlarkList::new(parts))
    }
    "elems" =>
      @value.Value::StringElems(@value.StarlarkStringElems::new(s, false))
    "elem_ords" =>
      @value.Value::StringElems(@value.StarlarkStringElems::new(s, true))
    "istitle" => {
      let mut cased = false
      let mut prev_cased = false
      let mut valid = true
      for c in s.raw() {
        let n = c.to_int()
        if (n >= 'A'.to_int() && n <= 'Z'.to_int()) ||
          @utf8util.is_title_letter(n) {
          if prev_cased {
            valid = false
            break
          }
          prev_cased = true
          cased = true
        } else if @utf8util.is_lower_letter(n) {
          if !prev_cased {
            valid = false
            break
          }
          prev_cased = true
          cased = true
        } else if @utf8util.is_upper_letter(n) {
          valid = false
          break
        } else {
          prev_cased = false
        }
      }
      @value.Value::Bool(valid && cased)
    }
    "codepoints" =>
      @value.Value::StringCodepoints(
        @value.StarlarkStringCodepoints::new(s, false),
      )
    "codepoint_ords" =>
      @value.Value::StringCodepoints(
        @value.StarlarkStringCodepoints::new(s, true),
      )
    _ =>
      raise EvalErr(
        make_eval_error(ctx, "string has no method '\{method_name}'"),
      )
  }
}

///|
fn set_iterate_into(
  ctx : EvalContext,
  arg : @value.Value,
  arg_idx : Int,
  method_nm : String,
  result : @value.StarlarkSet,
) -> Unit raise EvalErr {
  let it = match @value.iterate(arg) {
    Err(_) =>
      raise EvalErr(
        make_eval_error(
          ctx,
          "\{method_nm}: argument #\{arg_idx} is not iterable: \{@value.type_name(arg)}",
        ),
      )
    Ok(it) => it
  }
  while true {
    match it.next() {
      None => {
        it.done()
        break
      }
      Some(v) =>
        match result.add(v) {
          Err(e) => raise EvalErr(make_eval_error(ctx, "\{method_nm}: \{e}"))
          Ok(_) => ()
        }
    }
  }
}

///|
// Validate the single optional iterable argument shared by the set operations
// intersection/difference/symmetric_difference/issubset/issuperset. These are
// declared with min=0 and one optional parameter, so >1 args reports
// "want at most 1" and a non-iterable reports the parameter-named unpack error.
fn set_other_iter(
  ctx : EvalContext,
  name : String,
  pos_args : Array[@value.Value],
  kw_args : Array[(String, @value.Value)],
) -> @value.StarlarkIterator raise EvalErr {
  check_positional(ctx, name, pos_args, kw_args, 0, 1)
  if pos_args.length() != 1 {
    raise EvalErr(make_eval_error(ctx, "\{name}: missing argument"))
  }
  match @value.iterate(pos_args[0]) {
    Ok(it) => it
    Err(_) =>
      raise EvalErr(
        make_eval_error(
          ctx,
          "\{name}: for parameter 1: got \{@value.type_name(pos_args[0])}, want iterable",
        ),
      )
  }
}

///|
fn call_set_method(
  ctx : EvalContext,
  s : @value.StarlarkSet,
  method_name : String,
  pos_args : Array[@value.Value],
  kw_args : Array[(String, @value.Value)],
) -> @value.Value raise EvalErr {
  match method_name {
    "add" => {
      check_positional(ctx, "add", pos_args, kw_args, 1, 1)
      match s.add(pos_args[0]) {
        Err(e) => raise EvalErr(make_eval_error(ctx, "add: \{e}"))
        Ok(_) => ()
      }
      @value.Value::None
    }
    "discard" => {
      check_positional(ctx, "discard", pos_args, kw_args, 1, 1)
      match s.remove(pos_args[0]) {
        Err(e) => raise EvalErr(make_eval_error(ctx, "discard: \{e}"))
        Ok(_) => ()
      }
      @value.Value::None
    }
    "remove" => {
      check_positional(ctx, "remove", pos_args, kw_args, 1, 1)
      match s.remove(pos_args[0]) {
        Err(e) => raise EvalErr(make_eval_error(ctx, "remove: \{e}"))
        Ok(false) => raise EvalErr(make_eval_error(ctx, "remove: missing key"))
        Ok(true) => ()
      }
      @value.Value::None
    }
    "clear" => {
      check_positional(ctx, "clear", pos_args, kw_args, 0, 0)
      if s.length() == 0 {
        return @value.Value::None
      }
      match s.clear() {
        Err(e) => raise EvalErr(make_eval_error(ctx, "clear: \{e}"))
        Ok(_) => ()
      }
      @value.Value::None
    }
    "pop" => {
      check_positional(ctx, "pop", pos_args, kw_args, 0, 0)
      match s.pop_first() {
        Err(e) => raise EvalErr(make_eval_error(ctx, "pop: \{e}"))
        Ok(None) => raise EvalErr(make_eval_error(ctx, "pop: empty set"))
        Ok(Some(v)) => v
      }
    }
    "union" => {
      if kw_args.length() > 0 {
        raise EvalErr(
          make_eval_error(ctx, "union: does not accept keyword arguments"),
        )
      }
      let result = @value.StarlarkSet::new()
      s.each(fn(v) { ignore(result.add(v)) })
      for i in 0..<pos_args.length() {
        set_iterate_into(ctx, pos_args[i], i + 1, "union", result)
      }
      @value.Value::Set(result)
    }
    "intersection" => {
      let result = @value.StarlarkSet::new()
      let it = set_other_iter(ctx, "intersection", pos_args, kw_args)
      while true {
        match it.next() {
          None => {
            it.done()
            break
          }
          Some(v) =>
            match s.contains(v) {
              Ok(true) => ignore(result.add(v))
              _ => ()
            }
        }
      }
      @value.Value::Set(result)
    }
    "difference" => {
      let other_set = @value.StarlarkSet::new()
      let it = set_other_iter(ctx, "difference", pos_args, kw_args)
      while true {
        match it.next() {
          None => {
            it.done()
            break
          }
          Some(v) => ignore(other_set.add(v))
        }
      }
      let result = @value.StarlarkSet::new()
      s.each(fn(v) {
        match other_set.contains(v) {
          Ok(false) => ignore(result.add(v))
          _ => ()
        }
      })
      @value.Value::Set(result)
    }
    "symmetric_difference" => {
      let other_items : Array[@value.Value] = []
      let it = set_other_iter(ctx, "symmetric_difference", pos_args, kw_args)
      while true {
        match it.next() {
          None => {
            it.done()
            break
          }
          Some(v) => other_items.push(v)
        }
      }
      let other_set = @value.StarlarkSet::new()
      for v in other_items {
        ignore(other_set.add(v))
      }
      let result = @value.StarlarkSet::new()
      s.each(fn(v) {
        match other_set.contains(v) {
          Ok(false) => ignore(result.add(v))
          _ => ()
        }
      })
      for v in other_items {
        match s.contains(v) {
          Ok(false) => ignore(result.add(v))
          _ => ()
        }
      }
      @value.Value::Set(result)
    }
    "issubset" => {
      let other_set = @value.StarlarkSet::new()
      let it = set_other_iter(ctx, "issubset", pos_args, kw_args)
      while true {
        match it.next() {
          None => {
            it.done()
            break
          }
          Some(v) => ignore(other_set.add(v))
        }
      }
      let mut all_in = true
      s.each(fn(v) {
        match other_set.contains(v) {
          Ok(true) => ()
          _ => all_in = false
        }
      })
      @value.Value::Bool(all_in)
    }
    "issuperset" => {
      let mut all_in = true
      let it = set_other_iter(ctx, "issuperset", pos_args, kw_args)
      while true {
        match it.next() {
          None => {
            it.done()
            break
          }
          Some(v) =>
            match s.contains(v) {
              Ok(true) => ()
              _ => {
                it.done()
                all_in = false
                break
              }
            }
        }
      }
      @value.Value::Bool(all_in)
    }
    "update" => {
      if kw_args.length() > 0 {
        raise EvalErr(
          make_eval_error(ctx, "update: does not accept keyword arguments"),
        )
      }
      for i in 0..<pos_args.length() {
        let arg = pos_args[i]
        let it = match @value.iterate(arg) {
          Err(_) =>
            raise EvalErr(
              make_eval_error(
                ctx,
                "update: argument #\{i + 1} is not iterable: \{@value.type_name(arg)}",
              ),
            )
          Ok(it) => it
        }
        while true {
          match it.next() {
            None => {
              it.done()
              break
            }
            Some(v) =>
              match s.add(v) {
                Err(e) => raise EvalErr(make_eval_error(ctx, "update: \{e}"))
                Ok(_) => ()
              }
          }
        }
      }
      @value.Value::None
    }
    _ =>
      raise EvalErr(make_eval_error(ctx, "set has no method '\{method_name}'"))
  }
}

///|
fn builtin_bytes(
  ctx : EvalContext,
  pos_args : Array[@value.Value],
) -> @value.Value raise EvalErr {
  if pos_args.length() != 1 {
    raise EvalErr(
      make_eval_error(
        ctx,
        "bytes: got \{pos_args.length()} arguments, want exactly 1",
      ),
    )
  }
  match pos_args[0] {
    @value.Value::Bytes(b) => @value.Value::Bytes(b)
    @value.Value::String(s) => @value.Value::Bytes(s.to_bytes())
    other => {
      let it = match @value.iterate(other) {
        Err(_) =>
          raise EvalErr(
            make_eval_error(
              ctx,
              "bytes: got \{@value.type_name(other)}, want string, bytes, or iterable of ints",
            ),
          )
        Ok(it) => it
      }
      let buf : Array[Byte] = []
      let mut idx = 0
      while true {
        match it.next() {
          None => {
            it.done()
            break
          }
          Some(@value.Value::Int(n)) => {
            if n < 0N || n > 255N {
              it.done()
              raise EvalErr(
                make_eval_error(
                  ctx,
                  "bytes: at index \{idx}, \{n} out of range (want value in unsigned 8-bit range)",
                ),
              )
            }
            buf.push(n.to_int().to_byte())
            idx += 1
          }
          Some(v) => {
            it.done()
            raise EvalErr(
              make_eval_error(
                ctx,
                "bytes: at index \{idx}, got \{@value.type_name(v)}, want int",
              ),
            )
          }
        }
      }
      @value.Value::Bytes(Bytes::from_array(buf))
    }
  }
}

///|
fn call_bytes_method(
  ctx : EvalContext,
  b : Bytes,
  method_name : String,
  _pos_args : Array[@value.Value],
) -> @value.Value raise EvalErr {
  match method_name {
    "elems" => @value.Value::BytesElems(@value.StarlarkBytesElems::new(b))
    _ =>
      raise EvalErr(
        make_eval_error(ctx, "bytes has no method '\{method_name}'"),
      )
  }
}

///|
// Validate a builtin/method's positional-argument count and reject keyword
// arguments.
fn check_positional(
  ctx : EvalContext,
  name : String,
  pos_args : Array[@value.Value],
  kw_args : Array[(String, @value.Value)],
  min : Int,
  max : Int,
) -> Unit raise EvalErr {
  if kw_args.length() > 0 {
    raise EvalErr(make_eval_error(ctx, "\{name}: unexpected keyword arguments"))
  }
  let n = pos_args.length()
  if n < min {
    let atleast = if min < max { "at least " } else { "" }
    raise EvalErr(
      make_eval_error(ctx, "\{name}: got \{n} arguments, want \{atleast}\{min}"),
    )
  }
  if n > max {
    let atmost = if max > min { "at most " } else { "" }
    raise EvalErr(
      make_eval_error(ctx, "\{name}: got \{n} arguments, want \{atmost}\{max}"),
    )
  }
}

///|
// Reject keyword arguments with the "X does not accept keyword
// arguments" message (used by builtins that bypass UnpackPositionalArgs).
fn reject_kwargs(
  ctx : EvalContext,
  name : String,
  kw_args : Array[(String, @value.Value)],
) -> Unit raise EvalErr {
  if kw_args.length() > 0 {
    raise EvalErr(
      make_eval_error(ctx, "\{name} does not accept keyword arguments"),
    )
  }
}

///|
// Coerce the `idx`-th (0-based) positional argument to a string, raising the
// unpack error on type mismatch.
fn arg_as_string(
  ctx : EvalContext,
  name : String,
  pos_args : Array[@value.Value],
  idx : Int,
) -> @value.StarlarkString raise EvalErr {
  match pos_args[idx] {
    @value.Value::String(s) => s
    v =>
      raise EvalErr(
        make_eval_error(
          ctx,
          "\{name}: for parameter \{idx + 1}: got \{@value.type_name(v)}, want string",
        ),
      )
  }
}

///|
// Coerce the `idx`-th (0-based) positional argument to an int, raising the
// unpack error on type mismatch.
fn arg_as_int(
  ctx : EvalContext,
  name : String,
  pos_args : Array[@value.Value],
  idx : Int,
) -> Int raise EvalErr {
  match pos_args[idx] {
    @value.Value::Int(n) => n.to_int()
    v =>
      raise EvalErr(
        make_eval_error(
          ctx,
          "\{name}: for parameter \{idx + 1}: got \{@value.type_name(v)}, want int",
        ),
      )
  }
}

///|
// Validate and extract an optional start/end index argument for string search
// methods. Accepts Int (clamped) or None (default); errors on any other type.
fn parse_search_index(
  ctx : EvalContext,
  mname : String,
  args : Array[@value.Value],
  pos : Int,
  slen : Int,
  default_val : Int,
  kind : String,
) -> Int raise EvalErr {
  if args.length() > pos {
    match args[pos] {
      @value.Value::Int(n) => {
        if n.compare_int64(@int64.MAX_VALUE) > 0 ||
          n.compare_int64(@int64.MIN_VALUE) < 0 {
          raise EvalErr(
            make_eval_error(
              ctx,
              "\{mname}: invalid \{kind} index: \{n} out of range",
            ),
          )
        }
        let i64 = n.to_int64()
        let slen64 = slen.to_int64()
        if i64 >= slen64 {
          slen
        } else if i64 < -slen64 {
          0
        } else {
          clamp_byte_index(i64.to_int(), slen)
        }
      }
      @value.Value::None => default_val
      v =>
        raise EvalErr(
          make_eval_error(
            ctx,
            "\{mname}: invalid \{kind} index: got \{@value.type_name(v)}, want int",
          ),
        )
    }
  } else {
    default_val
  }
}

///|
// Clamp a Starlark start/end index against a byte length: negatives count from
// the end, then clamp to [0, len].
fn clamp_byte_index(idx : Int, blen : Int) -> Int {
  if idx < 0 {
    (blen + idx).max(0)
  } else {
    idx.min(blen)
  }
}

///|
// Slice a StarlarkString by byte offsets [lo, hi), returning a new string.
fn str_byte_slice(
  s : @value.StarlarkString,
  lo : Int,
  hi : Int,
) -> @value.StarlarkString {
  if lo >= hi {
    return @value.StarlarkString::new("")
  }
  let buf : Array[Byte] = []
  for i in lo..<hi {
    buf.push(s.byte_at(i))
  }
  @value.StarlarkString::from_bytes(Bytes::from_array(buf))
}

///|
// First byte offset of `needle` within `hay[lo:hi]`, or -1. Empty needle → lo.
fn bytes_index_in(
  hay : @value.StarlarkString,
  lo : Int,
  hi : Int,
  needle : @value.StarlarkString,
) -> Int {
  let nlen = needle.byte_len()
  if nlen == 0 {
    return lo
  }
  let limit = hi - nlen
  let mut i = lo
  while i <= limit {
    let mut k = 0
    while k < nlen && hay.byte_at(i + k) == needle.byte_at(k) {
      k = k + 1
    }
    if k == nlen {
      return i
    }
    i = i + 1
  }
  -1
}

///|
// Last byte offset of `needle` within `hay[lo:hi]`, or -1. Empty needle → hi.
fn bytes_last_index_in(
  hay : @value.StarlarkString,
  lo : Int,
  hi : Int,
  needle : @value.StarlarkString,
) -> Int {
  let nlen = needle.byte_len()
  if nlen == 0 {
    return hi
  }
  let mut i = hi - nlen
  while i >= lo {
    let mut k = 0
    while k < nlen && hay.byte_at(i + k) == needle.byte_at(k) {
      k = k + 1
    }
    if k == nlen {
      return i
    }
    i = i - 1
  }
  -1
}

///|
fn bytes_has_prefix(
  s : @value.StarlarkString,
  prefix : @value.StarlarkString,
) -> Bool {
  let plen = prefix.byte_len()
  if plen > s.byte_len() {
    return false
  }
  for k in 0..<plen {
    if s.byte_at(k) != prefix.byte_at(k) {
      return false
    }
  }
  true
}

///|
fn bytes_has_suffix(
  s : @value.StarlarkString,
  suffix : @value.StarlarkString,
) -> Bool {
  let slen = suffix.byte_len()
  let off = s.byte_len() - slen
  if off < 0 {
    return false
  }
  for k in 0..<slen {
    if s.byte_at(off + k) != suffix.byte_at(k) {
      return false
    }
  }
  true
}

///|
// Count non-overlapping occurrences of `needle` within `hay[lo:hi]`.
// Empty needle yields the Unicode code point count plus one (Go strings.Count).
fn bytes_count_in(
  hay : @value.StarlarkString,
  lo : Int,
  hi : Int,
  needle : @value.StarlarkString,
) -> Int {
  let nlen = needle.byte_len()
  if nlen == 0 {
    let bytes = hay.to_bytes()
    let mut runes = 0
    let mut i = lo
    while i < hi {
      let (_, width) = @utf8util.utf8_decode_rune(bytes, i)
      runes = runes + 1
      i = i + width
    }
    return runes + 1
  }
  let mut count = 0
  let mut i = lo
  while i <= hi - nlen {
    let mut k = 0
    while k < nlen && hay.byte_at(i + k) == needle.byte_at(k) {
      k = k + 1
    }
    if k == nlen {
      count = count + 1
      i = i + nlen
    } else {
      i = i + 1
    }
  }
  count
}

///|
fn find_substr(s : String, sub : String) -> Int {
  if sub.length() == 0 {
    return 0
  }
  let slen = s.length()
  let sublen = sub.length()
  if sublen > slen {
    return -1
  }
  for i in 0..<=(slen - sublen) {
    let mut match_ = true
    for j in 0..<sublen {
      if s[i + j] != sub[j] {
        match_ = false
        break
      }
    }
    if match_ {
      return i
    }
  }
  -1
}

///|
fn is_whitespace(c : Char) -> Bool {
  // Mirror Go's unicode.IsSpace, which Starlark uses for whitespace-based
  // split/strip and isspace: ASCII controls + space, the Latin-1 NEL and
  // no-break space, and the Unicode White_Space code points.
  let n = c.to_int()
  match n {
    0x09 | 0x0A | 0x0B | 0x0C | 0x0D | 0x20 => true
    0x85 | 0xA0 => true
    0x1680 => true
    0x2028 | 0x2029 | 0x202F | 0x205F | 0x3000 => true
    _ => n >= 0x2000 && n <= 0x200A
  }
}

///|
/// Applies a per-rune mapping to every codepoint of a string and rebuilds it.
fn map_string_runes(raw : String, f : (Int) -> Int) -> String {
  let buf = StringBuilder::new()
  for c in raw {
    buf.write_char(f(c.to_int()).unsafe_to_char())
  }
  buf.to_string()
}

///|
fn to_value_list(parts : Array[String]) -> @value.Value {
  let items : Array[@value.Value] = []
  for p in parts {
    items.push(@value.Value::String(@value.StarlarkString::new(p)))
  }
  @value.Value::List(@value.StarlarkList::new(items))
}

///|
fn split_whitespace(s : String, maxsplit : Int) -> Array[String] {
  let chars = s.to_array()
  let n = chars.length()
  let result : Array[String] = []
  let mut start = -1
  for i in 0..<n {
    let c = chars[i]
    if is_whitespace(c) {
      if start >= 0 {
        if maxsplit >= 0 && result.length() == maxsplit {
          break
        }
        let buf = StringBuilder::new()
        for k in start..<i {
          buf.write_char(chars[k])
        }
        result.push(buf.to_string())
        start = -1
      }
    } else if start == -1 {
      start = i
    }
  }
  if start >= 0 {
    let buf = StringBuilder::new()
    for k in start..<n {
      buf.write_char(chars[k])
    }
    result.push(buf.to_string())
  }
  result
}

///|
fn rsplit_whitespace(s : String, maxsplit : Int) -> Array[String] {
  let chars = s.to_array()
  let n = chars.length()
  let result : Array[String] = []
  let mut end_pos = -1
  let mut i = n - 1
  while i >= 0 {
    let c = chars[i]
    if is_whitespace(c) {
      if end_pos >= 0 {
        if maxsplit >= 0 && result.length() == maxsplit {
          break
        }
        let buf = StringBuilder::new()
        for k in (i + 1)..<end_pos {
          buf.write_char(chars[k])
        }
        result.push(buf.to_string())
        end_pos = -1
      }
    } else if end_pos == -1 {
      end_pos = i + 1
    }
    i -= 1
  }
  if end_pos >= 0 {
    let buf = StringBuilder::new()
    for k in 0..<end_pos {
      buf.write_char(chars[k])
    }
    result.push(buf.to_string())
  }
  result.rev()
}

///|
fn find_substr_from(s : String, sub : String, from : Int) -> Int {
  if sub.length() == 0 {
    return from
  }
  let slen = s.length()
  let sublen = sub.length()
  if from + sublen > slen {
    return -1
  }
  for i in from..<=(slen - sublen) {
    let mut match_ = true
    for j in 0..<sublen {
      if s[i + j] != sub[j] {
        match_ = false
        break
      }
    }
    if match_ {
      return i
    }
  }
  -1
}

///|
fn rfind_substr_before(s : String, sub : String, before : Int) -> Int {
  if sub.length() == 0 {
    return before
  }
  let sublen = sub.length()
  let end = (before - sublen).min(s.length() - sublen)
  if end < 0 {
    return -1
  }
  let mut i = end
  while i >= 0 {
    let mut match_ = true
    for j in 0..<sublen {
      if s[i + j] != sub[j] {
        match_ = false
        break
      }
    }
    if match_ {
      return i
    }
    i -= 1
  }
  -1
}

///|
fn split_by_sep(s : String, sep : String, maxsplit : Int) -> Array[String] {
  let seplen = sep.length()
  let slen = s.length()
  let parts : Array[String] = []
  let mut start = 0
  let mut splits = 0
  while start <= slen {
    if maxsplit >= 0 && splits >= maxsplit {
      parts.push(s[start:].to_owned())
      break
    }
    let idx = find_substr_from(s, sep, start)
    if idx < 0 {
      parts.push(s[start:].to_owned())
      break
    }
    parts.push(s[start:idx].to_owned())
    start = idx + seplen
    splits += 1
  }
  parts
}

///|
fn rsplit_by_sep(s : String, sep : String, maxsplit : Int) -> Array[String] {
  if maxsplit < 0 {
    return split_by_sep(s, sep, -1)
  }
  let seplen = sep.length()
  let slen = s.length()
  let parts : Array[String] = []
  let mut end = slen
  let mut splits = 0
  while end >= 0 {
    if splits >= maxsplit {
      parts.push(s[0:end].to_owned())
      break
    }
    let idx = rfind_substr_before(s, sep, end)
    if idx < 0 {
      parts.push(s[0:end].to_owned())
      break
    }
    parts.push(s[idx + seplen:end].to_owned())
    end = idx
    splits += 1
  }
  parts.rev()
}

///|
fn strip_whitespace(s : String, from_left : Bool, from_right : Bool) -> String {
  let chars = s.to_array()
  let n = chars.length()
  let mut start = 0
  let mut end = n
  if from_left {
    while start < end && is_whitespace(chars[start]) {
      start += 1
    }
  }
  if from_right {
    while end > start && is_whitespace(chars[end - 1]) {
      end -= 1
    }
  }
  let buf = StringBuilder::new()
  for i in start..<end {
    buf.write_char(chars[i])
  }
  buf.to_string()
}

///|
fn strip_chars(
  s : String,
  chars : String,
  from_left : Bool,
  from_right : Bool,
) -> String {
  let char_set = chars.to_array()
  let s_chars = s.to_array()
  let n = s_chars.length()
  let mut start = 0
  let mut end = n
  if from_left {
    while start < end {
      let c = s_chars[start]
      if char_set.contains(c) {
        start += 1
      } else {
        break
      }
    }
  }
  if from_right {
    while end > start {
      let c = s_chars[end - 1]
      if char_set.contains(c) {
        end -= 1
      } else {
        break
      }
    }
  }
  let buf = StringBuilder::new()
  for i in start..<end {
    buf.write_char(s_chars[i])
  }
  buf.to_string()
}

///|
fn str_replace_count(
  s : String,
  old : String,
  new_s : String,
  count : Int,
) -> String {
  if old.length() == 0 {
    let buf = StringBuilder::new()
    let chars = s.to_array()
    let mut replacements = 0
    for i in 0..<chars.length() {
      if replacements < count {
        buf.write_string(new_s)
        replacements += 1
      }
      buf.write_char(chars[i])
    }
    if replacements < count {
      buf.write_string(new_s)
    }
    return buf.to_string()
  }
  let buf = StringBuilder::new()
  let slen = s.length()
  let oldlen = old.length()
  let mut start = 0
  let mut replacements = 0
  while start <= slen && replacements < count {
    let idx = find_substr_from(s, old, start)
    if idx < 0 {
      break
    }
    buf.write_string(s[start:idx].to_owned())
    buf.write_string(new_s)
    start = idx + oldlen
    replacements += 1
  }
  buf.write_string(s[start:].to_owned())
  buf.to_string()
}

///|
fn str_format(
  ctx : EvalContext,
  template : String,
  args : Array[@value.Value],
  kw_args : Array[(String, @value.Value)],
) -> @value.Value raise EvalErr {
  let buf = StringBuilder::new()
  let tlen = template.length()
  let mut i = 0
  let mut auto_idx = 0
  let mut auto_mode = false
  let mut manual_mode = false
  while i < tlen {
    let c = template[i]
    if c == '{' {
      if i + 1 < tlen && template[i + 1] == '{' {
        buf.write_char('{')
        i += 2
      } else {
        let start = i + 1
        let mut j = start
        while j < tlen && template[j] != '}' {
          if template[j] == '{' {
            raise EvalErr(
              make_eval_error(
                ctx, "format: nested replacement fields not supported",
              ),
            )
          }
          j += 1
        }
        if j >= tlen {
          raise EvalErr(make_eval_error(ctx, "format: unmatched '{' in format"))
        }
        let field = template[start:j].to_owned()
        i = j + 1
        let (name, conv) = if find_substr(field, "!") >= 0 {
          let bang = find_substr(field, "!")
          let raw_name = field[0:bang].to_owned()
          let after_bang = field[bang + 1:].to_owned()
          let colon = find_substr(after_bang, ":")
          let (conv_part, spec_part) = if colon >= 0 {
            (after_bang[0:colon].to_owned(), after_bang[colon + 1:].to_owned())
          } else {
            (after_bang, "")
          }
          if spec_part != "" {
            raise EvalErr(
              make_eval_error(
                ctx,
                "format spec features not supported in replacement fields: \{spec_part}",
              ),
            )
          }
          (raw_name, conv_part)
        } else {
          let colon = find_substr(field, ":")
          if colon >= 0 {
            let spec_part = field[colon + 1:].to_owned()
            if spec_part != "" {
              raise EvalErr(
                make_eval_error(
                  ctx,
                  "format spec features not supported in replacement fields: \{spec_part}",
                ),
              )
            }
            (field[0:colon].to_owned(), "s")
          } else {
            (field, "s")
          }
        }
        if find_substr(name, ".") >= 0 {
          raise EvalErr(
            make_eval_error(
              ctx,
              "format: attribute syntax x.y is not supported in replacement fields: \{name}",
            ),
          )
        }
        if find_substr(name, "[") >= 0 {
          raise EvalErr(
            make_eval_error(
              ctx,
              "format: element syntax a[i] is not supported in replacement fields: \{name}",
            ),
          )
        }
        let arg = if name == "" {
          if manual_mode {
            raise EvalErr(
              make_eval_error(
                ctx, "format: cannot switch from manual field specification to automatic field numbering",
              ),
            )
          }
          auto_mode = true
          if auto_idx >= args.length() {
            raise EvalErr(
              make_eval_error(ctx, "format: tuple index out of range"),
            )
          }
          let v = args[auto_idx]
          auto_idx += 1
          v
        } else {
          let mut is_digit = name.length() > 0
          for k in 0..<name.length() {
            if name[k] < '0' || name[k] > '9' {
              is_digit = false
              break
            }
          }
          // A field name made entirely of digits is a positional index only
          // when it fits in a machine int; an overflowing all-digit name
          // falls through to the keyword path (matches Go's decimal()).
          let index : Int? = if is_digit {
            match parse_int_str(name, 10) {
              Ok(n) =>
                if n.compare_int64(@int64.MAX_VALUE) <= 0 &&
                  n.compare_int64(@int64.MIN_VALUE) >= 0 {
                  Some(n.to_int64().to_int())
                } else {
                  None
                }
              Err(_) => None
            }
          } else {
            None
          }
          match index {
            Some(n) => {
              if auto_mode {
                raise EvalErr(
                  make_eval_error(
                    ctx, "format: cannot switch from automatic field numbering to manual field specification",
                  ),
                )
              }
              manual_mode = true
              if n >= args.length() {
                raise EvalErr(
                  make_eval_error(ctx, "format: tuple index out of range"),
                )
              }
              args[n]
            }
            None => {
              let mut found : @value.Value? = None
              for kv in kw_args {
                let (k, v) = kv
                if k == name {
                  found = Some(v)
                  break
                }
              }
              match found {
                None =>
                  raise EvalErr(
                    make_eval_error(ctx, "format: keyword \{name} not found"),
                  )
                Some(v) => v
              }
            }
          }
        }
        match conv {
          "s" => buf.write_string(@value.to_str(arg))
          "r" => buf.write_string(@value.repr(arg))
          other =>
            raise EvalErr(
              make_eval_error(ctx, "format: unknown conversion \"\{other}\""),
            )
        }
      }
    } else if c == '}' {
      if i + 1 < tlen && template[i + 1] == '}' {
        buf.write_char('}')
        i += 2
      } else {
        raise EvalErr(make_eval_error(ctx, "format: single '}' in format"))
      }
    } else {
      buf.write_char(Int::unsafe_to_char(c.to_int()))
      i += 1
    }
  }
  @value.Value::String(@value.StarlarkString::new(buf.to_string()))
}

///|
fn parse_int_str(s : String, base : Int) -> Result[BigInt, String] {
  if s.length() == 0 {
    return Err("invalid literal with base \{base}: \{s}")
  }
  let negative = s[0] == '-'
  let start = if negative || s[0] == '+' { 1 } else { 0 }
  if start >= s.length() {
    return Err("invalid literal with base \{base}: \{s}")
  }
  let actual_base = if base == 0 {
    if s[start] == '0' && start + 1 < s.length() {
      match s[start + 1] {
        'x' | 'X' => 16
        'o' | 'O' => 8
        'b' | 'B' => 2
        _ => {
          if s[start + 1] >= '1' && s[start + 1] <= '9' {
            return Err("invalid literal with base 0: \{s}")
          }
          10
        }
      }
    } else {
      10
    }
  } else {
    base
  }
  let report_base = if base == 0 { actual_base } else { base }
  let digit_start = if s[start] == '0' && start + 1 < s.length() {
    let prefix = s[start + 1]
    if (prefix == 'x' || prefix == 'X') && actual_base == 16 {
      start + 2
    } else if (prefix == 'o' || prefix == 'O') && actual_base == 8 {
      start + 2
    } else if (prefix == 'b' || prefix == 'B') && actual_base == 2 {
      start + 2
    } else {
      start
    }
  } else {
    start
  }
  if digit_start >= s.length() {
    return Err("invalid literal with base \{report_base}: \{s}")
  }
  let digits = s[digit_start:].to_owned()
  for i in 0..<digits.length() {
    let c = digits[i].to_int()
    let digit = if c >= '0'.to_int() && c <= '9'.to_int() {
      c - '0'.to_int()
    } else if c >= 'a'.to_int() && c <= 'z'.to_int() {
      c - 'a'.to_int() + 10
    } else if c >= 'A'.to_int() && c <= 'Z'.to_int() {
      c - 'A'.to_int() + 10
    } else {
      return Err("invalid literal with base \{report_base}: \{s}")
    }
    if digit >= actual_base {
      return Err("invalid literal with base \{report_base}: \{s}")
    }
  }
  let result = BigInt::from_string(digits, radix=actual_base)
  Ok(if negative { -result } else { result })
}

///|
// eval_comp_clauses evaluates comprehension clauses sharing a single comp_env.
// outer_env: the scope outside the comprehension (used only for the first
// clause's iterable).
// comp_env: the shared comprehension scope with all for-target names in
// known_locals so that a target used as its own iterable raises LUnbound.
fn eval_comp_clauses(
  ctx : EvalContext,
  outer_env : EvalEnv,
  comp_env : EvalEnv,
  clauses : Array[@syntax.CompClause],
  idx : Int,
  body_fn : (EvalEnv) -> Unit raise EvalErr,
) -> Unit raise EvalErr {
  if idx >= clauses.length() {
    return body_fn(comp_env)
  }
  match clauses[idx] {
    @syntax.CompClause::ClauseFor(target, iter_expr, clause_pos) => {
      // First clause's iterable is evaluated in the outer scope;
      // subsequent clauses' iterables are evaluated in the comp scope.
      let eval_env = if idx == 0 { outer_env } else { comp_env }
      let iter_val = eval_expr_node(ctx, eval_env, iter_expr)
      let it = check(ctx, @value.iterate(iter_val))
      let mut continue_loop = true
      while continue_loop {
        match it.next() {
          None => {
            it.done()
            continue_loop = false
          }
          Some(item) =>
            try {
              assign_to(ctx, comp_env, target, item, clause_pos)
              eval_comp_clauses(
                ctx,
                outer_env,
                comp_env,
                clauses,
                idx + 1,
                body_fn,
              )
            } catch {
              EvalErr(e) => {
                it.done()
                raise EvalErr(e)
              }
            }
        }
      }
    }
    @syntax.CompClause::ClauseIf(cond_expr, _) => {
      let cond_val = eval_expr_node(ctx, comp_env, cond_expr)
      if @value.truth(cond_val) {
        eval_comp_clauses(ctx, outer_env, comp_env, clauses, idx + 1, body_fn)
      }
    }
  }
}

///|
fn collect_comp_target_names(
  clauses : Array[@syntax.CompClause],
) -> Array[String] {
  let result : Array[String] = []
  for clause in clauses {
    match clause {
      @syntax.CompClause::ClauseFor(target, _, _) =>
        collect_lhs_names(target, result)
      _ => ()
    }
  }
  result
}

///|
fn collect_assigned_names(stmts : Array[@syntax.Stmt]) -> Array[String] {
  let result : Array[String] = []
  collect_stmts_names(stmts, result)
  result
}

///|
fn collect_stmts_names(
  stmts : Array[@syntax.Stmt],
  out : Array[String],
) -> Unit {
  for stmt in stmts {
    match stmt {
      @syntax.Stmt::SAssign(lhs, _, _) => collect_lhs_names(lhs, out)
      @syntax.Stmt::SAugAssign(@syntax.Expr::EIdent(name, _), _, _, _) =>
        push_unique_name(name, out)
      @syntax.Stmt::SFor(target, _, body, _) => {
        collect_lhs_names(target, out)
        collect_stmts_names(body, out)
      }
      @syntax.Stmt::SDef(name, _, _, _) => push_unique_name(name, out)
      @syntax.Stmt::SIf(_, then_body, else_body, _) => {
        collect_stmts_names(then_body, out)
        collect_stmts_names(else_body, out)
      }
      @syntax.Stmt::SWhile(_, body, _) => collect_stmts_names(body, out)
      _ => ()
    }
  }
}

///|
fn collect_lhs_names(expr : @syntax.Expr, out : Array[String]) -> Unit {
  match expr {
    @syntax.Expr::EIdent(name, _) => push_unique_name(name, out)
    @syntax.Expr::ETuple(elems, _) | @syntax.Expr::EList(elems, _) =>
      for elem in elems {
        collect_lhs_names(elem, out)
      }
    _ => ()
  }
}

///|
fn push_unique_name(name : String, out : Array[String]) -> Unit {
  if !out.contains(name) {
    out.push(name)
  }
}

///|
fn is_float_syntax(s : String) -> Bool {
  let n = s.length()
  let mut i = 0
  if i < n && (s[i] == '+' || s[i] == '-') {
    i += 1
  }
  let int_start = i
  while i < n && s[i] >= '0' && s[i] <= '9' {
    i += 1
  }
  let has_int_digits = i > int_start
  let mut has_frac_digits = false
  if i < n && s[i] == '.' {
    i += 1
    let frac_start = i
    while i < n && s[i] >= '0' && s[i] <= '9' {
      i += 1
    }
    has_frac_digits = i > frac_start
  }
  if !has_int_digits && !has_frac_digits {
    return false
  }
  if i < n && (s[i] == 'e' || s[i] == 'E') {
    i += 1
    if i < n && (s[i] == '+' || s[i] == '-') {
      i += 1
    }
    let exp_start = i
    while i < n && s[i] >= '0' && s[i] <= '9' {
      i += 1
    }
    if i == exp_start {
      return false
    }
  }
  i == n
}
