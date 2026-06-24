// Binary serialization for Program: the compiled bytecode program (constant
// pool, function table, global/load tables, and the module-init funcode) plus
// the program's options. The format is NOT byte-compatible with starlark-go's
// Program.Write, but serves the same purpose: pay parse + resolve + compile
// costs once, persist the result, and reload it without re-parsing or
// re-compiling. All node positions are reconstructed with the file path on
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
const SerialVersion : Int = 2

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

// --- Compiled program (bytecode) ---

///|
fn encode_binding(enc : Encoder, b : @errors.Binding) -> Unit {
  enc.str(b.name())
  encode_pos(enc, b.pos())
}

///|
fn Decoder::decode_binding(self : Decoder) -> @errors.Binding raise SerialErr {
  let name = self.str()
  let pos = self.decode_pos()
  @errors.Binding::new(name, pos)
}

///|
fn encode_const(enc : Encoder, c : @compile.Const) -> Unit {
  match c {
    CNone => enc.tag(0)
    CBool(b) => {
      enc.tag(1)
      enc.bool(b)
    }
    CInt(n) => {
      enc.tag(2)
      enc.str(n.to_string())
    }
    CFloat(f) => {
      enc.tag(3)
      enc.u64(f.reinterpret_as_uint64())
    }
    CStr(s) => {
      enc.tag(4)
      enc.str(s)
    }
    CBytes(b) => {
      enc.tag(5)
      enc.bytes(b)
    }
  }
}

///|
fn Decoder::decode_const(self : Decoder) -> @compile.Const raise SerialErr {
  match self.byte().to_int() {
    0 => CNone
    1 => CBool(self.bool())
    2 => CInt(BigInt::from_string(self.str()))
    3 => CFloat(self.u64().reinterpret_as_double())
    4 => CStr(self.str())
    5 => CBytes(self.bytes())
    t => raise SerialErr("bad const tag \{t}")
  }
}

///|
fn encode_param_spec(enc : Encoder, p : @compile.ParamSpec) -> Unit {
  match p {
    PRequired(name) => {
      enc.tag(0)
      enc.str(name)
    }
    POptional(name) => {
      enc.tag(1)
      enc.str(name)
    }
    PStarBare => enc.tag(2)
    PStarArgs(name) => {
      enc.tag(3)
      enc.str(name)
    }
    PKwArgs(name) => {
      enc.tag(4)
      enc.str(name)
    }
  }
}

///|
fn Decoder::decode_param_spec(
  self : Decoder,
) -> @compile.ParamSpec raise SerialErr {
  match self.byte().to_int() {
    0 => PRequired(self.str())
    1 => POptional(self.str())
    2 => PStarBare
    3 => PStarArgs(self.str())
    4 => PKwArgs(self.str())
    t => raise SerialErr("bad param-spec tag \{t}")
  }
}

///|
fn encode_freevar_source(enc : Encoder, s : @compile.FreevarSource) -> Unit {
  match s {
    FromLocal(i) => {
      enc.tag(0)
      enc.uint(i)
    }
    FromFree(i) => {
      enc.tag(1)
      enc.uint(i)
    }
  }
}

///|
fn Decoder::decode_freevar_source(
  self : Decoder,
) -> @compile.FreevarSource raise SerialErr {
  match self.byte().to_int() {
    0 => FromLocal(self.uint())
    1 => FromFree(self.uint())
    t => raise SerialErr("bad freevar-source tag \{t}")
  }
}

///|
fn encode_funcode(enc : Encoder, fc : @compile.Funcode) -> Unit {
  encode_pos(enc, fc.pos)
  enc.str(fc.name)
  enc.str(fc.doc)
  enc.bytes(fc.code)
  enc.uint(fc.pclinetab.length())
  for e in fc.pclinetab {
    enc.uint(e.pc)
    enc.uint(e.line)
    enc.uint(e.col)
  }
  enc.uint(fc.locals.length())
  for b in fc.locals {
    encode_binding(enc, b)
  }
  enc.uint(fc.cells.length())
  for c in fc.cells {
    enc.uint(c)
  }
  enc.uint(fc.freevars.length())
  for b in fc.freevars {
    encode_binding(enc, b)
  }
  enc.uint(fc.max_stack)
  enc.uint(fc.num_params)
  enc.uint(fc.num_kwonly_params)
  enc.bool(fc.has_varargs)
  enc.bool(fc.has_kwargs)
  enc.uint(fc.params.length())
  for p in fc.params {
    encode_param_spec(enc, p)
  }
  enc.uint(fc.freevar_sources.length())
  for s in fc.freevar_sources {
    encode_freevar_source(enc, s)
  }
}

