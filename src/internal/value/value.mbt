///|
pub(all) struct StarlarkString {
  raw : String
  bytes : Bytes
}

///|
pub fn StarlarkString::new(raw : String) -> StarlarkString {
  let bytes = @utf8.encode(raw)
  { raw, bytes }
}

///|
pub fn StarlarkString::from_bytes(bytes : Bytes) -> StarlarkString {
  let raw = @utf8.decode_lossy(bytes[:])
  { raw, bytes }
}

///|
pub fn StarlarkString::byte_len(self : StarlarkString) -> Int {
  self.bytes.length()
}

///|
pub fn StarlarkString::byte_at(self : StarlarkString, i : Int) -> Byte {
  self.bytes[i]
}

///|
pub fn StarlarkString::equals(
  self : StarlarkString,
  other : StarlarkString,
) -> Bool {
  self.bytes == other.bytes
}

///|
pub(all) struct StarlarkList {
  mut items : Array[Value]
  mut frozen : Bool
  mut itercount : Int
}

///|
pub fn StarlarkList::new(items : Array[Value]) -> StarlarkList {
  { items, frozen: false, itercount: 0 }
}

///|
pub fn StarlarkList::is_frozen(self : StarlarkList) -> Bool {
  self.frozen
}

///|
pub fn StarlarkList::freeze(self : StarlarkList) -> Unit {
  self.frozen = true
}

///|
pub fn StarlarkList::check_mutable(
  self : StarlarkList,
  verb : String,
) -> Result[Unit, String] {
  if self.frozen {
    Err("cannot \{verb} frozen list")
  } else if self.itercount > 0 {
    Err("cannot \{verb} list during iteration")
  } else {
    Ok(())
  }
}

///|
pub(all) struct StarlarkRange {
  start : Int64
  stop : Int64
  step : Int64
}

///|
pub fn StarlarkRange::new(
  start : Int64,
  stop : Int64,
  step : Int64,
) -> StarlarkRange {
  { start, stop, step }
}

///|
pub fn StarlarkRange::length(self : StarlarkRange) -> Int {
  if self.step > 0L {
    if self.stop > self.start {
      return ((self.stop - self.start - 1L) / self.step + 1L).to_int()
    }
  } else if self.step < 0L {
    if self.start > self.stop {
      return ((self.start - self.stop - 1L) / -self.step + 1L).to_int()
    }
  }
  0
}

///|
pub fn StarlarkRange::index_at(self : StarlarkRange, i : Int) -> Int64 {
  self.start + self.step * i.to_int64()
}

///|
pub fn StarlarkRange::contains(self : StarlarkRange, n : Int64) -> Bool {
  if self.step > 0L {
    n >= self.start && n < self.stop && (n - self.start) % self.step == 0L
  } else if self.step < 0L {
    n <= self.start && n > self.stop && (n - self.start) % self.step == 0L
  } else {
    false
  }
}

///|
pub(all) struct StarlarkFunction {
  name : String
  params : Array[@syntax.Param]
  body : Array[@syntax.Stmt]
  defaults : Array[Value?]
  captured_scope : Array[Map[String, Value]]
}

///|
pub(all) struct BuiltinCallCtx {
  call : (Value, Array[Value], Array[(String, Value)]) -> Result[Value, String]
}

///|
pub(all) struct StarlarkBuiltinFunc {
  name : String
  body : ((BuiltinCallCtx, Array[Value], Array[(String, Value)]) -> Result[
    Value,
    String,
  ])?
}

///|
pub(all) struct StarlarkBoundMethod {
  recv : Value
  method_name : String
}

///|
pub(all) struct StarlarkModule {
  name : String
  attrs : Map[String, Value]
}

///|
pub fn StarlarkModule::new(
  name : String,
  attrs : Map[String, Value],
) -> StarlarkModule {
  { name, attrs }
}

///|
pub fn StarlarkModule::get(self : StarlarkModule, key : String) -> Value? {
  self.attrs.get(key)
}

