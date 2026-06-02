// Starlark lexical token types.

///|
pub(all) enum Token {
  Illegal
  EOF
  Newline
  Indent
  Outdent
  // Literals with embedded values
  Ident(String)
  Int(BigInt)
  Float(Double)
  Str(String) // decoded string content (UTF-8)
  Bytes(Bytes) // decoded bytes content
  // Arithmetic
  Plus // +
  Minus // -
  Star // *
  Slash // /
  SlashSlash // //
  Percent // %
  StarStar // **
  // Bitwise
  Amp // &
  Pipe // |
  Circumflex // ^
  LtLt // <<
  GtGt // >>
  Tilde // ~
  // Delimiters
  Dot // .
  Comma // ,
  Assign // =
  Semi // ;
  Colon // :
  LParen // (
  RParen // )
  LBrack // [
  RBrack // ]
  LBrace // {
  RBrace // }
  // Comparison
  Lt // <
  Gt // >
  Ge // >=
  Le // <=
  Eql // ==
  Neq // !=
  // Augmented assignment
  PlusAssign // +=
  MinusAssign // -=
  StarAssign // *=
  SlashAssign // /=
  SlashSlashAssign // //=
  PercentAssign // %=
  AmpAssign // &=
  PipeAssign // |=
  CircumflexAssign // ^=
  LtLtAssign // <<=
  GtGtAssign // >>=
  // Keywords
  And
  Break
  Continue
  Def
  Elif
  Else
  For
  If
  In
  Lambda
  Load
  Not
  NotIn // synthesized from NOT IN
  Or
  Pass
  Return
  While
  // Keyword literals (not identifiers)
  NoneKw
  TrueKw
  FalseKw
  // Reserved Python keywords (not valid in Starlark; parser rejects)
  As
  Async
  Await
  Class
  Del
  Except
  Finally
  From
  Global
  Import
  Is
  Nonlocal
  Raise
  Try
  With
  Yield
} derive(Eq)

///|
/// Returns a human-readable description of the token (e.g. `"identifier"`, `"+"`).
///
/// Parameters:
///
/// - `self` : The token to describe.
///
/// Returns a short string naming the token kind or its literal spelling.
pub fn Token::to_string(self : Token) -> String {
  match self {
    Illegal => "illegal token"
    EOF => "end of file"
    Newline => "newline"
    Indent => "indent"
    Outdent => "outdent"
    Ident(_) => "identifier"
    Int(_) => "int literal"
    Float(_) => "float literal"
    Str(_) => "string literal"
    Bytes(_) => "bytes literal"
    Plus => "+"
    Minus => "-"
    Star => "*"
    Slash => "/"
    SlashSlash => "//"
    Percent => "%"
    StarStar => "**"
    Amp => "&"
    Pipe => "|"
    Circumflex => "^"
    LtLt => "<<"
    GtGt => ">>"
    Tilde => "~"
    Dot => "."
    Comma => ","
    Assign => "="
    Semi => ";"
    Colon => ":"
    LParen => "("
    RParen => ")"
    LBrack => "["
    RBrack => "]"
    LBrace => "{"
    RBrace => "}"
    Lt => "<"
    Gt => ">"
    Ge => ">="
    Le => "<="
    Eql => "=="
    Neq => "!="
    PlusAssign => "+="
    MinusAssign => "-="
    StarAssign => "*="
    SlashAssign => "/="
    SlashSlashAssign => "//="
    PercentAssign => "%="
    AmpAssign => "&="
    PipeAssign => "|="
    CircumflexAssign => "^="
    LtLtAssign => "<<="
    GtGtAssign => ">>="
    And => "and"
    Break => "break"
    Continue => "continue"
    Def => "def"
    Elif => "elif"
    Else => "else"
    For => "for"
    If => "if"
    In => "in"
    Lambda => "lambda"
    Load => "load"
    Not => "not"
    NotIn => "not in"
    Or => "or"
    Pass => "pass"
    Return => "return"
    While => "while"
    NoneKw => "None"
    TrueKw => "True"
    FalseKw => "False"
    As => "as"
    Async => "async"
    Await => "await"
    Class => "class"
    Del => "del"
    Except => "except"
    Finally => "finally"
    From => "from"
    Global => "global"
    Import => "import"
    Is => "is"
    Nonlocal => "nonlocal"
    Raise => "raise"
    Try => "try"
    With => "with"
    Yield => "yield"
  }
}

///|
/// Renders a token the way starlark-go's `Token.GoString` does: punctuation
/// and operator tokens are wrapped in single quotes; identifiers, literals,
/// keywords, and structural tokens (EOF, newline, indent) are rendered bare.
/// Used in `got %#v` style error messages to match starlark-go wording.
///
/// Parameters:
///
/// - `self` : The token to render.
///
/// Returns the token's Go-style debug string.
pub fn Token::go_string(self : Token) -> String {
  match self {
    Plus
    | Minus
    | Star
    | Slash
    | SlashSlash
    | Percent
    | StarStar
    | Amp
    | Pipe
    | Circumflex
    | LtLt
    | GtGt
    | Tilde
    | Dot
    | Comma
    | Assign
    | Semi
    | Colon
    | LParen
    | RParen
    | LBrack
    | RBrack
    | LBrace
    | RBrace
    | Lt
    | Gt
    | Ge
    | Le
    | Eql
    | Neq
    | PlusAssign
    | MinusAssign
    | StarAssign
    | SlashAssign
    | SlashSlashAssign
    | PercentAssign
    | AmpAssign
    | PipeAssign
    | CircumflexAssign
    | LtLtAssign
    | GtGtAssign => "'" + self.to_string() + "'"
    _ => self.to_string()
  }
}

///|
/// Returns the keyword `Token` for the given identifier name, or `None` if
/// the name is not a Starlark keyword.
///
/// Parameters:
///
/// - `name` : The identifier string to look up.
///
/// Returns `Some(token)` if `name` is a Starlark keyword, `None` otherwise.
pub fn keyword_token(name : String) -> Token? {
  match name {
    "and" => Some(And)
    "break" => Some(Break)
    "continue" => Some(Continue)
    "def" => Some(Def)
    "elif" => Some(Elif)
    "else" => Some(Else)
    "for" => Some(For)
    "if" => Some(If)
    "in" => Some(In)
    "lambda" => Some(Lambda)
    "load" => Some(Load)
    "not" => Some(Not)
    "or" => Some(Or)
    "pass" => Some(Pass)
    "return" => Some(Return)
    "while" => Some(While)
    "None" => Some(NoneKw)
    "True" => Some(TrueKw)
    "False" => Some(FalseKw)
    "as" => Some(As)
    "async" => Some(Async)
    "await" => Some(Await)
    "class" => Some(Class)
    "del" => Some(Del)
    "except" => Some(Except)
    "finally" => Some(Finally)
    "from" => Some(From)
    "global" => Some(Global)
    "import" => Some(Import)
    "is" => Some(Is)
    "nonlocal" => Some(Nonlocal)
    "raise" => Some(Raise)
    "try" => Some(Try)
    "with" => Some(With)
    "yield" => Some(Yield)
    _ => None
  }
}
