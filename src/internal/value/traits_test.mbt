///|
test "to_str: String returns raw unquoted value" {
  assert_eq(to_str(Value::String(StarlarkString::new("hello"))), "hello")
  assert_eq(to_str(Value::String(StarlarkString::new(""))), "")
  // str() does NOT escape — raw bytes are returned as-is
  assert_eq(
    to_str(Value::String(StarlarkString::new("say \"hi\""))),
    "say \"hi\"",
  )
}

///|
test "to_str: None returns None" {
  assert_eq(to_str(Value::None), "None")
}

///|
test "to_str: Bool returns True or False" {
  assert_eq(to_str(Value::Bool(true)), "True")
  assert_eq(to_str(Value::Bool(false)), "False")
}

///|
test "to_str: Int returns decimal string" {
  assert_eq(to_str(Value::Int(0N)), "0")
  assert_eq(to_str(Value::Int(42N)), "42")
  assert_eq(to_str(Value::Int(-1N)), "-1")
}

///|
test "to_str: Float returns formatted float same as repr" {
  assert_eq(to_str(Value::Float(1.0)), "1.0")
  assert_eq(to_str(Value::Float(1.5)), "1.5")
}

///|
test "to_str: Bytes returns b-quoted repr" {
  assert_eq(to_str(Value::Bytes(Bytes::new(0))), "b\"\"")
}

///|
test "to_str: List and Tuple same as repr" {
  assert_eq(to_str(Value::List(StarlarkList::new([]))), "[]")
  assert_eq(to_str(Value::Tuple([])), "()")
  assert_eq(to_str(Value::Tuple([Value::Int(1N)])), "(1,)")
}

// --- starlark_equals ---

///|
test "starlark_equals: None equals None" {
  assert_true(starlark_equals(Value::None, Value::None))
}

///|
test "starlark_equals: Bool equal when same" {
  assert_true(starlark_equals(Value::Bool(true), Value::Bool(true)))
  assert_true(starlark_equals(Value::Bool(false), Value::Bool(false)))
  assert_false(starlark_equals(Value::Bool(true), Value::Bool(false)))
}

///|
test "starlark_equals: Int equal when same value" {
  assert_true(starlark_equals(Value::Int(42N), Value::Int(42N)))
  assert_false(starlark_equals(Value::Int(42N), Value::Int(43N)))
  assert_true(starlark_equals(Value::Int(-1N), Value::Int(-1N)))
}

///|
test "starlark_equals: Float equal when same finite value" {
  assert_true(starlark_equals(Value::Float(1.0), Value::Float(1.0)))
  assert_false(starlark_equals(Value::Float(1.0), Value::Float(2.0)))
}

///|
test "starlark_equals: Float NaN is equal to itself" {
  let nan = @double.not_a_number
  assert_true(starlark_equals(Value::Float(nan), Value::Float(nan)))
}

///|
test "starlark_equals: String equal when same bytes" {
  assert_true(
    starlark_equals(
      Value::String(StarlarkString::new("hello")),
      Value::String(StarlarkString::new("hello")),
    ),
  )
  assert_false(
    starlark_equals(
      Value::String(StarlarkString::new("hello")),
      Value::String(StarlarkString::new("world")),
    ),
  )
}

///|
test "starlark_equals: Bytes equal when same content" {
  let a = @utf8.encode("abc")
  let b = @utf8.encode("abc")
  let c = @utf8.encode("xyz")
  assert_true(starlark_equals(Value::Bytes(a), Value::Bytes(b)))
  assert_false(starlark_equals(Value::Bytes(a), Value::Bytes(c)))
}

///|
test "starlark_equals: List equal when same length and elements" {
  let mk = fn(items : Array[Value]) -> Value {
    Value::List(StarlarkList::new(items))
  }
  let a = mk([Value::Int(1N), Value::Int(2N)])
  let b = mk([Value::Int(1N), Value::Int(2N)])
  let c = mk([Value::Int(1N), Value::Int(3N)])
  let d = mk([Value::Int(1N)])
  assert_true(starlark_equals(a, b))
  assert_false(starlark_equals(a, c))
  assert_false(starlark_equals(a, d))
}

///|
test "starlark_equals: Tuple equal when same length and elements" {
  let a = Value::Tuple([Value::Int(1N), Value::Int(2N)])
  let b = Value::Tuple([Value::Int(1N), Value::Int(2N)])
  let c = Value::Tuple([Value::Int(1N), Value::Int(3N)])
  assert_true(starlark_equals(a, b))
  assert_false(starlark_equals(a, c))
}