///|
pub(all) enum Value {
  NoneVal
  BoolVal(Bool)
  IntVal(Int64)
  FloatVal(Double)
  StrVal(StarlarkString)
  BytesVal(Bytes)
  ListVal(StarlarkList)
  TupleVal(Array[Value])
  DictVal(StarlarkDict)
  SetVal(StarlarkSet)
  RangeVal(StarlarkRange)
  FuncVal(StarlarkFunction)
  BuiltinFuncVal(StarlarkBuiltinFunc)
  BoundMethodVal(StarlarkBoundMethod)
  ModuleVal(StarlarkModule)
}

///|
pub fn type_name(v : Value) -> String {
  match v {
    NoneVal => "NoneType"
    BoolVal(_) => "bool"
    IntVal(_) => "int"
    FloatVal(_) => "float"
    StrVal(_) => "string"
    BytesVal(_) => "bytes"
    ListVal(_) => "list"
    TupleVal(_) => "tuple"
    DictVal(_) => "dict"
    SetVal(_) => "set"
    RangeVal(_) => "range"
    FuncVal(_) => "function"
    BuiltinFuncVal(_) => "builtin_function_or_method"
    BoundMethodVal(_) => "builtin_function_or_method"
    ModuleVal(_) => "module"
  }
}

///|
pub fn truth(v : Value) -> Bool {
  match v {
    NoneVal => false
    BoolVal(b) => b
    IntVal(i) => i != 0L
    FloatVal(f) => f != 0.0
    StrVal(s) => s.byte_len() > 0
    BytesVal(b) => b.length() > 0
    ListVal(l) => l.items.is_empty() == false
    TupleVal(t) => t.is_empty() == false
    DictVal(d) => d.length() > 0
    SetVal(s) => s.length() > 0
    RangeVal(r) => r.length() > 0
    FuncVal(_) => true
    BuiltinFuncVal(_) => true
    BoundMethodVal(_) => true
    ModuleVal(_) => true
  }
}

///|
pub fn floor_div(a : Int64, b : Int64) -> Result[Int64, String] {
  if b == 0L {
    return Err("integer division by zero")
  }
  let q = a / b
  let r = a % b
  if r != 0L && (r < 0L) != (b < 0L) {
    Ok(q - 1L)
  } else {
    Ok(q)
  }
}

///|
pub fn starlark_mod(a : Int64, b : Int64) -> Result[Int64, String] {
  if b == 0L {
    return Err("integer modulo by zero")
  }
  let r = a % b
  if r != 0L && (r < 0L) != (b < 0L) {
    Ok(r + b)
  } else {
    Ok(r)
  }
}

///|
fn is_neg_zero(f : Double) -> Bool {
  f == 0.0 && f.reinterpret_as_int64() < 0L
}

///|
fn format_float(f : Double) -> String {
  if f.is_nan() {
    return "nan"
  }
  if f == @double.infinity {
    return "+inf"
  }
  if f == @double.neg_infinity {
    return "-inf"
  }
  if is_neg_zero(f) {
    return "-0.0"
  }
  let s = f.to_string()
  if s.contains(".") || s.contains("e") || s.contains("E") {
    s
  } else {
    s + ".0"
  }
}

///|
fn hex_char(n : Int) -> Char {
  if n < 10 {
    ('0'.to_int() + n).unsafe_to_char()
  } else {
    ('a'.to_int() + n - 10).unsafe_to_char()
  }
}

