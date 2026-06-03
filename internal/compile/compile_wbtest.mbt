// Whitebox tests for internal compiler invariants. These guards fire only on
// compiler-emitter bugs and are unreachable through the public `compile` API,
// so they are exercised directly against the internal helpers.

///|
test "panic write_uvarint rejects a negative operand" {
  let code : Array[Byte] = []
  write_uvarint(code, -1)
}

///|
fn empty_pcomp() -> Pcomp {
  {
    constants: [],
    names: [],
    name_index: {},
    functions: [],
    globals: [],
    global_index: {},
    loads: [],
    load_stmts: [],
    is_predeclared: fn(_) { false },
    is_universal: fn(_) { false },
  }
}

///|
test "panic operand-stack underflow aborts" {
  let fc = Fcomp::new(empty_pcomp(), "<test>", @errors.Position::new("t", 1, 1))
  fc.stack(1, 0)
}

///|
fn fresh_fcomp() -> Fcomp {
  Fcomp::new(empty_pcomp(), "<test>", @errors.Position::new("t.star", 1, 1))
}

///|
test "an unsupported statement reports its position in the error" {
  let fc = fresh_fcomp()
  // Augmented assignment is not yet lowered.
  let stmt = @syntax.Stmt::SAugAssign(
    @syntax.Expr::EIdent("x", @errors.Position::new("t.star", 7, 1)),
    AugAdd,
    @syntax.Expr::ELiteral(
      @syntax.LiteralVal::LitInt(BigInt::from_int(1)),
      @errors.Position::new("t.star", 7, 6),
    ),
    @errors.Position::new("t.star", 7, 2),
  )
  let r = try? fc.compile_stmt(stmt)
  match r {
    Err(CompileErr(msg)) => assert_true(msg.contains("t.star:7:2"))
    _ => abort("expected a CompileErr")
  }
}

///|
test "an unsupported assignment target reports the target position" {
  let fc = fresh_fcomp()
  let target = @syntax.Expr::EIndex(
    @syntax.Expr::EIdent("xs", @errors.Position::new("t.star", 4, 1)),
    @syntax.Expr::ELiteral(
      @syntax.LiteralVal::LitInt(BigInt::from_int(0)),
      @errors.Position::new("t.star", 4, 4),
    ),
    @errors.Position::new("t.star", 4, 1),
  )
  let rhs = @syntax.Expr::ELiteral(
    @syntax.LiteralVal::LitInt(BigInt::from_int(1)),
    @errors.Position::new("t.star", 4, 8),
  )
  let stmt = @syntax.Stmt::SAssign(
    target,
    rhs,
    @errors.Position::new("t.star", 4, 1),
  )
  let r = try? fc.compile_stmt(stmt)
  match r {
    Err(CompileErr(msg)) => assert_true(msg.contains("t.star:4:1"))
    _ => abort("expected a CompileErr")
  }
}
