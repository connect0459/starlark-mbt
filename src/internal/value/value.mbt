///|
/// An immutable Starlark string backed by a pre-computed UTF-8 `Bytes` array.
/// All length, indexing, and hashing operations use the byte array so that
/// `s[i]` returns the i-th byte, matching starlark-go semantics.
pub struct StarlarkString {
  priv raw : String
  priv bytes : Bytes
}

///|
/// Creates a `StarlarkString` from a MoonBit `String`, encoding it to UTF-8.
pub fn StarlarkString::new(raw : String) -> StarlarkString {
  let bytes = @utf8.encode(raw)
  { raw, bytes }
}

///|
/// Creates a `StarlarkString` from a raw UTF-8 byte sequence. Invalid bytes
/// are replaced with U+FFFD.
pub fn StarlarkString::from_bytes(bytes : Bytes) -> StarlarkString {
  let raw = @utf8.decode_lossy(bytes[:])
  { raw, bytes }
}

///|
/// Returns the number of UTF-8 bytes in the string (the Starlark `len()`).
pub fn StarlarkString::byte_len(self : StarlarkString) -> Int {
  self.bytes.length()
}

///|
/// Returns the byte at UTF-8 offset `i`.
pub fn StarlarkString::byte_at(self : StarlarkString, i : Int) -> Byte {
  self.bytes[i]
}

///|
/// Returns `true` if `self` and `other` contain the same bytes.
pub fn StarlarkString::equals(
  self : StarlarkString,
  other : StarlarkString,
) -> Bool {
  self.bytes == other.bytes
}

///|
/// Returns the underlying UTF-8 `Bytes` array.
pub fn StarlarkString::to_bytes(self : StarlarkString) -> Bytes {
  self.bytes
}

///|
/// Returns the MoonBit `String` (UTF-16 internally) that was used to create
/// this `StarlarkString`.
pub fn StarlarkString::raw(self : StarlarkString) -> String {
  self.raw
}

///|
/// A mutable, ordered sequence of Starlark values. Mutation is rejected when
/// the list is frozen or has active iterators.
pub struct StarlarkList {
  priv mut items : Array[Value]
  priv mut frozen : Bool
  priv mut itercount : Int
}

///|
/// Creates a new, unfrozen `StarlarkList` wrapping `items`.
pub fn StarlarkList::new(items : Array[Value]) -> StarlarkList {
  { items, frozen: false, itercount: 0 }
}

///|
/// Returns `true` if the list has been frozen.
pub fn StarlarkList::is_frozen(self : StarlarkList) -> Bool {
  self.frozen
}

///|
/// Marks the list as frozen; subsequent mutation attempts raise an error.
pub fn StarlarkList::freeze(self : StarlarkList) -> Unit {
  self.frozen = true
}

///|
/// Returns `Ok(())` if the list can be mutated, otherwise `Err` with a
/// descriptive message using `verb` (e.g. `"append to"`, `"clear"`).
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
/// Returns the number of elements in the list.
pub fn StarlarkList::length(self : StarlarkList) -> Int {
  self.items.length()
}

///|
/// Returns `true` if the list contains no elements.
pub fn StarlarkList::is_empty(self : StarlarkList) -> Bool {
  self.items.is_empty()
}

///|
/// Returns the element at index `i` (unchecked).
pub fn StarlarkList::get(self : StarlarkList, i : Int) -> Value {
  self.items[i]
}

///|
/// Returns a lazy iterator over the list elements.
pub fn StarlarkList::iter(self : StarlarkList) -> Iter[Value] {
  self.items.iter()
}

///|
/// Returns a lazy iterator over the list elements (alias for `iter`).
pub fn StarlarkList::to_iter(self : StarlarkList) -> Iter[Value] {
  self.items.iter()
}

///|
/// Calls `f(index, value)` for each element.
pub fn StarlarkList::eachi(
  self : StarlarkList,
  f : (Int, Value) -> Unit,
) -> Unit {
  self.items.eachi(f)
}

