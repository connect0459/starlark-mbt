///|
test "to_str: String returns raw unquoted value" {
  assert_eq(to_str(Value::StrVal(StarlarkString::new("hello"))), "hello")
  assert_eq(to_str(Value::StrVal(StarlarkString::new(""))), "")
  // str() does NOT escape — raw bytes are returned as-is
  assert_eq(
    to_str(Value::StrVal(StarlarkString::new("say \"hi\""))),
    "say \"hi\"",
  )
}

///|
test "to_str: None returns None" {
  assert_eq(to_str(Value::NoneVal), "None")
}

///|
test "to_str: Bool returns True or False" {
  assert_eq(to_str(Value::BoolVal(true)), "True")
  assert_eq(to_str(Value::BoolVal(false)), "False")
}

///|
test "to_str: Int returns decimal string" {
  assert_eq(to_str(Value::IntVal(0L)), "0")
  assert_eq(to_str(Value::IntVal(42L)), "42")
  assert_eq(to_str(Value::IntVal(-1L)), "-1")
}

///|
test "to_str: Float returns formatted float same as repr" {
  assert_eq(to_str(Value::FloatVal(1.0)), "1.0")
  assert_eq(to_str(Value::FloatVal(1.5)), "1.5")
}

///|
test "to_str: Bytes returns b-quoted repr" {
  assert_eq(to_str(Value::BytesVal(Bytes::new(0))), "b\"\"")
}

///|
test "to_str: List and Tuple same as repr" {
  assert_eq(to_str(Value::ListVal(StarlarkList::new([]))), "[]")
  assert_eq(to_str(Value::TupleVal([])), "()")
  assert_eq(to_str(Value::TupleVal([Value::IntVal(1L)])), "(1,)")
}

// --- starlark_equals ---

///|
test "starlark_equals: None equals None" {
  assert_true(starlark_equals(Value::NoneVal, Value::NoneVal))
}

///|
test "starlark_equals: Bool equal when same" {
  assert_true(starlark_equals(Value::BoolVal(true), Value::BoolVal(true)))
  assert_true(starlark_equals(Value::BoolVal(false), Value::BoolVal(false)))
  assert_false(starlark_equals(Value::BoolVal(true), Value::BoolVal(false)))
}

///|
test "starlark_equals: Int equal when same value" {
  assert_true(starlark_equals(Value::IntVal(42L), Value::IntVal(42L)))
  assert_false(starlark_equals(Value::IntVal(42L), Value::IntVal(43L)))
  assert_true(starlark_equals(Value::IntVal(-1L), Value::IntVal(-1L)))
}

///|
test "starlark_equals: Float equal when same finite value" {
  assert_true(starlark_equals(Value::FloatVal(1.0), Value::FloatVal(1.0)))
  assert_false(starlark_equals(Value::FloatVal(1.0), Value::FloatVal(2.0)))
}

///|
test "starlark_equals: Float NaN is equal to itself" {
  let nan = @double.not_a_number
  assert_true(starlark_equals(Value::FloatVal(nan), Value::FloatVal(nan)))
}

///|
test "starlark_equals: String equal when same bytes" {
  assert_true(
    starlark_equals(
      Value::StrVal(StarlarkString::new("hello")),
      Value::StrVal(StarlarkString::new("hello")),
    ),
  )
  assert_false(
    starlark_equals(
      Value::StrVal(StarlarkString::new("hello")),
      Value::StrVal(StarlarkString::new("world")),
    ),
  )
}

///|
test "starlark_equals: Bytes equal when same content" {
  let a = @utf8.encode("abc")
  let b = @utf8.encode("abc")
  let c = @utf8.encode("xyz")
  assert_true(starlark_equals(Value::BytesVal(a), Value::BytesVal(b)))
  assert_false(starlark_equals(Value::BytesVal(a), Value::BytesVal(c)))
}

///|
test "starlark_equals: List equal when same length and elements" {
  let mk = fn(items : Array[Value]) -> Value {
    Value::ListVal(StarlarkList::new(items))
  }
  let a = mk([Value::IntVal(1L), Value::IntVal(2L)])
  let b = mk([Value::IntVal(1L), Value::IntVal(2L)])
  let c = mk([Value::IntVal(1L), Value::IntVal(3L)])
  let d = mk([Value::IntVal(1L)])
  assert_true(starlark_equals(a, b))
  assert_false(starlark_equals(a, c))
  assert_false(starlark_equals(a, d))
}

///|
test "starlark_equals: Tuple equal when same length and elements" {
  let a = Value::TupleVal([Value::IntVal(1L), Value::IntVal(2L)])
  let b = Value::TupleVal([Value::IntVal(1L), Value::IntVal(2L)])
  let c = Value::TupleVal([Value::IntVal(1L), Value::IntVal(3L)])
  assert_true(starlark_equals(a, b))
  assert_false(starlark_equals(a, c))
}

