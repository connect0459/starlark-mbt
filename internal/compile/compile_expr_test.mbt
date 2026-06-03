// Unit tests for the bytecode compiler, exercised by disassembling the emitted
// code (no VM yet). AST nodes are built by hand since the compile package does
// not depend on the parser.

///|
fn p(line : Int, col : Int) -> @errors.Position {
  @errors.Position::new("t.star", line, col)
}

///|
fn lit_int(n : Int) -> @syntax.Expr {
  @syntax.Expr::ELiteral(
    @syntax.LiteralVal::LitInt(BigInt::from_int(n)),
    p(1, 1),
  )
}

///|
/// Compiles a file built from the given statements with no predeclared names and
/// the standard universal set, returning the toplevel Funcode. Aborts if the
/// compiler rejects the program (tests only build supported programs).
fn compile_top(
  stmts : Array[@syntax.Stmt],
  is_pred? : (String) -> Bool = fn(_) { false },
) -> @compile.Funcode {
  let file = @syntax.File::new("t.star", stmts)
  let prog = @compile.compile(
    file,
    is_pred,
    fn(n) { n == "None" || n == "True" || n == "False" },
    true,
  ) catch {
    _ => abort("compile failed")
  }
  prog.toplevel
}

///|
fn ops_of(fc : @compile.Funcode) -> Array[@compile.Opcode] {
  fc.disasm().map(fn(ins) { ins.op })
}

///|
/// Asserts the opcode sequence of a funcode matches `expected` exactly.
fn assert_ops(
  fc : @compile.Funcode,
  expected : Array[@compile.Opcode],
) -> Unit raise {
  let got = ops_of(fc)
  assert_eq(got.length(), expected.length())
  for i, op in expected {
    assert_true(got[i] == op)
  }
}

///|
test "assignment of an arithmetic expression emits constants, op, and store" {
  // x = 1 + 2
  let assign = @syntax.Stmt::SAssign(
    @syntax.Expr::EIdent("x", p(1, 1)),
    @syntax.Expr::EBinary(lit_int(1), OpAdd, lit_int(2), p(1, 5)),
    p(1, 3),
  )
  let fc = compile_top([assign])
  assert_ops(fc, [Constant, Constant, Plus, SetGlobal, NoneOp, Return])
  let instrs = fc.disasm()
  // global x is slot 0; the two constants are 1 and 2 at indices 0 and 1
  assert_eq(instrs[0].arg, 0)
  assert_eq(instrs[1].arg, 1)
  assert_eq(instrs[3].arg, 0)
}

///|
test "identical integer literals are deduplicated in the constant pool" {
  // x = 1 + 1  -> single constant entry, referenced twice
  let assign = @syntax.Stmt::SAssign(
    @syntax.Expr::EIdent("x", p(1, 1)),
    @syntax.Expr::EBinary(lit_int(1), OpAdd, lit_int(1), p(1, 5)),
    p(1, 3),
  )
  let instrs = compile_top([assign]).disasm()
  assert_eq(instrs[0].arg, 0)
  assert_eq(instrs[1].arg, 0)
}

///|
test "bare predeclared names use the Predeclared opcode" {
  // a = len      (len predeclared)
  let stmts : Array[@syntax.Stmt] = [
    @syntax.Stmt::SAssign(
      @syntax.Expr::EIdent("a", p(1, 1)),
      @syntax.Expr::EIdent("len", p(1, 5)),
      p(1, 3),
    ),
  ]
  let fc = compile_top(stmts, is_pred=fn(n) { n == "len" })
  let ops = ops_of(fc)
  assert_true(ops[0] == Predeclared)
  assert_true(ops[1] == SetGlobal)
}

///|
test "comparison, membership, and not-in lower to the right opcodes" {
  // x = 1 < 2
  let lt = @syntax.Stmt::SAssign(
    @syntax.Expr::EIdent("x", p(1, 1)),
    @syntax.Expr::EBinary(lit_int(1), OpLt, lit_int(2), p(1, 5)),
    p(1, 3),
  )
  assert_true(ops_of(compile_top([lt]))[2] == Lt)

  // y = 1 not in [2]  -> In then Not
  let notin = @syntax.Stmt::SAssign(
    @syntax.Expr::EIdent("y", p(2, 1)),
    @syntax.Expr::EBinary(
      lit_int(1),
      OpNotIn,
      @syntax.Expr::EList([lit_int(2)], p(2, 10)),
      p(2, 6),
    ),
    p(2, 3),
  )
  let ops = ops_of(compile_top([notin]))
  assert_true(ops.contains(In))
  assert_true(ops.contains(Not))
  assert_true(ops.contains(MakeList))
}

