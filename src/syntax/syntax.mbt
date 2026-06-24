// Starlark AST node types.
// All nodes carry a Position for error reporting.

///|
/// Represents a literal value in the Starlark AST.
///
/// Variants:
///
/// - `LitInt` : An integer literal.
/// - `LitFloat` : A floating-point literal.
/// - `LitString` : A string literal.
/// - `LitBytes` : A bytes literal.
pub(all) enum LiteralVal {
  LitInt(BigInt)
  LitFloat(Double)
  LitString(String)
  LitBytes(Bytes)
}

///|
/// Represents a unary operator in the Starlark AST.
///
/// Variants:
///
/// - `OpPlus` : Unary `+`.
/// - `OpMinus` : Unary `-`.
/// - `OpBitNot` : Bitwise complement `~`.
/// - `OpNot` : Logical negation `not`.
pub(all) enum UnaryOp {
  OpPlus
  OpMinus
  OpBitNot
  OpNot
}

///|
/// Represents a binary operator in the Starlark AST.
///
/// Covers arithmetic, bitwise, comparison, membership, and logical operators.
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
/// Represents an augmented-assignment operator in the Starlark AST.
///
/// Each variant corresponds to one of the `+=`, `-=`, `*=`, `/=`, `//=`,
/// `%=`, `&=`, `|=`, `^=`, `<<=`, `>>=` forms.
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
/// Represents a single parameter in a function definition.
///
/// Variants:
///
/// - `ParamIdent` : A plain positional parameter `name`.
/// - `ParamDefault` : A parameter with a default value `name = expr`.
/// - `ParamStarBare` : A bare `*` separator (no name).
/// - `ParamStarIdent` : A `*name` variadic positional parameter.
/// - `ParamKwIdent` : A `**name` variadic keyword parameter.
///
/// Each variant carries the source `Position` of the parameter token.
pub(all) enum Param {
  ParamIdent(String, @errors.Position)
  ParamDefault(String, Expr, @errors.Position)
  ParamStarBare(@errors.Position)
  ParamStarIdent(String, @errors.Position)
  ParamKwIdent(String, @errors.Position)
}

///|
/// Represents a single argument at a call site.
///
/// Variants:
///
/// - `ArgPos` : A positional argument `expr`.
/// - `ArgKw` : A keyword argument `name = expr`.
/// - `ArgStarArgs` : A `*expr` unpacked positional argument.
/// - `ArgKwArgs` : A `**expr` unpacked keyword argument.
///
/// `ArgKw`, `ArgStarArgs`, and `ArgKwArgs` carry the source `Position` of
/// the argument token.
pub(all) enum Arg {
  ArgPos(Expr)
  ArgKw(String, Expr, @errors.Position)
  ArgStarArgs(@errors.Position, Expr)
  ArgKwArgs(@errors.Position, Expr)
}

///|
/// Represents a single clause in a comprehension expression.
///
/// Variants:
///
/// - `ClauseFor` : A `for lhs in rhs` iteration clause.
/// - `ClauseIf` : A filtering `if cond` clause.
///
/// Each variant carries the source `Position` of the clause keyword.
pub(all) enum CompClause {
  ClauseFor(Expr, Expr, @errors.Position)
  ClauseIf(Expr, @errors.Position)
}

