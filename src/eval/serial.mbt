// Binary serialization for Program (parsed + resolved AST + options).
// Unlike starlark-go, this is a tree-walking interpreter, so the serialized
// form is the resolved AST rather than compiled bytecode. The format is NOT
// byte-compatible with starlark-go's Program.Write. Its purpose is the same:
// pay parse + resolve costs once, persist the result, and reload it without
// re-parsing. All node positions are reconstructed with the file path on
// decode, so synthetic positions that carried a different filename are not
// preserved (this affects only error-message text, not execution).

///|
priv suberror SerialErr {
  SerialErr(String)
}

///|
const SerialMagic0 : Byte = b's'

///|
const SerialMagic1 : Byte = b'm'

///|
const SerialMagic2 : Byte = b'b'

///|
const SerialMagic3 : Byte = b't'

///|
const SerialVersion : Int = 1

// --- Encoder ---

///|
priv struct Encoder {
  buf : Array[Byte]
}

///|
fn Encoder::new() -> Encoder {
  { buf: [] }
}

///|
fn Encoder::byte(self : Encoder, b : Byte) -> Unit {
  self.buf.push(b)
}

///|
fn Encoder::tag(self : Encoder, t : Int) -> Unit {
  self.buf.push(t.to_byte())
}

///|
fn Encoder::bool(self : Encoder, b : Bool) -> Unit {
  self.byte(if b { b'\x01' } else { b'\x00' })
}

///|
fn Encoder::uint(self : Encoder, n : Int) -> Unit {
  let mut v = n
  while v >= 0x80 {
    self.buf.push(((v & 0x7f) | 0x80).to_byte())
    v = v >> 7
  }
  self.buf.push(v.to_byte())
}

///|
fn Encoder::u64(self : Encoder, n : UInt64) -> Unit {
  for i in 0..<8 {
    self.buf.push(((n >> (i * 8)) & 0xFFUL).to_int().to_byte())
  }
}

///|
fn Encoder::str(self : Encoder, s : String) -> Unit {
  let b = @utf8.encode(s)
  self.uint(b.length())
  for i in 0..<b.length() {
    self.buf.push(b[i])
  }
}

///|
fn Encoder::bytes(self : Encoder, b : Bytes) -> Unit {
  self.uint(b.length())
  for i in 0..<b.length() {
    self.buf.push(b[i])
  }
}

// --- Decoder ---

///|
priv struct Decoder {
  data : Bytes
  filename : String
  mut pos : Int
}

///|
fn Decoder::byte(self : Decoder) -> Byte raise SerialErr {
  if self.pos >= self.data.length() {
    raise SerialErr("unexpected end of input")
  }
  let b = self.data[self.pos]
  self.pos += 1
  b
}

///|
fn Decoder::bool(self : Decoder) -> Bool raise SerialErr {
  self.byte() != b'\x00'
}

///|
fn Decoder::uint(self : Decoder) -> Int raise SerialErr {
  let mut result = 0
  let mut shift = 0
  for _ in 0..<5 {
    let b = self.byte().to_int()
    result = result | ((b & 0x7f) << shift)
    if (b & 0x80) == 0 {
      return result
    }
    shift += 7
  }
  raise SerialErr("varint too long")
}

///|
fn Decoder::u64(self : Decoder) -> UInt64 raise SerialErr {
  let mut r = 0UL
  for i in 0..<8 {
    r = r | (self.byte().to_int().to_uint64() << (i * 8))
  }
  r
}

///|
fn Decoder::str(self : Decoder) -> String raise SerialErr {
  let n = self.uint()
  let arr : Array[Byte] = []
  for _ in 0..<n {
    arr.push(self.byte())
  }
  @utf8.decode_lossy(Bytes::from_array(arr)[:])
}

///|
fn Decoder::bytes(self : Decoder) -> Bytes raise SerialErr {
  let n = self.uint()
  let arr : Array[Byte] = []
  for _ in 0..<n {
    arr.push(self.byte())
  }
  Bytes::from_array(arr)
}

// --- Position ---
// Encoded as (line, col); the filename is reconstructed from the file path.

///|
fn encode_pos(enc : Encoder, p : @errors.Position) -> Unit {
  enc.uint(p.line())
  enc.uint(p.col())
}

