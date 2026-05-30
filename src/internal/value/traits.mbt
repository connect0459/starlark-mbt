///|
pub impl Eq for Value with fn equal(a, b) -> Bool {
  starlark_equals(a, b)
}

///|
pub fn to_str(v : Value) -> String {
  match v {
    None => "None"
    Bool(true) => "True"
    Bool(false) => "False"
    Int(i) => i.to_string()
    Float(f) => format_float(f)
    String(s) => s.raw
    Bytes(b) => repr_bytes_val(b)
    List(l) => repr_inner(List(l), [], [])
    Tuple(t) => repr_tuple(t)
    Dict(d) => repr_inner(Dict(d), [], [])
    Set(s) => repr_inner(Set(s), [], [])
    Range(_) | Function(_) | Builtin(_) | BoundMethod(_) | Module(_) => repr(v)
    StringElems(_) | StringCodepoints(_) | BytesElems(_) => repr(v)
    ExtVal(c) => c.get_repr()
  }
}

///|
pub fn starlark_equals(a : Value, b : Value) -> Bool {
  match (a, b) {
    (None, None) => true
    (Bool(x), Bool(y)) => x == y
    (Int(x), Int(y)) => x == y
    (Float(x), Float(y)) => if x.is_nan() { y.is_nan() } else { x == y }
    (String(x), String(y)) => x.equals(y)
    (Bytes(x), Bytes(y)) => x.equal(y)
    (List(x), List(y)) => slice_equals(x.items[:], y.items[:])
    (Tuple(x), Tuple(y)) => slice_equals(x[:], y[:])
    (Int(n), Float(f)) => int_float_eq(n, f)
    (Float(f), Int(n)) => int_float_eq(n, f)
    (Dict(x), Dict(y)) => dict_equals(x, y)
    (Set(x), Set(y)) => set_equals(x, y)
    (Range(x), Range(y)) => range_equals(x, y)
    // Functions use identity: two distinct objects are never equal
    (Function(_), Function(_)) => false
    (Builtin(x), Builtin(y)) => x.name == y.name
    // Bound methods use identity: each access creates a new unique object
    (BoundMethod(x), BoundMethod(y)) => x.id == y.id
    // Modules use identity equality
    (Module(_), Module(_)) => false
    // Lazy iterators use identity equality
    (StringElems(_), StringElems(_)) => false
    (StringCodepoints(_), StringCodepoints(_)) => false
    (BytesElems(_), BytesElems(_)) => false
    (ExtVal(a), ExtVal(b)) => a.get_equals(ExtVal(b))
    _ => false
  }
}

///|
pub fn double_to_bigint(f : Double) -> BigInt {
  // f must be finite and satisfy f == f.trunc() (no fractional part).
  // Handles the full double range via IEEE 754 bit extraction.
  let bits = f.reinterpret_as_uint64()
  let negative = bits >> 63 != 0UL
  let biased_exp = ((bits >> 52) & 0x7FFUL).to_int()
  if biased_exp < 1023 {
    return 0N
  }
  let mantissa = (bits & 0x000FFFFFFFFFFFFFUL) | 0x0010000000000000UL
  let shift = biased_exp - 1023 - 52
  let abs_val = if shift >= 0 {
    BigInt::from_uint64(mantissa) << shift
  } else {
    BigInt::from_uint64(mantissa) >> -shift
  }
  if negative {
    -abs_val
  } else {
    abs_val
  }
}

///|
fn int_float_eq(n : BigInt, f : Double) -> Bool {
  if f.is_nan() || f.is_inf() {
    return false
  }
  if f != f.trunc() {
    return false
  }
  n == double_to_bigint(f)
}

///|
fn slice_equals(a : ArrayView[Value], b : ArrayView[Value]) -> Bool {
  if a.length() != b.length() {
    return false
  }
  for i in 0..<a.length() {
    if starlark_equals(a[i], b[i]) == false {
      return false
    }
  }
  true
}

///|
let fnv_offset_basis : UInt = 2166136261U

///|
let fnv_prime : UInt = 16777619U

// Starlark integer hash multiplier: 12582917 * (lo + 3)

///|
let int_hash_mult : UInt = 12582917U

// Sentinel hash for NaN/Inf floats (golden ratio × 10^6)

///|
let float_special_hash : UInt = 1618033U

// Starlark tuple hash algorithm constants

///|
let tuple_hash_init : UInt = 0x345678U

///|
let tuple_hash_prime : UInt = 1000003U