///|
test "starlark_equals: Int equals Float when numerically equal" {
  assert_true(starlark_equals(Value::IntVal(1L), Value::FloatVal(1.0)))
  assert_true(starlark_equals(Value::FloatVal(1.0), Value::IntVal(1L)))
  assert_false(starlark_equals(Value::IntVal(1L), Value::FloatVal(1.5)))
  assert_false(
    starlark_equals(Value::IntVal(1L), Value::FloatVal(@double.not_a_number)),
  )
  assert_false(
    starlark_equals(Value::IntVal(1L), Value::FloatVal(@double.infinity)),
  )
}

///|
test "starlark_equals: different non-numeric types are unequal" {
  assert_false(starlark_equals(Value::NoneVal, Value::BoolVal(false)))
  assert_false(starlark_equals(Value::IntVal(1L), Value::BoolVal(true)))
  assert_false(starlark_equals(Value::IntVal(0L), Value::NoneVal))
}

// --- starlark_hash ---

///|
test "starlark_hash: None hashes to 0" {
  assert_true(starlark_hash(Value::NoneVal) == Ok(0U))
}

///|
test "starlark_hash: Bool false hashes to 0, true hashes to 1" {
  assert_true(starlark_hash(Value::BoolVal(false)) == Ok(0U))
  assert_true(starlark_hash(Value::BoolVal(true)) == Ok(1U))
}

///|
test "starlark_hash: Int hash values ensure equal Int and Float produce the same hash" {
  let mul : UInt = 12582917U
  assert_true(starlark_hash(Value::IntVal(0L)) == Ok(mul * (0U + 3U)))
  assert_true(starlark_hash(Value::IntVal(1L)) == Ok(mul * (1U + 3U)))
  assert_true(starlark_hash(Value::IntVal(-1L)) == Ok(mul * (0xFFFFFFFFU + 3U)))
}

///|
test "starlark_hash: equal Int and Float produce same hash" {
  // hash(1.0) must equal hash(1) because 1.0 == 1 in starlark cross-type equality
  let h_int = starlark_hash(Value::IntVal(1L))
  let h_float = starlark_hash(Value::FloatVal(1.0))
  assert_true(h_int == h_float)
  let h_int0 = starlark_hash(Value::IntVal(0L))
  let h_float0 = starlark_hash(Value::FloatVal(0.0))
  assert_true(h_int0 == h_float0)
}

///|
test "starlark_hash: Float NaN and Inf all produce the same fixed hash" {
  // 1618033 is the spec constant for non-finite floats
  let non_finite_hash : UInt = 1618033U
  assert_true(
    starlark_hash(Value::FloatVal(@double.not_a_number)) == Ok(non_finite_hash),
  )
  assert_true(
    starlark_hash(Value::FloatVal(@double.infinity)) == Ok(non_finite_hash),
  )
  assert_true(
    starlark_hash(Value::FloatVal(@double.neg_infinity)) == Ok(non_finite_hash),
  )
}

///|
test "starlark_hash: Bytes hash equals String hash for same bytes" {
  let s = "abc"
  let bytes = @utf8.encode(s)
  let h_str = starlark_hash(Value::StrVal(StarlarkString::new(s)))
  let h_bytes = starlark_hash(Value::BytesVal(bytes))
  assert_true(h_str == h_bytes)
}

///|
test "starlark_hash: empty Tuple has the spec-defined initial hash value" {
  // 0x345678 is the Starlark initial hash accumulator for tuples
  let tuple_hash_init : UInt = 0x345678U
  assert_true(starlark_hash(Value::TupleVal([])) == Ok(tuple_hash_init))
}

///|
test "starlark_hash: Tuple hashes combine element hashes deterministically" {
  let t1 = Value::TupleVal([Value::IntVal(0L)])
  let t2 = Value::TupleVal([Value::IntVal(1L)])
  let h1 = starlark_hash(t1)
  let h2 = starlark_hash(t2)
  assert_true(h1 is Ok(_))
  assert_true(h2 is Ok(_))
  assert_false(h1 == h2)
}

///|
test "starlark_hash: List is unhashable" {
  let result = starlark_hash(Value::ListVal(StarlarkList::new([])))
  assert_true(result is Err(_))
  match result {
    Err(msg) => assert_true(msg.contains("list"))
    _ => ()
  }
}

// --- compare_values ---

