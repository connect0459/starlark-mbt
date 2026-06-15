///|
/// A tagged union of every AST node kind, used as the argument to the visitor
/// function passed to `walk_file`/`walk_stmt`/`walk_expr`.
pub(all) enum Node {
  NFile(File)
  NStmt(Stmt)
  NExpr(Expr)
  NParam(Param)
  NArg(Arg)
  NCompClause(CompClause)
}

///|
/// Performs a depth-first walk of a parsed Starlark file, calling `f` before
/// descending into each node. If `f` returns `false`, the subtree is skipped.
/// `f(None)` is called after the last child of every parent.
///
/// Parameters:
///
/// - `file` : The parsed file whose nodes are visited.
/// - `f` : Visitor callback; receives `Some(node)` on entry and `None` on exit
///   of each parent. Return `false` to skip a subtree.
pub fn walk_file(file : File, f : (Node?) -> Bool) -> Unit {
  if !f(Some(NFile(file))) {
    f(None) |> ignore
    return
  }
  for stmt in file.stmts {
    walk_stmt(stmt, f)
  }
  f(None) |> ignore
}

///|
/// Performs a depth-first walk of a statement and all its sub-expressions.
///
/// Parameters:
///
/// - `stmt` : The statement node to walk.
/// - `f` : Visitor callback; receives `Some(node)` on entry and `None` on exit
///   of each parent. Return `false` to skip a subtree.
pub fn walk_stmt(stmt : Stmt, f : (Node?) -> Bool) -> Unit {
  if !f(Some(NStmt(stmt))) {
    f(None) |> ignore
    return
  }
  match stmt {
    SExpr(e) => walk_expr(e, f)
    SAssign(lhs, rhs, _) => {
      walk_expr(lhs, f)
      walk_expr(rhs, f)
    }
    SAugAssign(lhs, _, rhs, _) => {
      walk_expr(lhs, f)
      walk_expr(rhs, f)
    }
    SIf(cond, then_body, else_body, _) => {
      walk_expr(cond, f)
      for s in then_body {
        walk_stmt(s, f)
      }
      for s in else_body {
        walk_stmt(s, f)
      }
    }
    SFor(target, iter, body, _) => {
      walk_expr(target, f)
      walk_expr(iter, f)
      for s in body {
        walk_stmt(s, f)
      }
    }
    SWhile(cond, body, _) => {
      walk_expr(cond, f)
      for s in body {
        walk_stmt(s, f)
      }
    }
    SDef(_, _, params, body, _) => {
      for p in params {
        walk_param(p, f)
      }
      for s in body {
        walk_stmt(s, f)
      }
    }
    SReturn(e_opt, _) =>
      match e_opt {
        Some(e) => walk_expr(e, f)
        None => ()
      }
    SBreak(_) | SContinue(_) | SPass(_) => ()
    SLoad(_, _, _) => ()
  }
  f(None) |> ignore
}

///|
/// Performs a depth-first walk of an expression and all its sub-expressions.
///
/// Parameters:
///
/// - `expr` : The expression node to walk.
/// - `f` : Visitor callback; receives `Some(node)` on entry and `None` on exit
///   of each parent. Return `false` to skip a subtree.
pub fn walk_expr(expr : Expr, f : (Node?) -> Bool) -> Unit {
  if !f(Some(NExpr(expr))) {
    f(None) |> ignore
    return
  }
  match expr {
    EIdent(_, _) | ELiteral(_, _) => ()
    EUnary(_, e, _) => walk_expr(e, f)
    EBinary(lhs, _, rhs, _) => {
      walk_expr(lhs, f)
      walk_expr(rhs, f)
    }
    ECond(cond, t, e, _) => {
      walk_expr(cond, f)
      walk_expr(t, f)
      walk_expr(e, f)
    }
    EIndex(obj, idx, _) => {
      walk_expr(obj, f)
      walk_expr(idx, f)
    }
    ESlice(obj, lo, hi, step, _) => {
      walk_expr(obj, f)
      match lo {
        Some(e) => walk_expr(e, f)
        None => ()
      }
      match hi {
        Some(e) => walk_expr(e, f)
        None => ()
      }
      match step {
        Some(e) => walk_expr(e, f)
        None => ()
      }
    }
    EDot(obj, _, _) => walk_expr(obj, f)
    ECall(func, args, _) => {
      walk_expr(func, f)
      for arg in args {
        walk_arg(arg, f)
      }
    }
    EList(elems, _) | ETuple(elems, _) | ESet(elems, _) =>
      for e in elems {
        walk_expr(e, f)
      }
    EDict(pairs, _) =>
      for pair in pairs {
        walk_expr(pair.0, f)
        walk_expr(pair.1, f)
      }
    ELambda(params, body, _) => {
      for p in params {
        walk_param(p, f)
      }
      walk_expr(body, f)
    }
    EListComp(body, clauses, _) | ESetComp(body, clauses, _) => {
      walk_expr(body, f)
      for c in clauses {
        walk_comp_clause(c, f)
      }
    }
    EDictComp(key, val, clauses, _) => {
      walk_expr(key, f)
      walk_expr(val, f)
      for c in clauses {
        walk_comp_clause(c, f)
      }
    }
  }
  f(None) |> ignore
}

///|
fn walk_param(param : Param, f : (Node?) -> Bool) -> Unit {
  if !f(Some(NParam(param))) {
    f(None) |> ignore
    return
  }
  match param {
    ParamDefault(_, default_expr, _) => walk_expr(default_expr, f)
    ParamIdent(_, _)
    | ParamStarBare(_)
    | ParamStarIdent(_, _)
    | ParamKwIdent(_, _) => ()
  }
  f(None) |> ignore
}

///|
fn walk_arg(arg : Arg, f : (Node?) -> Bool) -> Unit {
  if !f(Some(NArg(arg))) {
    f(None) |> ignore
    return
  }
  match arg {
    ArgPos(e) | ArgStarArgs(_, e) | ArgKwArgs(_, e) => walk_expr(e, f)
    ArgKw(_, e, _) => walk_expr(e, f)
  }
  f(None) |> ignore
}

///|
fn walk_comp_clause(clause : CompClause, f : (Node?) -> Bool) -> Unit {
  if !f(Some(NCompClause(clause))) {
    f(None) |> ignore
    return
  }
  match clause {
    ClauseFor(target, iter, _) => {
      walk_expr(target, f)
      walk_expr(iter, f)
    }
    ClauseIf(cond, _) => walk_expr(cond, f)
  }
  f(None) |> ignore
}
