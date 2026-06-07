///|
test "to_str: String returns raw unquoted value" {
  assert_eq(Value::String(StarlarkString::new("hello")).to_str(), "hello")
  assert_eq(Value::String(StarlarkString::new("")).to_str(), "")
  // str() does NOT escape — raw bytes are returned as-is
  assert_eq(
    Value::String(StarlarkString::new("say \"hi\"")).to_str(),
    "say \"hi\"",
  )
}

///|
test "to_str: None returns None" {
  assert_eq(Value::None.to_str(), "None")
}

///|
test "to_str: Bool returns True or False" {
  assert_eq(Value::Bool(true).to_str(), "True")
  assert_eq(Value::Bool(false).to_str(), "False")
}

///|
test "to_str: Int returns decimal string" {
  assert_eq(Value::Int(0N).to_str(), "0")
  assert_eq(Value::Int(42N).to_str(), "42")
  assert_eq(Value::Int(-1N).to_str(), "-1")
}

///|
test "to_str: Float returns formatted float same as repr" {
  assert_eq(Value::Float(1.0).to_str(), "1.0")
  assert_eq(Value::Float(1.5).to_str(), "1.5")
}

///|
test "to_str: Bytes returns b-quoted repr" {
  assert_eq(Value::Bytes(Bytes::new(0)).to_str(), "b\"\"")
}

///|
test "to_str: List and Tuple same as repr" {
  assert_eq(Value::List(StarlarkList::new([])).to_str(), "[]")
  assert_eq(Value::Tuple([]).to_str(), "()")
  assert_eq(Value::Tuple([Value::Int(1N)]).to_str(), "(1,)")
}

// --- starlark_equals ---

///|
test "starlark_equals: None equals None" {
  assert_true(Value::None.starlark_equals(Value::None))
}

///|
test "starlark_equals: Bool equal when same" {
  assert_true(Value::Bool(true).starlark_equals(Value::Bool(true)))
  assert_true(Value::Bool(false).starlark_equals(Value::Bool(false)))
  assert_false(Value::Bool(true).starlark_equals(Value::Bool(false)))
}

///|
test "starlark_equals: Int equal when same value" {
  assert_true(Value::Int(42N).starlark_equals(Value::Int(42N)))
  assert_false(Value::Int(42N).starlark_equals(Value::Int(43N)))
  assert_true(Value::Int(-1N).starlark_equals(Value::Int(-1N)))
}

///|
test "starlark_equals: Float equal when same finite value" {
  assert_true(Value::Float(1.0).starlark_equals(Value::Float(1.0)))
  assert_false(Value::Float(1.0).starlark_equals(Value::Float(2.0)))
}

///|
test "starlark_equals: Float NaN is equal to itself" {
  let nan = @double.not_a_number
  assert_true(Value::Float(nan).starlark_equals(Value::Float(nan)))
}

///|
test "starlark_equals: String equal when same bytes" {
  assert_true(
    Value::String(StarlarkString::new("hello")).starlark_equals(
      Value::String(StarlarkString::new("hello")),
    ),
  )
  assert_false(
    Value::String(StarlarkString::new("hello")).starlark_equals(
      Value::String(StarlarkString::new("world")),
    ),
  )
}

///|
test "starlark_equals: Bytes equal when same content" {
  let a = @utf8.encode("abc")
  let b = @utf8.encode("abc")
  let c = @utf8.encode("xyz")
  assert_true(Value::Bytes(a).starlark_equals(Value::Bytes(b)))
  assert_false(Value::Bytes(a).starlark_equals(Value::Bytes(c)))
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
  assert_true(a.starlark_equals(b))
  assert_false(a.starlark_equals(c))
  assert_false(a.starlark_equals(d))
}

///|
test "starlark_equals: Tuple equal when same length and elements" {
  let a = Value::Tuple([Value::Int(1N), Value::Int(2N)])
  let b = Value::Tuple([Value::Int(1N), Value::Int(2N)])
  let c = Value::Tuple([Value::Int(1N), Value::Int(3N)])
  assert_true(a.starlark_equals(b))
  assert_false(a.starlark_equals(c))
}

