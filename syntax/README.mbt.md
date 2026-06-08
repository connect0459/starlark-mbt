# `syntax` package

AST node types for the Starlark language. Import `connect0459/starlark/syntax` to work
with parsed source trees: inspect nodes, walk the tree, or build ASTs for testing.

Obtain a `File` by calling `@eval.parse_file`; use the node types and walker functions
to analyse or transform it.

## Key types and functions

| Symbol | Description |
| :--- | :--- |
| `File` | Top-level parsed file (path + statement list) |
| `Expr` | Expression node (24 variants) |
| `Stmt` | Statement node (12 variants) |
| `Param` / `Arg` / `CompClause` | Parameter, call argument, comprehension clause |
| `LiteralVal` / `BinaryOp` / `UnaryOp` / `AugOp` | Leaf enums |
| `Node` | Visitor wrapper covering all node kinds |
| `walk_file` / `walk_stmt` / `walk_expr` | Depth-first tree traversal |
| `stmt_pos` / `expr_pos` | Source position of any node |

## Quick start

Building a `File` directly for tests (bypassing the parser):

```mbt check
///|
test {
  let pos = @errors.Position::new("<test>", 1, 1)
  let stmt = @syntax.Stmt::SPass(pos)
  let file = @syntax.File::new("<test>", [stmt])
  assert_eq(file.path(), "<test>")
  assert_eq(file.stmts().length(), 1)
}
```

Collecting identifiers from an expression node:

```mbt check
///|
test {
  let pos = @errors.Position::new("<e>", 1, 1)
  let lhs = @syntax.Expr::EIdent("x", pos)
  let rhs = @syntax.Expr::EIdent("y", pos)
  let expr = @syntax.Expr::EBinary(lhs, @syntax.BinaryOp::OpAdd, rhs, pos)
  let names : Array[String] = []
  @syntax.walk_expr(expr, fn(node) {
    match node {
      Some(@syntax.Node::NExpr(@syntax.Expr::EIdent(name, _))) =>
        names.push(name)
      _ => ()
    }
    true
  })
  assert_true(names == ["x", "y"])
}
```

Parsing from source requires `@eval.parse_file` / `@eval.parse_expr`.

## API reference

### Functions

| Function | Signature | Description |
| :--- | :--- | :--- |
| `walk_file` | `(File, (Node?) -> Bool) -> Unit` | Depth-first traversal of a file; visitor called with `Some(node)` on entry and `None` on exit after each parent's last child; return `false` to stop descending |
| `walk_stmt` | `(Stmt, (Node?) -> Bool) -> Unit` | Depth-first traversal of a statement; same `Some`/`None` entry/exit contract as `walk_file` |
| `walk_expr` | `(Expr, (Node?) -> Bool) -> Unit` | Depth-first traversal of an expression; same `Some`/`None` entry/exit contract as `walk_file` |
| `stmt_pos` | `(Stmt) -> @errors.Position` | Source position of a statement node |
| `expr_pos` | `(Expr) -> @errors.Position` | Source position of an expression node |

### `File`

| Method | Signature | Description |
| :--- | :--- | :--- |
| `File::new(String, Array[Stmt])` | `-> File` | Construct from a path and statements |
| `path()` | `-> String` | Source path |
| `stmts()` | `-> Array[Stmt]` | Top-level statements |

### AST node enums

Every node carries a trailing `@errors.Position`.

