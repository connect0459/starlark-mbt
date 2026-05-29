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
    @syntax.Expr::EList(elems, _) => {
      let items : Array[@value.Value] = []
      for e in elems {
        items.push(eval_expr_node(ctx, env, e))
      }
      @value.Value::List(@value.StarlarkList::new(items))
    }
    @syntax.Expr::ETuple(elems, _) => {
      let items : Array[@value.Value] = []
      for e in elems {
        items.push(eval_expr_node(ctx, env, e))
      }
      @value.Value::Tuple(items)
    }
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
        @value.Value::Int(n) => Some(n.to_int())
        _ =>
          raise EvalErr(make_eval_error(ctx, "slice step must be an integer"))
      }
      let lo = match lo_val {
        @value.Value::None => None
        @value.Value::Int(n) => Some(n.to_int())
        _ =>
          raise EvalErr(make_eval_error(ctx, "slice indices must be integers"))
      }
      let hi = match hi_val {
        @value.Value::None => None
        @value.Value::Int(n) => Some(n.to_int())
        _ =>
          raise EvalErr(make_eval_error(ctx, "slice indices must be integers"))
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
        "<lambda>",
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
      eval_comp_clauses(ctx, env, clauses, 0, fn(inner_env) raise EvalErr {
        result.push(eval_expr_node(ctx, inner_env, body_expr))
      })
      @value.Value::List(@value.StarlarkList::new(result))
    }
    @syntax.Expr::ESetComp(body_expr, clauses, _) => {
      let s = @value.StarlarkSet::new()
      eval_comp_clauses(ctx, env, clauses, 0, fn(inner_env) raise EvalErr {
        let v = eval_expr_node(ctx, inner_env, body_expr)
        check(ctx, s.add(v))
      })
      @value.Value::Set(s)
    }
    @syntax.Expr::EDictComp(key_expr, val_expr, clauses, _) => {
      let d = @value.StarlarkDict::new()
      eval_comp_clauses(ctx, env, clauses, 0, fn(inner_env) raise EvalErr {
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
    | @value.Value::Bytes(_) =>
      @value.Value::BoundMethod(@value.StarlarkBoundMethod::new(obj, attr))
    @value.Value::Module(m) =>
      match m.get(attr) {
        Some(v) => v
        None => {
          let candidates = m.attr_names()
          let hint = match spell_nearest(attr, candidates) {
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
              "\{@value.type_name(obj)} has no attribute '\{attr}'",
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
        if v is @value.Value::String(_) {
          raise EvalErr(make_eval_error(ctx, "must be iterable, not string"))
        }
        let it = check(ctx, @value.iterate(v))
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
            d.each(fn(k, val) {
              match k {
                @value.Value::String(s) => kw_args.push((s.raw(), val))
                _ => ()
              }
            })
          _ =>
            raise EvalErr(make_eval_error(ctx, "** operand must be a mapping"))
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
  match func_val {
    @value.Value::Function(f) => call_func(ctx, f, pos_args, kw_args, pos)
    @value.Value::Builtin(f) => {
      let builtin_frame = @errors.CallFrame::new(
        f.name(),
        @errors.Position::new("<builtin>", 0, 0),
      )
      ctx.thread.call_stack.push(builtin_frame)
      let call_ctx = @value.BuiltinCallCtx::new(fn(f2, args, kwargs) {
        Ok(call_value(ctx, f2, args, kwargs, pos)) catch {
          EvalErr(e) => Err(e.msg())
        }
      })
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
              "'\{c.get_type_name()}' object is not callable",
            ),
          )
      }
    _ =>
      raise EvalErr(
        make_eval_error(
          ctx,
          "'\{@value.type_name(func_val)}' object is not callable",
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
fn bind_args(
  ctx : EvalContext,
  f : @value.StarlarkFunction,
  pos_args : Array[@value.Value],
  kw_args : Array[(String, @value.Value)],
  func_env : EvalEnv,
  _pos : @errors.Position,
) -> Unit raise EvalErr {
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
  let params = f.params()
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
          raise EvalErr(
            make_eval_error(
              ctx,
              "function \{f.name()} accepts at most \{max_pos} positional arguments (\{pos_args.length()} given)",
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
    raise EvalErr(
      make_eval_error(
        ctx,
        "function \{f.name()} accepts \{max_pos} positional arguments (\{pos_args.length()} given)",
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
    let hint = match spell_nearest(first_key, valid_names) {
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
          match kv {
            ("sep", @value.Value::String(s)) => {
              found = s.raw()
              break
            }
            _ => ()
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
        buf.write_string(@value.to_str(arg))
      }
      (ctx.thread.print_fn)(ctx.thread, buf.to_string())
      @value.Value::None
    }
    "len" => {
      if pos_args.length() != 1 {
        raise EvalErr(make_eval_error(ctx, "len() takes exactly one argument"))
      }
      let n = check(ctx, @value.length_of(pos_args[0]))
      @value.Value::Int(BigInt::from_int(n))
    }
    "str" =>
      if pos_args.length() == 0 {
        @value.Value::String(@value.StarlarkString::new(""))
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
        raise EvalErr(make_eval_error(ctx, "str() takes at most one argument"))
      }
    "repr" => {
      if pos_args.length() != 1 {
        raise EvalErr(make_eval_error(ctx, "repr() takes exactly one argument"))
      }
      @value.Value::String(@value.StarlarkString::new(@value.repr(pos_args[0])))
    }
    "type" => {
      if pos_args.length() != 1 {
        raise EvalErr(make_eval_error(ctx, "type() takes exactly one argument"))
      }
      @value.Value::String(
        @value.StarlarkString::new(@value.type_name(pos_args[0])),
      )
    }
    "bool" =>
      if pos_args.length() == 0 {
        @value.Value::Bool(false)
      } else if pos_args.length() == 1 {
        @value.Value::Bool(@value.truth(pos_args[0]))
      } else {
        raise EvalErr(make_eval_error(ctx, "bool() takes at most one argument"))
      }
    "int" => {
      let base_from_kw = {
        let mut found : Int? = None
        for kv in kw_args {
          if kv.0 == "base" {
            match kv.1 {
              @value.Value::Int(b) => {
                found = Some(b.to_int())
                break
              }
              _ => ()
            }
          }
        }
        found
      }
      let base_from_pos = if pos_args.length() >= 2 {
        match pos_args[1] {
          @value.Value::Int(b) => Some(b.to_int())
          _ => None
        }
      } else {
        None
      }
      let explicit_base = match base_from_kw {
        Some(b) => Some(b)
        None => base_from_pos
      }
      if pos_args.length() == 0 {
        raise EvalErr(make_eval_error(ctx, "int() missing argument"))
      }
      match (pos_args[0], explicit_base) {
        (@value.Value::String(s), base_opt) => {
          let base = match base_opt {
            Some(b) => b
            None => 10
          }
          let n = check(ctx, parse_int_str(s.raw(), base))
          @value.Value::Int(n)
        }
        (_, Some(_)) =>
          raise EvalErr(make_eval_error(ctx, "non-string with explicit base"))
        (@value.Value::Int(n), None) => @value.Value::Int(n)
        (@value.Value::Float(f), None) =>
          if f.is_nan() {
            raise EvalErr(
              make_eval_error(ctx, "cannot convert float NaN to integer"),
            )
          } else if f.is_inf() {
            raise EvalErr(
              make_eval_error(ctx, "cannot convert float infinity to integer"),
            )
          } else {
            @value.Value::Int(@value.double_to_bigint(f.trunc()))
          }
        (@value.Value::Bool(b), None) =>
          @value.Value::Int(if b { 1N } else { 0N })
        (v, None) =>
          raise EvalErr(
            make_eval_error(
              ctx,
              "int() argument must be a number or string, not '\{@value.type_name(v)}'",
            ),
          )
      }
    }
    "float" =>
      if pos_args.length() == 0 {
        @value.Value::Float(0.0)
      } else if pos_args.length() == 1 {
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
            let raw = s.raw().trim().to_owned()
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
                "float() argument must be a number, not '\{@value.type_name(v)}'",
              ),
            )
        }
      } else {
        raise EvalErr(
          make_eval_error(ctx, "float() takes at most one argument"),
        )
      }
    "abs" => {
      if pos_args.length() != 1 {
        raise EvalErr(make_eval_error(ctx, "abs() takes exactly one argument"))
      }
      match pos_args[0] {
        @value.Value::Int(n) => @value.Value::Int(if n < 0N { -n } else { n })
        @value.Value::Float(f) => @value.Value::Float(f.abs())
        v =>
          raise EvalErr(
            make_eval_error(
              ctx,
              "abs: got \{@value.type_name(v)}, want int or float",
            ),
          )
      }
    }
    "range" => builtin_range(ctx, pos_args)
    "list" => builtin_list(ctx, pos_args)
    "tuple" => builtin_tuple(ctx, pos_args)
    "dict" => builtin_dict(ctx, pos_args, kw_args)
    "set" => builtin_set(ctx, pos_args)
    "bytes" => builtin_bytes(ctx, pos_args)
    "min" => builtin_minmax(ctx, pos_args, kw_args, false)
    "max" => builtin_minmax(ctx, pos_args, kw_args, true)
    "enumerate" => builtin_enumerate(ctx, pos_args)
    "sorted" => builtin_sorted(ctx, pos_args, kw_args)
    "reversed" => builtin_reversed(ctx, pos_args)
    "zip" => builtin_zip(ctx, pos_args)
    "any" => builtin_any_all(ctx, pos_args, true)
    "all" => builtin_any_all(ctx, pos_args, false)
    "hash" => {
      if pos_args.length() != 1 {
        raise EvalErr(make_eval_error(ctx, "hash() takes exactly one argument"))
      }
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
      if pos_args.length() != 1 {
        raise EvalErr(make_eval_error(ctx, "dir() takes exactly one argument"))
      }
      let names : Array[String] = match pos_args[0] {
        @value.Value::String(_) =>
          [
            "capitalize", "count", "elem_ords", "elems", "endswith", "find", "format",
            "index", "isalnum", "isalpha", "isdigit", "islower", "isspace", "istitle",
            "isupper", "join", "lower", "lstrip", "partition", "removeprefix", "removesuffix",
            "replace", "rfind", "rindex", "rpartition", "rstrip", "split", "splitlines",
            "startswith", "strip", "title", "upper",
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
      if pos_args.length() != 1 {
        raise EvalErr(make_eval_error(ctx, "chr() takes exactly one argument"))
      }
      match pos_args[0] {
        @value.Value::Int(n) => {
          if n < 0N || n > BigInt::from_int(0x10ffff) {
            raise EvalErr(
              make_eval_error(
                ctx,
                "chr() argument not in range(0x110000): \{n}",
              ),
            )
          }
          let c = n.to_int().unsafe_to_char()
          let buf = StringBuilder::new()
          buf.write_char(c)
          @value.Value::String(@value.StarlarkString::new(buf.to_string()))
        }
        _ =>
          raise EvalErr(
            make_eval_error(ctx, "chr() argument must be an integer"),
          )
      }
    }
    "ord" => {
      if pos_args.length() != 1 {
        raise EvalErr(make_eval_error(ctx, "ord() takes exactly one argument"))
      }
      match pos_args[0] {
        @value.Value::String(s) => {
          let chars = s.raw().to_array()
          if chars.length() != 1 {
            raise EvalErr(
              make_eval_error(
                ctx,
                "string encodes \{chars.length()} Unicode code points, want 1",
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
        _ =>
          raise EvalErr(make_eval_error(ctx, "ord() argument must be a string"))
      }
    }
    "fail" => {
      let sep = {
        let mut s = " "
        for kv in kw_args {
          match kv {
            ("sep", @value.Value::String(sv)) => {
              s = sv.raw()
              break
            }
            _ => ()
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
      if pos_args.length() != 2 {
        raise EvalErr(
          make_eval_error(ctx, "hasattr() takes exactly 2 arguments"),
        )
      }
      match pos_args[1] {
        @value.Value::String(s) => {
          let dummy_pos = @errors.Position::new("<hasattr>", 0, 0)
          let found = try {
            ignore(eval_getattr(ctx, pos_args[0], s.raw(), dummy_pos))
            true
          } catch {
            EvalErr(_) => false
          }
          @value.Value::Bool(found)
        }
        _ =>
          raise EvalErr(
            make_eval_error(ctx, "hasattr() attribute name must be a string"),
          )
      }
    }
    "getattr" => {
      if pos_args.length() < 2 {
        raise EvalErr(
          make_eval_error(ctx, "getattr() requires at least 2 arguments"),
        )
      }
      match pos_args[1] {
        @value.Value::String(s) => {
          let dummy_pos = @errors.Position::new("<getattr>", 0, 0)
          eval_getattr(ctx, pos_args[0], s.raw(), dummy_pos) catch {
            EvalErr(_) =>
              if pos_args.length() >= 3 {
                pos_args[2]
              } else {
                raise EvalErr(
                  make_eval_error(
                    ctx,
                    "'\{@value.type_name(pos_args[0])}' has no attribute '\{s.raw()}'",
                  ),
                )
              }
          }
        }
        _ =>
          raise EvalErr(
            make_eval_error(ctx, "getattr() attribute name must be a string"),
          )
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
) -> @value.Value raise EvalErr {
  match pos_args.length() {
    1 =>
      match pos_args[0] {
        @value.Value::Int(stop) =>
          @value.Value::Range(
            @value.StarlarkRange::new(0L, range_arg_to_int64(ctx, stop), 1L),
          )
        _ =>
          raise EvalErr(
            make_eval_error(ctx, "range() arguments must be integers"),
          )
      }
    2 =>
      match (pos_args[0], pos_args[1]) {
        (@value.Value::Int(start), @value.Value::Int(stop)) =>
          @value.Value::Range(
            @value.StarlarkRange::new(
              range_arg_to_int64(ctx, start),
              range_arg_to_int64(ctx, stop),
              1L,
            ),
          )
        _ =>
          raise EvalErr(
            make_eval_error(ctx, "range() arguments must be integers"),
          )
      }
    3 =>
      match (pos_args[0], pos_args[1], pos_args[2]) {
        (
          @value.Value::Int(start),
          @value.Value::Int(stop),
          @value.Value::Int(step),
        ) => {
          if step.is_zero() {
            raise EvalErr(
              make_eval_error(ctx, "range() step argument must not be zero"),
            )
          }
          @value.Value::Range(
            @value.StarlarkRange::new(
              range_arg_to_int64(ctx, start),
              range_arg_to_int64(ctx, stop),
              range_arg_to_int64(ctx, step),
            ),
          )
        }
        _ =>
          raise EvalErr(
            make_eval_error(ctx, "range() arguments must be integers"),
          )
      }
    _ => raise EvalErr(make_eval_error(ctx, "range() takes 1 to 3 arguments"))
  }
}

///|
fn builtin_list(
  ctx : EvalContext,
  pos_args : Array[@value.Value],
) -> @value.Value raise EvalErr {
  if pos_args.length() == 0 {
    return @value.Value::List(@value.StarlarkList::new([]))
  }
  if pos_args.length() != 1 {
    raise EvalErr(make_eval_error(ctx, "list() takes at most one argument"))
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
      let it = require_seq(ctx, v)
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
  if pos_args.length() != 1 {
    raise EvalErr(make_eval_error(ctx, "tuple() takes at most one argument"))
  }
  let items : Array[@value.Value] = []
  let it = require_seq(ctx, pos_args[0])
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
fn builtin_dict(
  ctx : EvalContext,
  pos_args : Array[@value.Value],
  kw_args : Array[(String, @value.Value)],
) -> @value.Value raise EvalErr {
  let d = @value.StarlarkDict::new()
  if pos_args.length() == 1 {
    match pos_args[0] {
      @value.Value::Dict(src) => src.each(fn(k, v) { ignore(d.set(k, v)) })
      v => {
        let it = require_seq(ctx, v)
        while true {
          match it.next() {
            None => {
              it.done()
              break
            }
            Some(@value.Value::Tuple(pair)) => {
              if pair.length() != 2 {
                it.done()
                raise EvalErr(
                  make_eval_error(
                    ctx, "dict() items must be sequences of length 2",
                  ),
                )
              }
              check(ctx, d.set(pair[0], pair[1]))
            }
            Some(@value.Value::List(pair)) => {
              if pair.length() != 2 {
                it.done()
                raise EvalErr(
                  make_eval_error(
                    ctx, "dict() items must be sequences of length 2",
                  ),
                )
              }
              check(ctx, d.set(pair.get(0), pair.get(1)))
            }
            Some(item) =>
              match @value.iterate(item) {
                Err(_) => {
                  it.done()
                  raise EvalErr(
                    make_eval_error(
                      ctx,
                      "dictionary update sequence element is not iterable (\{@value.type_name(item)})",
                    ),
                  )
                }
                Ok(item_it) => {
                  let elems : Array[@value.Value] = []
                  while true {
                    match item_it.next() {
                      None => {
                        item_it.done()
                        break
                      }
                      Some(e) => {
                        elems.push(e)
                        if elems.length() > 2 {
                          item_it.done()
                          break
                        }
                      }
                    }
                  }
                  if elems.length() != 2 {
                    it.done()
                    raise EvalErr(
                      make_eval_error(
                        ctx, "dict() items must be sequences of length 2",
                      ),
                    )
                  }
                  check(ctx, d.set(elems[0], elems[1]))
                }
              }
          }
        }
      }
    }
  } else if pos_args.length() > 1 {
    raise EvalErr(
      make_eval_error(ctx, "dict() takes at most one positional argument"),
    )
  }
  let kw_seen : Array[String] = []
  for kw_pair in kw_args {
    let (kw_name, kw_val) = kw_pair
    if kw_seen.contains(kw_name) {
      raise EvalErr(
        make_eval_error(ctx, "dict: duplicate keyword arg: \"\{kw_name}\""),
      )
    }
    kw_seen.push(kw_name)
    let key = @value.Value::String(@value.StarlarkString::new(kw_name))
    ignore(d.set(key, kw_val))
  }
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
  if pos_args.length() != 1 {
    raise EvalErr(
      make_eval_error(
        ctx,
        "set: got \{pos_args.length()} arguments, want at most 1",
      ),
    )
  }
  let iterable = pos_args[0]
  let it = match @value.iterate(iterable) {
    Err(_) =>
      raise EvalErr(
        make_eval_error(
          ctx,
          "set: got \{@value.type_name(iterable)}, want iterable",
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
      let hint = match spell_nearest(kw_name, ["key"]) {
        "" => ""
        s => " (did you mean \{s}?)"
      }
      raise EvalErr(
        make_eval_error(
          ctx,
          "function \{fn_name} got an unexpected keyword argument \{kw_name}\{hint}",
        ),
      )
    }
  }
  let items : Array[@value.Value] = []
  if pos_args.length() == 0 {
    raise EvalErr(
      make_eval_error(
        ctx,
        "\{fn_name} requires at least one positional argument",
      ),
    )
  }
  if pos_args.length() == 1 {
    let it = match @value.iterate(pos_args[0]) {
      Ok(it) => it
      Err(_) =>
        raise EvalErr(
          make_eval_error(ctx, "\{fn_name}() argument is not iterable"),
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
        make_eval_error(ctx, "\{fn_name}() arg is an empty sequence"),
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
) -> @value.Value raise EvalErr {
  if pos_args.length() < 1 {
    raise EvalErr(
      make_eval_error(ctx, "enumerate() requires at least one argument"),
    )
  }
  let start = if pos_args.length() >= 2 {
    match pos_args[1] {
      @value.Value::Int(n) => n
      _ => 0N
    }
  } else {
    0N
  }
  let result : Array[@value.Value] = []
  let it = require_seq(ctx, pos_args[0])
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
  if pos_args.length() < 1 {
    raise EvalErr(
      make_eval_error(ctx, "sorted() requires at least one argument"),
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
  let reverse = {
    let mut found = false
    for kv in kw_args {
      match kv {
        ("reverse", @value.Value::Bool(b)) => {
          found = b
          break
        }
        _ => ()
      }
    }
    found
  }
  let items : Array[@value.Value] = []
  let it = match @value.iterate(pos_args[0]) {
    Ok(it) => it
    Err(_) =>
      raise EvalErr(
        make_eval_error(
          ctx,
          "sorted: for parameter iterable: got \{@value.type_name(pos_args[0])}, want iterable",
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
      Ok(c) => if reverse { -c } else { c }
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
  if pos_args.length() != 1 {
    raise EvalErr(make_eval_error(ctx, "reversed() takes exactly one argument"))
  }
  let items : Array[@value.Value] = []
  let it = require_seq(ctx, pos_args[0])
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
  if pos_args.length() != 1 {
    raise EvalErr(make_eval_error(ctx, "any/all() takes exactly one argument"))
  }
  let it = require_seq(ctx, pos_args[0])
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
    @value.Value::List(l) => call_list_method(ctx, l, method_name, pos_args)
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
) -> @value.Value raise EvalErr {
  match method_name {
    "append" => {
      if pos_args.length() != 1 {
        raise EvalErr(
          make_eval_error(ctx, "append() takes exactly one argument"),
        )
      }
      check(ctx, l.push(pos_args[0]))
      @value.Value::None
    }
    "extend" => {
      if pos_args.length() != 1 {
        raise EvalErr(
          make_eval_error(ctx, "extend() takes exactly one argument"),
        )
      }
      if pos_args[0] is @value.Value::List(src) {
        let snapshot = src.copy_items()
        check(ctx, l.check_mutable("extend"))
        for item in snapshot {
          l.push(item) |> ignore
        }
      } else {
        check(ctx, l.check_mutable("extend"))
        let it = require_seq(ctx, pos_args[0])
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
      if l.is_empty() {
        raise EvalErr(make_eval_error(ctx, "pop from empty list"))
      }
      if pos_args.length() == 0 {
        match check(ctx, l.pop()) {
          None => raise EvalErr(make_eval_error(ctx, "pop from empty list"))
          Some(v) => v
        }
      } else {
        match pos_args[0] {
          @value.Value::Int(i) => {
            let j = check(ctx, adjust_index(i, l.length()))
            check(ctx, l.pop_at(j))
          }
          _ =>
            raise EvalErr(
              make_eval_error(ctx, "list.pop() argument must be an integer"),
            )
        }
      }
    }
    "remove" => {
      if pos_args.length() != 1 {
        raise EvalErr(
          make_eval_error(ctx, "remove() takes exactly one argument"),
        )
      }
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
      if pos_args.length() != 2 {
        raise EvalErr(
          make_eval_error(ctx, "insert() takes exactly 2 arguments"),
        )
      }
      match pos_args[0] {
        @value.Value::Int(i) => {
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
        _ =>
          raise EvalErr(
            make_eval_error(ctx, "insert() first argument must be an integer"),
          )
      }
    }
    "clear" => {
      check(ctx, l.clear()) |> ignore
      @value.Value::None
    }
    "index" => {
      if pos_args.length() < 1 {
        raise EvalErr(
          make_eval_error(ctx, "index() takes at least one argument"),
        )
      }
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
          _ =>
            raise EvalErr(
              make_eval_error(ctx, "list.index: start must be an integer"),
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
          _ =>
            raise EvalErr(
              make_eval_error(ctx, "list.index: end must be an integer"),
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
      raise EvalErr(make_eval_error(ctx, "value not in list"))
    }
    "count" => {
      if pos_args.length() != 1 {
        raise EvalErr(
          make_eval_error(ctx, "count() takes exactly one argument"),
        )
      }
      let item = pos_args[0]
      let mut count = 0
      for v in l.iter() {
        if @value.starlark_equals(v, item) {
          count += 1
        }
      }
      @value.Value::Int(BigInt::from_int(count))
    }
    "sort" => {
      let mut sort_err : @errors.EvalError? = None
      check(
        ctx,
        l.sort_by(fn(a, b) {
          match @value.compare_values(a, b) {
            Err(msg) => {
              sort_err = Some(make_eval_error(ctx, msg))
              0
            }
            Ok(c) => c
          }
        }),
      )
      |> ignore
      match sort_err {
        Some(e) => raise EvalErr(e)
        None => @value.Value::None
      }
    }
    "reverse" => {
      check(ctx, l.reverse()) |> ignore
      @value.Value::None
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
      if !kw_args.is_empty() {
        raise EvalErr(make_eval_error(ctx, "get: unexpected keyword arguments"))
      }
      if pos_args.length() < 1 {
        raise EvalErr(
          make_eval_error(ctx, "dict.get() requires at least one argument"),
        )
      }
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
      let keys = d.keys()
      @value.Value::List(@value.StarlarkList::new(keys))
    }
    "values" => {
      let vals : Array[@value.Value] = []
      d.each(fn(_k, v) { vals.push(v) })
      @value.Value::List(@value.StarlarkList::new(vals))
    }
    "items" => {
      let items : Array[@value.Value] = []
      d.each(fn(k, v) { items.push(@value.Value::Tuple([k, v])) })
      @value.Value::List(@value.StarlarkList::new(items))
    }
    "pop" => {
      if pos_args.length() < 1 {
        raise EvalErr(
          make_eval_error(ctx, "dict.pop() requires at least one argument"),
        )
      }
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
      if pos_args.length() > 0 {
        let src_val = pos_args[0]
        match src_val {
          @value.Value::Dict(src) => {
            let pairs : Array[(@value.Value, @value.Value)] = []
            src.each(fn(k, v) { pairs.push((k, v)) })
            for pair in pairs {
              let (k, v) = pair
              check(ctx, d.set(k, v))
            }
          }
          _ => {
            let iter = require_seq(ctx, src_val)
            while true {
              match iter.next() {
                None => break
                Some(item) =>
                  match item {
                    @value.Value::Tuple(pair) =>
                      if pair.length() == 2 {
                        check(ctx, d.set(pair[0], pair[1]))
                      } else {
                        iter.done()
                        raise EvalErr(
                          make_eval_error(
                            ctx, "dict.update: items must be 2-element sequences",
                          ),
                        )
                      }
                    @value.Value::List(l2) =>
                      if l2.length() == 2 {
                        check(ctx, d.set(l2.get(0), l2.get(1)))
                      } else {
                        iter.done()
                        raise EvalErr(
                          make_eval_error(
                            ctx, "dict.update: items must be 2-element sequences",
                          ),
                        )
                      }
                    _ => {
                      iter.done()
                      raise EvalErr(
                        make_eval_error(
                          ctx, "dict.update: items must be 2-element sequences",
                        ),
                      )
                    }
                  }
              }
            }
            iter.done()
          }
        }
      }
      for kw_pair in kw_args {
        let (kw_name, kw_val) = kw_pair
        let key = @value.Value::String(@value.StarlarkString::new(kw_name))
        check(ctx, d.set(key, kw_val))
      }
      @value.Value::None
    }
    "clear" => {
      check(ctx, d.clear())
      @value.Value::None
    }
    "popitem" =>
      match check(ctx, d.popitem()) {
        None => raise EvalErr(make_eval_error(ctx, "empty dict"))
        Some((k, v)) => @value.Value::Tuple([k, v])
      }
    "setdefault" => {
      if pos_args.length() < 1 {
        raise EvalErr(
          make_eval_error(ctx, "setdefault() requires a key argument"),
        )
      }
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
      @value.Value::String(@value.StarlarkString::new(s.raw().to_upper()))
    "lower" =>
      @value.Value::String(@value.StarlarkString::new(s.raw().to_lower()))
    "strip" => {
      let chars_opt = if pos_args.length() > 0 {
        match pos_args[0] {
          @value.Value::String(c) if c.raw().length() > 0 => Some(c.raw())
          _ => None
        }
      } else {
        None
      }
      let result = match chars_opt {
        None => strip_whitespace(s.raw(), true, true)
        Some(chars) => strip_chars(s.raw(), chars, true, true)
      }
      @value.Value::String(@value.StarlarkString::new(result))
    }
    "lstrip" => {
      let chars_opt = if pos_args.length() > 0 {
        match pos_args[0] {
          @value.Value::String(c) if c.raw().length() > 0 => Some(c.raw())
          _ => None
        }
      } else {
        None
      }
      let result = match chars_opt {
        None => strip_whitespace(s.raw(), true, false)
        Some(chars) => strip_chars(s.raw(), chars, true, false)
      }
      @value.Value::String(@value.StarlarkString::new(result))
    }
    "rstrip" => {
      let chars_opt = if pos_args.length() > 0 {
        match pos_args[0] {
          @value.Value::String(c) if c.raw().length() > 0 => Some(c.raw())
          _ => None
        }
      } else {
        None
      }
      let result = match chars_opt {
        None => strip_whitespace(s.raw(), false, true)
        Some(chars) => strip_chars(s.raw(), chars, false, true)
      }
      @value.Value::String(@value.StarlarkString::new(result))
    }
    "startswith" => {
      if pos_args.length() == 0 {
        raise EvalErr(
          make_eval_error(ctx, "startswith() takes at least one argument"),
        )
      }
      let start_idx = if pos_args.length() >= 2 {
        match pos_args[1] {
          @value.Value::Int(n) => n.to_int()
          @value.Value::None => 0
          _ => 0
        }
      } else {
        0
      }
      let end_idx = if pos_args.length() >= 3 {
        match pos_args[2] {
          @value.Value::Int(n) => n.to_int()
          @value.Value::None => s.raw().length()
          _ => s.raw().length()
        }
      } else {
        s.raw().length()
      }
      let slen = s.raw().length()
      let i = if start_idx < 0 {
        (slen + start_idx).max(0)
      } else {
        start_idx.min(slen)
      }
      let j = if end_idx < 0 {
        (slen + end_idx).max(0)
      } else {
        end_idx.min(slen)
      }
      let sub = if i <= j { s.raw()[i:j].to_owned() } else { "" }
      let check_prefix = fn(prefix : String) -> Bool { sub.has_prefix(prefix) }
      match pos_args[0] {
        @value.Value::String(prefix) =>
          @value.Value::Bool(check_prefix(prefix.raw()))
        @value.Value::Tuple(t) => {
          let mut found = false
          for item in t {
            match item {
              @value.Value::String(p) =>
                if check_prefix(p.raw()) {
                  found = true
                  break
                }
              v =>
                raise EvalErr(
                  make_eval_error(
                    ctx,
                    "got \{@value.type_name(v)}, for element 0",
                  ),
                )
            }
          }
          @value.Value::Bool(found)
        }
        @value.Value::List(_) =>
          raise EvalErr(
            make_eval_error(ctx, "got list, want string or tuple of string"),
          )
        v =>
          raise EvalErr(
            make_eval_error(ctx, "got \{@value.type_name(v)}, want string"),
          )
      }
    }
    "endswith" => {
      if pos_args.length() == 0 {
        raise EvalErr(
          make_eval_error(ctx, "endswith() takes at least one argument"),
        )
      }
      let start_idx = if pos_args.length() >= 2 {
        match pos_args[1] {
          @value.Value::Int(n) => n.to_int()
          @value.Value::None => 0
          _ => 0
        }
      } else {
        0
      }
      let end_idx = if pos_args.length() >= 3 {
        match pos_args[2] {
          @value.Value::Int(n) => n.to_int()
          @value.Value::None => s.raw().length()
          _ => s.raw().length()
        }
      } else {
        s.raw().length()
      }
      let slen = s.raw().length()
      let i = if start_idx < 0 {
        (slen + start_idx).max(0)
      } else {
        start_idx.min(slen)
      }
      let j = if end_idx < 0 {
        (slen + end_idx).max(0)
      } else {
        end_idx.min(slen)
      }
      let sub = if i <= j { s.raw()[i:j].to_owned() } else { "" }
      let check_suffix = fn(suffix : String) -> Bool { sub.has_suffix(suffix) }
      match pos_args[0] {
        @value.Value::String(suffix) =>
          @value.Value::Bool(check_suffix(suffix.raw()))
        @value.Value::Tuple(t) => {
          let mut found = false
          for item in t {
            match item {
              @value.Value::String(p) =>
                if check_suffix(p.raw()) {
                  found = true
                  break
                }
              v =>
                raise EvalErr(
                  make_eval_error(
                    ctx,
                    "got \{@value.type_name(v)}, for element 0",
                  ),
                )
            }
          }
          @value.Value::Bool(found)
        }
        @value.Value::List(_) =>
          raise EvalErr(
            make_eval_error(ctx, "got list, want string or tuple of string"),
          )
        v =>
          raise EvalErr(
            make_eval_error(ctx, "got \{@value.type_name(v)}, want string"),
          )
      }
    }
    "find" => {
      if pos_args.length() < 1 {
        raise EvalErr(
          make_eval_error(ctx, "find() takes at least one argument"),
        )
      }
      match pos_args[0] {
        @value.Value::String(sub) => {
          let slen = s.raw().length()
          let start = if pos_args.length() >= 2 {
            match pos_args[1] {
              @value.Value::Int(n) => {
                let n2 = n.to_int()
                if n2 < 0 {
                  (slen + n2).max(0)
                } else {
                  n2.min(slen)
                }
              }
              _ => 0
            }
          } else {
            0
          }
          let end = if pos_args.length() >= 3 {
            match pos_args[2] {
              @value.Value::Int(n) => {
                let n2 = n.to_int()
                if n2 < 0 {
                  (slen + n2).max(0)
                } else {
                  n2.min(slen)
                }
              }
              _ => slen
            }
          } else {
            slen
          }
          let slice = if start < end {
            s.raw()[start:end].to_owned()
          } else {
            ""
          }
          let result = find_substr(slice, sub.raw())
          @value.Value::Int(
            BigInt::from_int(if result >= 0 { result + start } else { -1 }),
          )
        }
        _ =>
          raise EvalErr(
            make_eval_error(ctx, "find() argument must be a string"),
          )
      }
    }
    "count" => {
      if pos_args.length() < 1 {
        raise EvalErr(
          make_eval_error(ctx, "count() takes at least one argument"),
        )
      }
      match pos_args[0] {
        @value.Value::String(sub) => {
          let slen = s.raw().length()
          let start = if pos_args.length() >= 2 {
            match pos_args[1] {
              @value.Value::Int(n) => {
                let n2 = n.to_int()
                if n2 < 0 {
                  (slen + n2).max(0)
                } else {
                  n2.min(slen)
                }
              }
              _ => 0
            }
          } else {
            0
          }
          let end = if pos_args.length() >= 3 {
            match pos_args[2] {
              @value.Value::Int(n) => {
                let n2 = n.to_int()
                if n2 < 0 {
                  (slen + n2).max(0)
                } else {
                  n2.min(slen)
                }
              }
              _ => slen
            }
          } else {
            slen
          }
          let slice = if start < end {
            s.raw()[start:end].to_owned()
          } else {
            ""
          }
          @value.Value::Int(BigInt::from_int(count_substr(slice, sub.raw())))
        }
        _ =>
          raise EvalErr(
            make_eval_error(ctx, "count() argument must be a string"),
          )
      }
    }
    "replace" => {
      if pos_args.length() < 2 {
        raise EvalErr(
          make_eval_error(ctx, "replace() takes at least 2 arguments"),
        )
      }
      match (pos_args[0], pos_args[1]) {
        (@value.Value::String(old), @value.Value::String(new_s)) => {
          let max_count = if pos_args.length() >= 3 {
            match pos_args[2] {
              @value.Value::Int(n) => n.to_int()
              _ => -1
            }
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
        _ =>
          raise EvalErr(
            make_eval_error(ctx, "replace() arguments must be strings"),
          )
      }
    }
    "split" => {
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
          _ =>
            raise EvalErr(
              make_eval_error(ctx, "split() separator must be a string or None"),
            )
        }
      }
      let kw_sep : String? = {
        let mut found : String? = None
        for kv in kw_args {
          if kv.0 == "sep" {
            match kv.1 {
              @value.Value::None => ()
              @value.Value::String(sep) => found = Some(sep.raw())
              _ => ()
            }
            break
          }
        }
        found
      }
      let sep = match sep_opt {
        Some(s2) => Some(s2)
        None => kw_sep
      }
      let maxsplit = if pos_args.length() >= 2 {
        match pos_args[1] {
          @value.Value::Int(n) => n.to_int()
          _ => -1
        }
      } else {
        let mut found = -1
        for kv in kw_args {
          if kv.0 == "maxsplit" {
            match kv.1 {
              @value.Value::Int(n) => {
                found = n.to_int()
                break
              }
              _ => ()
            }
          }
        }
        found
      }
      match sep {
        None => to_value_list(split_whitespace(s.raw(), maxsplit))
        Some(sep_str) => to_value_list(split_by_sep(s.raw(), sep_str, maxsplit))
      }
    }
    "rsplit" => {
      let sep_opt = if pos_args.length() == 0 {
        None
      } else {
        match pos_args[0] {
          @value.Value::None => None
          @value.Value::String(sep) => {
            if sep.raw().length() == 0 {
              raise EvalErr(make_eval_error(ctx, "rsplit: empty separator"))
            }
            Some(sep.raw())
          }
          _ =>
            raise EvalErr(
              make_eval_error(
                ctx, "rsplit() separator must be a string or None",
              ),
            )
        }
      }
      let maxsplit = if pos_args.length() >= 2 {
        match pos_args[1] {
          @value.Value::Int(n) => n.to_int()
          _ => -1
        }
      } else {
        -1
      }
      match sep_opt {
        None => to_value_list(rsplit_whitespace(s.raw(), maxsplit))
        Some(sep_str) =>
          to_value_list(rsplit_by_sep(s.raw(), sep_str, maxsplit))
      }
    }
    "join" => {
      if pos_args.length() != 1 {
        raise EvalErr(make_eval_error(ctx, "join() takes exactly one argument"))
      }
      let parts : Array[String] = []
      let it = require_seq(ctx, pos_args[0])
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
      let chars = s.raw().to_array()
      if chars.is_empty() {
        @value.Value::String(s)
      } else {
        let buf = StringBuilder::new()
        buf.write_char(char_to_upper(chars[0]))
        for i in 1..<chars.length() {
          buf.write_char(char_to_lower(chars[i]))
        }
        @value.Value::String(@value.StarlarkString::new(buf.to_string()))
      }
    }
    "index" => {
      if pos_args.length() < 1 {
        raise EvalErr(
          make_eval_error(ctx, "index() takes at least one argument"),
        )
      }
      match pos_args[0] {
        @value.Value::String(sub) => {
          let result = find_substr(s.raw(), sub.raw())
          if result < 0 {
            raise EvalErr(make_eval_error(ctx, "substring not found"))
          }
          @value.Value::Int(BigInt::from_int(result))
        }
        _ =>
          raise EvalErr(
            make_eval_error(ctx, "index() argument must be a string"),
          )
      }
    }
    "rfind" => {
      if pos_args.length() < 1 {
        raise EvalErr(
          make_eval_error(ctx, "rfind() takes at least one argument"),
        )
      }
      match pos_args[0] {
        @value.Value::String(sub) => {
          let slen = s.raw().length()
          let start = if pos_args.length() >= 2 {
            match pos_args[1] {
              @value.Value::Int(n) => {
                let n2 = n.to_int()
                if n2 < 0 {
                  (slen + n2).max(0)
                } else {
                  n2.min(slen)
                }
              }
              _ => 0
            }
          } else {
            0
          }
          let end = if pos_args.length() >= 3 {
            match pos_args[2] {
              @value.Value::Int(n) => {
                let n2 = n.to_int()
                if n2 < 0 {
                  (slen + n2).max(0)
                } else {
                  n2.min(slen)
                }
              }
              _ => slen
            }
          } else {
            slen
          }
          let slice = if start < end {
            s.raw()[start:end].to_owned()
          } else {
            ""
          }
          let result = rfind_substr(slice, sub.raw())
          @value.Value::Int(
            BigInt::from_int(if result >= 0 { result + start } else { -1 }),
          )
        }
        _ =>
          raise EvalErr(
            make_eval_error(ctx, "rfind() argument must be a string"),
          )
      }
    }
    "rindex" => {
      if pos_args.length() < 1 {
        raise EvalErr(
          make_eval_error(ctx, "rindex() takes at least one argument"),
        )
      }
      match pos_args[0] {
        @value.Value::String(sub) => {
          let result = rfind_substr(s.raw(), sub.raw())
          if result < 0 {
            raise EvalErr(make_eval_error(ctx, "substring not found"))
          }
          @value.Value::Int(BigInt::from_int(result))
        }
        _ =>
          raise EvalErr(
            make_eval_error(ctx, "rindex() argument must be a string"),
          )
      }
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
      let chars = s.raw().to_array()
      let mut has_cased = false
      let mut result = true
      for c in chars {
        let n = c.to_int()
        if n >= 'A'.to_int() && n <= 'Z'.to_int() {
          result = false
          break
        } else if n >= 'a'.to_int() && n <= 'z'.to_int() {
          has_cased = true
        }
      }
      @value.Value::Bool(result && has_cased)
    }
    "isupper" => {
      let chars = s.raw().to_array()
      let mut has_cased = false
      let mut result = true
      for c in chars {
        let n = c.to_int()
        if n >= 'a'.to_int() && n <= 'z'.to_int() {
          result = false
          break
        } else if n >= 'A'.to_int() && n <= 'Z'.to_int() {
          has_cased = true
        }
      }
      @value.Value::Bool(result && has_cased)
    }
    "isspace" => {
      if s.raw().length() == 0 {
        return @value.Value::Bool(false)
      }
      let mut result = true
      for c in s.raw().to_array() {
        let n = c.to_int()
        if n != ' '.to_int() &&
          n != '\t'.to_int() &&
          n != '\n'.to_int() &&
          n != '\r'.to_int() &&
          n != 0x0C &&
          n != 0x0B {
          result = false
          break
        }
      }
      @value.Value::Bool(result)
    }
    "title" => {
      let chars = s.raw().to_array()
      let buf = StringBuilder::new()
      let mut prev_cased = false
      for c in chars {
        let n = c.to_int()
        if n >= 'a'.to_int() && n <= 'z'.to_int() {
          if !prev_cased {
            buf.write_char(char_to_upper(c))
          } else {
            buf.write_char(c)
          }
          prev_cased = true
        } else if n >= 'A'.to_int() && n <= 'Z'.to_int() {
          if prev_cased {
            buf.write_char(char_to_lower(c))
          } else {
            buf.write_char(c)
          }
          prev_cased = true
        } else {
          buf.write_char(c)
          prev_cased = false
        }
      }
      @value.Value::String(@value.StarlarkString::new(buf.to_string()))
    }
    "partition" => {
      if pos_args.length() != 1 {
        raise EvalErr(
          make_eval_error(ctx, "partition() takes exactly one argument"),
        )
      }
      match pos_args[0] {
        @value.Value::String(sep) => {
          if sep.raw().length() == 0 {
            raise EvalErr(make_eval_error(ctx, "partition: empty separator"))
          }
          let idx = find_substr(s.raw(), sep.raw())
          if idx < 0 {
            @value.Value::Tuple([
              @value.Value::String(s),
              @value.Value::String(@value.StarlarkString::new("")),
              @value.Value::String(@value.StarlarkString::new("")),
            ])
          } else {
            let before = s.raw()[0:idx].to_owned()
            let after = s.raw()[idx + sep.raw().length():].to_owned()
            @value.Value::Tuple([
              @value.Value::String(@value.StarlarkString::new(before)),
              @value.Value::String(@value.StarlarkString::new(sep.raw())),
              @value.Value::String(@value.StarlarkString::new(after)),
            ])
          }
        }
        _ =>
          raise EvalErr(
            make_eval_error(ctx, "partition() argument must be a string"),
          )
      }
    }
    "rpartition" => {
      if pos_args.length() != 1 {
        raise EvalErr(
          make_eval_error(ctx, "rpartition() takes exactly one argument"),
        )
      }
      match pos_args[0] {
        @value.Value::String(sep) => {
          if sep.raw().length() == 0 {
            raise EvalErr(make_eval_error(ctx, "rpartition: empty separator"))
          }
          let idx = rfind_substr(s.raw(), sep.raw())
          if idx < 0 {
            @value.Value::Tuple([
              @value.Value::String(@value.StarlarkString::new("")),
              @value.Value::String(@value.StarlarkString::new("")),
              @value.Value::String(s),
            ])
          } else {
            let before = s.raw()[0:idx].to_owned()
            let after = s.raw()[idx + sep.raw().length():].to_owned()
            @value.Value::Tuple([
              @value.Value::String(@value.StarlarkString::new(before)),
              @value.Value::String(@value.StarlarkString::new(sep.raw())),
              @value.Value::String(@value.StarlarkString::new(after)),
            ])
          }
        }
        _ =>
          raise EvalErr(
            make_eval_error(ctx, "rpartition() argument must be a string"),
          )
      }
    }
    "removeprefix" => {
      if pos_args.length() != 1 {
        raise EvalErr(
          make_eval_error(ctx, "removeprefix() takes exactly one argument"),
        )
      }
      match pos_args[0] {
        @value.Value::String(prefix) =>
          if s.raw().has_prefix(prefix.raw()) {
            let rest = s.raw()[prefix.raw().length():].to_owned()
            @value.Value::String(@value.StarlarkString::new(rest))
          } else {
            @value.Value::String(s)
          }
        _ =>
          raise EvalErr(
            make_eval_error(ctx, "removeprefix() argument must be a string"),
          )
      }
    }
    "removesuffix" => {
      if pos_args.length() != 1 {
        raise EvalErr(
          make_eval_error(ctx, "removesuffix() takes exactly one argument"),
        )
      }
      match pos_args[0] {
        @value.Value::String(suffix) =>
          if s.raw().has_suffix(suffix.raw()) {
            let rest = s.raw()[0:s.raw().length() - suffix.raw().length()].to_owned()
            @value.Value::String(@value.StarlarkString::new(rest))
          } else {
            @value.Value::String(s)
          }
        _ =>
          raise EvalErr(
            make_eval_error(ctx, "removesuffix() argument must be a string"),
          )
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
                "splitlines: got \{@value.type_name(pos_args[0])}, want bool",
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
        let cv = c.to_int()
        if cv == '\r'.to_int() {
          if keepends {
            buf.write_char(c)
          }
          if i + 1 < n && chars[i + 1].to_int() == '\n'.to_int() {
            i += 1
            if keepends {
              buf.write_char(chars[i])
            }
          }
          parts.push(
            @value.Value::String(@value.StarlarkString::new(buf.to_string())),
          )
          buf.reset()
        } else if cv == '\n'.to_int() {
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
      let chars = s.raw().to_array()
      let mut cased = false
      let mut prev_cased = false
      let mut valid = true
      for c in chars {
        let n = c.to_int()
        if n >= 'A'.to_int() && n <= 'Z'.to_int() {
          if prev_cased {
            valid = false
            break
          }
          prev_cased = true
          cased = true
        } else if n >= 'a'.to_int() && n <= 'z'.to_int() {
          if !prev_cased {
            valid = false
            break
          }
          prev_cased = true
          cased = true
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
fn call_set_method(
  ctx : EvalContext,
  s : @value.StarlarkSet,
  method_name : String,
  pos_args : Array[@value.Value],
  kw_args : Array[(String, @value.Value)],
) -> @value.Value raise EvalErr {
  match method_name {
    "add" => {
      if pos_args.length() != 1 {
        raise EvalErr(
          make_eval_error(
            ctx,
            "add: got \{pos_args.length()} arguments, want 1",
          ),
        )
      }
      match s.add(pos_args[0]) {
        Err(e) => raise EvalErr(make_eval_error(ctx, "add: \{e}"))
        Ok(_) => ()
      }
      @value.Value::None
    }
    "discard" => {
      if pos_args.length() != 1 {
        raise EvalErr(
          make_eval_error(
            ctx,
            "discard: got \{pos_args.length()} arguments, want 1",
          ),
        )
      }
      match s.remove(pos_args[0]) {
        Err(e) => raise EvalErr(make_eval_error(ctx, "discard: \{e}"))
        Ok(_) => ()
      }
      @value.Value::None
    }
    "remove" => {
      if pos_args.length() != 1 {
        raise EvalErr(
          make_eval_error(
            ctx,
            "remove: got \{pos_args.length()} arguments, want 1",
          ),
        )
      }
      match s.remove(pos_args[0]) {
        Err(e) => raise EvalErr(make_eval_error(ctx, "remove: \{e}"))
        Ok(false) => raise EvalErr(make_eval_error(ctx, "remove: missing key"))
        Ok(true) => ()
      }
      @value.Value::None
    }
    "clear" => {
      if s.length() == 0 {
        return @value.Value::None
      }
      match s.clear() {
        Err(e) => raise EvalErr(make_eval_error(ctx, "clear: \{e}"))
        Ok(_) => ()
      }
      @value.Value::None
    }
    "pop" =>
      match s.pop_first() {
        Err(e) => raise EvalErr(make_eval_error(ctx, "pop: \{e}"))
        Ok(None) => raise EvalErr(make_eval_error(ctx, "pop: empty set"))
        Ok(Some(v)) => v
      }
    "union" => {
      let result = @value.StarlarkSet::new()
      s.each(fn(v) { ignore(result.add(v)) })
      for i in 0..<pos_args.length() {
        set_iterate_into(ctx, pos_args[i], i + 1, "union", result)
      }
      @value.Value::Set(result)
    }
    "intersection" => {
      if pos_args.length() != 1 {
        raise EvalErr(
          make_eval_error(ctx, "intersection() takes exactly one argument"),
        )
      }
      let other_set = @value.StarlarkSet::new()
      let it = check(ctx, @value.iterate(pos_args[0]))
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
          Ok(true) => ignore(result.add(v))
          _ => ()
        }
      })
      @value.Value::Set(result)
    }
    "difference" => {
      if pos_args.length() != 1 {
        raise EvalErr(
          make_eval_error(ctx, "difference() takes exactly one argument"),
        )
      }
      let other_set = @value.StarlarkSet::new()
      let it = check(ctx, @value.iterate(pos_args[0]))
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
      if pos_args.length() != 1 {
        raise EvalErr(
          make_eval_error(
            ctx, "symmetric_difference() takes exactly one argument",
          ),
        )
      }
      let other_items : Array[@value.Value] = []
      let it = check(ctx, @value.iterate(pos_args[0]))
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
      if pos_args.length() != 1 {
        raise EvalErr(
          make_eval_error(ctx, "issubset() takes exactly one argument"),
        )
      }
      let other_set = @value.StarlarkSet::new()
      let it = check(ctx, @value.iterate(pos_args[0]))
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
      if pos_args.length() != 1 {
        raise EvalErr(
          make_eval_error(ctx, "issuperset() takes exactly one argument"),
        )
      }
      let mut all_in = true
      let it = check(ctx, @value.iterate(pos_args[0]))
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
    raise EvalErr(make_eval_error(ctx, "bytes() takes exactly one argument"))
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
                  "at index \{idx}, \{n} out of range (want value in unsigned 8-bit range)",
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
                "at index \{idx}, got \{@value.type_name(v)}, want int",
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
fn char_to_upper(c : Char) -> Char {
  let n = c.to_int()
  if n >= 'a'.to_int() && n <= 'z'.to_int() {
    (n - 32).unsafe_to_char()
  } else {
    c
  }
}

///|
fn char_to_lower(c : Char) -> Char {
  let n = c.to_int()
  if n >= 'A'.to_int() && n <= 'Z'.to_int() {
    (n + 32).unsafe_to_char()
  } else {
    c
  }
}

///|
fn rfind_substr(s : String, sub : String) -> Int {
  if sub.length() == 0 {
    return s.length()
  }
  let slen = s.length()
  let sublen = sub.length()
  if sublen > slen {
    return -1
  }
  let mut i = slen - sublen
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
fn count_substr(s : String, sub : String) -> Int {
  if sub.length() == 0 {
    return s.length() + 1
  }
  let mut count = 0
  let slen = s.length()
  let sublen = sub.length()
  let mut i = 0
  while i <= slen - sublen {
    let mut match_ = true
    for j in 0..<sublen {
      if s[i + j] != sub[j] {
        match_ = false
        break
      }
    }
    if match_ {
      count += 1
      i += sublen
    } else {
      i += 1
    }
  }
  count
}

///|
fn is_whitespace(c : Char) -> Bool {
  let n = c.to_int()
  n == ' '.to_int() ||
  n == '\t'.to_int() ||
  n == '\n'.to_int() ||
  n == '\r'.to_int() ||
  n == 0x0B ||
  n == 0x0C
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
              make_eval_error(ctx, "nested replacement fields not supported"),
            )
          }
          j += 1
        }
        if j >= tlen {
          raise EvalErr(make_eval_error(ctx, "unmatched '{' in format"))
        }
        let field = template[start:j].to_owned()
        i = j + 1
        let (name, conv) = if find_substr(field, "!") >= 0 {
          let bang = find_substr(field, "!")
          (field[0:bang].to_owned(), field[bang + 1:].to_owned())
        } else {
          (field, "s")
        }
        if find_substr(name, ".") >= 0 {
          raise EvalErr(
            make_eval_error(
              ctx, "syntax x.y is not supported in format strings",
            ),
          )
        }
        if find_substr(name, "[") >= 0 {
          raise EvalErr(
            make_eval_error(
              ctx, "syntax a[i] is not supported in format strings",
            ),
          )
        }
        if find_substr(name, ":") >= 0 {
          raise EvalErr(
            make_eval_error(ctx, "format spec features not supported"),
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
          let mut is_digit = true
          for k in 0..<name.length() {
            if name[k] < '0' || name[k] > '9' {
              is_digit = false
              break
            }
          }
          if is_digit && name.length() > 0 {
            if auto_mode {
              raise EvalErr(
                make_eval_error(
                  ctx, "format: cannot switch from automatic field numbering to manual field specification",
                ),
              )
            }
            manual_mode = true
            let n = match parse_int_str(name, 10) {
              Ok(n) => n.to_int()
              Err(_) =>
                raise EvalErr(
                  make_eval_error(ctx, "format: invalid field index '\{name}'"),
                )
            }
            if n >= args.length() {
              raise EvalErr(
                make_eval_error(ctx, "format: tuple index out of range"),
              )
            }
            args[n]
          } else {
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
        match conv {
          "s" => buf.write_string(@value.to_str(arg))
          "r" => buf.write_string(@value.repr(arg))
          other =>
            raise EvalErr(
              make_eval_error(ctx, "format: unknown conversion '\{other}'"),
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
  let s = s.trim().to_owned()
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
fn eval_comp_clauses(
  ctx : EvalContext,
  env : EvalEnv,
  clauses : Array[@syntax.CompClause],
  idx : Int,
  body_fn : (EvalEnv) -> Unit raise EvalErr,
) -> Unit raise EvalErr {
  if idx >= clauses.length() {
    return body_fn(env)
  }
  match clauses[idx] {
    @syntax.CompClause::ClauseFor(target, iter_expr, clause_pos) => {
      let iter_val = eval_expr_node(ctx, env, iter_expr)
      let it = check(ctx, @value.iterate(iter_val))
      let mut continue_loop = true
      while continue_loop {
        match it.next() {
          None => {
            it.done()
            continue_loop = false
          }
          Some(item) => {
            let inner_env = EvalEnv::with_parent(env)
            try {
              assign_to(ctx, inner_env, target, item, clause_pos)
              eval_comp_clauses(ctx, inner_env, clauses, idx + 1, body_fn)
            } catch {
              EvalErr(e) => {
                it.done()
                raise EvalErr(e)
              }
            }
          }
        }
      }
    }
    @syntax.CompClause::ClauseIf(cond_expr, _) => {
      let cond_val = eval_expr_node(ctx, env, cond_expr)
      if @value.truth(cond_val) {
        eval_comp_clauses(ctx, env, clauses, idx + 1, body_fn)
      }
    }
  }
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
