// Coverage tests for AST construction, position helpers, and the walker.
// These document the AST traversal contract independent of the parser.

///|
fn p() -> @errors.Position {
  @errors.Position::new("t.star", 1, 1)
}

///|
fn ident(name : String) -> Expr {
  EIdent(name, p())
}

// Collect every identifier name reached by the walker, in visit order.

///|
fn collect_idents(file : File) -> Array[String] {
  let names = []
  walk_file(file, fn(node) {
    match node {
      Some(NExpr(EIdent(name, _))) => names.push(name)
      _ => ()
    }
    true
  })
  names
}

///|
test "File accessors expose path and statements" {
  let stmts = [SPass(p())]
  let file = File::new("module.star", stmts)
  assert_eq(file.path(), "module.star")
  assert_eq(file.stmts().length(), 1)
}

///|
test "walk visits every expression node in a deeply nested tree" {
  // An expression that exercises most Expr variants in one tree.
  let expr = EBinary(
    EUnary(OpNot, ident("a"), p()),
    OpAdd,
    ECond(
      ident("c"),
      EIndex(ident("d"), ident("e"), p()),
      ESlice(
        ident("f"),
        Some(ident("g")),
        Some(ident("h")),
        Some(ident("i")),
        p(),
      ),
      p(),
    ),
    p(),
  )
  let file = File::new("t.star", [SExpr(expr)])
  let names = collect_idents(file)
  assert_eq(names.join(","), "a,c,d,e,f,g,h,i")
}

///|
test "walk visits collection literals, calls, and attribute access" {
  let call = ECall(
    EDot(ident("obj"), "method", p()),
    [
      ArgPos(ident("pos")),
      ArgKw("kw", ident("kwval"), p()),
      ArgStarArgs(ident("args")),
      ArgKwArgs(ident("kwargs")),
    ],
    p(),
  )
  let list = EList([ident("l1"), ident("l2")], p())
  let tuple = ETuple([ident("t1")], p())
  let set = ESet([ident("s1")], p())
  let dict = EDict([(ident("k"), ident("v"))], p())
  let file = File::new("t.star", [
    SExpr(call),
    SExpr(list),
    SExpr(tuple),
    SExpr(set),
    SExpr(dict),
  ])
  let names = collect_idents(file)
  assert_eq(names.join(","), "obj,pos,kwval,args,kwargs,l1,l2,t1,s1,k,v")
}

///|
test "walk visits lambda parameters and comprehension clauses" {
  let lambda = ELambda(
    [
      ParamIdent("x", p()),
      ParamDefault("y", ident("dflt"), p()),
      ParamStarBare(p()),
      ParamStarIdent("rest", p()),
      ParamKwIdent("kw", p()),
    ],
    ident("body"),
    p(),
  )
  let list_comp = EListComp(
    ident("out"),
    [ClauseFor(ident("v"), ident("seq"), p()), ClauseIf(ident("cond"), p())],
    p(),
  )
  let set_comp = ESetComp(
    ident("so"),
    [ClauseFor(ident("sv"), ident("sseq"), p())],
    p(),
  )
  let dict_comp = EDictComp(
    ident("dk"),
    ident("dv"),
    [ClauseFor(ident("dvv"), ident("dseq"), p())],
    p(),
  )
  let file = File::new("t.star", [
    SExpr(lambda),
    SExpr(list_comp),
    SExpr(set_comp),
    SExpr(dict_comp),
  ])
  let names = collect_idents(file)
  assert_eq(
    names.join(","),
    "dflt,body,out,v,seq,cond,so,sv,sseq,dk,dv,dvv,dseq",
  )
}

///|
test "walk visits every statement kind" {
  let stmts = [
    SAssign(ident("a"), ident("b"), p()),
    SAugAssign(ident("c"), AugAdd, ident("d"), p()),
    SIf(ident("cond"), [SExpr(ident("then"))], [SExpr(ident("els"))], p()),
    SFor(ident("tgt"), ident("it"), [SExpr(ident("body"))], p()),
    SWhile(ident("wc"), [SExpr(ident("wbody"))], p()),
    SDef("f", [ParamIdent("pa", p())], [SExpr(ident("fbody"))], p()),
    SReturn(Some(ident("rv")), p()),
    SReturn(None, p()),
    SBreak(p()),
    SContinue(p()),
    SPass(p()),
    SLoad("m", [("local", "remote", p())], p()),
  ]
  let file = File::new("t.star", stmts)
  let names = collect_idents(file)
  assert_eq(
    names.join(","),
    "a,b,c,d,cond,then,els,tgt,it,body,wc,wbody,fbody,rv",
  )
}

