// Bytecode opcode set, modeled on starlark-go's `internal/compile` package.
// The numeric encoding matches starlark-go for ease of cross-reference, but the
// serialized form is NOT byte-compatible with starlark-go (this is a distinct
// implementation with a distinct Value model).
//
// Opcodes below `op_arg_min` take no operand; opcodes at or above it are
// followed by a uvarint operand in the instruction stream. For the `CALL`
// family, the operand encodes `(npositional << 8) | nnamed`.

///|
pub(all) enum Opcode {
  // sentinel / stack operations
  Nop
  Dup
  Dup2
  Pop
  Exch
  // binary comparisons (order matches the runtime comparison dispatch)
  Lt
  Gt
  Ge
  Le
  Eql
  Neq
  // binary arithmetic
  Plus
  Minus
  Star
  Slash
  SlashSlash
  Percent
  Amp
  Pipe
  Circumflex
  LtLt
  GtGt
  In
  // unary operators
  UPlus
  UMinus
  Tilde
  // constants / sentinels
  NoneOp
  TrueOp
  FalseOp
  Mandatory
  // misc no-argument operations
  IterPush
  IterPop
  Not
  Return
  SetIndex
  Index
  SetDict
  SetDictUniq
  Append
  Slice
  InplaceAdd
  InplacePipe
  MakeDict
  // --- opcodes with an argument go below this line (op_arg_min) ---
  Jmp
  CJmp
  IterJmp
  Constant
  MakeTuple
  MakeList
  MakeFunc
  Load
  SetLocal
  SetGlobal
  Local
  Free
  FreeCell
  LocalCell
  SetLocalCell
  Global
  Predeclared
  Universal
  Attr
  SetField
  Unpack
  Call
  CallVar
  CallKw
  CallVarKw
} derive(Eq)

///|
/// The lowest opcode byte value that carries a uvarint operand. Opcodes whose
/// byte value is `>= op_arg_min` are followed by an operand in the stream.
pub let op_arg_min : Int = 43

///|
/// Maps an opcode to its byte encoding. This is the authoritative ordering;
/// `Opcode::from_byte` is its inverse.
pub fn Opcode::to_byte(self : Opcode) -> Byte {
  let n = match self {
    Nop => 0
    Dup => 1
    Dup2 => 2
    Pop => 3
    Exch => 4
    Lt => 5
    Gt => 6
    Ge => 7
    Le => 8
    Eql => 9
    Neq => 10
    Plus => 11
    Minus => 12
    Star => 13
    Slash => 14
    SlashSlash => 15
    Percent => 16
    Amp => 17
    Pipe => 18
    Circumflex => 19
    LtLt => 20
    GtGt => 21
    In => 22
    UPlus => 23
    UMinus => 24
    Tilde => 25
    NoneOp => 26
    TrueOp => 27
    FalseOp => 28
    Mandatory => 29
    IterPush => 30
    IterPop => 31
    Not => 32
    Return => 33
    SetIndex => 34
    Index => 35
    SetDict => 36
    SetDictUniq => 37
    Append => 38
    Slice => 39
    InplaceAdd => 40
    InplacePipe => 41
    MakeDict => 42
    Jmp => 43
    CJmp => 44
    IterJmp => 45
    Constant => 46
    MakeTuple => 47
    MakeList => 48
    MakeFunc => 49
    Load => 50
    SetLocal => 51
    SetGlobal => 52
    Local => 53
    Free => 54
    FreeCell => 55
    LocalCell => 56
    SetLocalCell => 57
    Global => 58
    Predeclared => 59
    Universal => 60
    Attr => 61
    SetField => 62
    Unpack => 63
    Call => 64
    CallVar => 65
    CallKw => 66
    CallVarKw => 67
  }
  n.to_byte()
}

