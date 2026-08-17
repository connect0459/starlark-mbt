# `syntax` package

AST node types for the Starlark language. Import `connect0459/starlark/syntax` to work with parsed source trees: inspect nodes, walk the tree, or build ASTs for testing.

Obtain a `File` by calling `@eval.parse_file`; use the node types and walker functions to analyse or transform it.

## Key types and functions

| Symbol | Description |
| :--- | :--- |
| `File` | Top-level parsed file (path + statement list) |
| `Expr` | Expression node (17 variants) |
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

## Error-position anchoring policy

When the compiler or resolver emits a diagnostic for an AST node it must choose one token as the *anchor position* — the source location shown to the user. The rules below are applied across the compilation pipeline (`syntax`, `internal/parser`, `internal/resolver`, `internal/compile`, `eval`) and mirror the behaviour of the starlark-go reference implementation.

| Error class | Anchor token | How to obtain it |
| :--- | :--- | :--- |
| Assignment target is not assignable (e.g. `f() = 2`, `(a or b) = 1`) | Leftmost token of the LHS expression | `syntax.start(lhs)` |
| Augmented-assignment target is not assignable | Leftmost token of the LHS expression | `syntax.start(lhs)` |
| Dict key errors in literals and comprehensions (unhashable key, duplicate key) | Colon token separating the key from its value | `colon_pos` from `EDict`/`EDictComp`; see note below |
| `def`/`lambda` parameter is not an identifier | Scanner cursor (one position past the bad token) | `Parser::scanner_error` → `scanner.position()` |
| Positional argument appears after `*args`, `**kwargs`, or a keyword argument | Leftmost token of the misplaced argument expression | `syntax.start(arg_expr)` |

### Position accessors

Four mechanisms cover all anchoring sites above:

- **`syntax.start(e)`** — walks into `EBinary`, `ECall`, `ESlice`, `EIndex`,
  and `EDot` sub-expressions to reach the leftmost token of a compound
  expression. Use this whenever the error should point at the *beginning* of a
  possibly-compound expression (LHS of assignments, misplaced arguments).
- **`expr_pos(e)`** — returns the position stored in the node's own slot
  (operator, opening bracket, or other delimiter). Use this when the error is
  about the operator or delimiter itself rather than an operand.
- **`Parser::scanner_error(msg)`** — uses `scanner.position()`, which is one
  past the current token. Use this for unexpected-token parse errors that must
  match starlark-go's scanner cursor convention.
- **`set_pos(colon)` in `internal/compile`** — dict-literal and
  dict-comprehension key errors use a different mechanism: the compiler calls
  `set_pos(colon_pos)` before emitting the dict-insertion opcode
  (`SetDictUniq` / `SetDict`), recording the colon as the error anchor. The
  error itself is raised at runtime by the `eval` package using that recorded
  position. Both `EDict` pairs and `EDictComp` store a `colon_pos`; compile
  uses it in both code paths.

### Adding a new anchoring site

1. Identify which rule class the new error falls into (table above).
2. Choose the matching mechanism (`syntax.start`, `expr_pos`,
   `scanner_error`, or `set_pos` in compile).
3. Add a conformance test that checks the reported column against the expected
   source position so regressions are caught automatically.

## API reference

### Functions

| Function | Signature | Description |
| :--- | :--- | :--- |
| `walk_file` | `(File, (Node?) -> Bool) -> Unit` | Depth-first traversal of a file; visitor called with `Some(node)` on entry and `None` on exit after each parent's last child; return `false` to stop descending |
| `walk_stmt` | `(Stmt, (Node?) -> Bool) -> Unit` | Depth-first traversal of a statement; same `Some`/`None` entry/exit contract as `walk_file` |
| `walk_expr` | `(Expr, (Node?) -> Bool) -> Unit` | Depth-first traversal of an expression; same `Some`/`None` entry/exit contract as `walk_file` |
| `stmt_pos` | `(Stmt) -> @errors.Position` | Source position of a statement node |
| `expr_pos` | `(Expr) -> @errors.Position` | Source position of an expression node (node's own slot: operator, bracket, etc.) |
| `start` | `(Expr) -> @errors.Position` | Position of the leftmost token in an expression (walks into sub-expressions for compound LHS nodes) |

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
  EIdent(String, @errors.Position)
  ELiteral(LiteralVal, @errors.Position)
  EUnary(UnaryOp, Expr, @errors.Position)
  EBinary(Expr, BinaryOp, Expr, @errors.Position)
  ECond(Expr, Expr, Expr, @errors.Position) // cond, then, else (surface: then if cond else else)
  EIndex(Expr, Expr, @errors.Position) // a[i]
  ESlice(Expr, Expr?, Expr?, Expr?, @errors.Position) // a[start:end:step]
  EDot(Expr, String, @errors.Position) // x.attr
  ECall(Expr, Array[Arg], @errors.Position) // f(args…)
  EList(Array[Expr], @errors.Position)
  ETuple(Array[Expr], @errors.Position)
  EDict(Array[(Expr, Expr, @errors.Position)], @errors.Position) // (key, val, colon_pos)
  ESet(Array[Expr], @errors.Position)
  ELambda(Array[Param], Expr, @errors.Position)
  EListComp(Expr, Array[CompClause], @errors.Position)
  ESetComp(Expr, Array[CompClause], @errors.Position)
  EDictComp(Expr, Expr, Array[CompClause], @errors.Position, @errors.Position) // (key, val, clauses, colon_pos, brace_pos)
}

///|
pub(all) enum Stmt {
  SExpr(Expr)
  SAssign(Expr, Expr, @errors.Position)
  SAugAssign(Expr, AugOp, Expr, @errors.Position)
  SIf(Expr, Array[Stmt], Array[Stmt], @errors.Position)
  SFor(Expr, Expr, Array[Stmt], @errors.Position)
  SWhile(Expr, Array[Stmt], @errors.Position)
  SDef(String, Array[Param], Array[Stmt], @errors.Position)
  SReturn(Expr?, @errors.Position)
  SBreak(@errors.Position)
  SContinue(@errors.Position)
  SPass(@errors.Position)
  SLoad(String, Array[(String, String, @errors.Position)], @errors.Position)
}

///|
pub(all) enum Param {
  ParamIdent(String, @errors.Position) // x
  ParamDefault(String, Expr, @errors.Position) // x=expr
  ParamStarBare(@errors.Position) // *
  ParamStarIdent(String, @errors.Position) // *args
  ParamKwIdent(String, @errors.Position) // **kwargs
}

///|
pub(all) enum Arg {
  ArgPos(Expr) // positional
  ArgKw(String, Expr, @errors.Position) // name=expr
  ArgStarArgs(Expr) // *args
  ArgKwArgs(Expr) // **kwargs
}

///|
pub(all) enum CompClause {
  ClauseFor(Expr, Expr, @errors.Position) // for target in iterable
  ClauseIf(Expr, @errors.Position) // if guard
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