///|
let tuple_hash_step_base : UInt = 82520U

///|
fn fnv1a(bytes : Bytes) -> UInt {
  let mut h = fnv_offset_basis
  for i in 0..<bytes.length() {
    let b = bytes[i].to_int().reinterpret_as_uint()
    h = (h ^ b) * fnv_prime
  }
  h
}

///|
pub fn java_string_hash(s : StarlarkString) -> Int {
  let b = s.bytes
  let mut h : Int = 0
  let mut pos = 0
  while pos < b.length() {
    let (cp, n) = @utf8util.utf8_decode_rune(b, pos)
    pos += n
    h = 31 * h + (if cp < 0 { 0xFFFD } else { cp })
  }
  h
}

///|
fn hash_int(n : Int) -> UInt {
  n.reinterpret_as_uint() * fnv_prime
}

///|
fn hash_bigint(n : BigInt) -> UInt {
  let lo = n.to_int64().to_int().reinterpret_as_uint()
  int_hash_mult * (lo + 3U)
}

///|
fn hash_float(f : Double) -> UInt {
  if f.is_nan() || f.is_inf() {
    return float_special_hash
  }
  // Convert to exact integer value then hash, matching starlark-go's
  // finiteFloatToInt(f).Hash() — ensures hash(1e20) == hash(10**20).
  hash_bigint(double_to_bigint(f))
}

///|
fn hash_tuple(t : Array[Value]) -> Result[UInt, String] {
  let mut x : UInt = tuple_hash_init
  let mut mult : UInt = tuple_hash_prime
  let n = (t.length() + t.length()).reinterpret_as_uint()
  for elem in t {
    match starlark_hash(elem) {
      Err(e) => return Err(e)
      Ok(y) => {
        x = x ^ (y * mult)
        mult = mult + tuple_hash_step_base + n
      }
    }
  }
  Ok(x)
}

///|
pub fn starlark_hash(v : Value) -> Result[UInt, String] {
  match v {
    None => Ok(0U)
    Bool(false) => Ok(0U)
    Bool(true) => Ok(1U)
    Int(n) => Ok(hash_bigint(n))
    Float(f) => Ok(hash_float(f))
    String(s) => Ok(fnv1a(s.bytes))
    Bytes(b) => Ok(fnv1a(b))
    Tuple(t) => hash_tuple(t)
    List(_) => Err("unhashable type: list")
    Dict(_) => Err("unhashable type: dict")
    Set(_) => Err("unhashable type: set")
    Range(_) => Err("unhashable: range")
    Function(_) => Err("unhashable type: function")
    Builtin(_) => Err("unhashable type: builtin_function_or_method")
    BoundMethod(m) => Ok(hash_int(m.id))
    Module(_) => Err("unhashable: module")
    StringElems(_) => Err("unhashable: string.elems")
    StringCodepoints(_) => Err("unhashable: string.codepoints")
    BytesElems(_) => Err("unhashable: bytes.elems")
    ExtVal(c) => c.get_hash()
  }
}

///|
fn int64_signum(a : Int64, b : Int64) -> Int {
  if a < b {
    -1
  } else if a > b {
    1
  } else {
    0
  }
}

///|
fn bigint_signum(a : BigInt, b : BigInt) -> Int {
  a.compare(b)
}

///|
fn float_cmp(x : Double, y : Double) -> Int {
  if x > y {
    1
  } else if x < y {
    -1
  } else if x == y {
    0
  } else if x == x {
    // x is not NaN, so y is NaN; NaN > everything
    -1
  } else if y == y {
    // y is not NaN, so x is NaN; NaN > everything
    1
  } else {
    // both NaN
    0
  }
}

///|
fn bytes_lex_cmp(a : Bytes, b : Bytes) -> Int {
  let len = if a.length() < b.length() { a.length() } else { b.length() }
  for i in 0..<len {
    let ca = a[i].to_int()
    let cb = b[i].to_int()
    if ca < cb {
      return -1
    }
    if ca > cb {
      return 1
    }
  }
  int64_signum(a.length().to_int64(), b.length().to_int64())
}

///|
pub fn bigint_to_double(n : BigInt) -> Double {
  @string.parse_double(n.to_string()) catch {
    _ => 0.0
  }
}

///|
pub fn bigint_to_finite_double(n : BigInt) -> Result[Double, String] {
  let f = @string.parse_double(n.to_string()) catch { _ => @double.infinity }
  if f.is_inf() {
    Err("int too large to convert to float")
  } else {
    Ok(f)
  }
}