///|
fn Decoder::decode_pos(self : Decoder) -> @errors.Position raise SerialErr {
  let line = self.uint()
  let col = self.uint()
  @errors.Position::new(self.filename, line, col)
}

// --- Operators ---

///|
fn encode_unary_op(enc : Encoder, op : @syntax.UnaryOp) -> Unit {
  let t = match op {
    OpPlus => 0
    OpMinus => 1
    OpBitNot => 2
    OpNot => 3
  }
  enc.tag(t)
}

///|
fn Decoder::decode_unary_op(self : Decoder) -> @syntax.UnaryOp raise SerialErr {
  match self.byte().to_int() {
    0 => OpPlus
    1 => OpMinus
    2 => OpBitNot
    3 => OpNot
    t => raise SerialErr("bad unary op tag \{t}")
  }
}

///|
fn encode_binary_op(enc : Encoder, op : @syntax.BinaryOp) -> Unit {
  let t = match op {
    OpAdd => 0
    OpSub => 1
    OpMul => 2
    OpDiv => 3
    OpFloorDiv => 4
    OpMod => 5
    OpBitAnd => 6
    OpBitOr => 7
    OpBitXor => 8
    OpLShift => 9
    OpRShift => 10
    OpEq => 11
    OpNe => 12
    OpLt => 13
    OpLe => 14
    OpGt => 15
    OpGe => 16
    OpIn => 17
    OpNotIn => 18
    OpAnd => 19
    OpOr => 20
  }
  enc.tag(t)
}

///|
fn Decoder::decode_binary_op(
  self : Decoder,
) -> @syntax.BinaryOp raise SerialErr {
  match self.byte().to_int() {
    0 => OpAdd
    1 => OpSub
    2 => OpMul
    3 => OpDiv
    4 => OpFloorDiv
    5 => OpMod
    6 => OpBitAnd
    7 => OpBitOr
    8 => OpBitXor
    9 => OpLShift
    10 => OpRShift
    11 => OpEq
    12 => OpNe
    13 => OpLt
    14 => OpLe
    15 => OpGt
    16 => OpGe
    17 => OpIn
    18 => OpNotIn
    19 => OpAnd
    20 => OpOr
    t => raise SerialErr("bad binary op tag \{t}")
  }
}

///|
fn encode_aug_op(enc : Encoder, op : @syntax.AugOp) -> Unit {
  let t = match op {
    AugAdd => 0
    AugSub => 1
    AugMul => 2
    AugDiv => 3
    AugFloorDiv => 4
    AugMod => 5
    AugBitAnd => 6
    AugBitOr => 7
    AugBitXor => 8
    AugLShift => 9
    AugRShift => 10
  }
  enc.tag(t)
}

///|
fn Decoder::decode_aug_op(self : Decoder) -> @syntax.AugOp raise SerialErr {
  match self.byte().to_int() {
    0 => AugAdd
    1 => AugSub
    2 => AugMul
    3 => AugDiv
    4 => AugFloorDiv
    5 => AugMod
    6 => AugBitAnd
    7 => AugBitOr
    8 => AugBitXor
    9 => AugLShift
    10 => AugRShift
    t => raise SerialErr("bad aug op tag \{t}")
  }
}

// --- LiteralVal ---

///|
fn encode_literal(enc : Encoder, lit : @syntax.LiteralVal) -> Unit {
  match lit {
    LitNone => enc.tag(0)
    LitBool(b) => {
      enc.tag(1)
      enc.bool(b)
    }
    LitInt(n) => {
      enc.tag(2)
      enc.str(n.to_string())
    }
    LitFloat(f) => {
      enc.tag(3)
      enc.u64(f.reinterpret_as_uint64())
    }
    LitString(s) => {
      enc.tag(4)
      enc.str(s)
    }
    LitBytes(b) => {
      enc.tag(5)
      enc.bytes(b)
    }
  }
}

///|
fn Decoder::decode_literal(
  self : Decoder,
) -> @syntax.LiteralVal raise SerialErr {
  match self.byte().to_int() {
    0 => LitNone
    1 => LitBool(self.bool())
    2 => LitInt(BigInt::from_string(self.str()))
    3 => LitFloat(self.u64().reinterpret_as_double())
    4 => LitString(self.str())
    5 => LitBytes(self.bytes())
    t => raise SerialErr("bad literal tag \{t}")
  }
}

