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
      let lv = eval_expr_node(ctx, env, lhs)
      let rv = eval_expr_node(ctx, env, rhs)
      let bin_op = aug_to_bin_op(aug_op)
      let new_val = eval_binary(ctx, lv, bin_op, rv, pos)
      assign_to(ctx, env, lhs, new_val, pos)
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
      let func = @value.StarlarkFunction::{
        name,
        params,
        body,
        defaults,
        freevars: [],
      }
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
      let items = match value {
        @value.Value::TupleVal(t) => t
        @value.Value::ListVal(l) => l.items
        _ =>
          raise EvalErr(
            make_eval_error(
              ctx,
              "\{pos.to_string()}: cannot unpack non-sequence",
            ),
          )
      }
      if items.length() != elems.length() {
        let few_or_many = if items.length() < elems.length() {
          "few"
        } else {
          "many"
        }
        raise EvalErr(
          make_eval_error(
            ctx,
            "\{pos.to_string()}: too \{few_or_many} values to unpack (expected \{elems.length()}, got \{items.length()})",
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
    _ =>
      raise EvalErr(
        make_eval_error(ctx, "\{pos.to_string()}: invalid assignment target"),
      )
  }
}

///|
fn exec_load(
  ctx : EvalContext,
  _env : EvalEnv,
  _path : String,
  _bindings : Array[(String, String)],
  pos : @errors.Position,
) -> Signal raise EvalErr {
  raise EvalErr(
    make_eval_error(ctx, "\{pos.to_string()}: load is not supported"),
  )
}