///|
test "walk stops descending when visitor returns false at file level" {
  let file = File::new("t.star", [SExpr(ident("a"))])
  let names = []
  walk_file(file, fn(node) {
    match node {
      Some(NExpr(EIdent(name, _))) => names.push(name)
      _ => ()
    }
    false
  })
  assert_eq(names.join(","), "")
}

///|
test "walk stops descending when visitor returns false at a statement" {
  let file = File::new("t.star", [SDef("f", [], [SExpr(ident("inner"))], p())])
  let names = []
  walk_file(file, fn(node) {
    match node {
      Some(NStmt(SDef(_, _, _, _))) => false
      Some(NExpr(EIdent(name, _))) => {
        names.push(name)
        true
      }
      _ => true
    }
  })
  assert_eq(names.join(","), "")
}

///|
test "walk stops descending when visitor returns false at an expression" {
  let file = File::new("t.star", [
    SExpr(EBinary(ident("a"), OpAdd, ident("b"), p())),
  ])
  let names = []
  walk_file(file, fn(node) {
    match node {
      Some(NExpr(EBinary(_, _, _, _))) => false
      Some(NExpr(EIdent(name, _))) => {
        names.push(name)
        true
      }
      _ => true
    }
  })
  assert_eq(names.join(","), "")
}

///|
test "walk stops descending when visitor returns false at a parameter" {
  let file = File::new("t.star", [
    SDef("f", [ParamDefault("y", ident("dflt"), p())], [], p()),
  ])
  let names = []
  walk_file(file, fn(node) {
    match node {
      Some(NParam(_)) => false
      Some(NExpr(EIdent(name, _))) => {
        names.push(name)
        true
      }
      _ => true
    }
  })
  assert_eq(names.join(","), "")
}

///|
test "walk stops descending when visitor returns false at an argument" {
  let file = File::new("t.star", [
    SExpr(ECall(ident("f"), [ArgPos(ident("inner"))], p())),
  ])
  let names = []
  walk_file(file, fn(node) {
    match node {
      Some(NArg(_)) => false
      Some(NExpr(EIdent(name, _))) => {
        names.push(name)
        true
      }
      _ => true
    }
  })
  // The callee ident "f" is still visited; the arg's "inner" is skipped.
  assert_eq(names.join(","), "f")
}

///|
test "walk stops descending when visitor returns false at a comprehension clause" {
  let file = File::new("t.star", [
    SExpr(EListComp(ident("out"), [ClauseIf(ident("cond"), p())], p())),
  ])
  let names = []
  walk_file(file, fn(node) {
    match node {
      Some(NCompClause(_)) => false
      Some(NExpr(EIdent(name, _))) => {
        names.push(name)
        true
      }
      _ => true
    }
  })
  assert_eq(names.join(","), "out")
}

///|
test "expr_pos returns the position of every expression variant" {
  let q = @errors.Position::new("e.star", 9, 3)
  let exprs : Array[Expr] = [
    EIdent("x", q),
    ELiteral(LitString("x"), q),
    EUnary(OpMinus, ident("a"), q),
    EBinary(ident("a"), OpAdd, ident("b"), q),
    ECond(ident("a"), ident("b"), ident("c"), q),
    EIndex(ident("a"), ident("b"), q),
    ESlice(ident("a"), None, None, None, q),
    EDot(ident("a"), "f", q),
    ECall(ident("a"), [], q),
    EList([], q),
    ETuple([], q),
    EDict([], q),
    ESet([], q),
    ELambda([], ident("a"), q),
    EListComp(ident("a"), [], q),
    ESetComp(ident("a"), [], q),
    EDictComp(ident("a"), ident("b"), [], q),
  ]
  for e in exprs {
    assert_eq(expr_pos(e).line(), 9)
    assert_eq(expr_pos(e).col(), 3)
  }
}

///|
test "stmt_pos returns the position of every statement variant" {
  let q = @errors.Position::new("s.star", 12, 4)
  let stmts : Array[Stmt] = [
    SExpr(EIdent("x", q)),
    SAssign(ident("a"), ident("b"), q),
    SAugAssign(ident("a"), AugSub, ident("b"), q),
    SIf(ident("a"), [], [], q),
    SFor(ident("a"), ident("b"), [], q),
    SWhile(ident("a"), [], q),
    SDef("f", [], [], q),
    SReturn(None, q),
    SBreak(q),
    SContinue(q),
    SPass(q),
    SLoad("m", [], q),
  ]
  for s in stmts {
    assert_eq(stmt_pos(s).line(), 12)
    assert_eq(stmt_pos(s).col(), 4)
  }
}