///|
fn utf8_decode_rune(b : Bytes, pos : Int) -> (Int, Int) {
  let b0 = b[pos].to_int()
  if b0 < 0x80 {
    return (b0, 1)
  }
  let len = b.length()
  if b0 >= 0xC2 && b0 <= 0xDF && pos + 1 < len {
    let b1 = b[pos + 1].to_int()
    if b1 >= 0x80 && b1 <= 0xBF {
      let r = ((b0 & 0x1F) << 6) | (b1 & 0x3F)
      return (r, 2)
    }
  } else if b0 >= 0xE0 && b0 <= 0xEF && pos + 2 < len {
    let b1 = b[pos + 1].to_int()
    let b2 = b[pos + 2].to_int()
    if b1 >= 0x80 && b1 <= 0xBF && b2 >= 0x80 && b2 <= 0xBF {
      let r = ((b0 & 0x0F) << 12) | ((b1 & 0x3F) << 6) | (b2 & 0x3F)
      if r >= 0x0800 && !(r >= 0xD800 && r <= 0xDFFF) {
        return (r, 3)
      }
    }
  } else if b0 >= 0xF0 && b0 <= 0xF4 && pos + 3 < len {
    let b1 = b[pos + 1].to_int()
    let b2 = b[pos + 2].to_int()
    let b3 = b[pos + 3].to_int()
    if b1 >= 0x80 &&
      b1 <= 0xBF &&
      b2 >= 0x80 &&
      b2 <= 0xBF &&
      b3 >= 0x80 &&
      b3 <= 0xBF {
      let r = ((b0 & 0x07) << 18) |
        ((b1 & 0x3F) << 12) |
        ((b2 & 0x3F) << 6) |
        (b3 & 0x3F)
      if r >= 0x10000 && r <= 0x10FFFF {
        return (r, 4)
      }
    }
  }
  (-1, 1)
}

///|
fn is_unicode_printable(r : Int) -> Bool {
  if r < 0x20 || r == 0x7F {
    return false
  }
  if r < 0x80 {
    return true
  }
  if r == 0xAD {
    return false
  }
  if r >= 0x2028 && r <= 0x2029 {
    return false
  }
  if r >= 0xFFF9 && r <= 0xFFFB {
    return false
  }
  if r >= 0x200B && r <= 0x200F {
    return false
  }
  if r >= 0x202A && r <= 0x202E {
    return false
  }
  if r >= 0x2060 && r <= 0x2064 {
    return false
  }
  if r >= 0x2066 && r <= 0x206F {
    return false
  }
  if r == 0xFEFF {
    return false
  }
  true
}

///|
fn write_unicode_escape(r : Int, buf : StringBuilder) -> Unit {
  if r < 0x10000 {
    buf.write_string("\\u")
    buf.write_char(hex_char((r >> 12) & 0xF))
    buf.write_char(hex_char((r >> 8) & 0xF))
    buf.write_char(hex_char((r >> 4) & 0xF))
    buf.write_char(hex_char(r & 0xF))
  } else {
    buf.write_string("\\U")
    buf.write_char(hex_char((r >> 28) & 0xF))
    buf.write_char(hex_char((r >> 24) & 0xF))
    buf.write_char(hex_char((r >> 20) & 0xF))
    buf.write_char(hex_char((r >> 16) & 0xF))
    buf.write_char(hex_char((r >> 12) & 0xF))
    buf.write_char(hex_char((r >> 8) & 0xF))
    buf.write_char(hex_char((r >> 4) & 0xF))
    buf.write_char(hex_char(r & 0xF))
  }
}

///|
fn repr_bytes_inner(b : Bytes, buf : StringBuilder, quote_char : Char) -> Unit {
  let len = b.length()
  let mut i = 0
  while i < len {
    let byte_val = b[i].to_int()
    match byte_val {
      0x5C => {
        buf.write_string("\\\\")
        i += 1
      }
      0x0A => {
        buf.write_string("\\n")
        i += 1
      }
      0x0D => {
        buf.write_string("\\r")
        i += 1
      }
      0x09 => {
        buf.write_string("\\t")
        i += 1
      }
      n =>
        if n.unsafe_to_char() == quote_char {
          buf.write_char('\\')
          buf.write_char(quote_char)
          i += 1
        } else if n >= 0x20 && n < 0x7F {
          buf.write_char(n.unsafe_to_char())
          i += 1
        } else if n >= 0x80 {
          let (r, width) = utf8_decode_rune(b, i)
          if r >= 0 && is_unicode_printable(r) {
            buf.write_char(r.unsafe_to_char())
            i += width
          } else if r >= 0 {
            write_unicode_escape(r, buf)
            i += width
          } else {
            buf.write_string("\\x")
            buf.write_char(hex_char((n >> 4) & 0xF))
            buf.write_char(hex_char(n & 0xF))
            i += 1
          }
        } else {
          buf.write_string("\\x")
          buf.write_char(hex_char((n >> 4) & 0xF))
          buf.write_char(hex_char(n & 0xF))
          i += 1
        }
    }
  }
}