///|
/// Returns `true` if `self` and `other` share the same underlying array
/// (identity, not equality). Used to detect self-extend operations.
pub fn StarlarkList::is_same_storage(
  self : StarlarkList,
  other : StarlarkList,
) -> Bool {
  physical_equal(self.items, other.items)
}

///|
/// Returns a copy of the underlying items array.
pub fn StarlarkList::copy_items(self : StarlarkList) -> Array[Value] {
  self.items.copy()
}

///|
/// Appends `v` to the end of the list. Fails if the list is frozen or being
/// iterated.
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
/// Removes and returns the last element, or `None` if the list is empty.
/// Fails if the list is frozen or being iterated.
pub fn StarlarkList::pop(self : StarlarkList) -> Result[Value?, String] {
  match self.check_mutable("pop from") {
    Err(e) => Err(e)
    Ok(_) => Ok(self.items.pop())
  }
}

///|
/// Removes and returns the element at index `i`. Fails if the list is frozen
/// or being iterated.
pub fn StarlarkList::pop_at(
  self : StarlarkList,
  i : Int,
  verb? : String = "remove from",
) -> Result[Value, String] {
  match self.check_mutable(verb) {
    Err(e) => Err(e)
    Ok(_) => Ok(self.items.remove(i))
  }
}

///|
/// Inserts `v` at index `i`, shifting subsequent elements right. Fails if
/// the list is frozen or being iterated.
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
/// Replaces the element at index `i` with `v`. Fails if the list is frozen
/// or being iterated.
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
/// Removes all elements. Fails if the list is frozen or being iterated.
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
/// Sorts the list in place using `cmp`. Fails if the list is frozen or being
/// iterated.
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
/// Reverses the list in place. Fails if the list is frozen or being iterated.
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
/// A lazy, immutable arithmetic sequence returned by `range()`. Not a list;
/// supports membership testing and indexing without materialising all elements.
pub struct StarlarkRange {
  priv start : Int64
  priv stop : Int64
  priv step : Int64
}

///|
/// Creates a `StarlarkRange` with the given start, stop, and step.
pub fn StarlarkRange::new(
  start : Int64,
  stop : Int64,
  step : Int64,
) -> StarlarkRange {
  { start, stop, step }
}

///|
/// Returns the start of the range.
pub fn StarlarkRange::start(self : StarlarkRange) -> Int64 {
  self.start
}

///|
/// Returns the stop (exclusive end) of the range.
pub fn StarlarkRange::stop(self : StarlarkRange) -> Int64 {
  self.stop
}

///|
/// Returns the step of the range.
pub fn StarlarkRange::step(self : StarlarkRange) -> Int64 {
  self.step
}

///|
/// Returns the number of elements in the range.
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
/// Returns the value at position `i` within the range.
pub fn StarlarkRange::index_at(self : StarlarkRange, i : Int) -> Int64 {
  self.start + self.step * i.to_int64()
}

///|
/// Returns `true` if `n` is a member of the range.
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
  priv captured_scope : Array[(Map[String, Value], Array[String])]
  priv pos : @errors.Position
  priv module_globals : Map[String, Value]?
}

///|
pub fn StarlarkFunction::new(
  name : String,
  params : Array[@syntax.Param],
  body : Array[@syntax.Stmt],
  defaults : Array[Value?],
  captured_scope : Array[(Map[String, Value], Array[String])],
  pos : @errors.Position,
) -> StarlarkFunction {
  { name, params, body, defaults, captured_scope, pos, module_globals: None }
}

///|
pub fn StarlarkFunction::name(self : StarlarkFunction) -> String {
  self.name
}

///|
pub fn StarlarkFunction::position(self : StarlarkFunction) -> @errors.Position {
  self.pos
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
) -> Array[(Map[String, Value], Array[String])] {
  self.captured_scope
}

///|
pub fn StarlarkFunction::with_module_globals(
  self : StarlarkFunction,
  g : Map[String, Value],
) -> StarlarkFunction {
  { ..self, module_globals: Some(g) }
}

