///|
pub struct StarlarkString {
  priv raw : String
  priv bytes : Bytes
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
pub fn StarlarkString::to_bytes(self : StarlarkString) -> Bytes {
  self.bytes
}

///|
pub fn StarlarkString::raw(self : StarlarkString) -> String {
  self.raw
}

///|
pub struct StarlarkList {
  priv mut items : Array[Value]
  priv mut frozen : Bool
  priv mut itercount : Int
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
pub fn StarlarkList::length(self : StarlarkList) -> Int {
  self.items.length()
}

///|
pub fn StarlarkList::is_empty(self : StarlarkList) -> Bool {
  self.items.is_empty()
}

///|
pub fn StarlarkList::get(self : StarlarkList, i : Int) -> Value {
  self.items[i]
}

///|
pub fn StarlarkList::iter(self : StarlarkList) -> Iter[Value] {
  self.items.iter()
}

///|
pub fn StarlarkList::eachi(
  self : StarlarkList,
  f : (Int, Value) -> Unit,
) -> Unit {
  self.items.eachi(f)
}

///|
pub fn StarlarkList::is_same_storage(
  self : StarlarkList,
  other : StarlarkList,
) -> Bool {
  physical_equal(self.items, other.items)
}

///|
pub fn StarlarkList::push(
  self : StarlarkList,
  v : Value,
) -> Result[Unit, String] {
  match self.check_mutable("append to") {
    Err(e) => Err(e)
    Ok(_) => {
      self.items.push(v)
      Ok(())
    }
  }
}

///|
pub fn StarlarkList::pop(self : StarlarkList) -> Result[Value?, String] {
  match self.check_mutable("pop from") {
    Err(e) => Err(e)
    Ok(_) => Ok(self.items.pop())
  }
}

///|
pub fn StarlarkList::pop_at(
  self : StarlarkList,
  i : Int,
) -> Result[Value, String] {
  match self.check_mutable("remove from") {
    Err(e) => Err(e)
    Ok(_) => Ok(self.items.remove(i))
  }
}

///|
pub fn StarlarkList::insert(
  self : StarlarkList,
  i : Int,
  v : Value,
) -> Result[Unit, String] {
  match self.check_mutable("insert into") {
    Err(e) => Err(e)
    Ok(_) => {
      self.items.insert(i, v)
      Ok(())
    }
  }
}

///|
pub fn StarlarkList::set(
  self : StarlarkList,
  i : Int,
  v : Value,
) -> Result[Unit, String] {
  match self.check_mutable("assign to element of") {
    Err(e) => Err(e)
    Ok(_) => {
      self.items[i] = v
      Ok(())
    }
  }
}

///|
pub fn StarlarkList::clear(self : StarlarkList) -> Result[Unit, String] {
  match self.check_mutable("clear") {
    Err(e) => Err(e)
    Ok(_) => {
      self.items.clear()
      Ok(())
    }
  }
}

///|
pub fn StarlarkList::sort_by(
  self : StarlarkList,
  cmp : (Value, Value) -> Int,
) -> Result[Unit, String] {
  match self.check_mutable("sort") {
    Err(e) => Err(e)
    Ok(_) => {
      self.items.sort_by(cmp)
      Ok(())
    }
  }
}

///|
pub fn StarlarkList::reverse(self : StarlarkList) -> Result[Unit, String] {
  match self.check_mutable("reverse") {
    Err(e) => Err(e)
    Ok(_) => {
      let n = self.items.length()
      let mut i = 0
      while i < n / 2 {
        let tmp = self.items[i]
        self.items[i] = self.items[n - 1 - i]
        self.items[n - 1 - i] = tmp
        i += 1
      }
      Ok(())
    }
  }
}

///|
pub struct StarlarkRange {
  priv start : Int64
  priv stop : Int64
  priv step : Int64
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
pub fn StarlarkRange::start(self : StarlarkRange) -> Int64 {
  self.start
}

///|
pub fn StarlarkRange::stop(self : StarlarkRange) -> Int64 {
  self.stop
}

///|
pub fn StarlarkRange::step(self : StarlarkRange) -> Int64 {
  self.step
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
pub struct StarlarkFunction {
  priv name : String
  priv params : Array[@syntax.Param]
  priv body : Array[@syntax.Stmt]
  priv defaults : Array[Value?]
  priv captured_scope : Array[Map[String, Value]]
}

///|
pub fn StarlarkFunction::new(
  name : String,
  params : Array[@syntax.Param],
  body : Array[@syntax.Stmt],
  defaults : Array[Value?],
  captured_scope : Array[Map[String, Value]],
) -> StarlarkFunction {
  { name, params, body, defaults, captured_scope }
}

///|
pub fn StarlarkFunction::name(self : StarlarkFunction) -> String {
  self.name
}

///|
pub fn StarlarkFunction::params(
  self : StarlarkFunction,
) -> Array[@syntax.Param] {
  self.params
}

///|
pub fn StarlarkFunction::body(self : StarlarkFunction) -> Array[@syntax.Stmt] {
  self.body
}

///|
pub fn StarlarkFunction::defaults(self : StarlarkFunction) -> Array[Value?] {
  self.defaults
}

///|
pub fn StarlarkFunction::captured_scope(
  self : StarlarkFunction,
) -> Array[Map[String, Value]] {
  self.captured_scope
}

///|
pub struct BuiltinCallCtx {
  priv call : (Value, Array[Value], Array[(String, Value)]) -> Result[
    Value,
    String,
  ]
}

///|
pub fn BuiltinCallCtx::new(
  call : (Value, Array[Value], Array[(String, Value)]) -> Result[Value, String],
) -> BuiltinCallCtx {
  { call, }
}

///|
pub fn BuiltinCallCtx::invoke(
  self : BuiltinCallCtx,
  callee : Value,
  args : Array[Value],
  kwargs : Array[(String, Value)],
) -> Result[Value, String] {
  (self.call)(callee, args, kwargs)
}

///|
pub struct StarlarkBuiltinFunc {
  priv name : String
  priv body : ((BuiltinCallCtx, Array[Value], Array[(String, Value)]) -> Result[
    Value,
    String,
  ])?
}

///|
pub fn StarlarkBuiltinFunc::dispatch(name : String) -> StarlarkBuiltinFunc {
  { name, body: None }
}

///|
pub fn StarlarkBuiltinFunc::name(self : StarlarkBuiltinFunc) -> String {
  self.name
}

///|
pub fn StarlarkBuiltinFunc::call_body(
  self : StarlarkBuiltinFunc,
  ctx : BuiltinCallCtx,
  pos_args : Array[Value],
  kw_args : Array[(String, Value)],
) -> Result[Value, String]? {
  match self.body {
    None => None
    Some(f) => Some(f(ctx, pos_args, kw_args))
  }
}

///|
let bound_method_id_counter : Ref[Int] = { val: 0 }

///|
pub struct StarlarkBoundMethod {
  priv recv : Value
  priv method_name : String
  priv id : Int
}

///|
pub fn StarlarkBoundMethod::new(
  recv : Value,
  method_name : String,
) -> StarlarkBoundMethod {
  let id = bound_method_id_counter.val
  bound_method_id_counter.val += 1
  { recv, method_name, id }
}

///|
pub fn StarlarkBoundMethod::recv(self : StarlarkBoundMethod) -> Value {
  self.recv
}

///|
pub fn StarlarkBoundMethod::method_name(self : StarlarkBoundMethod) -> String {
  self.method_name
}

///|
pub struct StarlarkModule {
  priv name : String
  priv attrs : Map[String, Value]
}

///|
pub fn StarlarkModule::new(
  name : String,
  attrs : Map[String, Value],
) -> StarlarkModule {
  { name, attrs }
}

///|
pub fn StarlarkModule::name(self : StarlarkModule) -> String {
  self.name
}

///|
pub fn StarlarkModule::get(self : StarlarkModule, key : String) -> Value? {
  self.attrs.get(key)
}

///|
pub fn StarlarkModule::attr_names(self : StarlarkModule) -> Array[String] {
  self.attrs.keys().collect()
}

///|
pub(all) enum Value {
  None
  Bool(Bool)
  Int(Int64)
  Float(Double)
  String(StarlarkString)
  Bytes(Bytes)
  List(StarlarkList)
  Tuple(Array[Value])
  Dict(StarlarkDict)
  Set(StarlarkSet)
  Range(StarlarkRange)
  Function(StarlarkFunction)
  Builtin(StarlarkBuiltinFunc)
  BoundMethod(StarlarkBoundMethod)
  Module(StarlarkModule)
}

///|
pub fn Value::of_string(s : String) -> Value {
  String(StarlarkString::new(s))
}

///|
pub fn Value::new_list(items : Array[Value]) -> Value {
  List(StarlarkList::new(items))
}

///|
pub fn Value::new_dict() -> Value {
  Dict(StarlarkDict::new())
}

///|
pub fn Value::new_set() -> Value {
  Set(StarlarkSet::new())
}

///|
pub fn Value::new_builtin(
  name : String,
  body : (BuiltinCallCtx, Array[Value], Array[(String, Value)]) -> Result[
    Value,
    String,
  ],
) -> Value {
  Builtin({ name, body: Some(body) })
}

///|
pub fn type_name(v : Value) -> String {
  match v {
    None => "NoneType"
    Bool(_) => "bool"
    Int(_) => "int"
    Float(_) => "float"
    String(_) => "string"
    Bytes(_) => "bytes"
    List(_) => "list"
    Tuple(_) => "tuple"
    Dict(_) => "dict"
    Set(_) => "set"
    Range(_) => "range"
    Function(_) => "function"
    Builtin(_) => "builtin_function_or_method"
    BoundMethod(_) => "builtin_function_or_method"
    Module(_) => "module"
  }
}

///|
pub fn truth(v : Value) -> Bool {
  match v {
    None => false
    Bool(b) => b
    Int(i) => i != 0L
    Float(f) => f != 0.0
    String(s) => s.byte_len() > 0
    Bytes(b) => b.length() > 0
    List(l) => l.items.is_empty() == false
    Tuple(t) => t.is_empty() == false
    Dict(d) => d.length() > 0
    Set(s) => s.length() > 0
    Range(r) => r.length() > 0
    Function(_) => true
    Builtin(_) => true
    BoundMethod(_) => true
    Module(_) => true
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
fn write_unicode_escape(r : Int, buf : StringBuilder) -> Unit {
  if r < 0x10000 {
    buf.write_string("\\u")
    @utf8util.write_hex4(buf, r)
  } else {
    buf.write_string("\\U")
    @utf8util.write_hex8(buf, r)
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
          let (r, width) = @utf8util.utf8_decode_rune(b, i)
          if r >= 0 && @utf8util.is_unicode_printable(r) {
            buf.write_char(r.unsafe_to_char())
            i += width
          } else if r >= 0 {
            write_unicode_escape(r, buf)
            i += width
          } else {
            buf.write_string("\\x")
            @utf8util.write_hex2(buf, n)
            i += 1
          }
        } else {
          buf.write_string("\\x")
          @utf8util.write_hex2(buf, n)
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
    None => "None"
    Bool(true) => "True"
    Bool(false) => "False"
    Int(i) => i.to_string()
    Float(f) => format_float(f)
    String(s) => repr_string_val(s)
    Bytes(b) => repr_bytes_val(b)
    List(l) => repr_list(l)
    Tuple(t) => repr_tuple(t)
    Dict(d) => repr_dict(d)
    Set(s) => repr_set(s)
    Range(r) => repr_range(r)
    Function(f) => "<function \{f.name}>"
    Builtin(f) => "<built-in function \{f.name}>"
    BoundMethod(m) =>
      "<built-in method \{m.method_name} of \{type_name(m.recv)} value>"
    Module(m) => "<module \"\{m.name}\">"
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