///|
test "starlark_equals: Int equals Float when numerically equal" {
  assert_true(starlark_equals(Value::Int(1N), Value::Float(1.0)))
  assert_true(starlark_equals(Value::Float(1.0), Value::Int(1N)))
  assert_false(starlark_equals(Value::Int(1N), Value::Float(1.5)))
  assert_false(
    starlark_equals(Value::Int(1N), Value::Float(@double.not_a_number)),
  )
  assert_false(starlark_equals(Value::Int(1N), Value::Float(@double.infinity)))
}

///|
test "starlark_equals: different non-numeric types are unequal" {
  assert_false(starlark_equals(Value::None, Value::Bool(false)))
  assert_false(starlark_equals(Value::Int(1N), Value::Bool(true)))
  assert_false(starlark_equals(Value::Int(0N), Value::None))
}

// --- starlark_hash ---

///|
test "starlark_hash: None hashes to 0" {
  assert_true(starlark_hash(Value::None) == Ok(0U))
}

///|
test "starlark_hash: Bool false hashes to 0, true hashes to 1" {
  assert_true(starlark_hash(Value::Bool(false)) == Ok(0U))
  assert_true(starlark_hash(Value::Bool(true)) == Ok(1U))
}

///|
test "starlark_hash: Int hash values ensure equal Int and Float produce the same hash" {
  let mul : UInt = 12582917U
  assert_true(starlark_hash(Value::Int(0N)) == Ok(mul * (0U + 3U)))
  assert_true(starlark_hash(Value::Int(1N)) == Ok(mul * (1U + 3U)))
  assert_true(starlark_hash(Value::Int(-1N)) == Ok(mul * (0xFFFFFFFFU + 3U)))
}

///|
test "starlark_hash: equal Int and Float produce same hash" {
  // hash(1.0) must equal hash(1) because 1.0 == 1 in starlark cross-type equality
  let h_int = starlark_hash(Value::Int(1N))
  let h_float = starlark_hash(Value::Float(1.0))
  assert_true(h_int == h_float)
  let h_int0 = starlark_hash(Value::Int(0N))
  let h_float0 = starlark_hash(Value::Float(0.0))
  assert_true(h_int0 == h_float0)
}

///|
test "starlark_hash: large Float equals large Int hash (MISSING-66)" {
  // 1e20 == 10**20 in Starlark so their hashes must match.
  // Old code used f.to_int64() which overflows for 1e20; new code uses
  // double_to_bigint so both sides go through hash_bigint with the same BigInt.
  let big_int = 100000000000000000000N // 10**20
  let h_int = starlark_hash(Value::Int(big_int))
  let h_float = starlark_hash(Value::Float(1.0e20))
  assert_true(h_int == h_float)
}

///|
test "starlark_hash: Float NaN and Inf all produce the same fixed hash" {
  // 1618033 is the spec constant for non-finite floats
  let non_finite_hash : UInt = 1618033U
  assert_true(
    starlark_hash(Value::Float(@double.not_a_number)) == Ok(non_finite_hash),
  )
  assert_true(
    starlark_hash(Value::Float(@double.infinity)) == Ok(non_finite_hash),
  )
  assert_true(
    starlark_hash(Value::Float(@double.neg_infinity)) == Ok(non_finite_hash),
  )
}

///|
test "starlark_hash: Bytes hash equals String hash for same bytes" {
  let s = "abc"
  let bytes = @utf8.encode(s)
  let h_str = starlark_hash(Value::String(StarlarkString::new(s)))
  let h_bytes = starlark_hash(Value::Bytes(bytes))
  assert_true(h_str == h_bytes)
}

///|
test "starlark_hash: empty Tuple has the spec-defined initial hash value" {
  // 0x345678 is the Starlark initial hash accumulator for tuples
  let tuple_hash_init : UInt = 0x345678U
  assert_true(starlark_hash(Value::Tuple([])) == Ok(tuple_hash_init))
}

///|
test "starlark_hash: Tuple hashes combine element hashes deterministically" {
  let t1 = Value::Tuple([Value::Int(0N)])
  let t2 = Value::Tuple([Value::Int(1N)])
  let h1 = starlark_hash(t1)
  let h2 = starlark_hash(t2)
  assert_true(h1 is Ok(_))
  assert_true(h2 is Ok(_))
  assert_false(h1 == h2)
}

///|
test "starlark_hash: List is unhashable" {
  let result = starlark_hash(Value::List(StarlarkList::new([])))
  assert_true(result is Err(_))
  match result {
    Err(msg) => assert_true(msg.contains("list"))
    _ => ()
  }
}

// --- compare_values ---

///|
test "compare_values: Bool False less than True" {
  assert_true(compare_values(Value::Bool(false), Value::Bool(true)) == Ok(-1))
  assert_true(compare_values(Value::Bool(true), Value::Bool(false)) == Ok(1))
  assert_true(compare_values(Value::Bool(true), Value::Bool(true)) == Ok(0))
}