///|
pub fn StarlarkFunction::globals(self : StarlarkFunction) -> Map[String, Value] {
  match self.module_globals {
    Some(g) => g
    None => {}
  }
}

///|
pub fn StarlarkFunction::defining_module(
  self : StarlarkFunction,
) -> StarlarkModule? {
  match self.module_globals {
    None => None
    Some(globals) => Some(StarlarkModule::new(self.pos.filename(), globals))
  }
}

///|
pub fn StarlarkFunction::doc(self : StarlarkFunction) -> String {
  match self.body {
    [
      @syntax.Stmt::SExpr(
        @syntax.Expr::ELiteral(@syntax.LiteralVal::LitString(s), _)
      ),
      ..,
    ] => s
    _ => ""
  }
}

///|
pub fn StarlarkFunction::has_varargs(self : StarlarkFunction) -> Bool {
  for p in self.params {
    if p is @syntax.Param::ParamStarIdent(_, _) {
      return true
    }
  }
  false
}

///|
pub fn StarlarkFunction::has_kwargs(self : StarlarkFunction) -> Bool {
  for p in self.params {
    if p is @syntax.Param::ParamKwIdent(_, _) {
      return true
    }
  }
  false
}

///|
pub fn StarlarkFunction::num_params(self : StarlarkFunction) -> Int {
  let mut count = 0
  for p in self.params {
    match p {
      @syntax.Param::ParamStarBare(_) => ()
      _ => count = count + 1
    }
  }
  count
}

///|
pub fn StarlarkFunction::num_kwonly_params(self : StarlarkFunction) -> Int {
  let mut after_star = false
  let mut count = 0
  for p in self.params {
    match p {
      @syntax.Param::ParamStarBare(_) | @syntax.Param::ParamStarIdent(_, _) =>
        after_star = true
      @syntax.Param::ParamKwIdent(_, _) => ()
      @syntax.Param::ParamIdent(_, _) | @syntax.Param::ParamDefault(_, _, _) =>
        if after_star {
          count = count + 1
        }
    }
  }
  count
}

///|
pub fn StarlarkFunction::param(
  self : StarlarkFunction,
  i : Int,
) -> (String, @errors.Position) {
  let mut idx = 0
  for p in self.params {
    match p {
      @syntax.Param::ParamStarBare(_) => ()
      @syntax.Param::ParamIdent(name, pos) => {
        if idx == i {
          return (name, pos)
        }
        idx = idx + 1
      }
      @syntax.Param::ParamDefault(name, _, pos) => {
        if idx == i {
          return (name, pos)
        }
        idx = idx + 1
      }
      @syntax.Param::ParamStarIdent(name, pos) => {
        if idx == i {
          return (name, pos)
        }
        idx = idx + 1
      }
      @syntax.Param::ParamKwIdent(name, pos) => {
        if idx == i {
          return (name, pos)
        }
        idx = idx + 1
      }
    }
  }
  abort("StarlarkFunction::param: index \{i} out of range")
}

///|
pub fn StarlarkFunction::param_default(
  self : StarlarkFunction,
  i : Int,
) -> Value? {
  if i < 0 || i >= self.defaults.length() {
    return None
  }
  self.defaults[i]
}

///|
pub fn StarlarkFunction::num_free_vars(self : StarlarkFunction) -> Int {
  let mut total = 0
  for scope in self.captured_scope {
    total = total + scope.0.length()
  }
  total
}

///|
pub fn StarlarkFunction::free_var(
  self : StarlarkFunction,
  i : Int,
) -> (String, Value)? {
  let mut idx = 0
  let mut result : (String, Value)? = None
  for scope in self.captured_scope {
    scope.0.each(fn(name, v) {
      if idx == i && result is None {
        result = Some((name, v))
      }
      idx = idx + 1
    })
    if result is Some(_) {
      break
    }
  }
  result
}

///|
pub struct BuiltinCallCtx {
  priv call : (Value, Array[Value], Array[(String, Value)]) -> Result[
    Value,
    String,
  ]
  priv get_local_fn : (String) -> Value?
}