// --- Expr ---

///|
fn encode_expr(enc : Encoder, e : @syntax.Expr) -> Unit {
  match e {
    EIdent(name, pos) => {
      enc.tag(0)
      enc.str(name)
      encode_pos(enc, pos)
    }
    ELiteral(lit, pos) => {
      enc.tag(1)
      encode_literal(enc, lit)
      encode_pos(enc, pos)
    }
    EUnary(op, x, pos) => {
      enc.tag(2)
      encode_unary_op(enc, op)
      encode_expr(enc, x)
      encode_pos(enc, pos)
    }
    EBinary(l, op, r, pos) => {
      enc.tag(3)
      encode_expr(enc, l)
      encode_binary_op(enc, op)
      encode_expr(enc, r)
      encode_pos(enc, pos)
    }
    ECond(c, t, f, pos) => {
      enc.tag(4)
      encode_expr(enc, c)
      encode_expr(enc, t)
      encode_expr(enc, f)
      encode_pos(enc, pos)
    }
    EIndex(x, i, pos) => {
      enc.tag(5)
      encode_expr(enc, x)
      encode_expr(enc, i)
      encode_pos(enc, pos)
    }
    ESlice(x, lo, hi, step, pos) => {
      enc.tag(6)
      encode_expr(enc, x)
      encode_expr_opt(enc, lo)
      encode_expr_opt(enc, hi)
      encode_expr_opt(enc, step)
      encode_pos(enc, pos)
    }
    EDot(x, name, pos) => {
      enc.tag(7)
      encode_expr(enc, x)
      enc.str(name)
      encode_pos(enc, pos)
    }
    ECall(f, args, pos) => {
      enc.tag(8)
      encode_expr(enc, f)
      enc.uint(args.length())
      for a in args {
        encode_arg(enc, a)
      }
      encode_pos(enc, pos)
    }
    EList(xs, pos) => {
      enc.tag(9)
      encode_expr_array(enc, xs)
      encode_pos(enc, pos)
    }
    ETuple(xs, pos) => {
      enc.tag(10)
      encode_expr_array(enc, xs)
      encode_pos(enc, pos)
    }
    EDict(pairs, pos) => {
      enc.tag(11)
      enc.uint(pairs.length())
      for p in pairs {
        encode_expr(enc, p.0)
        encode_expr(enc, p.1)
      }
      encode_pos(enc, pos)
    }
    ESet(xs, pos) => {
      enc.tag(12)
      encode_expr_array(enc, xs)
      encode_pos(enc, pos)
    }
    ELambda(params, body, pos) => {
      enc.tag(13)
      encode_param_array(enc, params)
      encode_expr(enc, body)
      encode_pos(enc, pos)
    }
    EListComp(x, clauses, pos) => {
      enc.tag(14)
      encode_expr(enc, x)
      encode_clause_array(enc, clauses)
      encode_pos(enc, pos)
    }
    ESetComp(x, clauses, pos) => {
      enc.tag(15)
      encode_expr(enc, x)
      encode_clause_array(enc, clauses)
      encode_pos(enc, pos)
    }
    EDictComp(k, v, clauses, pos) => {
      enc.tag(16)
      encode_expr(enc, k)
      encode_expr(enc, v)
      encode_clause_array(enc, clauses)
      encode_pos(enc, pos)
    }
  }
}

///|
fn encode_expr_opt(enc : Encoder, e : @syntax.Expr?) -> Unit {
  match e {
    Some(x) => {
      enc.bool(true)
      encode_expr(enc, x)
    }
    None => enc.bool(false)
  }
}

///|
fn encode_expr_array(enc : Encoder, xs : Array[@syntax.Expr]) -> Unit {
  enc.uint(xs.length())
  for x in xs {
    encode_expr(enc, x)
  }
}