///|
fn int_float_cmp(n : BigInt, f : Double) -> Int {
  if f != f {
    -1 // NaN > everything in starlark ordering
  } else if f == @double.infinity {
    -1 // n < +inf
  } else if f == @double.neg_infinity {
    1 // n > -inf
  } else {
    // finite f: compare exactly using floor(f)
    let ffloor = f.floor()
    let f_floor_big = double_to_bigint(ffloor)
    if f == ffloor {
      n.compare(f_floor_big)
    } else {
      // f is in (ffloor, ffloor+1); n is an integer
      let cmp = n.compare(f_floor_big)
      if cmp <= 0 {
        -1
      } else {
        1
      }
    }
  }
}

///|
pub let compare_limit : Int = 10

///|
pub fn compare_values(a : Value, b : Value) -> Result[Int, String] {
  compare_values_depth(a, b, compare_limit)
}

///|
pub fn compare_values_depth(
  a : Value,
  b : Value,
  depth : Int,
) -> Result[Int, String] {
  if depth < 1 {
    return Err("comparison exceeded maximum recursion depth")
  }
  match (a, b) {
    (Bool(x), Bool(y)) =>
      Ok(
        match (x, y) {
          (false, true) => -1
          (true, false) => 1
          _ => 0
        },
      )
    (Int(x), Int(y)) => Ok(bigint_signum(x, y))
    (Float(x), Float(y)) => Ok(float_cmp(x, y))
    (String(x), String(y)) => Ok(bytes_lex_cmp(x.bytes, y.bytes))
    (Bytes(x), Bytes(y)) => Ok(bytes_lex_cmp(x, y))
    (Tuple(x), Tuple(y)) => slice_cmp_depth(x[:], y[:], depth - 1)
    (List(x), List(y)) => slice_cmp_depth(x.items[:], y.items[:], depth - 1)
    (Int(n), Float(f)) => Ok(int_float_cmp(n, f))
    (Float(f), Int(n)) => Ok(-int_float_cmp(n, f))
    (ExtVal(ac), _) =>
      match ac.get_compare(b) {
        Some(c) => Ok(c)
        None => Err("\{type_name(a)} < \{type_name(b)} not implemented")
      }
    (_, ExtVal(rc)) =>
      match rc.get_compare(a) {
        Some(c) => Ok(-c)
        None => Err("\{type_name(a)} < \{type_name(b)} not implemented")
      }
    _ => Err("\{type_name(a)} < \{type_name(b)} not implemented")
  }
}

///|
pub fn starlark_equals_depth(
  a : Value,
  b : Value,
  depth : Int,
) -> Result[Bool, String] {
  if depth < 1 {
    return Err("comparison exceeded maximum recursion depth")
  }
  match (a, b) {
    (None, None) => Ok(true)
    (Bool(x), Bool(y)) => Ok(x == y)
    (Int(x), Int(y)) => Ok(x == y)
    (Float(x), Float(y)) => Ok(if x.is_nan() { y.is_nan() } else { x == y })
    (String(x), String(y)) => Ok(x.equals(y))
    (Bytes(x), Bytes(y)) => Ok(x.equal(y))
    (List(x), List(y)) => slice_equals_depth(x.items[:], y.items[:], depth - 1)
    (Tuple(x), Tuple(y)) => slice_equals_depth(x[:], y[:], depth - 1)
    (Int(n), Float(f)) => Ok(int_float_eq(n, f))
    (Float(f), Int(n)) => Ok(int_float_eq(n, f))
    (Dict(x), Dict(y)) => dict_equals_depth(x, y, depth - 1)
    (Set(x), Set(y)) => set_equals_depth(x, y, depth - 1)
    (Range(x), Range(y)) => Ok(range_equals(x, y))
    (Function(_), Function(_)) => Ok(false)
    (Builtin(x), Builtin(y)) => Ok(x.name == y.name)
    (BoundMethod(x), BoundMethod(y)) => Ok(x.id == y.id)
    (Module(_), Module(_)) => Ok(false)
    (StringElems(_), StringElems(_)) => Ok(false)
    (StringCodepoints(_), StringCodepoints(_)) => Ok(false)
    (BytesElems(_), BytesElems(_)) => Ok(false)
    (ExtVal(a), ExtVal(b)) => Ok(a.get_equals(ExtVal(b)))
    _ => Ok(false)
  }
}