///|
test "starlark_equals: Int equals Float when numerically equal" {
  assert_true(Value::Int(1N).starlark_equals(Value::Float(1.0)))
  assert_true(Value::Float(1.0).starlark_equals(Value::Int(1N)))
  assert_false(Value::Int(1N).starlark_equals(Value::Float(1.5)))
  assert_false(
    Value::Int(1N).starlark_equals(Value::Float(@double.not_a_number)),
  )
  assert_false(Value::Int(1N).starlark_equals(Value::Float(@double.infinity)))
}

///|
test "starlark_equals: different non-numeric types are unequal" {
  assert_false(Value::None.starlark_equals(Value::Bool(false)))
  assert_false(Value::Int(1N).starlark_equals(Value::Bool(true)))
  assert_false(Value::Int(0N).starlark_equals(Value::None))
}

// --- starlark_hash ---

///|
test "starlark_hash: None hashes to 0" {
  assert_true(Value::hash(Value::None) == Ok(0U))
}

///|
test "starlark_hash: Bool false hashes to 0, true hashes to 1" {
  assert_true(Value::hash(Value::Bool(false)) == Ok(0U))
  assert_true(Value::hash(Value::Bool(true)) == Ok(1U))
}

///|
test "starlark_hash: Int hash values ensure equal Int and Float produce the same hash" {
  let mul : UInt = 12582917U
  assert_true(Value::hash(Value::Int(0N)) == Ok(mul * (0U + 3U)))
  assert_true(Value::hash(Value::Int(1N)) == Ok(mul * (1U + 3U)))
  assert_true(Value::hash(Value::Int(-1N)) == Ok(mul * (0xFFFFFFFFU + 3U)))
}

///|
test "starlark_hash: equal Int and Float produce same hash" {
  // hash(1.0) must equal hash(1) because 1.0 == 1 in starlark cross-type equality
  let h_int = Value::hash(Value::Int(1N))
  let h_float = Value::hash(Value::Float(1.0))
  assert_true(h_int == h_float)
  let h_int0 = Value::hash(Value::Int(0N))
  let h_float0 = Value::hash(Value::Float(0.0))
  assert_true(h_int0 == h_float0)
}

///|
test "starlark_hash: large Float equals large Int hash" {
  // 1e20 == 10**20 in Starlark so their hashes must match.
  // Old code used f.to_int64() which overflows for 1e20; new code uses
  // double_to_bigint so both sides go through hash_bigint with the same BigInt.
  let big_int = 100000000000000000000N // 10**20
  let h_int = Value::hash(Value::Int(big_int))
  let h_float = Value::hash(Value::Float(1.0e20))
  assert_true(h_int == h_float)
}

///|
test "starlark_hash: Float NaN and Inf all produce the same fixed hash" {
  // 1618033 is the spec constant for non-finite floats
  let non_finite_hash : UInt = 1618033U
  assert_true(
    Value::hash(Value::Float(@double.not_a_number)) == Ok(non_finite_hash),
  )
  assert_true(
    Value::hash(Value::Float(@double.infinity)) == Ok(non_finite_hash),
  )
  assert_true(
    Value::hash(Value::Float(@double.neg_infinity)) == Ok(non_finite_hash),
  )
}

///|
test "starlark_hash: large negative BigInt uses low 32 bits of magnitude" {
  // For BigInts outside Int64 range, the hash uses bits[0] (low 64-bit
  // word of the magnitude). The hash formula reduces to:
  //   uint32(magnitude_lo64 + 3) = uint32(magnitude_lo32 + 3)
  // so we only need the low 32 bits of the magnitude.
  //
  // Test case: -(2^64 - 1) has magnitude 2^64-1 = 0xFFFFFFFF_FFFFFFFF.
  //   magnitude mod 2^32 = 0xFFFFFFFF.
  //   Expected hash = 12582917 * uint32(0xFFFFFFFF + 3) = 12582917 * 2 = 25165834.
  let mul : UInt = 12582917U
  let n = -18446744073709551615N // -(2^64 - 1)
  assert_true(Value::hash(Value::Int(n)) == Ok(mul * (0xFFFFFFFFU + 3U)))
}

///|
test "starlark_hash: Bytes hash equals String hash for same bytes" {
  let s = "abc"
  let bytes = @utf8.encode(s)
  let h_str = Value::hash(Value::String(StarlarkString::new(s)))
  let h_bytes = Value::hash(Value::Bytes(bytes))
  assert_true(h_str == h_bytes)
}