///|
pub fn BuiltinCallCtx::new(
  call : (Value, Array[Value], Array[(String, Value)]) -> Result[Value, String],
  get_local? : (String) -> Value? = fn(_) { None },
) -> BuiltinCallCtx {
  { call, get_local_fn: get_local }
}

///|
/// Reads the active thread's thread-local value for `key`. Used by extension
/// builtins (e.g. `time.now`) that honor an embedder-provided per-thread override.
pub fn BuiltinCallCtx::get_local(self : BuiltinCallCtx, key : String) -> Value? {
  (self.get_local_fn)(key)
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
  priv recv : Value?
}

///|
pub fn StarlarkBuiltinFunc::dispatch(name : String) -> StarlarkBuiltinFunc {
  { name, body: None, recv: None }
}

///|
pub fn StarlarkBuiltinFunc::name(self : StarlarkBuiltinFunc) -> String {
  self.name
}

///|
pub fn StarlarkBuiltinFunc::receiver(self : StarlarkBuiltinFunc) -> Value? {
  self.recv
}

///|
pub fn StarlarkBuiltinFunc::bind_receiver(
  self : StarlarkBuiltinFunc,
  recv : Value,
) -> StarlarkBuiltinFunc {
  { ..self, recv: Some(recv) }
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
pub struct StarlarkStringElems {
  priv s : StarlarkString
  priv ords : Bool
}

///|
pub fn StarlarkStringElems::new(
  s : StarlarkString,
  ords : Bool,
) -> StarlarkStringElems {
  { s, ords }
}

///|
pub fn StarlarkStringElems::source_string(
  self : StarlarkStringElems,
) -> StarlarkString {
  self.s
}

///|
pub fn StarlarkStringElems::is_ords(self : StarlarkStringElems) -> Bool {
  self.ords
}

///|
pub struct StarlarkStringCodepoints {
  priv s : StarlarkString
  priv ords : Bool
}

///|
pub fn StarlarkStringCodepoints::new(
  s : StarlarkString,
  ords : Bool,
) -> StarlarkStringCodepoints {
  { s, ords }
}

///|
pub fn StarlarkStringCodepoints::source_string(
  self : StarlarkStringCodepoints,
) -> StarlarkString {
  self.s
}

///|
pub fn StarlarkStringCodepoints::is_ords(
  self : StarlarkStringCodepoints,
) -> Bool {
  self.ords
}

///|
pub struct StarlarkBytesElems {
  priv b : Bytes
}

///|
pub fn StarlarkBytesElems::new(b : Bytes) -> StarlarkBytesElems {
  { b, }
}

///|
pub fn StarlarkBytesElems::raw_bytes(self : StarlarkBytesElems) -> Bytes {
  self.b
}

///|
/// The Starlark value sum type. Covers all built-in types plus embedder
/// extensions via `ExtVal`.
pub(all) enum Value {
  None
  Bool(Bool)
  Int(BigInt)
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
  StringElems(StarlarkStringElems)
  StringCodepoints(StarlarkStringCodepoints)
  BytesElems(StarlarkBytesElems)
  ExtVal(CustomValue)
}

///|
/// Creates a `Value::String` from a MoonBit `String`.
pub fn Value::of_string(s : String) -> Value {
  String(StarlarkString::new(s))
}

///|
/// Creates a `Value::List` wrapping a new `StarlarkList`.
pub fn Value::new_list(items : Array[Value]) -> Value {
  List(StarlarkList::new(items))
}

///|
/// Creates an empty `Value::Dict`.
pub fn Value::new_dict() -> Value {
  Dict(StarlarkDict::new())
}

///|
/// Creates an empty `Value::Set`.
pub fn Value::new_set() -> Value {
  Set(StarlarkSet::new())
}

///|
/// Creates a `Value::Builtin` with the given name and callable body.
pub fn Value::new_builtin(
  name : String,
  body : (BuiltinCallCtx, Array[Value], Array[(String, Value)]) -> Result[
    Value,
    String,
  ],
) -> Value {
  Builtin({ name, body: Some(body), recv: None })
}

///|
/// Returns the Starlark `type()` string for `v` (e.g. `"int"`, `"list"`).
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
    StringElems(_) => "string.elems"
    StringCodepoints(_) => "string.codepoints"
    BytesElems(_) => "bytes.elems"
    ExtVal(c) => c.get_type_name()
  }
}