///|
test "compare_values: Bool False less than True" {
  assert_true(
    compare_values(Value::BoolVal(false), Value::BoolVal(true)) == Ok(-1),
  )
  assert_true(
    compare_values(Value::BoolVal(true), Value::BoolVal(false)) == Ok(1),
  )
  assert_true(
    compare_values(Value::BoolVal(true), Value::BoolVal(true)) == Ok(0),
  )
}

///|
test "compare_values: Int numerical ordering" {
  assert_true(compare_values(Value::IntVal(1L), Value::IntVal(2L)) == Ok(-1))
  assert_true(compare_values(Value::IntVal(2L), Value::IntVal(1L)) == Ok(1))
  assert_true(compare_values(Value::IntVal(1L), Value::IntVal(1L)) == Ok(0))
  assert_true(compare_values(Value::IntVal(-1L), Value::IntVal(0L)) == Ok(-1))
}

///|
test "compare_values: Float standard ordering" {
  assert_true(
    compare_values(Value::FloatVal(1.0), Value::FloatVal(2.0)) == Ok(-1),
  )
  assert_true(
    compare_values(Value::FloatVal(2.0), Value::FloatVal(1.0)) == Ok(1),
  )
  assert_true(
    compare_values(Value::FloatVal(1.0), Value::FloatVal(1.0)) == Ok(0),
  )
}

///|
test "compare_values: Float NaN is greater than positive infinity" {
  let nan = @double.not_a_number
  let inf = @double.infinity
  // NaN > +Inf per Starlark spec
  assert_true(
    compare_values(Value::FloatVal(nan), Value::FloatVal(inf)) == Ok(1),
  )
  assert_true(
    compare_values(Value::FloatVal(inf), Value::FloatVal(nan)) == Ok(-1),
  )
  // Two NaNs compare equal
  assert_true(
    compare_values(Value::FloatVal(nan), Value::FloatVal(nan)) == Ok(0),
  )
}

///|
test "compare_values: String lexicographic byte ordering" {
  let cmp = fn(a : String, b : String) -> Result[Int, String] {
    compare_values(
      Value::StrVal(StarlarkString::new(a)),
      Value::StrVal(StarlarkString::new(b)),
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
  assert_true(compare_values(Value::BytesVal(a), Value::BytesVal(b)) == Ok(-1))
  assert_true(compare_values(Value::BytesVal(b), Value::BytesVal(a)) == Ok(1))
}

///|
test "compare_values: Tuple lexicographic element ordering" {
  let t1 = Value::TupleVal([Value::IntVal(1L), Value::IntVal(2L)])
  let t2 = Value::TupleVal([Value::IntVal(1L), Value::IntVal(3L)])
  let t3 = Value::TupleVal([Value::IntVal(2L)])
  let empty = Value::TupleVal([])
  assert_true(compare_values(t1, t2) == Ok(-1))
  assert_true(compare_values(t2, t1) == Ok(1))
  assert_true(compare_values(t1, t1) == Ok(0))
  assert_true(compare_values(empty, t1) == Ok(-1))
  assert_true(compare_values(t1, t3) == Ok(-1))
}

///|
test "compare_values: Int and Float cross-type ordering" {
  assert_true(compare_values(Value::IntVal(1L), Value::FloatVal(1.5)) == Ok(-1))
  assert_true(compare_values(Value::IntVal(2L), Value::FloatVal(1.5)) == Ok(1))
  assert_true(compare_values(Value::IntVal(1L), Value::FloatVal(1.0)) == Ok(0))
  // Int vs infinity
  assert_true(
    compare_values(Value::IntVal(1000000L), Value::FloatVal(@double.infinity)) ==
    Ok(-1),
  )
  assert_true(
    compare_values(
      Value::IntVal(1000000L),
      Value::FloatVal(@double.neg_infinity),
    ) ==
    Ok(1),
  )
  // Float vs Int (reversed operands)
  assert_true(compare_values(Value::FloatVal(1.5), Value::IntVal(1L)) == Ok(1))
  assert_true(compare_values(Value::FloatVal(1.5), Value::IntVal(2L)) == Ok(-1))
}

///|
test "compare_values: None is not orderable" {
  let result = compare_values(Value::NoneVal, Value::NoneVal)
  assert_true(result is Err(_))
}

///|
test "compare_values: different types are not orderable" {
  let result = compare_values(
    Value::IntVal(1L),
    Value::StrVal(StarlarkString::new("a")),
  )
  assert_true(result is Err(_))
}

///|
test "starlark_hash: module is unhashable" {
  let m = StarlarkModule::new("assert", {})
  assert_true(starlark_hash(Value::ModuleVal(m)) is Err(_))
}

///|
test "to_str: module returns repr" {
  let m = StarlarkModule::new("assert", {})
  assert_eq(to_str(Value::ModuleVal(m)), "<module \"assert\">")
}