///|
fn repr_string_val(s : StarlarkString) -> String {
  let buf = StringBuilder::new()
  buf.write_char('"')
  repr_bytes_inner(s.bytes, buf, '"')
  buf.write_char('"')
  buf.to_string()
}

///|
fn repr_bytes_val(b : Bytes) -> String {
  let buf = StringBuilder::new()
  buf.write_string("b\"")
  repr_bytes_inner(b, buf, '"')
  buf.write_char('"')
  buf.to_string()
}

///|
pub fn repr(v : Value) -> String {
  match v {
    NoneVal => "None"
    BoolVal(true) => "True"
    BoolVal(false) => "False"
    IntVal(i) => i.to_string()
    FloatVal(f) => format_float(f)
    StrVal(s) => repr_string_val(s)
    BytesVal(b) => repr_bytes_val(b)
    ListVal(l) => repr_list(l)
    TupleVal(t) => repr_tuple(t)
    DictVal(d) => repr_dict(d)
    SetVal(s) => repr_set(s)
    RangeVal(r) => repr_range(r)
    FuncVal(f) => "<function \{f.name}>"
    BuiltinFuncVal(f) => "<built-in function \{f.name}>"
    BoundMethodVal(m) =>
      "<built-in method \{m.method_name} of \{type_name(m.recv)} value>"
    ModuleVal(m) => "<module \{m.name}>"
  }
}

///|
fn repr_range(r : StarlarkRange) -> String {
  if r.step == 1L {
    if r.start == 0L {
      "range(\{r.stop})"
    } else {
      "range(\{r.start}, \{r.stop})"
    }
  } else {
    "range(\{r.start}, \{r.stop}, \{r.step})"
  }
}

///|
fn repr_dict(d : StarlarkDict) -> String {
  if d.length() == 0 {
    return "{}"
  }
  let buf = StringBuilder::new()
  buf.write_char('{')
  let mut first = true
  d.each(fn(k, v) {
    if first == false {
      buf.write_string(", ")
    }
    first = false
    buf.write_string(repr(k))
    buf.write_string(": ")
    buf.write_string(repr(v))
  })
  buf.write_char('}')
  buf.to_string()
}

///|
fn repr_set(s : StarlarkSet) -> String {
  let buf = StringBuilder::new()
  buf.write_string("set([")
  let mut first = true
  s.each(fn(k) {
    if first == false {
      buf.write_string(", ")
    }
    first = false
    buf.write_string(repr(k))
  })
  buf.write_string("])")
  buf.to_string()
}

///|
fn repr_list(l : StarlarkList) -> String {
  let buf = StringBuilder::new()
  buf.write_char('[')
  for i in 0..<l.items.length() {
    if i > 0 {
      buf.write_string(", ")
    }
    buf.write_string(repr(l.items[i]))
  }
  buf.write_char(']')
  buf.to_string()
}

///|
fn repr_tuple(t : Array[Value]) -> String {
  let buf = StringBuilder::new()
  buf.write_char('(')
  for i in 0..<t.length() {
    if i > 0 {
      buf.write_string(", ")
    }
    buf.write_string(repr(t[i]))
  }
  if t.length() == 1 {
    buf.write_char(',')
  }
  buf.write_char(')')
  buf.to_string()
}