///|
/// Represents an expression node in the Starlark AST.
///
/// Every variant carries a source `Position` as its last field for error
/// reporting. Variants:
///
/// - `EIdent` : An identifier reference.
/// - `ELiteral` : A literal value.
/// - `EUnary` : A unary operation.
/// - `EBinary` : A binary operation.
/// - `ECond` : A conditional expression `t if cond else f`.
/// - `EIndex` : A subscript expression `obj[key]`.
/// - `ESlice` : A slice expression `obj[lo:hi:step]`; absent bounds are `None`.
/// - `EDot` : An attribute access `obj.attr`.
/// - `ECall` : A function call `fn(args...)`.
/// - `EList` : A list display `[...]`.
/// - `ETuple` : A tuple display `(...)`.
/// - `EDict` : A dict display `{k: v, ...}`.
/// - `ESet` : A set display `{...}`.
/// - `ELambda` : A lambda expression `lambda params: body`.
/// - `EListComp` : A list comprehension `[expr for ...]`.
/// - `ESetComp` : A set comprehension `{expr for ...}`.
/// - `EDictComp` : A dict comprehension `{k: v for ...}`.
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
/// Represents a statement node in the Starlark AST.
///
/// Every variant (except `SExpr`) carries a source `Position` as its last
/// field for error reporting. Variants:
///
/// - `SExpr` : An expression used as a statement.
/// - `SAssign` : A simple assignment `lhs = rhs`.
/// - `SAugAssign` : An augmented assignment `lhs op= rhs`.
/// - `SIf` : An `if / else` block; the else branch may be empty.
/// - `SFor` : A `for` loop.
/// - `SWhile` : A `while` loop.
/// - `SDef` : A function definition `def name(params): body`.
/// - `SReturn` : A `return` statement; the expression is optional.
/// - `SBreak` : A `break` statement.
/// - `SContinue` : A `continue` statement.
/// - `SPass` : A `pass` statement.
/// - `SLoad` : A `load` statement; each binding is `(local, orig, pos)`.
pub(all) enum Stmt {
  SExpr(Expr)
  SAssign(Expr, Expr, @errors.Position)
  SAugAssign(Expr, AugOp, Expr, @errors.Position)
  SIf(Expr, Array[Stmt], Array[Stmt], @errors.Position)
  SFor(Expr, Expr, Array[Stmt], @errors.Position)
  SWhile(Expr, Array[Stmt], @errors.Position)
  SDef(String, @errors.Position, Array[Param], Array[Stmt], @errors.Position)
  SReturn(Expr?, @errors.Position)
  SBreak(@errors.Position)
  SContinue(@errors.Position)
  SPass(@errors.Position)
  SLoad(String, Array[(String, String, @errors.Position)], @errors.Position)
}

///|
/// A parsed Starlark source file: its filename and top-level statement list.
pub struct File {
  priv path : String
  priv stmts : Array[Stmt]
}

///|
/// Constructs a `File` with the given source path and top-level statement list.
///
/// Parameters:
///
/// - `path` : The source file path recorded in the AST.
/// - `stmts` : The top-level statements parsed from the file.
///
/// Returns a new `File` AST node.
pub fn File::new(path : String, stmts : Array[Stmt]) -> File {
  { path, stmts }
}

///|
/// Returns the source file path.
///
/// Parameters:
///
/// - `self` : The file node to inspect.
///
/// Returns the path string recorded in this `File`.
pub fn File::path(self : File) -> String {
  self.path
}

///|
/// Returns the top-level statement list.
///
/// Parameters:
///
/// - `self` : The file node to inspect.
///
/// Returns the array of top-level `Stmt` nodes in this file.
pub fn File::stmts(self : File) -> Array[Stmt] {
  self.stmts
}

///|
/// Returns the source position of an expression node.
///
/// Parameters:
///
/// - `e` : The expression node to inspect.
///
/// Returns the `Position` stored in the expression's position slot.
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
/// Returns the source position of a statement node.
///
/// Parameters:
///
/// - `s` : The statement node to inspect.
///
/// Returns the `Position` stored in the statement's position slot.
pub fn stmt_pos(s : Stmt) -> @errors.Position {
  match s {
    SExpr(e) => expr_pos(e)
    SAssign(_, _, p) => p
    SAugAssign(_, _, _, p) => p
    SIf(_, _, _, p) => p
    SFor(_, _, _, p) => p
    SWhile(_, _, p) => p
    SDef(_, _, _, _, p) => p
    SReturn(_, p) => p
    SBreak(p) => p
    SContinue(p) => p
    SPass(p) => p
    SLoad(_, _, p) => p
  }
}