///|
fn Decoder::decode_expr(self : Decoder) -> @syntax.Expr raise SerialErr {
  match self.byte().to_int() {
    0 => {
      let name = self.str()
      @syntax.Expr::EIdent(name, self.decode_pos())
    }
    1 => {
      let lit = self.decode_literal()
      @syntax.Expr::ELiteral(lit, self.decode_pos())
    }
    2 => {
      let op = self.decode_unary_op()
      let x = self.decode_expr()
      @syntax.Expr::EUnary(op, x, self.decode_pos())
    }
    3 => {
      let l = self.decode_expr()
      let op = self.decode_binary_op()
      let r = self.decode_expr()
      @syntax.Expr::EBinary(l, op, r, self.decode_pos())
    }
    4 => {
      let c = self.decode_expr()
      let t = self.decode_expr()
      let f = self.decode_expr()
      @syntax.Expr::ECond(c, t, f, self.decode_pos())
    }
    5 => {
      let x = self.decode_expr()
      let i = self.decode_expr()
      @syntax.Expr::EIndex(x, i, self.decode_pos())
    }
    6 => {
      let x = self.decode_expr()
      let lo = self.decode_expr_opt()
      let hi = self.decode_expr_opt()
      let step = self.decode_expr_opt()
      @syntax.Expr::ESlice(x, lo, hi, step, self.decode_pos())
    }
    7 => {
      let x = self.decode_expr()
      let name = self.str()
      @syntax.Expr::EDot(x, name, self.decode_pos())
    }
    8 => {
      let f = self.decode_expr()
      let n = self.uint()
      let args : Array[@syntax.Arg] = []
      for _ in 0..<n {
        args.push(self.decode_arg())
      }
      @syntax.Expr::ECall(f, args, self.decode_pos())
    }
    9 => {
      let xs = self.decode_expr_array()
      @syntax.Expr::EList(xs, self.decode_pos())
    }
    10 => {
      let xs = self.decode_expr_array()
      @syntax.Expr::ETuple(xs, self.decode_pos())
    }
    11 => {
      let n = self.uint()
      let pairs : Array[(@syntax.Expr, @syntax.Expr)] = []
      for _ in 0..<n {
        let k = self.decode_expr()
        let v = self.decode_expr()
        pairs.push((k, v))
      }
      @syntax.Expr::EDict(pairs, self.decode_pos())
    }
    12 => {
      let xs = self.decode_expr_array()
      @syntax.Expr::ESet(xs, self.decode_pos())
    }
    13 => {
      let params = self.decode_param_array()
      let body = self.decode_expr()
      @syntax.Expr::ELambda(params, body, self.decode_pos())
    }
    14 => {
      let x = self.decode_expr()
      let clauses = self.decode_clause_array()
      @syntax.Expr::EListComp(x, clauses, self.decode_pos())
    }
    15 => {
      let x = self.decode_expr()
      let clauses = self.decode_clause_array()
      @syntax.Expr::ESetComp(x, clauses, self.decode_pos())
    }
    16 => {
      let k = self.decode_expr()
      let v = self.decode_expr()
      let clauses = self.decode_clause_array()
      @syntax.Expr::EDictComp(k, v, clauses, self.decode_pos())
    }
    t => raise SerialErr("bad expr tag \{t}")
  }
}

///|
fn Decoder::decode_expr_opt(self : Decoder) -> @syntax.Expr? raise SerialErr {
  if self.bool() {
    Some(self.decode_expr())
  } else {
    None
  }
}

///|
fn Decoder::decode_expr_array(
  self : Decoder,
) -> Array[@syntax.Expr] raise SerialErr {
  let n = self.uint()
  let xs : Array[@syntax.Expr] = []
  for _ in 0..<n {
    xs.push(self.decode_expr())
  }
  xs
}

// --- Arg ---

///|
fn encode_arg(enc : Encoder, a : @syntax.Arg) -> Unit {
  match a {
    ArgPos(x) => {
      enc.tag(0)
      encode_expr(enc, x)
    }
    ArgKw(name, x, pos) => {
      enc.tag(1)
      enc.str(name)
      encode_expr(enc, x)
      encode_pos(enc, pos)
    }
    ArgStarArgs(x) => {
      enc.tag(2)
      encode_expr(enc, x)
    }
    ArgKwArgs(x) => {
      enc.tag(3)
      encode_expr(enc, x)
    }
  }
}