///|
test "compare_values: Int numerical ordering" {
  assert_true(compare_values(Value::Int(1N), Value::Int(2N)) == Ok(-1))
  assert_true(compare_values(Value::Int(2N), Value::Int(1N)) == Ok(1))
  assert_true(compare_values(Value::Int(1N), Value::Int(1N)) == Ok(0))
  assert_true(compare_values(Value::Int(-1N), Value::Int(0N)) == Ok(-1))
}

///|
test "compare_values: Float standard ordering" {
  assert_true(compare_values(Value::Float(1.0), Value::Float(2.0)) == Ok(-1))
  assert_true(compare_values(Value::Float(2.0), Value::Float(1.0)) == Ok(1))
  assert_true(compare_values(Value::Float(1.0), Value::Float(1.0)) == Ok(0))
}

///|
test "compare_values: Float NaN is greater than positive infinity" {
  let nan = @double.not_a_number
  let inf = @double.infinity
  // NaN > +Inf per Starlark spec
  assert_true(compare_values(Value::Float(nan), Value::Float(inf)) == Ok(1))
  assert_true(compare_values(Value::Float(inf), Value::Float(nan)) == Ok(-1))
  // Two NaNs compare equal
  assert_true(compare_values(Value::Float(nan), Value::Float(nan)) == Ok(0))
}

///|
test "compare_values: String lexicographic byte ordering" {
  let cmp = fn(a : String, b : String) -> Result[Int, String] {
    compare_values(
      Value::String(StarlarkString::new(a)),
      Value::String(StarlarkString::new(b)),
    )
  }
  assert_true(cmp("a", "b") == Ok(-1))
  assert_true(cmp("b", "a") == Ok(1))
  assert_true(cmp("a", "a") == Ok(0))
  assert_true(cmp("a", "ab") == Ok(-1))
  assert_true(cmp("abc", "abd") == Ok(-1))
}

///|
test "compare_values: Bytes lexicographic ordering" {
  let a = Bytes::make(1, b'\x01')
  let b = Bytes::make(1, b'\x02')
  assert_true(compare_values(Value::Bytes(a), Value::Bytes(b)) == Ok(-1))
  assert_true(compare_values(Value::Bytes(b), Value::Bytes(a)) == Ok(1))
}

///|
test "compare_values: Tuple lexicographic element ordering" {
  let t1 = Value::Tuple([Value::Int(1N), Value::Int(2N)])
  let t2 = Value::Tuple([Value::Int(1N), Value::Int(3N)])
  let t3 = Value::Tuple([Value::Int(2N)])
  let empty = Value::Tuple([])
  assert_true(compare_values(t1, t2) == Ok(-1))
  assert_true(compare_values(t2, t1) == Ok(1))
  assert_true(compare_values(t1, t1) == Ok(0))
  assert_true(compare_values(empty, t1) == Ok(-1))
  assert_true(compare_values(t1, t3) == Ok(-1))
}

///|
test "compare_values: Int and Float cross-type ordering" {
  assert_true(compare_values(Value::Int(1N), Value::Float(1.5)) == Ok(-1))
  assert_true(compare_values(Value::Int(2N), Value::Float(1.5)) == Ok(1))
  assert_true(compare_values(Value::Int(1N), Value::Float(1.0)) == Ok(0))
  // Int vs infinity
  assert_true(
    compare_values(Value::Int(1000000N), Value::Float(@double.infinity)) ==
    Ok(-1),
  )
  assert_true(
    compare_values(Value::Int(1000000N), Value::Float(@double.neg_infinity)) ==
    Ok(1),
  )
  // Float vs Int (reversed operands)
  assert_true(compare_values(Value::Float(1.5), Value::Int(1N)) == Ok(1))
  assert_true(compare_values(Value::Float(1.5), Value::Int(2N)) == Ok(-1))
}

///|
test "compare_values: None is not orderable" {
  let result = compare_values(Value::None, Value::None)
  assert_true(result is Err(_))
}

///|
test "compare_values: different types are not orderable" {
  let result = compare_values(
    Value::Int(1N),
    Value::String(StarlarkString::new("a")),
  )
  assert_true(result is Err(_))
}

///|
test "starlark_hash: module is unhashable" {
  let m = StarlarkModule::new("assert", {})
  assert_true(starlark_hash(Value::Module(m)) is Err(_))
}

///|
test "to_str: module returns repr" {
  let m = StarlarkModule::new("assert", {})
  assert_eq(to_str(Value::Module(m)), "<module \"assert\">")
}
