///|
pub impl Eq for Value with fn equal(a, b) -> Bool {
  starlark_equals(a, b)
}

///|
pub fn to_str(v : Value) -> String {
  match v {
    NoneVal => "None"
    BoolVal(true) => "True"
    BoolVal(false) => "False"
    IntVal(i) => i.to_string()
    FloatVal(f) => format_float(f)
    StrVal(s) => s.raw
    BytesVal(b) => repr_bytes_val(b)
    ListVal(l) => repr_list(l)
    TupleVal(t) => repr_tuple(t)
    DictVal(d) => repr_dict(d)
    SetVal(s) => repr_set(s)
    RangeVal(_)
    | FuncVal(_)
    | BuiltinFuncVal(_)
    | BoundMethodVal(_)
    | ModuleVal(_) => repr(v)
  }
}

///|
pub fn starlark_equals(a : Value, b : Value) -> Bool {
  match (a, b) {
    (NoneVal, NoneVal) => true
    (BoolVal(x), BoolVal(y)) => x == y
    (IntVal(x), IntVal(y)) => x == y
    (FloatVal(x), FloatVal(y)) => x == y
    (StrVal(x), StrVal(y)) => x.equals(y)
    (BytesVal(x), BytesVal(y)) => x.equal(y)
    (ListVal(x), ListVal(y)) => slice_equals(x.items[:], y.items[:])
    (TupleVal(x), TupleVal(y)) => slice_equals(x[:], y[:])
    (IntVal(n), FloatVal(f)) => int_float_eq(n, f)
    (FloatVal(f), IntVal(n)) => int_float_eq(n, f)
    (DictVal(x), DictVal(y)) => dict_equals(x, y)
    (SetVal(x), SetVal(y)) => set_equals(x, y)
    (RangeVal(x), RangeVal(y)) => range_equals(x, y)
    // Functions use identity: two distinct objects are never equal
    (FuncVal(_), FuncVal(_)) => false
    (BuiltinFuncVal(x), BuiltinFuncVal(y)) => x.name == y.name
    // Modules use identity equality
    (ModuleVal(_), ModuleVal(_)) => false
    _ => false
  }
}

///|
fn int_float_eq(n : Int64, f : Double) -> Bool {
  if f.is_nan() || f.is_inf() {
    return false
  }
  n.to_double() == f
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

// FNV-1a 32-bit constants

///|
let fnv_offset_basis : UInt = 2166136261U

///|
let fnv_prime : UInt = 16777619U

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
fn hash_int64(n : Int64) -> UInt {
  // Matches starlark-go: 12582917 * uint32(lo+3)
  // Take lower 32 bits of n (two's complement), add 3, multiply.
  let lo = n.to_int().reinterpret_as_uint()
  12582917U * (lo + 3U)
}

///|
fn hash_float(f : Double) -> UInt {
  if f.is_nan() || f.is_inf() {
    return 1618033U
  }
  // Finite: truncate toward zero to Int64, hash as Int
  hash_int64(f.to_int64())
}

///|
fn hash_tuple(t : Array[Value]) -> Result[UInt, String] {
  // Python's tuple hash algorithm (same as starlark-go)
  let mut x : UInt = 0x345678U
  let mut mult : UInt = 1000003U
  let n = (t.length() + t.length()).reinterpret_as_uint()
  for elem in t {
    match starlark_hash(elem) {
      Err(e) => return Err(e)
      Ok(y) => {
        x = x ^ (y * mult)
        mult = mult + 82520U + n
      }
    }
  }
  Ok(x)
}

///|
pub fn starlark_hash(v : Value) -> Result[UInt, String] {
  match v {
    NoneVal => Ok(0U)
    BoolVal(false) => Ok(0U)
    BoolVal(true) => Ok(1U)
    IntVal(n) => Ok(hash_int64(n))
    FloatVal(f) => Ok(hash_float(f))
    StrVal(s) => Ok(fnv1a(s.bytes))
    BytesVal(b) => Ok(fnv1a(b))
    TupleVal(t) => hash_tuple(t)
    ListVal(_) => Err("unhashable type: list")
    DictVal(_) => Err("unhashable type: dict")
    SetVal(_) => Err("unhashable type: set")
    RangeVal(_) => Err("unhashable: range")
    FuncVal(_) => Err("unhashable type: function")
    BuiltinFuncVal(_) => Err("unhashable type: builtin_function_or_method")
    BoundMethodVal(_) => Err("unhashable type: builtin_function_or_method")
    ModuleVal(_) => Err("unhashable type: module")
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
fn slice_cmp(a : ArrayView[Value], b : ArrayView[Value]) -> Result[Int, String] {
  let len = if a.length() < b.length() { a.length() } else { b.length() }
  for i in 0..<len {
    match compare_values(a[i], b[i]) {
      Err(e) => return Err(e)
      Ok(c) => if c != 0 { return Ok(c) }
    }
  }
  Ok(int64_signum(a.length().to_int64(), b.length().to_int64()))
}

///|
fn int_float_cmp(n : Int64, f : Double) -> Int {
  if f != f {
    // f is NaN; NaN > everything, so int < NaN
    -1
  } else if f == @double.infinity {
    -1 // n < +inf
  } else if f == @double.neg_infinity {
    1 // n > -inf
  } else {
    // finite: compare as float (precision loss possible for large Int64)
    float_cmp(n.to_double(), f)
  }
}

///|
pub fn compare_values(a : Value, b : Value) -> Result[Int, String] {
  match (a, b) {
    (BoolVal(x), BoolVal(y)) =>
      Ok(
        match (x, y) {
          (false, true) => -1
          (true, false) => 1
          _ => 0
        },
      )
    (IntVal(x), IntVal(y)) => Ok(int64_signum(x, y))
    (FloatVal(x), FloatVal(y)) => Ok(float_cmp(x, y))
    (StrVal(x), StrVal(y)) => Ok(bytes_lex_cmp(x.bytes, y.bytes))
    (BytesVal(x), BytesVal(y)) => Ok(bytes_lex_cmp(x, y))
    (TupleVal(x), TupleVal(y)) => slice_cmp(x[:], y[:])
    (ListVal(x), ListVal(y)) => slice_cmp(x.items[:], y.items[:])
    (IntVal(n), FloatVal(f)) => Ok(int_float_cmp(n, f))
    (FloatVal(f), IntVal(n)) => Ok(-int_float_cmp(n, f))
    _ => Err("\{type_name(a)} < \{type_name(b)} not implemented")
  }
}

///|
pub fn freeze_value(v : Value) -> Unit {
  freeze_value_inner(v, [])
}

///|
fn freeze_value_inner(v : Value, seen_funcs : Array[String]) -> Unit {
  match v {
    ListVal(l) => {
      if l.is_frozen() {
        return
      }
      l.freeze()
      for item in l.items {
        freeze_value_inner(item, seen_funcs)
      }
    }
    DictVal(d) => {
      if d.is_frozen() {
        return
      }
      d.freeze()
      d.each(fn(k, val) {
        freeze_value_inner(k, seen_funcs)
        freeze_value_inner(val, seen_funcs)
      })
    }
    SetVal(s) => {
      if s.is_frozen() {
        return
      }
      s.freeze()
      s.each(fn(k) { freeze_value_inner(k, seen_funcs) })
    }
    TupleVal(t) =>
      for item in t {
        freeze_value_inner(item, seen_funcs)
      }
    FuncVal(f) => {
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
      for scope_map in f.captured_scope {
        scope_map.each(fn(_, val) { freeze_value_inner(val, seen_funcs) })
      }
    }
    ModuleVal(_) => ()
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