///|
fn Decoder::decode_arg(self : Decoder) -> @syntax.Arg raise SerialErr {
  match self.byte().to_int() {
    0 => @syntax.Arg::ArgPos(self.decode_expr())
    1 => {
      let name = self.str()
      let x = self.decode_expr()
      @syntax.Arg::ArgKw(name, x, self.decode_pos())
    }
    2 => @syntax.Arg::ArgStarArgs(self.decode_expr())
    3 => @syntax.Arg::ArgKwArgs(self.decode_expr())
    t => raise SerialErr("bad arg tag \{t}")
  }
}

// --- Param ---

///|
fn encode_param(enc : Encoder, p : @syntax.Param) -> Unit {
  match p {
    ParamIdent(name, pos) => {
      enc.tag(0)
      enc.str(name)
      encode_pos(enc, pos)
    }
    ParamDefault(name, x, pos) => {
      enc.tag(1)
      enc.str(name)
      encode_expr(enc, x)
      encode_pos(enc, pos)
    }
    ParamStarBare(pos) => {
      enc.tag(2)
      encode_pos(enc, pos)
    }
    ParamStarIdent(name, pos) => {
      enc.tag(3)
      enc.str(name)
      encode_pos(enc, pos)
    }
    ParamKwIdent(name, pos) => {
      enc.tag(4)
      enc.str(name)
      encode_pos(enc, pos)
    }
  }
}

///|
fn encode_param_array(enc : Encoder, ps : Array[@syntax.Param]) -> Unit {
  enc.uint(ps.length())
  for p in ps {
    encode_param(enc, p)
  }
}

///|
fn Decoder::decode_param(self : Decoder) -> @syntax.Param raise SerialErr {
  match self.byte().to_int() {
    0 => {
      let name = self.str()
      @syntax.Param::ParamIdent(name, self.decode_pos())
    }
    1 => {
      let name = self.str()
      let x = self.decode_expr()
      @syntax.Param::ParamDefault(name, x, self.decode_pos())
    }
    2 => @syntax.Param::ParamStarBare(self.decode_pos())
    3 => {
      let name = self.str()
      @syntax.Param::ParamStarIdent(name, self.decode_pos())
    }
    4 => {
      let name = self.str()
      @syntax.Param::ParamKwIdent(name, self.decode_pos())
    }
    t => raise SerialErr("bad param tag \{t}")
  }
}

///|
fn Decoder::decode_param_array(
  self : Decoder,
) -> Array[@syntax.Param] raise SerialErr {
  let n = self.uint()
  let ps : Array[@syntax.Param] = []
  for _ in 0..<n {
    ps.push(self.decode_param())
  }
  ps
}

// --- CompClause ---

///|
fn encode_clause(enc : Encoder, c : @syntax.CompClause) -> Unit {
  match c {
    ClauseFor(target, iter, pos) => {
      enc.tag(0)
      encode_expr(enc, target)
      encode_expr(enc, iter)
      encode_pos(enc, pos)
    }
    ClauseIf(cond, pos) => {
      enc.tag(1)
      encode_expr(enc, cond)
      encode_pos(enc, pos)
    }
  }
}

///|
fn encode_clause_array(enc : Encoder, cs : Array[@syntax.CompClause]) -> Unit {
  enc.uint(cs.length())
  for c in cs {
    encode_clause(enc, c)
  }
}

///|
fn Decoder::decode_clause(self : Decoder) -> @syntax.CompClause raise SerialErr {
  match self.byte().to_int() {
    0 => {
      let target = self.decode_expr()
      let iter = self.decode_expr()
      @syntax.CompClause::ClauseFor(target, iter, self.decode_pos())
    }
    1 => {
      let cond = self.decode_expr()
      @syntax.CompClause::ClauseIf(cond, self.decode_pos())
    }
    t => raise SerialErr("bad comp clause tag \{t}")
  }
}

///|
fn Decoder::decode_clause_array(
  self : Decoder,
) -> Array[@syntax.CompClause] raise SerialErr {
  let n = self.uint()
  let cs : Array[@syntax.CompClause] = []
  for _ in 0..<n {
    cs.push(self.decode_clause())
  }
  cs
}

// --- Stmt ---