```mbt nocheck
///|
pub(all) enum Expr {
  EIdent(String, Position)
  ELiteral(LiteralVal, Position)
  EUnary(UnaryOp, Expr, Position)
  EBinary(Expr, BinaryOp, Expr, Position)
  ECond(Expr, Expr, Expr, Position) // x if cond else y
  EIndex(Expr, Expr, Position) // a[i]
  ESlice(Expr, Expr?, Expr?, Expr?, Position) // a[start:end:step]
  EDot(Expr, String, Position) // x.attr
  ECall(Expr, Array[Arg], Position) // f(args…)
  EList(Array[Expr], Position)
  ETuple(Array[Expr], Position)
  EDict(Array[(Expr, Expr)], Position)
  ESet(Array[Expr], Position)
  ELambda(Array[Param], Expr, Position)
  EListComp(Expr, Array[CompClause], Position)
  ESetComp(Expr, Array[CompClause], Position)
  EDictComp(Expr, Expr, Array[CompClause], Position)
}

///|
pub(all) enum Stmt {
  SExpr(Expr)
  SAssign(Expr, Expr, Position)
  SAugAssign(Expr, AugOp, Expr, Position)
  SIf(Expr, Array[Stmt], Array[Stmt], Position)
  SFor(Expr, Expr, Array[Stmt], Position)
  SWhile(Expr, Array[Stmt], Position)
  SDef(String, Array[Param], Array[Stmt], Position)
  SReturn(Expr?, Position)
  SBreak(Position)
  SContinue(Position)
  SPass(Position)
  SLoad(String, Array[(String, String, Position)], Position)
}

///|
pub(all) enum Param {
  ParamIdent(String, Position) // x
  ParamDefault(String, Expr, Position) // x=expr
  ParamStarBare(Position) // *
  ParamStarIdent(String, Position) // *args
  ParamKwIdent(String, Position) // **kwargs
}

///|
pub(all) enum Arg {
  ArgPos(Expr) // positional
  ArgKw(String, Expr, Position) // name=expr
  ArgStarArgs(Expr) // *args
  ArgKwArgs(Expr) // **kwargs
}

///|
pub(all) enum CompClause {
  ClauseFor(Expr, Expr, Position) // for target in iterable
  ClauseIf(Expr, Position) // if guard
}

///|
pub(all) enum LiteralVal {
  LitNone
  LitBool(Bool)
  LitInt(BigInt)
  LitFloat(Double)
  LitString(String)
  LitBytes(Bytes)
}

///|
pub(all) enum BinaryOp {
  OpAdd
  OpSub
  OpMul
  OpDiv
  OpFloorDiv
  OpMod
  OpBitAnd
  OpBitOr
  OpBitXor
  OpLShift
  OpRShift
  OpEq
  OpNe
  OpLt
  OpLe
  OpGt
  OpGe
  OpIn
  OpNotIn
  OpAnd
  OpOr
}

///|
pub(all) enum UnaryOp {
  OpPlus
  OpMinus
  OpBitNot
  OpNot
}

///|
pub(all) enum AugOp {
  AugAdd
  AugSub
  AugMul
  AugDiv
  AugFloorDiv
  AugMod
  AugBitAnd
  AugBitOr
  AugBitXor
  AugLShift
  AugRShift
}

// Visitor wrapper passed to walk_*; one variant per node kind.

///|
pub(all) enum Node {
  NFile(File)
  NStmt(Stmt)
  NExpr(Expr)
  NParam(Param)
  NArg(Arg)
  NCompClause(CompClause)
}
```

### `walk_file` example

```mbt check
///|
test {
  let pos = @errors.Position::new("<walk>", 1, 1)
  let lhs = @syntax.Expr::EIdent("x", pos)
  let rhs = @syntax.Expr::EIdent("y", pos)
  let expr = @syntax.Expr::EBinary(lhs, @syntax.BinaryOp::OpAdd, rhs, pos)
  let stmt = @syntax.Stmt::SExpr(expr)
  let file = @syntax.File::new("<walk>", [stmt])
  let idents : Array[String] = []
  @syntax.walk_file(file, fn(node) {
    match node {
      Some(@syntax.Node::NExpr(@syntax.Expr::EIdent(name, _))) =>
        idents.push(name)
      _ => ()
    }
    true
  })
  assert_true(idents.contains("x"))
  assert_true(idents.contains("y"))
}
```

### `expr_pos` example

```mbt check
///|
test {
  let pos = @errors.Position::new("<expr>", 3, 5)
  let expr = @syntax.Expr::EIdent("a", pos)
  let got = @syntax.expr_pos(expr)
  assert_eq(got.filename(), "<expr>")
  assert_eq(got.line(), 3)
}
```
