///|
pub impl Eq for Value with fn equal(a, b) -> Bool {
  a.starlark_equals(b)
}

///|
/// Returns the Starlark `str(v)` string representation of `v`. Unlike
/// `repr`, string values are returned without quotes.
///
/// Parameters:
///
/// - `v` : The value to convert to a string.
///
/// Returns the Starlark `str()` representation of `v`.
pub fn Value::to_str(v : Value) -> String {
  match v {
    None => "None"
    Bool(true) => "True"
    Bool(false) => "False"
    Int(i) => i.to_string()
    Float(f) => @numeric.format_float(f)
    String(s) => s.raw
    Bytes(b) => repr_bytes_val(b)
    List(l) => repr_inner(List(l), [], [])
    Tuple(t) => repr_tuple(t)
    Dict(d) => repr_inner(Dict(d), [], [])
    Set(s) => repr_inner(Set(s), [], [])
    Range(_) | Function(_) | Builtin(_) | BoundMethod(_) | Module(_) => v.repr()
    StringElems(_) | StringCodepoints(_) | BytesElems(_) => v.repr()
    ExtVal(c) => c.get_repr()
  }
}

///|
/// Returns `true` if `a == b` under Starlark semantics, including cross-type
/// `Int`/`Float` equality and NaN inequality.
///
/// Parameters:
///
/// - `a` : The left-hand side value.
/// - `b` : The right-hand side value.
///
/// Returns `true` when the two values are equal under Starlark semantics.
pub fn Value::starlark_equals(a : Value, b : Value) -> Bool {
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
    // Functions use identity: only equal if same object
    (Function(x), Function(y)) => physical_equal(x, y)
    (Builtin(x), Builtin(y)) => x.name == y.name
    // Bound methods use identity: each access creates a new unique object
    (BoundMethod(x), BoundMethod(y)) => x.id == y.id
    // Modules use identity equality
    (Module(x), Module(y)) => physical_equal(x, y)
    // Iterators compare by source value: two views over the same data are equal
    (StringElems(x), StringElems(y)) => x.s.equals(y.s) && x.ords == y.ords
    (StringCodepoints(x), StringCodepoints(y)) =>
      x.s.equals(y.s) && x.ords == y.ords
    (BytesElems(x), BytesElems(y)) => x.b.equal(y.b)
    (ExtVal(a), ExtVal(b)) =>
      match a.get_equals(ExtVal(b), compare_limit) {
        Ok(eq) => eq
        Err(_) => false
      }
    _ => false
  }
}

///|
fn int_float_eq(n : BigInt, f : Double) -> Bool {
  if f.is_nan() || f.is_inf() {
    return false
  }
  // An int can equal a float only when the float has no fractional part;
  // trunc() strips the fraction, so `f != f.trunc()` means one was present.
  if f != f.trunc() {
    return false
  }
  n == @numeric.double_to_bigint(f)
}