///|
pub fn truth(v : Value) -> Bool {
  match v {
    None => false
    Bool(b) => b
    Int(i) => !i.is_zero()
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
    StringElems(_) | StringCodepoints(_) | BytesElems(_) => true
    ExtVal(c) => c.get_truth()
  }
}

///|
/// Integer floor division flooring toward −∞ (sign of the remainder equals
/// the sign of the divisor), matching Starlark's `//` operator.
pub fn floor_div(a : BigInt, b : BigInt) -> Result[BigInt, String] {
  if b.is_zero() {
    return Err("floored division by zero")
  }
  let q = a / b
  let r = a % b
  let zero = 0N
  if r != zero && (r < zero) != (b < zero) {
    Ok(q - 1N)
  } else {
    Ok(q)
  }
}

///|
/// Integer modulo whose sign matches the divisor, matching Starlark's `%`
/// operator.
pub fn starlark_mod(a : BigInt, b : BigInt) -> Result[BigInt, String] {
  if b.is_zero() {
    return Err("integer modulo by zero")
  }
  let r = a % b
  let zero = 0N
  if r != zero && (r < zero) != (b < zero) {
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
/// Formats a `Double` as a Starlark float literal, matching starlark-go's
/// `strconv.FormatFloat('g')` output: scientific notation for very large or
/// very small values, decimal otherwise. Handles ±inf, nan, and −0.0.
pub fn format_float(f : Double) -> String {
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
  // Already in scientific notation: normalize to Go format (e+XX, 2-digit exponent).
  let e_idx = float_find_e(s)
  if e_idx >= 0 {
    return float_normalize_sci(s, e_idx)
  }
  let neg = s.has_prefix("-")
  let sign = if neg { "-" } else { "" }
  let abs_s = if neg { s[1:].to_owned() } else { s }
  if abs_s.contains(".") {
    // Decimal form.  Go's %g switches to scientific when the decimal exponent
    // is < -4 (small numbers below "0.0001") or >= 6 (magnitude >= 1e6).
    if abs_s.has_prefix("0.") {
      let frac = abs_s[2:].to_owned()
      let leading = float_count_leading_zeros(frac)
      // exponent = -(leading + 1); scientific when exp < -4 i.e. leading >= 4
      if leading >= 4 {
        let sig = frac[leading:].to_owned()
        return sign + float_small_to_sci(sig, leading + 1)
      }
    } else {
      let dot = float_find_dot(abs_s)
      let int_part = abs_s[0:dot].to_owned()
      // Integer-part length L means decimal exponent L-1; scientific when >= 6.
      if int_part.length() >= 7 {
        let frac_part = abs_s[dot + 1:].to_owned()
        return sign + float_large_frac_to_sci(int_part, frac_part)
      }
    }
    return s
  } else {
    // Integer form: check whether scientific notation is needed.
    return sign + float_int_to_str(abs_s)
  }
}

// Find index of 'e' or 'E' in s; returns -1 if not found.

///|
fn float_find_e(s : String) -> Int {
  let n = s.length()
  let mut i = 0
  while i < n {
    let c = s[i:i + 1]
    if c == "e" || c == "E" {
      return i
    }
    i += 1
  }
  -1
}

// Normalize a scientific-notation string to Go's "e+XX" / "e-XX" (min 2 digit exp).

///|
fn float_normalize_sci(s : String, e_idx : Int) -> String {
  let mantissa = s[0:e_idx].to_owned()
  let exp_part = s[e_idx + 1:].to_owned()
  let (exp_sign, exp_digits) = if exp_part.has_prefix("+") {
    ("+", exp_part[1:].to_owned())
  } else if exp_part.has_prefix("-") {
    ("-", exp_part[1:].to_owned())
  } else {
    ("+", exp_part)
  }
  let exp_str = if exp_digits.length() < 2 {
    "0" + exp_digits
  } else {
    exp_digits
  }
  // Scientific notation already satisfies the "has decimal or exponent" requirement;
  // do NOT append ".0" to the mantissa.
  mantissa + "e" + exp_sign + exp_str
}

// Count leading '0' chars in frac (the digits after "0.").

///|
fn float_count_leading_zeros(frac : String) -> Int {
  let n = frac.length()
  let mut i = 0
  while i < n && frac[i:i + 1] == "0" {
    i += 1
  }
  i
}

// Build scientific string for a small positive number.
// sig: significant digits string (no leading zeros), exp_abs: |exponent|.

///|
fn float_small_to_sci(sig : String, exp_abs : Int) -> String {
  if sig.length() == 0 {
    return "0.0"
  }
  let first = sig[0:1].to_owned()
  let rest = sig[1:].to_owned()
  let mantissa = if rest == "" { first } else { first + "." + rest }
  let exp_str = if exp_abs < 10 { "0\{exp_abs}" } else { exp_abs.to_string() }
  mantissa + "e-" + exp_str
}

// Convert an integer-form float string (no decimal, no exponent) to Go format.
// Go uses scientific notation when the integer representation has 7 or more digits.

///|
fn float_int_to_str(abs_s : String) -> String {
  let n = abs_s.length()
  if n < 7 {
    return abs_s + ".0"
  }
  // 7+ digits: convert to scientific notation by stripping trailing zeros.
  let exp = n - 1
  let mut sig_end = n
  while sig_end > 1 && abs_s[sig_end - 1:sig_end].to_owned() == "0" {
    sig_end -= 1
  }
  let first = abs_s[0:1].to_owned()
  let rest_sig = abs_s[1:sig_end].to_owned()
  let mantissa = if rest_sig == "" { first } else { first + "." + rest_sig }
  let exp_str = if exp < 10 { "0\{exp}" } else { exp.to_string() }
  mantissa + "e+" + exp_str
}

// Find the index of '.' in s; returns s.length() if absent.

///|
fn float_find_dot(s : String) -> Int {
  let n = s.length()
  let mut i = 0
  while i < n {
    if s[i:i + 1] == "." {
      return i
    }
    i += 1
  }
  n
}

// Build scientific string for a positive decimal-form number whose integer
// part has 7+ digits (decimal exponent >= 6).  int_part has no decimal point;
// frac_part is the (possibly empty) fractional tail.

///|
fn float_large_frac_to_sci(int_part : String, frac_part : String) -> String {
  let exp = int_part.length() - 1
  let digits = int_part + frac_part
  let mut sig_end = digits.length()
  while sig_end > 1 && digits[sig_end - 1:sig_end] == "0" {
    sig_end -= 1
  }
  let first = digits[0:1].to_owned()
  let rest_sig = digits[1:sig_end].to_owned()
  let mantissa = if rest_sig == "" { first } else { first + "." + rest_sig }
  let exp_str = if exp < 10 { "0\{exp}" } else { exp.to_string() }
  mantissa + "e+" + exp_str
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
      0x07 => {
        buf.write_string("\\a")
        i += 1
      }
      0x08 => {
        buf.write_string("\\b")
        i += 1
      }
      0x0C => {
        buf.write_string("\\f")
        i += 1
      }
      0x0B => {
        buf.write_string("\\v")
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
/// Returns the Starlark `repr(v)` string. Detects cyclic list/dict references
/// and replaces them with `[...]` / `{...}`.
pub fn repr(v : Value) -> String {
  repr_inner(v, [], [])
}

///|
fn repr_inner(
  v : Value,
  seen_lists : Array[StarlarkList],
  seen_dicts : Array[StarlarkDict],
) -> String {
  match v {
    None => "None"
    Bool(true) => "True"
    Bool(false) => "False"
    Int(i) => i.to_string()
    Float(f) => format_float(f)
    String(s) => repr_string_val(s)
    Bytes(b) => repr_bytes_val(b)
    List(l) => repr_list_inner(l, seen_lists, seen_dicts)
    Tuple(t) => repr_tuple_inner(t, seen_lists, seen_dicts)
    Dict(d) => repr_dict_inner(d, seen_lists, seen_dicts)
    Set(s) => repr_set_inner(s, seen_lists, seen_dicts)
    Range(r) => repr_range(r)
    Function(f) => "<function \{f.name}>"
    Builtin(f) => "<built-in function \{f.name}>"
    BoundMethod(m) =>
      "<built-in method \{m.method_name} of \{type_name(m.recv)} value>"
    Module(m) => "<module \"\{m.name}\">"
    StringElems(e) => {
      let suffix = if e.ords { "elem_ords()" } else { "elems()" }
      repr_string_val(e.s) + "." + suffix
    }
    StringCodepoints(c) => {
      let suffix = if c.ords { "codepoint_ords()" } else { "codepoints()" }
      repr_string_val(c.s) + "." + suffix
    }
    BytesElems(e) => repr_bytes_val(e.b) + ".elems()"
    ExtVal(c) => c.get_repr()
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
fn repr_dict_inner(
  d : StarlarkDict,
  seen_lists : Array[StarlarkList],
  seen_dicts : Array[StarlarkDict],
) -> String {
  if seen_dicts.iter().any(fn(sd) { d.is_same_storage(sd) }) {
    return "{...}"
  }
  if d.length() == 0 {
    return "{}"
  }
  seen_dicts.push(d)
  let buf = StringBuilder::new()
  buf.write_char('{')
  let mut first = true
  d.each(fn(k, v) {
    if first == false {
      buf.write_string(", ")
    }
    first = false
    buf.write_string(repr_inner(k, seen_lists, seen_dicts))
    buf.write_string(": ")
    buf.write_string(repr_inner(v, seen_lists, seen_dicts))
  })
  buf.write_char('}')
  let _ = seen_dicts.pop()
  buf.to_string()
}

///|
fn repr_set_inner(
  s : StarlarkSet,
  seen_lists : Array[StarlarkList],
  seen_dicts : Array[StarlarkDict],
) -> String {
  let buf = StringBuilder::new()
  buf.write_string("set([")
  let mut first = true
  s.each(fn(k) {
    if first == false {
      buf.write_string(", ")
    }
    first = false
    buf.write_string(repr_inner(k, seen_lists, seen_dicts))
  })
  buf.write_string("])")
  buf.to_string()
}

///|
fn repr_list_inner(
  l : StarlarkList,
  seen_lists : Array[StarlarkList],
  seen_dicts : Array[StarlarkDict],
) -> String {
  if seen_lists.iter().any(fn(sl) { l.is_same_storage(sl) }) {
    return "[...]"
  }
  seen_lists.push(l)
  let buf = StringBuilder::new()
  buf.write_char('[')
  for i in 0..<l.items.length() {
    if i > 0 {
      buf.write_string(", ")
    }
    buf.write_string(repr_inner(l.items[i], seen_lists, seen_dicts))
  }
  buf.write_char(']')
  let _ = seen_lists.pop()
  buf.to_string()
}

///|
fn repr_tuple_inner(
  t : Array[Value],
  seen_lists : Array[StarlarkList],
  seen_dicts : Array[StarlarkDict],
) -> String {
  repr_tuple_with(t, fn(v) { repr_inner(v, seen_lists, seen_dicts) })
}

///|
fn repr_tuple(t : Array[Value]) -> String {
  repr_tuple_with(t, repr)
}

///|
fn repr_tuple_with(t : Array[Value], f : (Value) -> String) -> String {
  let buf = StringBuilder::new()
  buf.write_char('(')
  for i in 0..<t.length() {
    if i > 0 {
      buf.write_string(", ")
    }
    buf.write_string(f(t[i]))
  }
  if t.length() == 1 {
    buf.write_char(',')
  }
  buf.write_char(')')
  buf.to_string()
}
