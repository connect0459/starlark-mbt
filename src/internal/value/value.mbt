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
}

///|
pub fn StarlarkList::new(items : Array[Value]) -> StarlarkList {
  { items, frozen: false }
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
fn repr_bytes_inner(b : Bytes, buf : StringBuilder, quote_char : Char) -> Unit {
  for i in 0..<b.length() {
    let byte_val = b[i].to_int()
    match byte_val {
      0x5C => buf.write_string("\\\\") // backslash
      0x0A => buf.write_string("\\n")
      0x0D => buf.write_string("\\r")
      0x09 => buf.write_string("\\t")
      n =>
        if n.unsafe_to_char() == quote_char {
          buf.write_char('\\')
          buf.write_char(quote_char)
        } else if n >= 0x20 && n < 0x7F {
          buf.write_char(n.unsafe_to_char())
        } else {
          buf.write_string("\\x")
          buf.write_char(hex_char((n >> 4) & 0xF))
          buf.write_char(hex_char(n & 0xF))
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
  if s.length() == 0 {
    return "set()"
  }
  let buf = StringBuilder::new()
  buf.write_char('{')
  let mut first = true
  s.each(fn(k) {
    if first == false {
      buf.write_string(", ")
    }
    first = false
    buf.write_string(repr(k))
  })
  buf.write_char('}')
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
