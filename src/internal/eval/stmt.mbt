///|
fn exec_stmts(
  ctx : EvalContext,
  env : EvalEnv,
  stmts : Array[@syntax.Stmt],
) -> Signal raise EvalErr {
  for stmt in stmts {
    match exec_stmt(ctx, env, stmt) {
      Signal::SigNormal => ()
      sig => return sig
    }
  }
  Signal::SigNormal
}

///|
fn exec_stmt(
  ctx : EvalContext,
  env : EvalEnv,
  stmt : @syntax.Stmt,
) -> Signal raise EvalErr {
  match stmt {
    @syntax.Stmt::SPass(_) => Signal::SigNormal
    @syntax.Stmt::SExpr(e) => {
      ignore(eval_expr_node(ctx, env, e))
      Signal::SigNormal
    }
    @syntax.Stmt::SAssign(lhs, rhs, pos) => {
      let v = eval_expr_node(ctx, env, rhs)
      assign_to(ctx, env, lhs, v, pos)
      Signal::SigNormal
    }
    @syntax.Stmt::SAugAssign(lhs, aug_op, rhs, pos) => {
      match lhs {
        @syntax.Expr::EIndex(obj_expr, idx_expr, idx_pos) => {
          let obj = eval_expr_node(ctx, env, obj_expr)
          let idx = eval_expr_node(ctx, env, idx_expr)
          let lv = eval_index(ctx, obj, idx, idx_pos)
          let rv = eval_expr_node(ctx, env, rhs)
          let new_val = eval_aug_val(ctx, lv, aug_op, rv, pos)
          set_index(ctx, obj, idx, new_val, idx_pos)
        }
        _ => {
          let lv = eval_expr_node(ctx, env, lhs)
          let rv = eval_expr_node(ctx, env, rhs)
          let new_val = eval_aug_val(ctx, lv, aug_op, rv, pos)
          assign_to(ctx, env, lhs, new_val, pos)
        }
      }
      Signal::SigNormal
    }
    @syntax.Stmt::SIf(cond, then_body, else_body, _) => {
      let cv = eval_expr_node(ctx, env, cond)
      if @value.truth(cv) {
        exec_stmts(ctx, env, then_body)
      } else {
        exec_stmts(ctx, env, else_body)
      }
    }
    @syntax.Stmt::SFor(target, iter_expr, body, pos) => {
      let iter_val = eval_expr_node(ctx, env, iter_expr)
      let iter = check(ctx, @value.iterate(iter_val))
      let mut result : Signal = Signal::SigNormal
      try {
        while true {
          match iter.next() {
            None => break
            Some(item) => {
              assign_to(ctx, env, target, item, pos)
              match exec_stmts(ctx, env, body) {
                Signal::SigNormal => ()
                Signal::SigBreak => {
                  result = Signal::SigNormal
                  break
                }
                Signal::SigContinue => ()
                Signal::SigReturn(_) as sig => {
                  result = sig
                  break
                }
              }
            }
          }
        }
      } catch {
        EvalErr(e) => {
          iter.done()
          raise EvalErr(e)
        }
      }
      iter.done()
      result
    }
    @syntax.Stmt::SWhile(cond, body, _) => {
      if !ctx.opts.allow_while {
        raise EvalErr(make_eval_error(ctx, "while loops are not allowed"))
      }
      let mut result : Signal = Signal::SigNormal
      while true {
        let cv = eval_expr_node(ctx, env, cond)
        if !@value.truth(cv) {
          break
        }
        match exec_stmts(ctx, env, body) {
          Signal::SigNormal => ()
          Signal::SigBreak => {
            result = Signal::SigNormal
            break
          }
          Signal::SigContinue => ()
          Signal::SigReturn(_) as sig => {
            result = sig
            break
          }
        }
      }
      result
    }
    @syntax.Stmt::SDef(name, params, body, _) => {
      let defaults = eval_defaults(ctx, env, params)
      let captured_scope = env.collect_local_scopes()
      let func = @value.StarlarkFunction::new(
        name, params, body, defaults, captured_scope,
      )
      env.bind(name, @value.Value::FuncVal(func))
      Signal::SigNormal
    }
    @syntax.Stmt::SReturn(expr_opt, _) =>
      match expr_opt {
        None => Signal::SigReturn(@value.Value::NoneVal)
        Some(e) => {
          let v = eval_expr_node(ctx, env, e)
          Signal::SigReturn(v)
        }
      }
    @syntax.Stmt::SBreak(_) => Signal::SigBreak
    @syntax.Stmt::SContinue(_) => Signal::SigContinue
    @syntax.Stmt::SLoad(path, bindings, pos) =>
      exec_load(ctx, env, path, bindings, pos)
  }
}