///|
/// Decodes an opcode from its byte encoding, or `None` if the byte is not a
/// valid opcode. Inverse of `Opcode::to_byte`.
pub fn Opcode::from_byte(b : Byte) -> Opcode? {
  match b.to_int() {
    0 => Some(Nop)
    1 => Some(Dup)
    2 => Some(Dup2)
    3 => Some(Pop)
    4 => Some(Exch)
    5 => Some(Lt)
    6 => Some(Gt)
    7 => Some(Ge)
    8 => Some(Le)
    9 => Some(Eql)
    10 => Some(Neq)
    11 => Some(Plus)
    12 => Some(Minus)
    13 => Some(Star)
    14 => Some(Slash)
    15 => Some(SlashSlash)
    16 => Some(Percent)
    17 => Some(Amp)
    18 => Some(Pipe)
    19 => Some(Circumflex)
    20 => Some(LtLt)
    21 => Some(GtGt)
    22 => Some(In)
    23 => Some(UPlus)
    24 => Some(UMinus)
    25 => Some(Tilde)
    26 => Some(NoneOp)
    27 => Some(TrueOp)
    28 => Some(FalseOp)
    29 => Some(Mandatory)
    30 => Some(IterPush)
    31 => Some(IterPop)
    32 => Some(Not)
    33 => Some(Return)
    34 => Some(SetIndex)
    35 => Some(Index)
    36 => Some(SetDict)
    37 => Some(SetDictUniq)
    38 => Some(Append)
    39 => Some(Slice)
    40 => Some(InplaceAdd)
    41 => Some(InplacePipe)
    42 => Some(MakeDict)
    43 => Some(Jmp)
    44 => Some(CJmp)
    45 => Some(IterJmp)
    46 => Some(Constant)
    47 => Some(MakeTuple)
    48 => Some(MakeList)
    49 => Some(MakeFunc)
    50 => Some(Load)
    51 => Some(SetLocal)
    52 => Some(SetGlobal)
    53 => Some(Local)
    54 => Some(Free)
    55 => Some(FreeCell)
    56 => Some(LocalCell)
    57 => Some(SetLocalCell)
    58 => Some(Global)
    59 => Some(Predeclared)
    60 => Some(Universal)
    61 => Some(Attr)
    62 => Some(SetField)
    63 => Some(Unpack)
    64 => Some(Call)
    65 => Some(CallVar)
    66 => Some(CallKw)
    67 => Some(CallVarKw)
    _ => None
  }
}

///|
/// Returns `true` if this opcode is followed by a uvarint operand in the
/// instruction stream.
pub fn Opcode::has_arg(self : Opcode) -> Bool {
  self.to_byte().to_int() >= op_arg_min
}

///|
/// Returns the canonical list of all opcodes in byte order. Used by tests to
/// verify the `to_byte`/`from_byte` round-trip and by tooling.
pub fn all_opcodes() -> Array[Opcode] {
  [
    Nop,
    Dup,
    Dup2,
    Pop,
    Exch,
    Lt,
    Gt,
    Ge,
    Le,
    Eql,
    Neq,
    Plus,
    Minus,
    Star,
    Slash,
    SlashSlash,
    Percent,
    Amp,
    Pipe,
    Circumflex,
    LtLt,
    GtGt,
    In,
    UPlus,
    UMinus,
    Tilde,
    NoneOp,
    TrueOp,
    FalseOp,
    Mandatory,
    IterPush,
    IterPop,
    Not,
    Return,
    SetIndex,
    Index,
    SetDict,
    SetDictUniq,
    Append,
    Slice,
    InplaceAdd,
    InplacePipe,
    MakeDict,
    Jmp,
    CJmp,
    IterJmp,
    Constant,
    MakeTuple,
    MakeList,
    MakeFunc,
    Load,
    SetLocal,
    SetGlobal,
    Local,
    Free,
    FreeCell,
    LocalCell,
    SetLocalCell,
    Global,
    Predeclared,
    Universal,
    Attr,
    SetField,
    Unpack,
    Call,
    CallVar,
    CallKw,
    CallVarKw,
  ]
}
