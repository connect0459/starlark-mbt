// Starlark AST node types.
// All nodes carry a Position for error reporting.

///|
pub(all) enum LiteralVal {
  LitNone
  LitBool(Bool)
  LitInt(Int64)
  LitBigInt(String)
  LitFloat(Double)
  LitString(String)
  LitBytes(Bytes)
}

///|
pub(all) enum UnaryOp {
  OpPlus
  OpMinus
  OpBitNot
  OpNot
}

///|
pub(all) enum BinaryOp {
  OpAdd
  OpSub
  OpMul
  OpDiv
  OpFloorDiv
  OpMod
  OpPow
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

// Param and Expr are mutually recursive.

///|
pub(all) enum Param {
  ParamIdent(String, @errors.Position)
  ParamDefault(String, Expr, @errors.Position)
  ParamStarBare(@errors.Position)
  ParamStarIdent(String, @errors.Position)
  ParamKwIdent(String, @errors.Position)
}

///|
pub(all) enum Arg {
  ArgPos(Expr)
  ArgKw(String, Expr, @errors.Position)
  ArgStarArgs(Expr)
  ArgKwArgs(Expr)
}

///|
pub(all) enum CompClause {
  ClauseFor(Expr, Expr, @errors.Position)
  ClauseIf(Expr, @errors.Position)
}

///|
pub(all) enum Expr {
  EIdent(String, @errors.Position)
  ELiteral(LiteralVal, @errors.Position)
  EUnary(UnaryOp, Expr, @errors.Position)
  EBinary(Expr, BinaryOp, Expr, @errors.Position)
  ECond(Expr, Expr, Expr, @errors.Position)
  EIndex(Expr, Expr, @errors.Position)
  ESlice(Expr, Expr?, Expr?, Expr?, @errors.Position)
  EDot(Expr, String, @errors.Position)
  ECall(Expr, Array[Arg], @errors.Position)
  EList(Array[Expr], @errors.Position)
  ETuple(Array[Expr], @errors.Position)
  EDict(Array[(Expr, Expr)], @errors.Position)
  ESet(Array[Expr], @errors.Position)
  ELambda(Array[Param], Expr, @errors.Position)
  EListComp(Expr, Array[CompClause], @errors.Position)
  ESetComp(Expr, Array[CompClause], @errors.Position)
  EDictComp(Expr, Expr, Array[CompClause], @errors.Position)
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
  SLoad(String, Array[(String, String)], @errors.Position)
}

///|
pub struct File {
  priv path : String
  priv stmts : Array[Stmt]
}

///|
pub fn File::new(path : String, stmts : Array[Stmt]) -> File {
  { path, stmts }
}

///|
pub fn File::path(self : File) -> String {
  self.path
}

///|
pub fn File::stmts(self : File) -> Array[Stmt] {
  self.stmts
}

///|
pub fn expr_pos(e : Expr) -> @errors.Position {
  match e {
    EIdent(_, p) => p
    ELiteral(_, p) => p
    EUnary(_, _, p) => p
    EBinary(_, _, _, p) => p
    ECond(_, _, _, p) => p
    EIndex(_, _, p) => p
    ESlice(_, _, _, _, p) => p
    EDot(_, _, p) => p
    ECall(_, _, p) => p
    EList(_, p) => p
    ETuple(_, p) => p
    EDict(_, p) => p
    ESet(_, p) => p
    ELambda(_, _, p) => p
    EListComp(_, _, p) => p
    ESetComp(_, _, p) => p
    EDictComp(_, _, _, p) => p
  }
}

///|
pub fn stmt_pos(s : Stmt) -> @errors.Position {
  match s {
    SExpr(e) => expr_pos(e)
    SAssign(_, _, p) => p
    SAugAssign(_, _, _, p) => p
    SIf(_, _, _, p) => p
    SFor(_, _, _, p) => p
    SWhile(_, _, p) => p
    SDef(_, _, _, p) => p
    SReturn(_, p) => p
    SBreak(p) => p
    SContinue(p) => p
    SPass(p) => p
    SLoad(_, _, p) => p
  }
}