///|
fn encode_stmt(enc : Encoder, s : @syntax.Stmt) -> Unit {
  match s {
    SExpr(x) => {
      enc.tag(0)
      encode_expr(enc, x)
    }
    SAssign(lhs, rhs, pos) => {
      enc.tag(1)
      encode_expr(enc, lhs)
      encode_expr(enc, rhs)
      encode_pos(enc, pos)
    }
    SAugAssign(lhs, op, rhs, pos) => {
      enc.tag(2)
      encode_expr(enc, lhs)
      encode_aug_op(enc, op)
      encode_expr(enc, rhs)
      encode_pos(enc, pos)
    }
    SIf(cond, then_body, else_body, pos) => {
      enc.tag(3)
      encode_expr(enc, cond)
      encode_stmt_array(enc, then_body)
      encode_stmt_array(enc, else_body)
      encode_pos(enc, pos)
    }
    SFor(target, iter, body, pos) => {
      enc.tag(4)
      encode_expr(enc, target)
      encode_expr(enc, iter)
      encode_stmt_array(enc, body)
      encode_pos(enc, pos)
    }
    SWhile(cond, body, pos) => {
      enc.tag(5)
      encode_expr(enc, cond)
      encode_stmt_array(enc, body)
      encode_pos(enc, pos)
    }
    SDef(name, params, body, pos) => {
      enc.tag(6)
      enc.str(name)
      encode_param_array(enc, params)
      encode_stmt_array(enc, body)
      encode_pos(enc, pos)
    }
    SReturn(x, pos) => {
      enc.tag(7)
      encode_expr_opt(enc, x)
      encode_pos(enc, pos)
    }
    SBreak(pos) => {
      enc.tag(8)
      encode_pos(enc, pos)
    }
    SContinue(pos) => {
      enc.tag(9)
      encode_pos(enc, pos)
    }
    SPass(pos) => {
      enc.tag(10)
      encode_pos(enc, pos)
    }
    SLoad(path, bindings, pos) => {
      enc.tag(11)
      enc.str(path)
      enc.uint(bindings.length())
      for b in bindings {
        enc.str(b.0)
        enc.str(b.1)
        encode_pos(enc, b.2)
      }
      encode_pos(enc, pos)
    }
  }
}

///|
fn encode_stmt_array(enc : Encoder, ss : Array[@syntax.Stmt]) -> Unit {
  enc.uint(ss.length())
  for s in ss {
    encode_stmt(enc, s)
  }
}

///|
fn Decoder::decode_stmt(self : Decoder) -> @syntax.Stmt raise SerialErr {
  match self.byte().to_int() {
    0 => @syntax.Stmt::SExpr(self.decode_expr())
    1 => {
      let lhs = self.decode_expr()
      let rhs = self.decode_expr()
      @syntax.Stmt::SAssign(lhs, rhs, self.decode_pos())
    }
    2 => {
      let lhs = self.decode_expr()
      let op = self.decode_aug_op()
      let rhs = self.decode_expr()
      @syntax.Stmt::SAugAssign(lhs, op, rhs, self.decode_pos())
    }
    3 => {
      let cond = self.decode_expr()
      let then_body = self.decode_stmt_array()
      let else_body = self.decode_stmt_array()
      @syntax.Stmt::SIf(cond, then_body, else_body, self.decode_pos())
    }
    4 => {
      let target = self.decode_expr()
      let iter = self.decode_expr()
      let body = self.decode_stmt_array()
      @syntax.Stmt::SFor(target, iter, body, self.decode_pos())
    }
    5 => {
      let cond = self.decode_expr()
      let body = self.decode_stmt_array()
      @syntax.Stmt::SWhile(cond, body, self.decode_pos())
    }
    6 => {
      let name = self.str()
      let params = self.decode_param_array()
      let body = self.decode_stmt_array()
      @syntax.Stmt::SDef(name, params, body, self.decode_pos())
    }
    7 => {
      let x = self.decode_expr_opt()
      @syntax.Stmt::SReturn(x, self.decode_pos())
    }
    8 => @syntax.Stmt::SBreak(self.decode_pos())
    9 => @syntax.Stmt::SContinue(self.decode_pos())
    10 => @syntax.Stmt::SPass(self.decode_pos())
    11 => {
      let path = self.str()
      let n = self.uint()
      let bindings : Array[(String, String, @errors.Position)] = []
      for _ in 0..<n {
        let local_name = self.str()
        let orig = self.str()
        bindings.push((local_name, orig, self.decode_pos()))
      }
      @syntax.Stmt::SLoad(path, bindings, self.decode_pos())
    }
    t => raise SerialErr("bad stmt tag \{t}")
  }
}

