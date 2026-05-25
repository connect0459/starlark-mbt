///|
fn eval_literal(
  ctx : EvalContext,
  lit : @syntax.LiteralVal,
) -> @value.Value raise EvalErr {
  match lit {
    @syntax.LiteralVal::LitNone => @value.Value::NoneVal
    @syntax.LiteralVal::LitBool(b) => @value.Value::BoolVal(b)
    @syntax.LiteralVal::LitInt(n) => @value.Value::IntVal(n)
    @syntax.LiteralVal::LitBigInt(s) =>
      raise EvalErr(make_eval_error(ctx, "integer too large: '\{s}'"))
    @syntax.LiteralVal::LitFloat(f) => @value.Value::FloatVal(f)
    @syntax.LiteralVal::LitString(s) =>
      @value.Value::StrVal(@value.StarlarkString::new(s))
    @syntax.LiteralVal::LitBytes(b) => @value.Value::BytesVal(b)
  }
}

///|
fn eval_expr_node(
  ctx : EvalContext,
  env : EvalEnv,
  expr : @syntax.Expr,
) -> @value.Value raise EvalErr {
  match expr {
    @syntax.Expr::ELiteral(lit, _) => eval_literal(ctx, lit)
    @syntax.Expr::EIdent(name, pos) =>
      match env.lookup(name) {
        Some(v) => v
        None =>
          raise EvalErr(
            make_eval_error(ctx, "\{pos.to_string()}: undefined: \{name}"),
          )
      }
    @syntax.Expr::EUnary(op, e, pos) => {
      let v = eval_expr_node(ctx, env, e)
      eval_unary(ctx, op, v, pos)
    }
    // Short-circuit operators handled before general binary
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
      @value.Value::ListVal(@value.StarlarkList::new(items))
    }
    @syntax.Expr::ETuple(elems, _) => {
      let items : Array[@value.Value] = []
      for e in elems {
        items.push(eval_expr_node(ctx, env, e))
      }
      @value.Value::TupleVal(items)
    }
    @syntax.Expr::EDict(pairs, _) => {
      let d = @value.StarlarkDict::new()
      for pair in pairs {
        let (k_expr, v_expr) = pair
        let k = eval_expr_node(ctx, env, k_expr)
        let v = eval_expr_node(ctx, env, v_expr)
        check(ctx, d.set(k, v))
      }
      @value.Value::DictVal(d)
    }
    @syntax.Expr::ESet(elems, _) => {
      let s = @value.StarlarkSet::new()
      for e in elems {
        let v = eval_expr_node(ctx, env, e)
        check(ctx, s.add(v))
      }
      @value.Value::SetVal(s)
    }
    @syntax.Expr::EIndex(e, idx, pos) => {
      let obj = eval_expr_node(ctx, env, e)
      let idx_v = eval_expr_node(ctx, env, idx)
      eval_index(ctx, obj, idx_v, pos)
    }
    @syntax.Expr::ESlice(e, lo_expr, hi_expr, step_expr, _pos) => {
      let obj = eval_expr_node(ctx, env, e)
      let lo = match lo_expr {
        None => None
        Some(ex) =>
          match eval_expr_node(ctx, env, ex) {
            @value.Value::IntVal(n) => Some(n.to_int())
            _ =>
              raise EvalErr(
                make_eval_error(ctx, "slice indices must be integers"),
              )
          }
      }
      let hi = match hi_expr {
        None => None
        Some(ex) =>
          match eval_expr_node(ctx, env, ex) {
            @value.Value::IntVal(n) => Some(n.to_int())
            _ =>
              raise EvalErr(
                make_eval_error(ctx, "slice indices must be integers"),
              )
          }
      }
      let step = match step_expr {
        None => None
        Some(ex) =>
          match eval_expr_node(ctx, env, ex) {
            @value.Value::IntVal(n) => Some(n.to_int())
            _ =>
              raise EvalErr(
                make_eval_error(ctx, "slice step must be an integer"),
              )
          }
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
      let func = @value.StarlarkFunction::{
        name: "<lambda>",
        params,
        body: [body_stmt],
        defaults,
        freevars: [],
      }
      @value.Value::FuncVal(func)
    }
    @syntax.Expr::EListComp(body_expr, clauses, _) => {
      let result : Array[@value.Value] = []
      eval_comp_clauses(ctx, env, clauses, 0, fn(inner_env) raise EvalErr {
        result.push(eval_expr_node(ctx, inner_env, body_expr))
      })
      @value.Value::ListVal(@value.StarlarkList::new(result))
    }
    @syntax.Expr::ESetComp(body_expr, clauses, _) => {
      let s = @value.StarlarkSet::new()
      eval_comp_clauses(ctx, env, clauses, 0, fn(inner_env) raise EvalErr {
        let v = eval_expr_node(ctx, inner_env, body_expr)
        check(ctx, s.add(v))
      })
      @value.Value::SetVal(s)
    }
    @syntax.Expr::EDictComp(key_expr, val_expr, clauses, _) => {
      let d = @value.StarlarkDict::new()
      eval_comp_clauses(ctx, env, clauses, 0, fn(inner_env) raise EvalErr {
        let k = eval_expr_node(ctx, inner_env, key_expr)
        let v = eval_expr_node(ctx, inner_env, val_expr)
        check(ctx, d.set(k, v))
      })
      @value.Value::DictVal(d)
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
    @value.Value::StrVal(_)
    | @value.Value::ListVal(_)
    | @value.Value::DictVal(_)
    | @value.Value::SetVal(_)
    | @value.Value::BytesVal(_) =>
      @value.Value::BoundMethodVal({ recv: obj, method_name: attr })
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
          @value.Value::DictVal(d) =>
            d.each(fn(k, val) {
              match k {
                @value.Value::StrVal(s) => kw_args.push((s.raw, val))
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
    @value.Value::FuncVal(f) => call_func(ctx, f, pos_args, kw_args, pos)
    @value.Value::BuiltinFuncVal(f) =>
      call_builtin(ctx, f.name, pos_args, kw_args, pos)
    @value.Value::BoundMethodVal(m) =>
      call_method(ctx, m.recv, m.method_name, pos_args, kw_args, pos)
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
  let frame : @errors.CallFrame = { name: f.name, pos }
  ctx.thread.call_stack.push(frame)
  try {
    let func_env = EvalEnv::with_parent(ctx.global_env)
    bind_args(ctx, f, pos_args, kw_args, func_env, pos)
    let sig = exec_stmts(ctx, func_env, f.body)
    ignore(ctx.thread.call_stack.pop())
    match sig {
      Signal::SigReturn(v) => v
      _ => @value.Value::NoneVal
    }
  } catch {
    EvalErr(e) => {
      ignore(ctx.thread.call_stack.pop())
      raise EvalErr(e)
    }
  }
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
    kw_map[kw_name] = kw_val
  }
  let params = f.params
  let defaults = f.defaults
  let mut pos_idx = 0
  let mut param_idx = 0
  while param_idx < params.length() {
    match params[param_idx] {
      @syntax.Param::ParamIdent(name, _) =>
        if pos_idx < pos_args.length() {
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
          raise EvalErr(
            make_eval_error(
              ctx,
              "\{f.name}() missing required argument: '\{name}'",
            ),
          )
        }
      @syntax.Param::ParamDefault(name, _, _) =>
        if pos_idx < pos_args.length() {
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
            None =>
              raise EvalErr(
                make_eval_error(
                  ctx,
                  "\{f.name}() missing required argument: '\{name}'",
                ),
              )
          }
          param_idx += 1
        } else {
          param_idx += 1
        }
      @syntax.Param::ParamStarIdent(name, _) => {
        let rest : Array[@value.Value] = []
        while pos_idx < pos_args.length() {
          rest.push(pos_args[pos_idx])
          pos_idx += 1
        }
        func_env.bind(name, @value.Value::TupleVal(rest))
        param_idx += 1
      }
      @syntax.Param::ParamStarBare(_) => param_idx += 1
      @syntax.Param::ParamKwIdent(name, _) => {
        let kw_dict = @value.StarlarkDict::new()
        kw_map.each(fn(kw_name, kw_val) {
          let key = @value.Value::StrVal(@value.StarlarkString::new(kw_name))
          ignore(kw_dict.set(key, kw_val))
        })
        func_env.bind(name, @value.Value::DictVal(kw_dict))
        param_idx += 1
      }
    }
  }
  if pos_idx < pos_args.length() {
    raise EvalErr(
      make_eval_error(
        ctx,
        "\{f.name}() takes \{params.length()} positional arguments but \{pos_args.length()} were given",
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
      let buf = StringBuilder::new()
      let mut first = true
      for arg in pos_args {
        if !first {
          buf.write_char(' ')
        }
        first = false
        buf.write_string(@value.to_str(arg))
      }
      (ctx.thread.print_fn)(buf.to_string())
      @value.Value::NoneVal
    }
    "len" => {
      if pos_args.length() != 1 {
        raise EvalErr(make_eval_error(ctx, "len() takes exactly one argument"))
      }
      let n = check(ctx, @value.length_of(pos_args[0]))
      @value.Value::IntVal(n.to_int64())
    }
    "str" =>
      if pos_args.length() == 0 {
        @value.Value::StrVal(@value.StarlarkString::new(""))
      } else if pos_args.length() == 1 {
        @value.Value::StrVal(
          @value.StarlarkString::new(@value.to_str(pos_args[0])),
        )
      } else {
        raise EvalErr(make_eval_error(ctx, "str() takes at most one argument"))
      }
    "repr" => {
      if pos_args.length() != 1 {
        raise EvalErr(make_eval_error(ctx, "repr() takes exactly one argument"))
      }
      @value.Value::StrVal(@value.StarlarkString::new(@value.repr(pos_args[0])))
    }
    "type" => {
      if pos_args.length() != 1 {
        raise EvalErr(make_eval_error(ctx, "type() takes exactly one argument"))
      }
      @value.Value::StrVal(
        @value.StarlarkString::new(@value.type_name(pos_args[0])),
      )
    }
    "bool" =>
      if pos_args.length() == 0 {
        @value.Value::BoolVal(false)
      } else if pos_args.length() == 1 {
        @value.Value::BoolVal(@value.truth(pos_args[0]))
      } else {
        raise EvalErr(make_eval_error(ctx, "bool() takes at most one argument"))
      }
    "int" =>
      if pos_args.length() == 0 {
        @value.Value::IntVal(0L)
      } else if pos_args.length() == 1 {
        match pos_args[0] {
          @value.Value::IntVal(n) => @value.Value::IntVal(n)
          @value.Value::FloatVal(f) => @value.Value::IntVal(f.to_int64())
          @value.Value::BoolVal(b) =>
            @value.Value::IntVal(if b { 1L } else { 0L })
          @value.Value::StrVal(s) => {
            let base = if kw_args.length() > 0 {
              match kw_args[0] {
                ("base", @value.Value::IntVal(b)) => b.to_int()
                _ => 10
              }
            } else {
              10
            }
            let n = check(ctx, parse_int_str(s.raw, base))
            @value.Value::IntVal(n)
          }
          v =>
            raise EvalErr(
              make_eval_error(
                ctx,
                "int() argument must be a number or string, not '\{@value.type_name(v)}'",
              ),
            )
        }
      } else {
        raise EvalErr(make_eval_error(ctx, "int() takes at most one argument"))
      }
    "float" =>
      if pos_args.length() == 0 {
        @value.Value::FloatVal(0.0)
      } else if pos_args.length() == 1 {
        match pos_args[0] {
          @value.Value::FloatVal(f) => @value.Value::FloatVal(f)
          @value.Value::IntVal(n) => @value.Value::FloatVal(n.to_double())
          @value.Value::BoolVal(b) =>
            @value.Value::FloatVal(if b { 1.0 } else { 0.0 })
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
        @value.Value::IntVal(n) => @value.Value::IntVal(n.abs())
        @value.Value::FloatVal(f) => @value.Value::FloatVal(f.abs())
        v =>
          raise EvalErr(
            make_eval_error(
              ctx,
              "abs() requires a numeric argument, not '\{@value.type_name(v)}'",
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
    "min" => builtin_minmax(ctx, pos_args, false)
    "max" => builtin_minmax(ctx, pos_args, true)
    "enumerate" => builtin_enumerate(ctx, pos_args)
    "sorted" => builtin_sorted(ctx, pos_args)
    "reversed" => builtin_reversed(ctx, pos_args)
    "zip" => builtin_zip(ctx, pos_args)
    "any" => builtin_any_all(ctx, pos_args, true)
    "all" => builtin_any_all(ctx, pos_args, false)
    "hash" => {
      if pos_args.length() != 1 {
        raise EvalErr(make_eval_error(ctx, "hash() takes exactly one argument"))
      }
      let h = check(ctx, @value.starlark_hash(pos_args[0]))
      @value.Value::IntVal(h.reinterpret_as_int().to_int64())
    }
    "dir" => @value.Value::ListVal(@value.StarlarkList::new([]))
    "chr" => {
      if pos_args.length() != 1 {
        raise EvalErr(make_eval_error(ctx, "chr() takes exactly one argument"))
      }
      match pos_args[0] {
        @value.Value::IntVal(n) => {
          if n < 0L || n > 0x10ffffL {
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
          @value.Value::StrVal(@value.StarlarkString::new(buf.to_string()))
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
        @value.Value::StrVal(s) => {
          let chars = s.raw.to_array()
          if chars.length() != 1 {
            raise EvalErr(
              make_eval_error(
                ctx,
                "ord() expected a character, but string of length \{chars.length()} found",
              ),
            )
          }
          @value.Value::IntVal(chars[0].to_int().to_int64())
        }
        _ =>
          raise EvalErr(make_eval_error(ctx, "ord() argument must be a string"))
      }
    }
    "fail" => {
      let msg = if pos_args.length() > 0 {
        @value.to_str(pos_args[0])
      } else {
        "fail() called"
      }
      raise EvalErr(make_eval_error(ctx, msg))
    }
    "hasattr" => {
      if pos_args.length() != 2 {
        raise EvalErr(
          make_eval_error(ctx, "hasattr() takes exactly 2 arguments"),
        )
      }
      match pos_args[1] {
        @value.Value::StrVal(s) => {
          let dummy_pos = @errors.Position::new("<hasattr>", 0, 0)
          let found = try {
            ignore(eval_getattr(ctx, pos_args[0], s.raw, dummy_pos))
            true
          } catch {
            EvalErr(_) => false
          }
          @value.Value::BoolVal(found)
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
        @value.Value::StrVal(s) => {
          let dummy_pos = @errors.Position::new("<getattr>", 0, 0)
          eval_getattr(ctx, pos_args[0], s.raw, dummy_pos) catch {
            EvalErr(_) =>
              if pos_args.length() >= 3 {
                pos_args[2]
              } else {
                raise EvalErr(
                  make_eval_error(
                    ctx,
                    "'\{@value.type_name(pos_args[0])}' has no attribute '\{s.raw}'",
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
    _ =>
      raise EvalErr(make_eval_error(ctx, "unknown built-in function '\{name}'"))
  }
}

///|
fn builtin_range(
  ctx : EvalContext,
  pos_args : Array[@value.Value],
) -> @value.Value raise EvalErr {
  match pos_args.length() {
    1 =>
      match pos_args[0] {
        @value.Value::IntVal(stop) =>
          @value.Value::RangeVal(@value.StarlarkRange::new(0L, stop, 1L))
        _ =>
          raise EvalErr(
            make_eval_error(ctx, "range() arguments must be integers"),
          )
      }
    2 =>
      match (pos_args[0], pos_args[1]) {
        (@value.Value::IntVal(start), @value.Value::IntVal(stop)) =>
          @value.Value::RangeVal(@value.StarlarkRange::new(start, stop, 1L))
        _ =>
          raise EvalErr(
            make_eval_error(ctx, "range() arguments must be integers"),
          )
      }
    3 =>
      match (pos_args[0], pos_args[1], pos_args[2]) {
        (
          @value.Value::IntVal(start),
          @value.Value::IntVal(stop),
          @value.Value::IntVal(step),
        ) => {
          if step == 0L {
            raise EvalErr(
              make_eval_error(ctx, "range() step argument must not be zero"),
            )
          }
          @value.Value::RangeVal(@value.StarlarkRange::new(start, stop, step))
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
    return @value.Value::ListVal(@value.StarlarkList::new([]))
  }
  if pos_args.length() != 1 {
    raise EvalErr(make_eval_error(ctx, "list() takes at most one argument"))
  }
  match pos_args[0] {
    @value.Value::ListVal(l) => {
      let items : Array[@value.Value] = []
      for v in l.items {
        items.push(v)
      }
      @value.Value::ListVal(@value.StarlarkList::new(items))
    }
    v => {
      let items : Array[@value.Value] = []
      let it = check(ctx, @value.iterate(v))
      while true {
        match it.next() {
          None => {
            it.done()
            break
          }
          Some(item) => items.push(item)
        }
      }
      @value.Value::ListVal(@value.StarlarkList::new(items))
    }
  }
}

///|
fn builtin_tuple(
  ctx : EvalContext,
  pos_args : Array[@value.Value],
) -> @value.Value raise EvalErr {
  if pos_args.length() == 0 {
    return @value.Value::TupleVal([])
  }
  if pos_args.length() != 1 {
    raise EvalErr(make_eval_error(ctx, "tuple() takes at most one argument"))
  }
  let items : Array[@value.Value] = []
  let it = check(ctx, @value.iterate(pos_args[0]))
  while true {
    match it.next() {
      None => {
        it.done()
        break
      }
      Some(item) => items.push(item)
    }
  }
  @value.Value::TupleVal(items)
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
      @value.Value::DictVal(src) => src.each(fn(k, v) { ignore(d.set(k, v)) })
      v => {
        let it = check(ctx, @value.iterate(v))
        while true {
          match it.next() {
            None => {
              it.done()
              break
            }
            Some(@value.Value::TupleVal(pair)) => {
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
            Some(@value.Value::ListVal(pair)) => {
              if pair.items.length() != 2 {
                it.done()
                raise EvalErr(
                  make_eval_error(
                    ctx, "dict() items must be sequences of length 2",
                  ),
                )
              }
              check(ctx, d.set(pair.items[0], pair.items[1]))
            }
            _ => {
              it.done()
              raise EvalErr(
                make_eval_error(
                  ctx, "dict() items must be sequences of length 2",
                ),
              )
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
  for kw_pair in kw_args {
    let (kw_name, kw_val) = kw_pair
    let key = @value.Value::StrVal(@value.StarlarkString::new(kw_name))
    ignore(d.set(key, kw_val))
  }
  @value.Value::DictVal(d)
}

///|
fn builtin_set(
  ctx : EvalContext,
  pos_args : Array[@value.Value],
) -> @value.Value raise EvalErr {
  let s = @value.StarlarkSet::new()
  if pos_args.length() == 0 {
    return @value.Value::SetVal(s)
  }
  if pos_args.length() != 1 {
    raise EvalErr(make_eval_error(ctx, "set() takes at most one argument"))
  }
  let it = check(ctx, @value.iterate(pos_args[0]))
  while true {
    match it.next() {
      None => {
        it.done()
        break
      }
      Some(v) => check(ctx, s.add(v))
    }
  }
  @value.Value::SetVal(s)
}

///|
fn builtin_minmax(
  ctx : EvalContext,
  pos_args : Array[@value.Value],
  want_max : Bool,
) -> @value.Value raise EvalErr {
  let items : Array[@value.Value] = []
  if pos_args.length() == 0 {
    raise EvalErr(
      make_eval_error(ctx, "min/max() expected at least one argument"),
    )
  }
  if pos_args.length() == 1 {
    let it = check(ctx, @value.iterate(pos_args[0]))
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
      raise EvalErr(make_eval_error(ctx, "min/max() arg is an empty sequence"))
    }
  } else {
    for v in pos_args {
      items.push(v)
    }
  }
  let mut result = items[0]
  for i in 1..<items.length() {
    let c = check(ctx, @value.compare_values(items[i], result))
    if (want_max && c > 0) || (!want_max && c < 0) {
      result = items[i]
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
      @value.Value::IntVal(n) => n
      _ => 0L
    }
  } else {
    0L
  }
  let result : Array[@value.Value] = []
  let it = check(ctx, @value.iterate(pos_args[0]))
  let mut idx = start
  while true {
    match it.next() {
      None => {
        it.done()
        break
      }
      Some(v) => {
        result.push(@value.Value::TupleVal([@value.Value::IntVal(idx), v]))
        idx = idx + 1L
      }
    }
  }
  @value.Value::ListVal(@value.StarlarkList::new(result))
}

///|
fn builtin_sorted(
  ctx : EvalContext,
  pos_args : Array[@value.Value],
) -> @value.Value raise EvalErr {
  if pos_args.length() < 1 {
    raise EvalErr(
      make_eval_error(ctx, "sorted() requires at least one argument"),
    )
  }
  let items : Array[@value.Value] = []
  let it = check(ctx, @value.iterate(pos_args[0]))
  while true {
    match it.next() {
      None => {
        it.done()
        break
      }
      Some(v) => items.push(v)
    }
  }
  let mut sort_err : @errors.EvalError? = None
  items.sort_by(fn(a, b) {
    match @value.compare_values(a, b) {
      Err(msg) => {
        sort_err = Some(make_eval_error(ctx, msg))
        0
      }
      Ok(c) => c
    }
  })
  match sort_err {
    Some(e) => raise EvalErr(e)
    None => @value.Value::ListVal(@value.StarlarkList::new(items))
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
  let it = check(ctx, @value.iterate(pos_args[0]))
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
  let rev : Array[@value.Value] = Array::make(n, @value.Value::NoneVal)
  for i in 0..<n {
    rev[i] = items[n - 1 - i]
  }
  @value.Value::ListVal(@value.StarlarkList::new(rev))
}

///|
fn builtin_zip(
  ctx : EvalContext,
  pos_args : Array[@value.Value],
) -> @value.Value raise EvalErr {
  if pos_args.length() == 0 {
    return @value.Value::ListVal(@value.StarlarkList::new([]))
  }
  let iterators : Array[@value.StarlarkIterator] = []
  for arg in pos_args {
    match @value.iterate(arg) {
      Err(msg) => {
        for it in iterators {
          it.done()
        }
        raise EvalErr(make_eval_error(ctx, msg))
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
    result.push(@value.Value::TupleVal(tuple_items))
  }
  @value.Value::ListVal(@value.StarlarkList::new(result))
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
  let it = check(ctx, @value.iterate(pos_args[0]))
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
  @value.Value::BoolVal(result)
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
    @value.Value::ListVal(l) => call_list_method(ctx, l, method_name, pos_args)
    @value.Value::DictVal(d) =>
      call_dict_method(ctx, d, method_name, pos_args, kw_args)
    @value.Value::StrVal(s) => call_str_method(ctx, s, method_name, pos_args)
    @value.Value::SetVal(s) => call_set_method(ctx, s, method_name, pos_args)
    @value.Value::BytesVal(b) =>
      call_bytes_method(ctx, b, method_name, pos_args)
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
      check(ctx, l.check_mutable("append to"))
      l.items.push(pos_args[0])
      @value.Value::NoneVal
    }
    "extend" => {
      if pos_args.length() != 1 {
        raise EvalErr(
          make_eval_error(ctx, "extend() takes exactly one argument"),
        )
      }
      check(ctx, l.check_mutable("extend"))
      let it = check(ctx, @value.iterate(pos_args[0]))
      while true {
        match it.next() {
          None => {
            it.done()
            break
          }
          Some(v) => l.items.push(v)
        }
      }
      @value.Value::NoneVal
    }
    "pop" => {
      check(ctx, l.check_mutable("pop from"))
      if l.items.is_empty() {
        raise EvalErr(make_eval_error(ctx, "pop from empty list"))
      }
      if pos_args.length() == 0 {
        match l.items.pop() {
          None => raise EvalErr(make_eval_error(ctx, "pop from empty list"))
          Some(v) => v
        }
      } else {
        match pos_args[0] {
          @value.Value::IntVal(i) => {
            let j = check(ctx, adjust_index(i, l.items.length()))
            l.items.remove(j)
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
      check(ctx, l.check_mutable("remove from"))
      let item = pos_args[0]
      let mut found = -1
      for i in 0..<l.items.length() {
        if @value.starlark_equals(l.items[i], item) {
          found = i
          break
        }
      }
      if found < 0 {
        raise EvalErr(make_eval_error(ctx, "list.remove(x): x not in list"))
      }
      ignore(l.items.remove(found))
      @value.Value::NoneVal
    }
    "insert" => {
      if pos_args.length() != 2 {
        raise EvalErr(
          make_eval_error(ctx, "insert() takes exactly 2 arguments"),
        )
      }
      check(ctx, l.check_mutable("insert into"))
      match pos_args[0] {
        @value.Value::IntVal(i) => {
          let len = l.items.length()
          let j = {
            let jj = if i < 0L { i + len.to_int64() } else { i }
            if jj < 0L {
              0
            } else if jj > len.to_int64() {
              len
            } else {
              jj.to_int()
            }
          }
          l.items.insert(j, pos_args[1])
          @value.Value::NoneVal
        }
        _ =>
          raise EvalErr(
            make_eval_error(ctx, "insert() first argument must be an integer"),
          )
      }
    }
    "clear" => {
      check(ctx, l.check_mutable("clear"))
      l.items.clear()
      @value.Value::NoneVal
    }
    "index" => {
      if pos_args.length() < 1 {
        raise EvalErr(
          make_eval_error(ctx, "index() takes at least one argument"),
        )
      }
      let item = pos_args[0]
      for i in 0..<l.items.length() {
        if @value.starlark_equals(l.items[i], item) {
          return @value.Value::IntVal(i.to_int64())
        }
      }
      raise EvalErr(make_eval_error(ctx, "list.index(x): x not in list"))
    }
    "count" => {
      if pos_args.length() != 1 {
        raise EvalErr(
          make_eval_error(ctx, "count() takes exactly one argument"),
        )
      }
      let item = pos_args[0]
      let mut count = 0
      for v in l.items {
        if @value.starlark_equals(v, item) {
          count += 1
        }
      }
      @value.Value::IntVal(count.to_int64())
    }
    "sort" => {
      check(ctx, l.check_mutable("sort"))
      let mut sort_err : @errors.EvalError? = None
      l.items.sort_by(fn(a, b) {
        match @value.compare_values(a, b) {
          Err(msg) => {
            sort_err = Some(make_eval_error(ctx, msg))
            0
          }
          Ok(c) => c
        }
      })
      match sort_err {
        Some(e) => raise EvalErr(e)
        None => @value.Value::NoneVal
      }
    }
    "reverse" => {
      check(ctx, l.check_mutable("reverse"))
      let n = l.items.length()
      let mut i = 0
      while i < n / 2 {
        let tmp = l.items[i]
        l.items[i] = l.items[n - 1 - i]
        l.items[n - 1 - i] = tmp
        i += 1
      }
      @value.Value::NoneVal
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
      if pos_args.length() < 1 {
        raise EvalErr(
          make_eval_error(ctx, "dict.get() requires at least one argument"),
        )
      }
      let default_val = if pos_args.length() >= 2 {
        pos_args[1]
      } else {
        @value.Value::NoneVal
      }
      match check(ctx, d.get(pos_args[0])) {
        None => default_val
        Some(v) => v
      }
    }
    "keys" => {
      let keys = d.keys()
      @value.Value::ListVal(@value.StarlarkList::new(keys))
    }
    "values" => {
      let vals : Array[@value.Value] = []
      d.each(fn(_k, v) { vals.push(v) })
      @value.Value::ListVal(@value.StarlarkList::new(vals))
    }
    "items" => {
      let items : Array[@value.Value] = []
      d.each(fn(k, v) { items.push(@value.Value::TupleVal([k, v])) })
      @value.Value::ListVal(@value.StarlarkList::new(items))
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
            raise EvalErr(make_eval_error(ctx, "dict.pop(): key not found"))
          }
        Some(v) => {
          ignore(check(ctx, d.delete(key)))
          v
        }
      }
    }
    "update" => {
      if pos_args.length() > 0 {
        match pos_args[0] {
          @value.Value::DictVal(src) =>
            src.each(fn(k, v) { ignore(d.set(k, v)) })
          _ =>
            raise EvalErr(
              make_eval_error(ctx, "dict.update() argument must be a dict"),
            )
        }
      }
      for kw_pair in kw_args {
        let (kw_name, kw_val) = kw_pair
        let key = @value.Value::StrVal(@value.StarlarkString::new(kw_name))
        ignore(d.set(key, kw_val))
      }
      @value.Value::NoneVal
    }
    "clear" => {
      check(ctx, d.clear())
      @value.Value::NoneVal
    }
    "popitem" =>
      match check(ctx, d.popitem()) {
        None =>
          raise EvalErr(
            make_eval_error(ctx, "dict.popitem(): dictionary is empty"),
          )
        Some((k, v)) => @value.Value::TupleVal([k, v])
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
        @value.Value::NoneVal
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
) -> @value.Value raise EvalErr {
  match method_name {
    "upper" =>
      @value.Value::StrVal(@value.StarlarkString::new(s.raw.to_upper()))
    "lower" =>
      @value.Value::StrVal(@value.StarlarkString::new(s.raw.to_lower()))
    "strip" => {
      let trimmed = s.raw.trim()
      @value.Value::StrVal(@value.StarlarkString::new("\{trimmed}"))
    }
    "lstrip" => {
      let trimmed = s.raw.trim_start()
      @value.Value::StrVal(@value.StarlarkString::new("\{trimmed}"))
    }
    "rstrip" => {
      let trimmed = s.raw.trim_end()
      @value.Value::StrVal(@value.StarlarkString::new("\{trimmed}"))
    }
    "startswith" => {
      if pos_args.length() != 1 {
        raise EvalErr(
          make_eval_error(ctx, "startswith() takes exactly one argument"),
        )
      }
      match pos_args[0] {
        @value.Value::StrVal(prefix) =>
          @value.Value::BoolVal(s.raw.has_prefix(prefix.raw))
        _ =>
          raise EvalErr(
            make_eval_error(ctx, "startswith() argument must be a string"),
          )
      }
    }
    "endswith" => {
      if pos_args.length() != 1 {
        raise EvalErr(
          make_eval_error(ctx, "endswith() takes exactly one argument"),
        )
      }
      match pos_args[0] {
        @value.Value::StrVal(suffix) =>
          @value.Value::BoolVal(s.raw.has_suffix(suffix.raw))
        _ =>
          raise EvalErr(
            make_eval_error(ctx, "endswith() argument must be a string"),
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
        @value.Value::StrVal(sub) => {
          let result = find_substr(s.raw, sub.raw)
          @value.Value::IntVal(result.to_int64())
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
        @value.Value::StrVal(sub) => {
          let count = count_substr(s.raw, sub.raw)
          @value.Value::IntVal(count.to_int64())
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
        (@value.Value::StrVal(old), @value.Value::StrVal(new_s)) => {
          let result = s.raw.replace_all(old=old.raw, new=new_s.raw)
          @value.Value::StrVal(@value.StarlarkString::new(result))
        }
        _ =>
          raise EvalErr(
            make_eval_error(ctx, "replace() arguments must be strings"),
          )
      }
    }
    "split" =>
      if pos_args.length() == 0 {
        let parts : Array[@value.Value] = []
        for sv in s.raw.split(" ") {
          let p = "\{sv}"
          if p != "" {
            parts.push(@value.Value::StrVal(@value.StarlarkString::new(p)))
          }
        }
        @value.Value::ListVal(@value.StarlarkList::new(parts))
      } else {
        match pos_args[0] {
          @value.Value::StrVal(sep) => {
            let parts : Array[@value.Value] = []
            for sv in s.raw.split(sep.raw) {
              parts.push(
                @value.Value::StrVal(@value.StarlarkString::new("\{sv}")),
              )
            }
            @value.Value::ListVal(@value.StarlarkList::new(parts))
          }
          _ =>
            raise EvalErr(
              make_eval_error(ctx, "split() argument must be a string"),
            )
        }
      }
    "join" => {
      if pos_args.length() != 1 {
        raise EvalErr(make_eval_error(ctx, "join() takes exactly one argument"))
      }
      let parts : Array[String] = []
      let it = check(ctx, @value.iterate(pos_args[0]))
      while true {
        match it.next() {
          None => {
            it.done()
            break
          }
          Some(@value.Value::StrVal(part)) => parts.push(part.raw)
          Some(v) => {
            it.done()
            raise EvalErr(
              make_eval_error(
                ctx,
                "join() requires string elements, got '\{@value.type_name(v)}'",
              ),
            )
          }
        }
      }
      let buf = StringBuilder::new()
      let mut first = true
      for part in parts {
        if !first {
          buf.write_string(s.raw)
        }
        first = false
        buf.write_string(part)
      }
      @value.Value::StrVal(@value.StarlarkString::new(buf.to_string()))
    }
    "format" => {
      let result = str_format(s.raw, pos_args)
      @value.Value::StrVal(@value.StarlarkString::new(result))
    }
    "capitalize" => {
      let chars = s.raw.to_array()
      if chars.is_empty() {
        @value.Value::StrVal(s)
      } else {
        let buf = StringBuilder::new()
        buf.write_char(char_to_upper(chars[0]))
        for i in 1..<chars.length() {
          buf.write_char(char_to_lower(chars[i]))
        }
        @value.Value::StrVal(@value.StarlarkString::new(buf.to_string()))
      }
    }
    "index" => {
      if pos_args.length() < 1 {
        raise EvalErr(
          make_eval_error(ctx, "index() takes at least one argument"),
        )
      }
      match pos_args[0] {
        @value.Value::StrVal(sub) => {
          let result = find_substr(s.raw, sub.raw)
          if result < 0 {
            raise EvalErr(make_eval_error(ctx, "substring not found"))
          }
          @value.Value::IntVal(result.to_int64())
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
        @value.Value::StrVal(sub) => {
          let result = rfind_substr(s.raw, sub.raw)
          @value.Value::IntVal(result.to_int64())
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
        @value.Value::StrVal(sub) => {
          let result = rfind_substr(s.raw, sub.raw)
          if result < 0 {
            raise EvalErr(make_eval_error(ctx, "substring not found"))
          }
          @value.Value::IntVal(result.to_int64())
        }
        _ =>
          raise EvalErr(
            make_eval_error(ctx, "rindex() argument must be a string"),
          )
      }
    }
    "isalpha" => {
      if s.raw.length() == 0 {
        return @value.Value::BoolVal(false)
      }
      let mut result = true
      for c in s.raw.to_array() {
        let n = c.to_int()
        if !((n >= 'A'.to_int() && n <= 'Z'.to_int()) ||
          (n >= 'a'.to_int() && n <= 'z'.to_int())) {
          result = false
          break
        }
      }
      @value.Value::BoolVal(result)
    }
    "isdigit" => {
      if s.raw.length() == 0 {
        return @value.Value::BoolVal(false)
      }
      let mut result = true
      for c in s.raw.to_array() {
        let n = c.to_int()
        if n < '0'.to_int() || n > '9'.to_int() {
          result = false
          break
        }
      }
      @value.Value::BoolVal(result)
    }
    "isalnum" => {
      if s.raw.length() == 0 {
        return @value.Value::BoolVal(false)
      }
      let mut result = true
      for c in s.raw.to_array() {
        let n = c.to_int()
        if !((n >= 'A'.to_int() && n <= 'Z'.to_int()) ||
          (n >= 'a'.to_int() && n <= 'z'.to_int()) ||
          (n >= '0'.to_int() && n <= '9'.to_int())) {
          result = false
          break
        }
      }
      @value.Value::BoolVal(result)
    }
    "islower" => {
      let chars = s.raw.to_array()
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
      @value.Value::BoolVal(result && has_cased)
    }
    "isupper" => {
      let chars = s.raw.to_array()
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
      @value.Value::BoolVal(result && has_cased)
    }
    "isspace" => {
      if s.raw.length() == 0 {
        return @value.Value::BoolVal(false)
      }
      let mut result = true
      for c in s.raw.to_array() {
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
      @value.Value::BoolVal(result)
    }
    "title" => {
      let chars = s.raw.to_array()
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
      @value.Value::StrVal(@value.StarlarkString::new(buf.to_string()))
    }
    "partition" => {
      if pos_args.length() != 1 {
        raise EvalErr(
          make_eval_error(ctx, "partition() takes exactly one argument"),
        )
      }
      match pos_args[0] {
        @value.Value::StrVal(sep) => {
          let idx = find_substr(s.raw, sep.raw)
          if idx < 0 {
            @value.Value::TupleVal([
              @value.Value::StrVal(s),
              @value.Value::StrVal(@value.StarlarkString::new("")),
              @value.Value::StrVal(@value.StarlarkString::new("")),
            ])
          } else {
            let before = s.raw[0:idx].to_owned()
            let after = s.raw[idx + sep.raw.length():].to_owned()
            @value.Value::TupleVal([
              @value.Value::StrVal(@value.StarlarkString::new(before)),
              @value.Value::StrVal(@value.StarlarkString::new(sep.raw)),
              @value.Value::StrVal(@value.StarlarkString::new(after)),
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
        @value.Value::StrVal(sep) => {
          let idx = rfind_substr(s.raw, sep.raw)
          if idx < 0 {
            @value.Value::TupleVal([
              @value.Value::StrVal(@value.StarlarkString::new("")),
              @value.Value::StrVal(@value.StarlarkString::new("")),
              @value.Value::StrVal(s),
            ])
          } else {
            let before = s.raw[0:idx].to_owned()
            let after = s.raw[idx + sep.raw.length():].to_owned()
            @value.Value::TupleVal([
              @value.Value::StrVal(@value.StarlarkString::new(before)),
              @value.Value::StrVal(@value.StarlarkString::new(sep.raw)),
              @value.Value::StrVal(@value.StarlarkString::new(after)),
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
        @value.Value::StrVal(prefix) =>
          if s.raw.has_prefix(prefix.raw) {
            let rest = s.raw[prefix.raw.length():].to_owned()
            @value.Value::StrVal(@value.StarlarkString::new(rest))
          } else {
            @value.Value::StrVal(s)
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
        @value.Value::StrVal(suffix) =>
          if s.raw.has_suffix(suffix.raw) {
            let rest = s.raw[0:s.raw.length() - suffix.raw.length()].to_owned()
            @value.Value::StrVal(@value.StarlarkString::new(rest))
          } else {
            @value.Value::StrVal(s)
          }
        _ =>
          raise EvalErr(
            make_eval_error(ctx, "removesuffix() argument must be a string"),
          )
      }
    }
    "splitlines" => {
      let parts : Array[@value.Value] = []
      let raw = s.raw
      let buf = StringBuilder::new()
      for c in raw.to_array() {
        let n = c.to_int()
        if n == '\n'.to_int() || n == '\r'.to_int() {
          parts.push(
            @value.Value::StrVal(@value.StarlarkString::new(buf.to_string())),
          )
          buf.reset()
        } else {
          buf.write_char(c)
        }
      }
      if buf.to_string().length() > 0 {
        parts.push(
          @value.Value::StrVal(@value.StarlarkString::new(buf.to_string())),
        )
      }
      @value.Value::ListVal(@value.StarlarkList::new(parts))
    }
    "elems" => {
      let parts : Array[@value.Value] = []
      for b in s.bytes {
        let buf = StringBuilder::new()
        buf.write_char(b.to_int().unsafe_to_char())
        parts.push(
          @value.Value::StrVal(@value.StarlarkString::new(buf.to_string())),
        )
      }
      @value.Value::ListVal(@value.StarlarkList::new(parts))
    }
    "elem_ords" => {
      let ords : Array[@value.Value] = []
      for b in s.bytes {
        ords.push(@value.Value::IntVal(b.to_int().to_int64()))
      }
      @value.Value::ListVal(@value.StarlarkList::new(ords))
    }
    "istitle" => {
      let chars = s.raw.to_array()
      if chars.is_empty() {
        return @value.Value::BoolVal(false)
      }
      let mut prev_cased = false
      let mut result = true
      for c in chars {
        let n = c.to_int()
        if n >= 'A'.to_int() && n <= 'Z'.to_int() {
          if prev_cased {
            result = false
            break
          }
          prev_cased = true
        } else if n >= 'a'.to_int() && n <= 'z'.to_int() {
          if !prev_cased {
            result = false
            break
          }
          prev_cased = true
        } else {
          prev_cased = false
        }
      }
      @value.Value::BoolVal(result)
    }
    _ =>
      raise EvalErr(
        make_eval_error(ctx, "string has no method '\{method_name}'"),
      )
  }
}

///|
fn call_set_method(
  ctx : EvalContext,
  s : @value.StarlarkSet,
  method_name : String,
  pos_args : Array[@value.Value],
) -> @value.Value raise EvalErr {
  match method_name {
    "add" => {
      if pos_args.length() != 1 {
        raise EvalErr(make_eval_error(ctx, "add() takes exactly one argument"))
      }
      check(ctx, s.add(pos_args[0]))
      @value.Value::NoneVal
    }
    "discard" => {
      if pos_args.length() != 1 {
        raise EvalErr(
          make_eval_error(ctx, "discard() takes exactly one argument"),
        )
      }
      ignore(check(ctx, s.remove(pos_args[0])))
      @value.Value::NoneVal
    }
    "remove" => {
      if pos_args.length() != 1 {
        raise EvalErr(
          make_eval_error(ctx, "remove() takes exactly one argument"),
        )
      }
      match check(ctx, s.remove(pos_args[0])) {
        false =>
          raise EvalErr(make_eval_error(ctx, "set.remove(x): x not in set"))
        true => @value.Value::NoneVal
      }
    }
    "clear" => {
      check(ctx, s.clear())
      @value.Value::NoneVal
    }
    "pop" =>
      match check(ctx, s.pop_first()) {
        None => raise EvalErr(make_eval_error(ctx, "set.pop(): set is empty"))
        Some(v) => v
      }
    "union" => {
      if pos_args.length() != 1 {
        raise EvalErr(
          make_eval_error(ctx, "union() takes exactly one argument"),
        )
      }
      let result = @value.StarlarkSet::new()
      s.each(fn(v) { ignore(result.add(v)) })
      let it = check(ctx, @value.iterate(pos_args[0]))
      while true {
        match it.next() {
          None => {
            it.done()
            break
          }
          Some(v) => check(ctx, result.add(v))
        }
      }
      @value.Value::SetVal(result)
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
      @value.Value::SetVal(result)
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
      @value.Value::SetVal(result)
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
      @value.Value::SetVal(result)
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
      @value.Value::BoolVal(all_in)
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
      @value.Value::BoolVal(all_in)
    }
    "update" => {
      if pos_args.length() != 1 {
        raise EvalErr(
          make_eval_error(ctx, "update() takes exactly one argument"),
        )
      }
      let it = check(ctx, @value.iterate(pos_args[0]))
      while true {
        match it.next() {
          None => {
            it.done()
            break
          }
          Some(v) => check(ctx, s.add(v))
        }
      }
      @value.Value::NoneVal
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
    @value.Value::BytesVal(b) => @value.Value::BytesVal(b)
    @value.Value::StrVal(s) => @value.Value::BytesVal(s.bytes)
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
          Some(@value.Value::IntVal(n)) => {
            if n < 0L || n > 255L {
              it.done()
              raise EvalErr(
                make_eval_error(
                  ctx,
                  "bytes: at index \{idx}, value \{n} is out of range for byte (0-255)",
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
      @value.Value::BytesVal(Bytes::from_array(buf))
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
    "elems" => {
      let items : Array[@value.Value] = []
      for i in 0..<b.length() {
        items.push(@value.Value::IntVal(b[i].to_int().to_int64()))
      }
      @value.Value::ListVal(@value.StarlarkList::new(items))
    }
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
fn str_format(template : String, args : Array[@value.Value]) -> String {
  let buf = StringBuilder::new()
  let mut idx = 0
  let mut arg_idx = 0
  while idx < template.length() {
    let c = template[idx]
    if c == '{' && idx + 1 < template.length() && template[idx + 1] == '}' {
      if arg_idx < args.length() {
        buf.write_string(@value.to_str(args[arg_idx]))
        arg_idx += 1
      }
      idx += 2
    } else {
      buf.write_char(Int::unsafe_to_char(c.to_int()))
      idx += 1
    }
  }
  buf.to_string()
}

///|
fn parse_int_str(s : String, base : Int) -> Result[Int64, String] {
  let s = s.trim().to_owned()
  if s.length() == 0 {
    return Err("invalid literal for int(): empty string")
  }
  let negative = s[0] == '-'
  let start = if negative || s[0] == '+' { 1 } else { 0 }
  if start >= s.length() {
    return Err("invalid literal for int(): '\{s}'")
  }
  let actual_base = if base == 0 {
    if s[start] == '0' && start + 1 < s.length() {
      match s[start + 1] {
        'x' | 'X' => 16
        'o' | 'O' => 8
        'b' | 'B' => 2
        _ => 10
      }
    } else {
      10
    }
  } else {
    base
  }
  let digit_start = if actual_base != 10 &&
    s[start] == '0' &&
    start + 1 < s.length() {
    let prefix = s[start + 1]
    if prefix == 'x' ||
      prefix == 'X' ||
      prefix == 'o' ||
      prefix == 'O' ||
      prefix == 'b' ||
      prefix == 'B' {
      start + 2
    } else {
      start
    }
  } else {
    start
  }
  if digit_start >= s.length() {
    return Err("invalid literal for int(): '\{s}'")
  }
  let mut result = 0L
  for i in digit_start..<s.length() {
    let c = s[i].to_int()
    let digit = if c >= '0'.to_int() && c <= '9'.to_int() {
      c - '0'.to_int()
    } else if c >= 'a'.to_int() && c <= 'z'.to_int() {
      c - 'a'.to_int() + 10
    } else if c >= 'A'.to_int() && c <= 'Z'.to_int() {
      c - 'A'.to_int() + 10
    } else {
      return Err("invalid literal for int(): '\{s}'")
    }
    if digit >= actual_base {
      return Err("invalid literal for int(): '\{s}'")
    }
    result = result * actual_base.to_int64() + digit.to_int64()
  }
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