///|
fn slice_equals_depth(
  a : ArrayView[Value],
  b : ArrayView[Value],
  depth : Int,
) -> Result[Bool, String] {
  if a.length() != b.length() {
    return Ok(false)
  }
  for i in 0..<a.length() {
    match starlark_equals_depth(a[i], b[i], depth) {
      Err(e) => return Err(e)
      Ok(false) => return Ok(false)
      Ok(true) => ()
    }
  }
  Ok(true)
}

///|
fn slice_cmp_depth(
  a : ArrayView[Value],
  b : ArrayView[Value],
  depth : Int,
) -> Result[Int, String] {
  let len = if a.length() < b.length() { a.length() } else { b.length() }
  for i in 0..<len {
    match compare_values_depth(a[i], b[i], depth) {
      Err(e) => return Err(e)
      Ok(c) => if c != 0 { return Ok(c) }
    }
  }
  Ok(int64_signum(a.length().to_int64(), b.length().to_int64()))
}

///|
fn dict_equals_depth(
  a : StarlarkDict,
  b : StarlarkDict,
  depth : Int,
) -> Result[Bool, String] {
  if a.length() != b.length() {
    return Ok(false)
  }
  let mut result : Result[Bool, String] = Ok(true)
  a.each(fn(k, v) {
    if result is Ok(true) {
      match b.get(k) {
        Ok(Some(bv)) =>
          match starlark_equals_depth(v, bv, depth) {
            Err(e) => result = Err(e)
            Ok(false) => result = Ok(false)
            Ok(true) => ()
          }
        _ => result = Ok(false)
      }
    }
  })
  result
}

///|
fn set_equals_depth(
  a : StarlarkSet,
  b : StarlarkSet,
  _depth : Int,
) -> Result[Bool, String] {
  if a.length() != b.length() {
    return Ok(false)
  }
  let mut result : Result[Bool, String] = Ok(true)
  a.each(fn(k) {
    if result is Ok(true) {
      match b.contains(k) {
        Ok(true) => ()
        Ok(false) => result = Ok(false)
        Err(e) => result = Err(e)
      }
    }
  })
  result
}

///|
pub fn freeze_value(v : Value) -> Unit {
  freeze_value_inner(v, [])
}

///|
fn freeze_value_inner(v : Value, seen_funcs : Array[String]) -> Unit {
  match v {
    List(l) => {
      if l.is_frozen() {
        return
      }
      l.freeze()
      for item in l.items {
        freeze_value_inner(item, seen_funcs)
      }
    }
    Dict(d) => {
      if d.is_frozen() {
        return
      }
      d.freeze()
      d.each(fn(k, val) {
        freeze_value_inner(k, seen_funcs)
        freeze_value_inner(val, seen_funcs)
      })
    }
    Set(s) => {
      if s.is_frozen() {
        return
      }
      s.freeze()
      s.each(fn(k) { freeze_value_inner(k, seen_funcs) })
    }
    Tuple(t) =>
      for item in t {
        freeze_value_inner(item, seen_funcs)
      }
    Function(f) => {
      if seen_funcs.contains(f.name) {
        return
      }
      seen_funcs.push(f.name)
      for default_opt in f.defaults {
        match default_opt {
          Some(dv) => freeze_value_inner(dv, seen_funcs)
          None => ()
        }
      }
      for pair in f.captured_scope {
        pair.0.each(fn(_, val) { freeze_value_inner(val, seen_funcs) })
      }
    }
    Module(_) => ()
    ExtVal(c) => c.do_freeze()
    _ => ()
  }
}

///|
fn range_equals(x : StarlarkRange, y : StarlarkRange) -> Bool {
  let xl = x.length()
  let yl = y.length()
  if xl != yl {
    return false
  }
  if xl == 0 {
    return true
  }
  if x.start != y.start {
    return false
  }
  xl == 1 || x.step == y.step
}

///|
fn dict_equals(a : StarlarkDict, b : StarlarkDict) -> Bool {
  if a.length() != b.length() {
    return false
  }
  let mut ok = true
  a.each(fn(k, v) {
    if ok {
      match b.get(k) {
        Ok(Some(bv)) => if starlark_equals(v, bv) == false { ok = false }
        _ => ok = false
      }
    }
  })
  ok
}

///|
fn set_equals(a : StarlarkSet, b : StarlarkSet) -> Bool {
  if a.length() != b.length() {
    return false
  }
  let mut ok = true
  a.each(fn(k) {
    if ok {
      match b.contains(k) {
        Ok(true) => ()
        _ => ok = false
      }
    }
  })
  ok
}
