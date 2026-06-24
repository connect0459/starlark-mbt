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
test "a dict literal builds a dict and sets each unique entry" {
  // d = {1: 2}
  let dict = @syntax.Expr::EDict([(lit_int(1), lit_int(2))], p(1, 5))
  let fc = compile_top([
    @syntax.Stmt::SAssign(@syntax.Expr::EIdent("d", p(1, 1)), dict, p(1, 3)),
  ])
  let ops = ops_of(fc)
  assert_true(ops.contains(MakeDict))
  assert_true(ops.contains(SetDictUniq))
}

///|
test "a set literal builds a set and adds each element" {
  // s = {1, 2}
  let set = @syntax.Expr::ESet([lit_int(1), lit_int(2)], p(1, 5))
  let fc = compile_top([
    @syntax.Stmt::SAssign(@syntax.Expr::EIdent("s", p(1, 1)), set, p(1, 3)),
  ])
  let ops = ops_of(fc)
  assert_true(ops.contains(MakeSet))
  assert_eq(ops.filter(fn(o) { o == SetAdd }).length(), 2)
}

///|
/// `num_params` counts every named parameter that occupies a local slot,
/// including `*args` and `**kwargs`, so it stays consistent with the `locals`
/// ordering and the runtime function's `num_params` contract.
test "num_params counts varargs and kwargs parameters" {
  // def f(a, b=1, *args, **kw): pass
  let def_ = @syntax.Stmt::SDef(
    "f",
    p(1, 1),
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
/// The `Call` operand packs the positional count in the high bits and the
/// keyword count in the low 8 bits, so a call may carry at most 255 keyword
/// arguments. Exceeding that must surface as a CompileErr rather than silently
/// truncating the count and mis-popping the stack.
test "call rejects more than 255 keyword arguments" {
  let args : Array[@syntax.Arg] = []
  for i in 0..<256 {
    args.push(@syntax.Arg::ArgKw("k\{i}", lit_int(i), p(1, 1)))
  }
  let call = @syntax.Stmt::SExpr(
    @syntax.Expr::ECall(@syntax.Expr::EIdent("f", p(1, 1)), args, p(1, 1)),
  )
  let file = @syntax.File::new("t.star", [call])
  try @compile.compile(file, fn(n) { n == "f" }, fn(_) { false }, true) catch {
    CompileErr(msg) => assert_true(msg.contains("limit is 255"))
  } noraise {
    _ => abort("expected a CompileErr")
  }
}

///|
/// The positional count shares the same 8-bit-per-field encoding, so a call may
/// carry at most 255 positional arguments before the count must be rejected.
test "call rejects more than 255 positional arguments" {
  let args : Array[@syntax.Arg] = []
  for i in 0..<256 {
    args.push(@syntax.Arg::ArgPos(lit_int(i)))
  }
  let call = @syntax.Stmt::SExpr(
    @syntax.Expr::ECall(@syntax.Expr::EIdent("f", p(1, 1)), args, p(1, 1)),
  )
  let file = @syntax.File::new("t.star", [call])
  try @compile.compile(file, fn(n) { n == "f" }, fn(_) { false }, true) catch {
    CompileErr(msg) => assert_true(msg.contains("limit is 255"))
  } noraise {
    _ => abort("expected a CompileErr")
  }
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
test "augmented assignment stamps the target load with the target's own position" {
  // y = 1   (line 1)
  // x += 1  (line 2)
  // The load of `x` must carry x's own position, not the previous statement's,
  // so a referenced-before-assignment error is attributed to the right line.
  let stmts : Array[@syntax.Stmt] = [
    @syntax.Stmt::SAssign(
      @syntax.Expr::EIdent("y", p(1, 1)),
      @syntax.Expr::ELiteral(@syntax.LiteralVal::LitInt(1N), p(1, 5)),
      p(1, 3),
    ),
    @syntax.Stmt::SAugAssign(
      @syntax.Expr::EIdent("x", p(2, 1)),
      AugAdd,
      @syntax.Expr::ELiteral(@syntax.LiteralVal::LitInt(1N), p(2, 6)),
      p(2, 3),
    ),
  ]
  let fc = compile_top(stmts)
  let mut load : @compile.Instr? = None
  for ins in fc.disasm() {
    if ins.op == Global {
      load = Some(ins)
      break
    }
  }
  match load {
    Some(ins) => {
      assert_eq(fc.position(ins.pc).line(), 2)
      assert_eq(fc.position(ins.pc).col(), 1)
    }
    None => abort("expected a Global load for the augmented-assignment target")
  }
}

///|
test "unsupported constructs surface as a CompileErr that pinpoints the source position" {
  // A literal is not a valid augmented-assignment target; the error must locate
  // the target.
  let stmt = @syntax.Stmt::SAugAssign(lit_int(0), AugAdd, lit_int(1), p(1, 3))
  let file = @syntax.File::new("t.star", [stmt])
  try @compile.compile(file, fn(_) { false }, fn(_) { false }, true) catch {
    CompileErr(msg) => assert_true(msg.contains("t.star:1:1"))
  } noraise {
    _ => abort("expected a CompileErr")
  }
}

///|
test "an invalid augmented-assignment target reports its own position in the error" {
  // A call is not a valid augmented-assignment target; the error must locate the
  // target expression rather than fall back to the statement.
  let lhs = @syntax.Expr::ECall(@syntax.Expr::EIdent("f", p(3, 9)), [], p(3, 9))
  let stmt = @syntax.Stmt::SAugAssign(lhs, AugAdd, lit_int(1), p(3, 1))
  let file = @syntax.File::new("t.star", [stmt])
  try @compile.compile(file, fn(_) { false }, fn(_) { false }, true) catch {
    CompileErr(msg) => assert_true(msg.contains("t.star:3:9"))
  } noraise {
    _ => abort("expected a CompileErr")
  }
}

///|
test "an invalid for-loop target reports its own position, not the enclosing statement" {
  // A literal `for` target is not assignable; the error must pinpoint the
  // target expression rather than fall back to the statement.
  let target = @syntax.Expr::ELiteral(
    @syntax.LiteralVal::LitInt(BigInt::from_int(5)),
    p(1, 5),
  )
  let for_stmt = @syntax.Stmt::SFor(
    target,
    @syntax.Expr::EList([], p(1, 14)),
    [@syntax.Stmt::SPass(p(2, 3))],
    p(1, 1),
  )
  let file = @syntax.File::new("t.star", [for_stmt])
  try @compile.compile(file, fn(_) { false }, fn(_) { false }, true) catch {
    CompileErr(msg) => {
      assert_true(msg.contains("invalid assignment target"))
      assert_true(msg.contains("t.star:1:5"))
    }
  } noraise {
    _ => abort("expected a CompileErr")
  }
}