///|
fn assign_to(
  ctx : EvalContext,
  env : EvalEnv,
  target : @syntax.Expr,
  value : @value.Value,
  pos : @errors.Position,
) -> Unit raise EvalErr {
  match target {
    @syntax.Expr::EIdent(name, _) => env.bind(name, value)
    @syntax.Expr::ETuple(elems, _) | @syntax.Expr::EList(elems, _) => {
      let items : Array[@value.Value] = match value {
        @value.Value::TupleVal(t) => t
        @value.Value::ListVal(l) => l.items
        _ => {
          let it = match @value.iterate(value) {
            Ok(it) => it
            Err(_) =>
              raise EvalErr(
                make_eval_error(
                  ctx,
                  "\{pos.to_string()}: got \{@value.type_name(value)} in sequence assignment",
                ),
              )
          }
          let collected : Array[@value.Value] = []
          while true {
            match it.next() {
              None => break
              Some(item) => collected.push(item)
            }
          }
          it.done()
          collected
        }
      }
      if items.length() < elems.length() {
        raise EvalErr(
          make_eval_error(
            ctx,
            "\{pos.to_string()}: too few values to unpack (expected \{elems.length()}, got \{items.length()})",
          ),
        )
      } else if items.length() > elems.length() {
        raise EvalErr(
          make_eval_error(
            ctx,
            "\{pos.to_string()}: too many values to unpack (expected \{elems.length()}, got \{items.length()})",
          ),
        )
      }
      for i in 0..<elems.length() {
        assign_to(ctx, env, elems[i], items[i], pos)
      }
    }
    @syntax.Expr::EIndex(obj_expr, idx_expr, idx_pos) => {
      let obj = eval_expr_node(ctx, env, obj_expr)
      let idx = eval_expr_node(ctx, env, idx_expr)
      set_index(ctx, obj, idx, value, idx_pos)
    }
    @syntax.Expr::EDot(obj_expr, attr, _) => {
      let obj = eval_expr_node(ctx, env, obj_expr)
      match obj {
        @value.Value::ModuleVal(_) =>
          raise EvalErr(
            make_eval_error(ctx, "can't assign to .\{attr} field of module"),
          )
        _ =>
          raise EvalErr(
            make_eval_error(
              ctx,
              "can't assign to .\{attr} field of \{@value.type_name(obj)} value",
            ),
          )
      }
    }
    _ =>
      raise EvalErr(
        make_eval_error(ctx, "\{pos.to_string()}: invalid assignment target"),
      )
  }
}

///|
fn eval_aug_val(
  ctx : EvalContext,
  lv : @value.Value,
  aug_op : @syntax.AugOp,
  rv : @value.Value,
  pos : @errors.Position,
) -> @value.Value raise EvalErr {
  match (lv, aug_op) {
    (@value.Value::ListVal(l), @syntax.AugOp::AugAdd) =>
      match @value.iterate(rv) {
        Ok(iter) => {
          match l.check_mutable("apply += to") {
            Err(msg) => {
              iter.done()
              raise EvalErr(make_eval_error(ctx, msg))
            }
            Ok(_) => ()
          }
          while true {
            match iter.next() {
              None => break
              Some(item) => l.items.push(item)
            }
          }
          iter.done()
          lv
        }
        Err(_) => eval_binary(ctx, lv, @syntax.BinaryOp::OpAdd, rv, pos)
      }
    (@value.Value::DictVal(ld), @syntax.AugOp::AugBitOr) =>
      match rv {
        @value.Value::DictVal(rd) => {
          let pairs : Array[(@value.Value, @value.Value)] = []
          rd.each(fn(k, v) { pairs.push((k, v)) })
          for pair in pairs {
            let (k, v) = pair
            check(ctx, ld.set(k, v))
          }
          lv
        }
        _ =>
          raise EvalErr(
            make_eval_error(
              ctx,
              "unknown binary op: dict | \{@value.type_name(rv)}",
            ),
          )
      }
    _ => {
      let bin_op = aug_to_bin_op(aug_op)
      eval_binary(ctx, lv, bin_op, rv, pos)
    }
  }
}

///|
fn exec_load(
  ctx : EvalContext,
  env : EvalEnv,
  path : String,
  bindings : Array[(String, String)],
  pos : @errors.Position,
) -> Signal raise EvalErr {
  match ctx.thread.load_fn {
    None =>
      raise EvalErr(
        make_eval_error(ctx, "\{pos.to_string()}: load is not supported"),
      )
    Some(loader) => {
      let loaded = match loader(ctx.thread, path) {
        Ok(m) => m
        Err(e) =>
          raise EvalErr(make_eval_error(ctx, "\{pos.to_string()}: \{e.msg}"))
      }
      for pair in bindings {
        let (local_name, export_name) = pair
        let key = @value.Value::StrVal(@value.StarlarkString::new(export_name))
        match loaded.globals.get(key) {
          Ok(Some(v)) => {
            env.bind(local_name, v)
            ctx.load_bound_names.push(local_name)
          }
          _ =>
            raise EvalErr(
              make_eval_error(
                ctx,
                "\{pos.to_string()}: load: name \{export_name} not found in module \{path}",
              ),
            )
        }
      }
      SigNormal
    }
  }
}
