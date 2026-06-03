# `syntax` package

The AST node types returned by `@eval.parse_file` / `@eval.parse_expr` and consumed by
`@eval.file_program` / `@eval.eval_parsed_expr`. All node enums are `pub(all)`, so they can be
constructed and pattern-matched directly.

## Functions

| Function | Signature | Description |
| :--- | :--- | :--- |
| `walk_file` | `(File, (Node?) -> Bool) -> Unit` | Depth-first traversal of a file; visitor returns `false` to stop descending |
| `walk_stmt` | `(Stmt, (Node?) -> Bool) -> Unit` | Depth-first traversal of a statement |
| `walk_expr` | `(Expr, (Node?) -> Bool) -> Unit` | Depth-first traversal of an expression |
| `stmt_pos` | `(Stmt) -> @errors.Position` | Source position of a statement node |
| `expr_pos` | `(Expr) -> @errors.Position` | Source position of an expression node |

## `File`

```moonbit nocheck
pub struct File { /* private fields */ }  // in "connect0459/starlark/syntax"
```

| Method | Signature | Description |
| :--- | :--- | :--- |
| `File::new(String, Array[Stmt])` | `-> File` | Construct from a path and statements |
| `path()` | `-> String` | Source path |
| `stmts()` | `-> Array[Stmt]` | Top-level statements |

## AST node enums

Every node carries a trailing `@errors.Position`.

```moonbit nocheck
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