///|
test "starlark_hash: empty Tuple has the spec-defined initial hash value" {
  // 0x345678 is the Starlark initial hash accumulator for tuples
  let tuple_hash_init : UInt = 0x345678U
  assert_true(Value::hash(Value::Tuple([])) == Ok(tuple_hash_init))
}

///|
test "starlark_hash: Tuple hashes combine element hashes deterministically" {
  let t1 = Value::Tuple([Value::Int(0N)])
  let t2 = Value::Tuple([Value::Int(1N)])
  let h1 = Value::hash(t1)
  let h2 = Value::hash(t2)
  assert_true(h1 is Ok(_))
  assert_true(h2 is Ok(_))
  assert_false(h1 == h2)
}

///|
test "starlark_hash: List is unhashable" {
  let result = Value::hash(Value::List(StarlarkList::new([])))
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
  assert_true(Value::hash(Value::Module(m)) is Err(_))
}

///|
test "to_str: module returns repr" {
  let m = StarlarkModule::new("assert", {})
  assert_eq(Value::Module(m).to_str(), "<module \"assert\">")
}

// --- equality and hash edge cases for callable and iterator types ---

///|
test "starlark_equals: function equality uses object identity, not name" {
  let pos = @errors.Position::new("", 0, 0)
  let f1 = Value::Function(StarlarkFunction::new("f", pos))
  let f2 = Value::Function(StarlarkFunction::new("f", pos))
  assert_false(f1.starlark_equals(f2))
}

///|
test "starlark_equals: a Function is equal to itself" {
  let f = StarlarkFunction::new("f", @errors.Position::new("", 0, 0))
  let v = Value::Function(f)
  assert_true(v.starlark_equals(v))
}

///|
test "starlark_equals: two distinct BoundMethod objects are unequal" {
  let m1 = Value::BoundMethod(StarlarkBoundMethod::new(Value::None, "m"))
  let m2 = Value::BoundMethod(StarlarkBoundMethod::new(Value::None, "m"))
  assert_false(m1.starlark_equals(m2))
}

///|
test "starlark_equals: Module is never equal to another Module" {
  let m1 = Value::Module(StarlarkModule::new("a", {}))
  let m2 = Value::Module(StarlarkModule::new("a", {}))
  assert_false(m1.starlark_equals(m2))
}

///|
test "starlark_equals: StringElems is never equal to another StringElems" {
  let s = StarlarkString::new("abc")
  let e1 = Value::StringElems(StarlarkStringElems::new(s, false))
  let e2 = Value::StringElems(StarlarkStringElems::new(s, false))
  assert_false(e1.starlark_equals(e2))
}

///|
test "starlark_hash: StringElems is unhashable" {
  let s = StarlarkString::new("hello")
  let e = Value::StringElems(StarlarkStringElems::new(s, false))
  assert_true(Value::hash(e) is Err(_))
}

///|
test "starlark_equals: two Builtin functions with the same name are equal" {
  let f1 = Value::Builtin(StarlarkBuiltinFunc::dispatch("len"))
  let f2 = Value::Builtin(StarlarkBuiltinFunc::dispatch("len"))
  assert_true(f1.starlark_equals(f2))
}

///|
test "starlark_equals: two Builtin functions with different names are unequal" {
  let f1 = Value::Builtin(StarlarkBuiltinFunc::dispatch("len"))
  let f2 = Value::Builtin(StarlarkBuiltinFunc::dispatch("str"))
  assert_false(f1.starlark_equals(f2))
}

///|
test "starlark_equals: two distinct StringCodepoints iterators are always unequal" {
  let s = StarlarkString::new("abc")
  let c1 = Value::StringCodepoints(StarlarkStringCodepoints::new(s, false))
  let c2 = Value::StringCodepoints(StarlarkStringCodepoints::new(s, false))
  assert_false(c1.starlark_equals(c2))
}

///|
test "starlark_hash: StringCodepoints is unhashable" {
  let s = StarlarkString::new("hello")
  let c = Value::StringCodepoints(StarlarkStringCodepoints::new(s, false))
  assert_true(Value::hash(c) is Err(_))
}