///|
test "index, slice, and attribute access lower to Index, Slice, and Attr" {
  let base = @syntax.Expr::EIdent("xs", p(1, 5))
  // xs[0]
  let idx = @syntax.Stmt::SExpr(@syntax.Expr::EIndex(base, lit_int(0), p(1, 7)))
  assert_true(
    ops_of(compile_top([idx], is_pred=fn(n) { n == "xs" })).contains(Index),
  )
  // xs[1:2] (no step) -> pushes base, lo, hi, None-step, Slice
  let sl = @syntax.Stmt::SExpr(
    @syntax.Expr::ESlice(
      base,
      Some(lit_int(1)),
      Some(lit_int(2)),
      None,
      p(1, 7),
    ),
  )
  let slops = ops_of(compile_top([sl], is_pred=fn(n) { n == "xs" }))
  assert_true(slops.contains(Slice))
  assert_true(slops.contains(NoneOp)) // missing step pushed as None
  // xs.field
  let dot = @syntax.Stmt::SExpr(@syntax.Expr::EDot(base, "field", p(1, 7)))
  assert_true(
    ops_of(compile_top([dot], is_pred=fn(n) { n == "xs" })).contains(Attr),
  )
}

///|
test "toplevel always ends with NONE and RETURN" {
  let fc = compile_top([@syntax.Stmt::SPass(p(1, 1))])
  assert_ops(fc, [NoneOp, Return])
}

///|
/// `num_params` counts every named parameter that occupies a local slot,
/// including `*args` and `**kwargs`, so it stays consistent with the `locals`
/// ordering and the runtime function's `num_params` contract.
test "num_params counts varargs and kwargs parameters" {
  // def f(a, b=1, *args, **kw): pass
  let def_ = @syntax.Stmt::SDef(
    "f",
    [
      @syntax.Param::ParamIdent("a", p(1, 1)),
      @syntax.Param::ParamDefault("b", lit_int(1), p(1, 1)),
      @syntax.Param::ParamStarIdent("args", p(1, 1)),
      @syntax.Param::ParamKwIdent("kw", p(1, 1)),
    ],
    [@syntax.Stmt::SPass(p(2, 3))],
    p(1, 1),
  )
  let file = @syntax.File::new("t.star", [def_])
  let prog = @compile.compile(
    file,
    fn(_) { false },
    fn(n) { n == "None" || n == "True" || n == "False" },
    true,
  ) catch {
    _ => abort("compile failed")
  }
  assert_eq(prog.functions[0].num_params, 4)
}

///|
test "line table maps a statement's instructions back to its source line" {
  // x = 42 placed on line 7
  let assign = @syntax.Stmt::SAssign(
    @syntax.Expr::EIdent("x", p(7, 1)),
    @syntax.Expr::ELiteral(@syntax.LiteralVal::LitInt(42N), p(7, 5)),
    p(7, 3),
  )
  let fc = compile_top([assign])
  // the first instruction (CONSTANT) was emitted with the literal's position
  assert_eq(fc.position(0).line(), 7)
  assert_eq(fc.position(0).col(), 5)
}

///|
test "unsupported constructs surface as a CompileErr that pinpoints the source position" {
  // Augmented assignment is not yet lowered; the error must locate it.
  let aug = @syntax.Stmt::SAugAssign(
    @syntax.Expr::EIdent("x", p(1, 1)),
    AugAdd,
    lit_int(1),
    p(1, 1),
  )
  let file = @syntax.File::new("t.star", [aug])
  let r = try? @compile.compile(file, fn(_) { false }, fn(_) { false }, true)
  match r {
    Err(CompileErr(msg)) => assert_true(msg.contains("t.star:1:1"))
    _ => abort("expected a CompileErr")
  }
}

///|
test "an unsupported expression reports its own position in the error" {
  // A dict literal is not yet lowered; the error must locate it.
  let dict = @syntax.Expr::EDict([], p(3, 9))
  let file = @syntax.File::new("t.star", [@syntax.Stmt::SExpr(dict)])
  let r = try? @compile.compile(file, fn(_) { false }, fn(_) { false }, true)
  match r {
    Err(CompileErr(msg)) => assert_true(msg.contains("t.star:3:9"))
    _ => abort("expected a CompileErr")
  }
}

///|
test "an unsupported for-loop target reports its own position, not the enclosing statement" {
  // A tuple-destructuring `for` target is not yet lowered; the error must
  // pinpoint the target expression rather than fall back to the statement.
  let target = @syntax.Expr::ETuple(
    [@syntax.Expr::EIdent("k", p(1, 5)), @syntax.Expr::EIdent("v", p(1, 8))],
    p(1, 5),
  )
  let for_stmt = @syntax.Stmt::SFor(
    target,
    @syntax.Expr::EList([], p(1, 14)),
    [@syntax.Stmt::SPass(p(2, 3))],
    p(1, 1),
  )
  let file = @syntax.File::new("t.star", [for_stmt])
  let r = try? @compile.compile(file, fn(_) { false }, fn(_) { false }, true)
  match r {
    Err(CompileErr(msg)) => {
      assert_true(msg.contains("for-loop target"))
      assert_true(msg.contains("t.star:1:5"))
    }
    _ => abort("expected a CompileErr")
  }
}
