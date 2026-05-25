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
  freevars : Array[Value]
}

///|
pub(all) struct StarlarkBuiltinFunc {
  name : String
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
    RangeVal(r) => repr_range(r)
    FuncVal(f) => "<function \{f.name}>"
    BuiltinFuncVal(f) => "<built-in function \{f.name}>"
    BoundMethodVal(m) =>
      "<built-in method \{m.method_name} of \{type_name(m.recv)} object>"
    ModuleVal(m) => "<module \{m.name}>"
  }
}

///|
fn repr_range(r : StarlarkRange) -> String {
  if r.step == 1L {
    "range(\{r.start}, \{r.stop})"
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
