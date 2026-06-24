// Bytecode opcode set, modeled on starlark-go's `internal/compile` package.
// The numeric encoding matches starlark-go for ease of cross-reference, but the
// serialized form is NOT byte-compatible with starlark-go (this is a distinct
// implementation with a distinct Value model).
//
// Opcodes below `op_arg_min` take no operand; opcodes at or above it are
// followed by a uvarint operand in the instruction stream. For the `CALL`
// family, the operand encodes `(npositional << 8) | nnamed`.

///|
/// The complete bytecode instruction set. Opcodes with a byte value below
/// `op_arg_min` take no operand; those at or above it are followed by a
/// uvarint-encoded operand in the instruction stream. For the `Call` family
/// the operand packs `(npositional << 8) | nnamed`.
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
  MakeSet
  SetAdd
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
  // Augmented assignment apply: pops rhs then lhs, pushes the combined value.
  // Operand is the augmented-operator code (see `AugOp` ordering). Not present
  // in starlark-go; this implementation applies the in-place `+=`/`|=` semantics
  // through one opcode rather than dedicated INPLACE_* opcodes.
  AugApply
} derive(Eq)

///|
/// The lowest opcode byte value that carries a uvarint operand. Opcodes whose
/// byte value is `>= op_arg_min` are followed by an operand in the stream.
pub let op_arg_min : Int = 45

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
    MakeSet => 43
    SetAdd => 44
    Jmp => 45
    CJmp => 46
    IterJmp => 47
    Constant => 48
    MakeTuple => 49
    MakeList => 50
    MakeFunc => 51
    Load => 52
    SetLocal => 53
    SetGlobal => 54
    Local => 55
    Free => 56
    FreeCell => 57
    LocalCell => 58
    SetLocalCell => 59
    Global => 60
    Predeclared => 61
    Universal => 62
    Attr => 63
    SetField => 64
    Unpack => 65
    Call => 66
    CallVar => 67
    CallKw => 68
    CallVarKw => 69
    AugApply => 70
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
    43 => Some(MakeSet)
    44 => Some(SetAdd)
    45 => Some(Jmp)
    46 => Some(CJmp)
    47 => Some(IterJmp)
    48 => Some(Constant)
    49 => Some(MakeTuple)
    50 => Some(MakeList)
    51 => Some(MakeFunc)
    52 => Some(Load)
    53 => Some(SetLocal)
    54 => Some(SetGlobal)
    55 => Some(Local)
    56 => Some(Free)
    57 => Some(FreeCell)
    58 => Some(LocalCell)
    59 => Some(SetLocalCell)
    60 => Some(Global)
    61 => Some(Predeclared)
    62 => Some(Universal)
    63 => Some(Attr)
    64 => Some(SetField)
    65 => Some(Unpack)
    66 => Some(Call)
    67 => Some(CallVar)
    68 => Some(CallKw)
    69 => Some(CallVarKw)
    70 => Some(AugApply)
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
    MakeSet,
    SetAdd,
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
    AugApply,
  ]
}