///|
fn Decoder::decode_stmt_array(
  self : Decoder,
) -> Array[@syntax.Stmt] raise SerialErr {
  let n = self.uint()
  let ss : Array[@syntax.Stmt] = []
  for _ in 0..<n {
    ss.push(self.decode_stmt())
  }
  ss
}

// --- Options ---

///|
fn encode_options(enc : Encoder, o : Options) -> Unit {
  enc.bool(o.allow_set())
  enc.bool(o.allow_recursion())
  enc.bool(o.allow_lambda())
  enc.bool(o.allow_while())
  enc.bool(o.allow_bytes())
  enc.bool(o.allow_float())
  enc.bool(o.allow_global_reassign())
  enc.bool(o.allow_top_level_control())
  enc.bool(o.load_binds_globally())
}

///|
fn Decoder::decode_options(self : Decoder) -> Options raise SerialErr {
  let allow_set = self.bool()
  let allow_recursion = self.bool()
  let allow_lambda = self.bool()
  let allow_while = self.bool()
  let allow_bytes = self.bool()
  let allow_float = self.bool()
  let allow_global_reassign = self.bool()
  let allow_top_level_control = self.bool()
  let load_binds_globally = self.bool()
  Options::default()
  .with_allow_set(allow_set)
  .with_allow_recursion(allow_recursion)
  .with_allow_lambda(allow_lambda)
  .with_allow_while(allow_while)
  .with_allow_bytes(allow_bytes)
  .with_allow_float(allow_float)
  .with_allow_global_reassign(allow_global_reassign)
  .with_allow_top_level_control(allow_top_level_control)
  .with_load_binds_globally(load_binds_globally)
}

// --- Program ---

///|
/// Serializes this program to a self-describing byte sequence that
/// `compiled_program` can reload without re-parsing or re-resolving the
/// source. The encoding holds the resolved AST plus the program's options;
/// it is specific to this tree-walking implementation and is NOT compatible
/// with starlark-go's bytecode `Program.Write` format.
pub fn Program::write(self : Program) -> Bytes {
  let enc = Encoder::new()
  enc.byte(SerialMagic0)
  enc.byte(SerialMagic1)
  enc.byte(SerialMagic2)
  enc.byte(SerialMagic3)
  enc.uint(SerialVersion)
  enc.str(self.file.path())
  encode_options(enc, self.opts)
  encode_stmt_array(enc, self.file.stmts())
  Bytes::from_array(enc.buf)
}

///|
/// Reconstructs a `Program` from bytes produced by `Program::write`. The input
/// is trusted to encode an already-resolved, valid program: resolution is not
/// re-run (it would require the original `is_predeclared` predicate). Returns
/// an `EvalError` if the bytes are truncated, carry an unknown magic header, or
/// were written by an incompatible serializer version.
pub fn compiled_program(data : Bytes) -> Result[Program, @errors.EvalError] {
  Ok(decode_program(data)) catch {
    SerialErr(msg) =>
      Err(@errors.EvalError::simple("cannot decode program: \{msg}"))
  }
}

///|
fn decode_program(data : Bytes) -> Program raise SerialErr {
  let header = { data, filename: "", pos: 0 }
  if header.byte() != SerialMagic0 ||
    header.byte() != SerialMagic1 ||
    header.byte() != SerialMagic2 ||
    header.byte() != SerialMagic3 {
    raise SerialErr("bad magic header")
  }
  let version = header.uint()
  if version != SerialVersion {
    raise SerialErr("unsupported version \{version}, expected \{SerialVersion}")
  }
  let path = header.str()
  let dec = { ..header, filename: path }
  let opts = dec.decode_options()
  let stmts = dec.decode_stmt_array()
  let file = @syntax.File::new(path, stmts)
  { file, opts }
}