///|
fn slice_equals(a : ArrayView[Value], b : ArrayView[Value]) -> Bool {
  if a.length() != b.length() {
    return false
  }
  for i in 0..<a.length() {
    if a[i].starlark_equals(b[i]) == false {
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

// 2^32 — used to extract the low 32 bits of a BigInt magnitude

///|
let bigint_uint32_modulus : BigInt = 4294967296N

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
fn hash_int(n : Int) -> UInt {
  n.reinterpret_as_uint() * fnv_prime
}

///|
let min_int64_bigint : BigInt = -9223372036854775808N

///|
let max_int64_bigint : BigInt = 9223372036854775807N

///|
fn hash_bigint(n : BigInt) -> UInt {
  // Integer hash algorithm:
  //   small int (int64 range): lo = big.Word(iSmall) = uint64(iSmall)
  //   big  int (outside int64 range): lo = iBig.Bits()[0] = low word of magnitude
  // uint32(lo+3) reduces to uint32(lo32+3) regardless of the upper 32 bits,
  // so we only need the low 32 bits of the appropriate 64-bit word.
  let lo : UInt = if n >= min_int64_bigint && n <= max_int64_bigint {
    // Two's-complement low 32 bits, matching uint32(uint64(iSmall)).
    n.to_int64().to_int().reinterpret_as_uint()
  } else {
    // Low 32 bits of the magnitude, matching uint32(iBig.Bits()[0]).
    let abs_n = if n < 0N { -n } else { n }
    (abs_n % bigint_uint32_modulus).to_int().reinterpret_as_uint()
  }
  int_hash_mult * (lo + 3U)
}

///|
fn hash_float(f : Double) -> UInt {
  if f.is_nan() || f.is_inf() {
    return float_special_hash
  }
  // Convert to exact integer value then hash — ensures
  // hash(1e20) == hash(10**20).
  hash_bigint(@numeric.double_to_bigint(f))
}

///|
fn hash_tuple(t : Array[Value]) -> Result[UInt, String] {
  let mut x : UInt = tuple_hash_init
  let mut mult : UInt = tuple_hash_prime
  // Python's tuplehash step: mult += 82520 + len + len per element.
  // The "len + len" form is a direct port of CPython's uint arithmetic.
  let n = (t.length() + t.length()).reinterpret_as_uint()
  for elem in t {
    match elem.hash() {
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
/// Computes the Starlark hash of `self`. Returns `Err` for unhashable types
/// (list, dict, set, range, module). Guarantees `hash(x) == hash(y)` whenever
/// `x == y` under Starlark semantics, including cross-type `Int`/`Float`.
///
/// Parameters:
///
/// - `self` : The value to hash.
///
/// Returns `Ok(hash)` for hashable values, or `Err` with a message like
/// `"unhashable type: list"` for unhashable types.
pub fn Value::hash(self : Value) -> Result[UInt, String] {
  match self {
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
    Function(f) => Ok(fnv1a(@utf8.encode(f.name())))
    Builtin(b) => Ok(fnv1a(@utf8.encode(b.name())))
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
    let f_floor_big = @numeric.double_to_bigint(ffloor)
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
/// Compares `a` and `b` using Starlark's total ordering, returning a negative
/// int, zero, or positive int. Returns `Err` for incompatible types. `op` is
/// the operator string used in the error message.
///
/// Parameters:
///
/// - `a` : The left-hand side value.
/// - `b` : The right-hand side value.
/// - `op` : The comparison operator string used in error messages (default `"<"`).
///
/// Returns `Ok(n)` where `n < 0`, `n == 0`, or `n > 0`, or `Err` when the
/// types cannot be compared.
#internal(unsafe, "eval engine only; embedders use compare_depth")
pub fn compare_values(
  a : Value,
  b : Value,
  op? : String = "<",
) -> Result[Int, String] {
  compare_values_depth(a, b, compare_limit, op~)
}

///|
/// Like `compare_values` but with an explicit recursion-depth cap to guard
/// against cycles in nested structures.
///
/// Parameters:
///
/// - `a` : The left-hand side value.
/// - `b` : The right-hand side value.
/// - `depth` : Maximum remaining recursion depth; returns `Err` when it
///   reaches zero.
/// - `op` : The comparison operator string used in error messages (default `"<"`).
///
/// Returns `Ok(n)` where `n < 0`, `n == 0`, or `n > 0`, or `Err` when types
/// are incompatible or the depth limit is exceeded.
#internal(unsafe, "eval engine only; embedders use compare_depth")
pub fn compare_values_depth(
  a : Value,
  b : Value,
  depth : Int,
  op? : String = "<",
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
    (Tuple(x), Tuple(y)) => slice_cmp_depth(x[:], y[:], depth - 1, op~)
    (List(x), List(y)) =>
      slice_cmp_depth(x.items[:], y.items[:], depth - 1, op~)
    (Int(n), Float(f)) => Ok(int_float_cmp(n, f))
    (Float(f), Int(n)) => Ok(-int_float_cmp(n, f))
    (ExtVal(ac), _) =>
      match ac.get_compare(b) {
        Some(c) => Ok(c)
        None => Err("\{a.type_name()} \{op} \{b.type_name()} not implemented")
      }
    (_, ExtVal(rc)) =>
      match rc.get_compare(a) {
        Some(c) => Ok(-c)
        None => Err("\{a.type_name()} \{op} \{b.type_name()} not implemented")
      }
    _ => Err("\{a.type_name()} \{op} \{b.type_name()} not implemented")
  }
}

///|
/// Like `starlark_equals` but with an explicit recursion-depth cap.
///
/// Parameters:
///
/// - `a` : The left-hand side value.
/// - `b` : The right-hand side value.
/// - `depth` : Maximum remaining recursion depth; returns `Err` when it
///   reaches zero.
///
/// Returns `Ok(true)` when equal, `Ok(false)` when not, or `Err` when the
/// depth limit is exceeded.
#internal(unsafe, "eval engine only; not part of the public embedding API")
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
    (Function(x), Function(y)) => Ok(physical_equal(x, y))
    (Builtin(x), Builtin(y)) => Ok(x.name == y.name)
    (BoundMethod(x), BoundMethod(y)) => Ok(x.id == y.id)
    (Module(x), Module(y)) => Ok(physical_equal(x, y))
    (StringElems(x), StringElems(y)) => Ok(x.s.equals(y.s) && x.ords == y.ords)
    (StringCodepoints(x), StringCodepoints(y)) =>
      Ok(x.s.equals(y.s) && x.ords == y.ords)
    (BytesElems(x), BytesElems(y)) => Ok(x.b.equal(y.b))
    (ExtVal(a), ExtVal(b)) => a.get_equals(ExtVal(b), depth - 1)
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
  op? : String = "<",
) -> Result[Int, String] {
  let len = if a.length() < b.length() { a.length() } else { b.length() }
  for i in 0..<len {
    match compare_values_depth(a[i], b[i], depth, op~) {
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
/// Recursively deep-freezes `self` and all values reachable from it (list
/// items, dict keys/values, set elements, function defaults and closures).
///
/// Parameters:
///
/// - `self` : The root value to freeze.
pub fn Value::freeze(self : Value) -> Unit {
  freeze_value_inner(self, [])
}

///|
fn freeze_value_inner(v : Value, seen_funcs : Array[StarlarkFunction]) -> Unit {
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
      if seen_funcs.iter().any(fn(g) { physical_equal(g, f) }) {
        return
      }
      seen_funcs.push(f)
      for default_opt in f.defaults {
        match default_opt {
          Some(dv) => freeze_value_inner(dv, seen_funcs)
          None => ()
        }
      }
      // Freeze the values the closure captured through cells, so freezing the
      // function also freezes the data it closes over.
      for cell in f.vm_freevars {
        match cell.get() {
          Some(cv) => freeze_value_inner(cv, seen_funcs)
          None => ()
        }
      }
    }
    BoundMethod(m) => freeze_value_inner(m.recv, seen_funcs)
    Builtin(f) =>
      match f.receiver() {
        Some(r) => freeze_value_inner(r, seen_funcs)
        None => ()
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
  if xl == 0L {
    return true
  }
  if x.start != y.start {
    return false
  }
  xl == 1L || x.step == y.step
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
        Ok(Some(bv)) => if v.starlark_equals(bv) == false { ok = false }
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