///|
fn Decoder::decode_funcode(self : Decoder) -> @compile.Funcode raise SerialErr {
  let pos = self.decode_pos()
  let name = self.str()
  let doc = self.str()
  let code = self.bytes()
  let pclinetab : Array[@compile.PcLine] = []
  for _ in 0..<self.uint() {
    let pc = self.uint()
    let line = self.uint()
    let col = self.uint()
    pclinetab.push({ pc, line, col })
  }
  let locals : Array[@errors.Binding] = []
  for _ in 0..<self.uint() {
    locals.push(self.decode_binding())
  }
  let cells : Array[Int] = []
  for _ in 0..<self.uint() {
    cells.push(self.uint())
  }
  let freevars : Array[@errors.Binding] = []
  for _ in 0..<self.uint() {
    freevars.push(self.decode_binding())
  }
  let max_stack = self.uint()
  let num_params = self.uint()
  let num_kwonly_params = self.uint()
  let has_varargs = self.bool()
  let has_kwargs = self.bool()
  let params : Array[@compile.ParamSpec] = []
  for _ in 0..<self.uint() {
    params.push(self.decode_param_spec())
  }
  let freevar_sources : Array[@compile.FreevarSource] = []
  for _ in 0..<self.uint() {
    freevar_sources.push(self.decode_freevar_source())
  }
  {
    pos,
    name,
    doc,
    code,
    pclinetab,
    locals,
    cells,
    freevars,
    max_stack,
    num_params,
    num_kwonly_params,
    has_varargs,
    has_kwargs,
    params,
    freevar_sources,
  }
}

///|
fn encode_load_stmt(enc : Encoder, ls : @compile.LoadStmt) -> Unit {
  enc.str(ls.path)
  encode_pos(enc, ls.pos)
  enc.uint(ls.exports.length())
  for s in ls.exports {
    enc.str(s)
  }
  enc.uint(ls.locals.length())
  for s in ls.locals {
    enc.str(s)
  }
  enc.uint(ls.slots.length())
  for i in ls.slots {
    enc.uint(i)
  }
}

///|
fn Decoder::decode_load_stmt(
  self : Decoder,
) -> @compile.LoadStmt raise SerialErr {
  let path = self.str()
  let pos = self.decode_pos()
  let exports : Array[String] = []
  for _ in 0..<self.uint() {
    exports.push(self.str())
  }
  let locals : Array[String] = []
  for _ in 0..<self.uint() {
    locals.push(self.str())
  }
  let slots : Array[Int] = []
  for _ in 0..<self.uint() {
    slots.push(self.uint())
  }
  { path, pos, exports, locals, slots }
}

///|
fn encode_compiled(enc : Encoder, prog : @compile.CompiledProgram) -> Unit {
  enc.uint(prog.loads.length())
  for b in prog.loads {
    encode_binding(enc, b)
  }
  enc.uint(prog.names.length())
  for s in prog.names {
    enc.str(s)
  }
  enc.uint(prog.constants.length())
  for c in prog.constants {
    encode_const(enc, c)
  }
  enc.uint(prog.functions.length())
  for fc in prog.functions {
    encode_funcode(enc, fc)
  }
  enc.uint(prog.globals.length())
  for b in prog.globals {
    encode_binding(enc, b)
  }
  encode_funcode(enc, prog.toplevel)
  enc.bool(prog.recursion)
  enc.uint(prog.load_stmts.length())
  for ls in prog.load_stmts {
    encode_load_stmt(enc, ls)
  }
}

///|
fn Decoder::decode_compiled(
  self : Decoder,
) -> @compile.CompiledProgram raise SerialErr {
  let loads : Array[@errors.Binding] = []
  for _ in 0..<self.uint() {
    loads.push(self.decode_binding())
  }
  let names : Array[String] = []
  for _ in 0..<self.uint() {
    names.push(self.str())
  }
  let constants : Array[@compile.Const] = []
  for _ in 0..<self.uint() {
    constants.push(self.decode_const())
  }
  let functions : Array[@compile.Funcode] = []
  for _ in 0..<self.uint() {
    functions.push(self.decode_funcode())
  }
  let globals : Array[@errors.Binding] = []
  for _ in 0..<self.uint() {
    globals.push(self.decode_binding())
  }
  let toplevel = self.decode_funcode()
  let recursion = self.bool()
  let load_stmts : Array[@compile.LoadStmt] = []
  for _ in 0..<self.uint() {
    load_stmts.push(self.decode_load_stmt())
  }
  {
    loads,
    names,
    constants,
    functions,
    globals,
    toplevel,
    recursion,
    load_stmts,
  }
}

// --- Program ---

///|
/// Serializes this program to a self-describing byte sequence that
/// `compiled_program` can reload without re-parsing, re-resolving, or
/// re-compiling the source. The encoding holds the compiled bytecode program
/// plus the program's options; it is specific to this implementation and is NOT
/// compatible with starlark-go's `Program.Write` format.
pub fn Program::write(self : Program) -> Bytes {
  let enc = Encoder::new()
  enc.byte(SerialMagic0)
  enc.byte(SerialMagic1)
  enc.byte(SerialMagic2)
  enc.byte(SerialMagic3)
  enc.uint(SerialVersion)
  enc.str(self.filename)
  encode_options(enc, self.opts)
  encode_compiled(enc, self.compiled)
  Bytes::from_array(enc.buf)
}

///|
/// Reconstructs a `Program` from bytes produced by `Program::write`. The input
/// is trusted to already carry the compiled bytecode program: neither
/// resolution nor compilation is re-run during decode (re-resolution would
/// require the original `is_predeclared` predicate), so the bytes hydrate
/// straight into a runnable `CompiledProgram`. Returns an `EvalError` if the
/// bytes are truncated, carry an unknown magic header, or were written by an
/// incompatible serializer version.
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
  let compiled = dec.decode_compiled()
  { filename: path, opts, compiled }
}
