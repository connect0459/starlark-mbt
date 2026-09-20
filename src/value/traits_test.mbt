///|
test "to_str: String returns raw unquoted value" {
  assert_eq(
    @value.Value::String(@value.StarlarkString::new("hello")).to_str(),
    "hello",
  )
  assert_eq(@value.Value::String(@value.StarlarkString::new("")).to_str(), "")
  // str() does NOT escape — raw bytes are returned as-is
  assert_eq(
    @value.Value::String(@value.StarlarkString::new("say \"hi\"")).to_str(),
    "say \"hi\"",
  )
}

///|
test "to_str: None returns None" {
  assert_eq(@value.Value::None.to_str(), "None")
}

///|
test "to_str: Bool returns True or False" {
  assert_eq(@value.Value::Bool(true).to_str(), "True")
  assert_eq(@value.Value::Bool(false).to_str(), "False")
}

///|
test "to_str: Int returns decimal string" {
  assert_eq(@value.Value::Int(0N).to_str(), "0")
  assert_eq(@value.Value::Int(42N).to_str(), "42")
  assert_eq(@value.Value::Int(-1N).to_str(), "-1")
}

///|
test "to_str: Float returns formatted float same as repr" {
  assert_eq(@value.Value::Float(1.0).to_str(), "1.0")
  assert_eq(@value.Value::Float(1.5).to_str(), "1.5")
}

///|
test "to_str: Bytes returns b-quoted repr" {
  assert_eq(@value.Value::Bytes(Bytes::new(0)).to_str(), "b\"\"")
}

///|
test "to_str: List and Tuple same as repr" {
  assert_eq(@value.Value::List(@value.StarlarkList::new([])).to_str(), "[]")
  assert_eq(@value.Value::Tuple([]).to_str(), "()")
  assert_eq(@value.Value::Tuple([@value.Value::Int(1N)]).to_str(), "(1,)")
}

// --- starlark_equals ---

///|
test "starlark_equals: None equals None" {
  assert_true(@value.Value::None.starlark_equals(@value.Value::None))
}

///|
test "starlark_equals: Bool equal when same" {
  assert_true(
    @value.Value::Bool(true).starlark_equals(@value.Value::Bool(true)),
  )
  assert_true(
    @value.Value::Bool(false).starlark_equals(@value.Value::Bool(false)),
  )
  assert_false(
    @value.Value::Bool(true).starlark_equals(@value.Value::Bool(false)),
  )
}

///|
test "starlark_equals: Int equal when same value" {
  assert_true(@value.Value::Int(42N).starlark_equals(@value.Value::Int(42N)))
  assert_false(@value.Value::Int(42N).starlark_equals(@value.Value::Int(43N)))
  assert_true(@value.Value::Int(-1N).starlark_equals(@value.Value::Int(-1N)))
}

///|
test "starlark_equals: Float equal when same finite value" {
  assert_true(
    @value.Value::Float(1.0).starlark_equals(@value.Value::Float(1.0)),
  )
  assert_false(
    @value.Value::Float(1.0).starlark_equals(@value.Value::Float(2.0)),
  )
}

///|
test "starlark_equals: Float NaN is equal to itself" {
  let nan = @double.not_a_number
  assert_true(
    @value.Value::Float(nan).starlark_equals(@value.Value::Float(nan)),
  )
}

///|
test "starlark_equals: String equal when same bytes" {
  assert_true(
    @value.Value::String(@value.StarlarkString::new("hello")).starlark_equals(
      @value.Value::String(@value.StarlarkString::new("hello")),
    ),
  )
  assert_false(
    @value.Value::String(@value.StarlarkString::new("hello")).starlark_equals(
      @value.Value::String(@value.StarlarkString::new("world")),
    ),
  )
}

///|
test "starlark_equals: Bytes equal when same content" {
  let a = @utf8.encode("abc")
  let b = @utf8.encode("abc")
  let c = @utf8.encode("xyz")
  assert_true(@value.Value::Bytes(a).starlark_equals(@value.Value::Bytes(b)))
  assert_false(@value.Value::Bytes(a).starlark_equals(@value.Value::Bytes(c)))
}

///|
test "starlark_equals: List equal when same length and elements" {
  let mk = fn(items : Array[@value.Value]) -> @value.Value {
    @value.Value::List(@value.StarlarkList::new(items))
  }
  let a = mk([@value.Value::Int(1N), @value.Value::Int(2N)])
  let b = mk([@value.Value::Int(1N), @value.Value::Int(2N)])
  let c = mk([@value.Value::Int(1N), @value.Value::Int(3N)])
  let d = mk([@value.Value::Int(1N)])
  assert_true(a.starlark_equals(b))
  assert_false(a.starlark_equals(c))
  assert_false(a.starlark_equals(d))
}

///|
test "starlark_equals: Tuple equal when same length and elements" {
  let a = @value.Value::Tuple([@value.Value::Int(1N), @value.Value::Int(2N)])
  let b = @value.Value::Tuple([@value.Value::Int(1N), @value.Value::Int(2N)])
  let c = @value.Value::Tuple([@value.Value::Int(1N), @value.Value::Int(3N)])
  assert_true(a.starlark_equals(b))
  assert_false(a.starlark_equals(c))
}

///|
test "starlark_equals: Int equals Float when numerically equal" {
  assert_true(@value.Value::Int(1N).starlark_equals(@value.Value::Float(1.0)))
  assert_true(@value.Value::Float(1.0).starlark_equals(@value.Value::Int(1N)))
  assert_false(@value.Value::Int(1N).starlark_equals(@value.Value::Float(1.5)))
  assert_false(
    @value.Value::Int(1N).starlark_equals(
      @value.Value::Float(@double.not_a_number),
    ),
  )
  assert_false(
    @value.Value::Int(1N).starlark_equals(@value.Value::Float(@double.infinity)),
  )
}

///|
test "starlark_equals: different non-numeric types are unequal" {
  assert_false(@value.Value::None.starlark_equals(@value.Value::Bool(false)))
  assert_false(@value.Value::Int(1N).starlark_equals(@value.Value::Bool(true)))
  assert_false(@value.Value::Int(0N).starlark_equals(@value.Value::None))
}

// --- starlark_hash ---

///|
test "starlark_hash: None hashes to 0" {
  assert_true(@value.Value::hash(@value.Value::None) == Ok(0U))
}

///|
test "starlark_hash: Bool false hashes to 0, true hashes to 1" {
  assert_true(@value.Value::hash(@value.Value::Bool(false)) == Ok(0U))
  assert_true(@value.Value::hash(@value.Value::Bool(true)) == Ok(1U))
}

///|
test "starlark_hash: Int hash values ensure equal Int and Float produce the same hash" {
  let mul : UInt = 12582917U
  assert_true(@value.Value::hash(@value.Value::Int(0N)) == Ok(mul * (0U + 3U)))
  assert_true(@value.Value::hash(@value.Value::Int(1N)) == Ok(mul * (1U + 3U)))
  assert_true(
    @value.Value::hash(@value.Value::Int(-1N)) == Ok(mul * (0xFFFFFFFFU + 3U)),
  )
}

///|
test "starlark_hash: equal Int and Float produce same hash" {
  // hash(1.0) must equal hash(1) because 1.0 == 1 in starlark cross-type equality
  let h_int = @value.Value::hash(@value.Value::Int(1N))
  let h_float = @value.Value::hash(@value.Value::Float(1.0))
  assert_true(h_int == h_float)
  let h_int0 = @value.Value::hash(@value.Value::Int(0N))
  let h_float0 = @value.Value::hash(@value.Value::Float(0.0))
  assert_true(h_int0 == h_float0)
}

///|
test "starlark_hash: large Float equals large Int hash" {
  // 1e20 == 10**20 in Starlark so their hashes must match.
  // Old code used f.to_int64() which overflows for 1e20; new code uses
  // double_to_bigint so both sides go through hash_bigint with the same BigInt.
  let big_int = 100000000000000000000N // 10**20
  let h_int = @value.Value::hash(@value.Value::Int(big_int))
  let h_float = @value.Value::hash(@value.Value::Float(1.0e20))
  assert_true(h_int == h_float)
}

///|
test "starlark_hash: Float NaN and Inf all produce the same fixed hash" {
  // 1618033 is the spec constant for non-finite floats
  let non_finite_hash : UInt = 1618033U
  assert_true(
    @value.Value::hash(@value.Value::Float(@double.not_a_number)) ==
    Ok(non_finite_hash),
  )
  assert_true(
    @value.Value::hash(@value.Value::Float(@double.infinity)) ==
    Ok(non_finite_hash),
  )
  assert_true(
    @value.Value::hash(@value.Value::Float(@double.neg_infinity)) ==
    Ok(non_finite_hash),
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
  assert_true(
    @value.Value::hash(@value.Value::Int(n)) == Ok(mul * (0xFFFFFFFFU + 3U)),
  )
}

///|
test "starlark_hash: Bytes hash equals String hash for same bytes" {
  let s = "abc"
  let bytes = @utf8.encode(s)
  let h_str = @value.Value::hash(
    @value.Value::String(@value.StarlarkString::new(s)),
  )
  let h_bytes = @value.Value::hash(@value.Value::Bytes(bytes))
  assert_true(h_str == h_bytes)
}

///|
test "starlark_hash: empty Tuple has the spec-defined initial hash value" {
  // 0x345678 is the Starlark initial hash accumulator for tuples
  let tuple_hash_init : UInt = 0x345678U
  assert_true(
    @value.Value::hash(@value.Value::Tuple([])) == Ok(tuple_hash_init),
  )
}

///|
test "starlark_hash: Tuple hashes combine element hashes deterministically" {
  let t1 = @value.Value::Tuple([@value.Value::Int(0N)])
  let t2 = @value.Value::Tuple([@value.Value::Int(1N)])
  let h1 = @value.Value::hash(t1)
  let h2 = @value.Value::hash(t2)
  assert_true(h1 is Ok(_))
  assert_true(h2 is Ok(_))
  assert_false(h1 == h2)
}

///|
test "starlark_hash: List is unhashable" {
  let result = @value.Value::hash(
    @value.Value::List(@value.StarlarkList::new([])),
  )
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
    @value.compare_values(@value.Value::Bool(false), @value.Value::Bool(true)) ==
    Ok(-1),
  )
  assert_true(
    @value.compare_values(@value.Value::Bool(true), @value.Value::Bool(false)) ==
    Ok(1),
  )
  assert_true(
    @value.compare_values(@value.Value::Bool(true), @value.Value::Bool(true)) ==
    Ok(0),
  )
}

///|
test "compare_values: Int numerical ordering" {
  assert_true(
    @value.compare_values(@value.Value::Int(1N), @value.Value::Int(2N)) ==
    Ok(-1),
  )
  assert_true(
    @value.compare_values(@value.Value::Int(2N), @value.Value::Int(1N)) == Ok(1),
  )
  assert_true(
    @value.compare_values(@value.Value::Int(1N), @value.Value::Int(1N)) == Ok(0),
  )
  assert_true(
    @value.compare_values(@value.Value::Int(-1N), @value.Value::Int(0N)) ==
    Ok(-1),
  )
}

///|
test "compare_values: Float standard ordering" {
  assert_true(
    @value.compare_values(@value.Value::Float(1.0), @value.Value::Float(2.0)) ==
    Ok(-1),
  )
  assert_true(
    @value.compare_values(@value.Value::Float(2.0), @value.Value::Float(1.0)) ==
    Ok(1),
  )
  assert_true(
    @value.compare_values(@value.Value::Float(1.0), @value.Value::Float(1.0)) ==
    Ok(0),
  )
}

///|
test "compare_values: Float NaN is greater than positive infinity" {
  let nan = @double.not_a_number
  let inf = @double.infinity
  // NaN > +Inf per Starlark spec
  assert_true(
    @value.compare_values(@value.Value::Float(nan), @value.Value::Float(inf)) ==
    Ok(1),
  )
  assert_true(
    @value.compare_values(@value.Value::Float(inf), @value.Value::Float(nan)) ==
    Ok(-1),
  )
  // Two NaNs compare equal
  assert_true(
    @value.compare_values(@value.Value::Float(nan), @value.Value::Float(nan)) ==
    Ok(0),
  )
}

///|
test "compare_values: String lexicographic byte ordering" {
  let cmp = fn(a : String, b : String) -> Result[Int, String] {
    @value.compare_values(
      @value.Value::String(@value.StarlarkString::new(a)),
      @value.Value::String(@value.StarlarkString::new(b)),
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
  assert_true(
    @value.compare_values(@value.Value::Bytes(a), @value.Value::Bytes(b)) ==
    Ok(-1),
  )
  assert_true(
    @value.compare_values(@value.Value::Bytes(b), @value.Value::Bytes(a)) ==
    Ok(1),
  )
}

///|
test "compare_values: Tuple lexicographic element ordering" {
  let t1 = @value.Value::Tuple([@value.Value::Int(1N), @value.Value::Int(2N)])
  let t2 = @value.Value::Tuple([@value.Value::Int(1N), @value.Value::Int(3N)])
  let t3 = @value.Value::Tuple([@value.Value::Int(2N)])
  let empty = @value.Value::Tuple([])
  assert_true(@value.compare_values(t1, t2) == Ok(-1))
  assert_true(@value.compare_values(t2, t1) == Ok(1))
  assert_true(@value.compare_values(t1, t1) == Ok(0))
  assert_true(@value.compare_values(empty, t1) == Ok(-1))
  assert_true(@value.compare_values(t1, t3) == Ok(-1))
}

///|
test "compare_values: Int and Float cross-type ordering" {
  assert_true(
    @value.compare_values(@value.Value::Int(1N), @value.Value::Float(1.5)) ==
    Ok(-1),
  )
  assert_true(
    @value.compare_values(@value.Value::Int(2N), @value.Value::Float(1.5)) ==
    Ok(1),
  )
  assert_true(
    @value.compare_values(@value.Value::Int(1N), @value.Value::Float(1.0)) ==
    Ok(0),
  )
  // Int vs infinity
  assert_true(
    @value.compare_values(
      @value.Value::Int(1000000N),
      @value.Value::Float(@double.infinity),
    ) ==
    Ok(-1),
  )
  assert_true(
    @value.compare_values(
      @value.Value::Int(1000000N),
      @value.Value::Float(@double.neg_infinity),
    ) ==
    Ok(1),
  )
  // Float vs Int (reversed operands)
  assert_true(
    @value.compare_values(@value.Value::Float(1.5), @value.Value::Int(1N)) ==
    Ok(1),
  )
  assert_true(
    @value.compare_values(@value.Value::Float(1.5), @value.Value::Int(2N)) ==
    Ok(-1),
  )
}

///|
test "compare_values: None is not orderable" {
  let result = @value.compare_values(@value.Value::None, @value.Value::None)
  assert_true(result is Err(_))
}

///|
test "compare_values: different types are not orderable" {
  let result = @value.compare_values(
    @value.Value::Int(1N),
    @value.Value::String(@value.StarlarkString::new("a")),
  )
  assert_true(result is Err(_))
}

///|
test "starlark_hash: module is unhashable" {
  let m = @value.StarlarkModule::new("assert", Map([]))
  assert_true(@value.Value::hash(@value.Value::Module(m)) is Err(_))
}

///|
test "to_str: module returns repr" {
  let m = @value.StarlarkModule::new("assert", Map([]))
  assert_eq(@value.Value::Module(m).to_str(), "<module \"assert\">")
}

// --- equality and hash edge cases for callable and iterator types ---

///|
test "starlark_equals: two distinct BoundMethod objects are unequal" {
  let m1 = @value.Value::BoundMethod(
    @value.StarlarkBoundMethod::new(@value.Value::None, "m"),
  )
  let m2 = @value.Value::BoundMethod(
    @value.StarlarkBoundMethod::new(@value.Value::None, "m"),
  )
  assert_false(m1.starlark_equals(m2))
}

///|
test "starlark_equals: Module is never equal to another Module" {
  let m1 = @value.Value::Module(@value.StarlarkModule::new("a", Map([])))
  let m2 = @value.Value::Module(@value.StarlarkModule::new("a", Map([])))
  assert_false(m1.starlark_equals(m2))
}

///|
test "starlark_equals: StringElems with same source string and ords flag are equal" {
  let s = @value.StarlarkString::new("abc")
  let e1 = @value.Value::StringElems(@value.StarlarkStringElems::new(s, false))
  let e2 = @value.Value::StringElems(@value.StarlarkStringElems::new(s, false))
  assert_true(e1.starlark_equals(e2))
}

///|
test "starlark_equals: StringElems with different source strings are unequal" {
  let e1 = @value.Value::StringElems(
    @value.StarlarkStringElems::new(@value.StarlarkString::new("ab"), false),
  )
  let e2 = @value.Value::StringElems(
    @value.StarlarkStringElems::new(@value.StarlarkString::new("cd"), false),
  )
  assert_false(e1.starlark_equals(e2))
}

///|
test "starlark_equals: StringElems with same string but different ords flags are unequal" {
  let s = @value.StarlarkString::new("abc")
  let e1 = @value.Value::StringElems(@value.StarlarkStringElems::new(s, false))
  let e2 = @value.Value::StringElems(@value.StarlarkStringElems::new(s, true))
  assert_false(e1.starlark_equals(e2))
}

///|
test "starlark_hash: StringElems is unhashable" {
  let s = @value.StarlarkString::new("hello")
  let e = @value.Value::StringElems(@value.StarlarkStringElems::new(s, false))
  assert_true(@value.Value::hash(e) is Err(_))
}

///|
test "starlark_equals: two Builtin functions with the same name are equal" {
  let f1 = @value.Value::Builtin(@value.StarlarkBuiltinFunc::dispatch("len"))
  let f2 = @value.Value::Builtin(@value.StarlarkBuiltinFunc::dispatch("len"))
  assert_true(f1.starlark_equals(f2))
}

///|
test "starlark_equals: two Builtin functions with different names are unequal" {
  let f1 = @value.Value::Builtin(@value.StarlarkBuiltinFunc::dispatch("len"))
  let f2 = @value.Value::Builtin(@value.StarlarkBuiltinFunc::dispatch("str"))
  assert_false(f1.starlark_equals(f2))
}

///|
test "starlark_equals: StringCodepoints with same source string and ords flag are equal" {
  let s = @value.StarlarkString::new("abc")
  let c1 = @value.Value::StringCodepoints(
    @value.StarlarkStringCodepoints::new(s, false),
  )
  let c2 = @value.Value::StringCodepoints(
    @value.StarlarkStringCodepoints::new(s, false),
  )
  assert_true(c1.starlark_equals(c2))
}

///|
test "starlark_equals: StringCodepoints with different source strings are unequal" {
  let c1 = @value.Value::StringCodepoints(
    @value.StarlarkStringCodepoints::new(
      @value.StarlarkString::new("ab"),
      false,
    ),
  )
  let c2 = @value.Value::StringCodepoints(
    @value.StarlarkStringCodepoints::new(
      @value.StarlarkString::new("cd"),
      false,
    ),
  )
  assert_false(c1.starlark_equals(c2))
}

///|
test "starlark_hash: StringCodepoints is unhashable" {
  let s = @value.StarlarkString::new("hello")
  let c = @value.Value::StringCodepoints(
    @value.StarlarkStringCodepoints::new(s, false),
  )
  assert_true(@value.Value::hash(c) is Err(_))
}

///|
test "starlark_equals: BytesElems with same bytes content are equal" {
  let b = @utf8.encode("hello")
  let e1 = @value.Value::BytesElems(@value.StarlarkBytesElems::new(b))
  let e2 = @value.Value::BytesElems(@value.StarlarkBytesElems::new(b))
  assert_true(e1.starlark_equals(e2))
}

///|
test "starlark_equals: BytesElems with different bytes content are unequal" {
  let e1 = @value.Value::BytesElems(
    @value.StarlarkBytesElems::new(@utf8.encode("hello")),
  )
  let e2 = @value.Value::BytesElems(
    @value.StarlarkBytesElems::new(@utf8.encode("world")),
  )
  assert_false(e1.starlark_equals(e2))
}

///|
test "starlark_hash: Builtin function produces a deterministic hash based on its name" {
  let f1 = @value.Value::Builtin(@value.StarlarkBuiltinFunc::dispatch("len"))
  let f2 = @value.Value::Builtin(@value.StarlarkBuiltinFunc::dispatch("len"))
  assert_true(@value.Value::hash(f1) is Ok(_))
  assert_true(@value.Value::hash(f1) == @value.Value::hash(f2))
}

///|
test "starlark_hash: BytesElems is unhashable" {
  let b = @utf8.encode("hello")
  let e = @value.Value::BytesElems(@value.StarlarkBytesElems::new(b))
  assert_true(@value.Value::hash(e) is Err(_))
}

// --- starlark_equals_depth ---

///|
test "starlark_equals_depth: Bytes equal when same content" {
  let a = @utf8.encode("abc")
  let b = @utf8.encode("abc")
  let c = @utf8.encode("xyz")
  assert_true(
    @value.starlark_equals_depth(
      @value.Value::Bytes(a),
      @value.Value::Bytes(b),
      10,
    ) ==
    Ok(true),
  )
  assert_true(
    @value.starlark_equals_depth(
      @value.Value::Bytes(a),
      @value.Value::Bytes(c),
      10,
    ) ==
    Ok(false),
  )
}

///|
test "starlark_equals_depth: Tuple equal when same elements" {
  let a = @value.Value::Tuple([@value.Value::Int(1N), @value.Value::Int(2N)])
  let b = @value.Value::Tuple([@value.Value::Int(1N), @value.Value::Int(2N)])
  let c = @value.Value::Tuple([@value.Value::Int(1N), @value.Value::Int(3N)])
  assert_true(@value.starlark_equals_depth(a, b, 10) == Ok(true))
  assert_true(@value.starlark_equals_depth(a, c, 10) == Ok(false))
}

///|
test "starlark_equals_depth: Range equal when start stop step match" {
  let r1 = @value.Value::Range(@value.StarlarkRange::new(0L, 5L, 1L))
  let r2 = @value.Value::Range(@value.StarlarkRange::new(0L, 5L, 1L))
  let r3 = @value.Value::Range(@value.StarlarkRange::new(0L, 4L, 1L))
  assert_true(@value.starlark_equals_depth(r1, r2, 10) == Ok(true))
  assert_true(@value.starlark_equals_depth(r1, r3, 10) == Ok(false))
}

///|
test "starlark_equals_depth: returns error when recursion limit is reached" {
  let a = @value.Value::Bytes(@utf8.encode("x"))
  let b = @value.Value::Bytes(@utf8.encode("x"))
  assert_true(@value.starlark_equals_depth(a, b, 0) is Err(_))
}

///|
test "starlark_equals_depth: ranges with same length but different start are not equal" {
  let r1 = @value.Value::Range(@value.StarlarkRange::new(0L, 5L, 1L))
  let r2 = @value.Value::Range(@value.StarlarkRange::new(1L, 6L, 1L))
  assert_true(@value.starlark_equals_depth(r1, r2, 10) == Ok(false))
}

///|
test "starlark_equals_depth: range(0, 1<<32) is not equal to empty range" {
  let big = @value.Value::Range(@value.StarlarkRange::new(0L, 4294967296L, 1L))
  let empty = @value.Value::Range(@value.StarlarkRange::new(0L, 0L, 1L))
  assert_true(@value.starlark_equals_depth(big, empty, 10) == Ok(false))
}

///|
test "compare_values: longer Bytes with common prefix is greater than shorter Bytes" {
  let prefix = @utf8.encode("ab")
  let longer = @utf8.encode("abc")
  assert_true(
    @value.compare_values(
      @value.Value::Bytes(longer),
      @value.Value::Bytes(prefix),
    ) ==
    Ok(1),
  )
  assert_true(
    @value.compare_values(
      @value.Value::Bytes(prefix),
      @value.Value::Bytes(longer),
    ) ==
    Ok(-1),
  )
}

///|
test "starlark_equals_depth: Builtin functions equal when same name" {
  let f1 = @value.Value::Builtin(@value.StarlarkBuiltinFunc::dispatch("len"))
  let f2 = @value.Value::Builtin(@value.StarlarkBuiltinFunc::dispatch("len"))
  let f3 = @value.Value::Builtin(@value.StarlarkBuiltinFunc::dispatch("str"))
  assert_true(@value.starlark_equals_depth(f1, f2, 10) == Ok(true))
  assert_true(@value.starlark_equals_depth(f1, f3, 10) == Ok(false))
}

///|
test "compare_depth: inequality operator negates structural equality" {
  assert_true(
    @value.compare_depth("!=", @value.Value::Int(1N), @value.Value::Int(2N), 10) ==
    Ok(true),
  )
  assert_true(
    @value.compare_depth("!=", @value.Value::Int(1N), @value.Value::Int(1N), 10) ==
    Ok(false),
  )
}

///|
test "compare_depth: less-than-or-equal holds for smaller and equal operands" {
  assert_true(
    @value.compare_depth("<=", @value.Value::Int(1N), @value.Value::Int(2N), 10) ==
    Ok(true),
  )
  assert_true(
    @value.compare_depth("<=", @value.Value::Int(2N), @value.Value::Int(2N), 10) ==
    Ok(true),
  )
  assert_true(
    @value.compare_depth("<=", @value.Value::Int(3N), @value.Value::Int(2N), 10) ==
    Ok(false),
  )
}

///|
test "compare_depth: greater-than comparisons report strict ordering" {
  assert_true(
    @value.compare_depth(">", @value.Value::Int(3N), @value.Value::Int(2N), 10) ==
    Ok(true),
  )
  assert_true(
    @value.compare_depth(">=", @value.Value::Int(2N), @value.Value::Int(2N), 10) ==
    Ok(true),
  )
}

///|
test "compare_depth: ordering incomparable types reports the underlying error" {
  let result = @value.compare_depth(
    "<",
    @value.Value::Int(1N),
    @value.Value::String(@value.StarlarkString::new("a")),
    10,
  )
  assert_true(result is Err(_))
}

///|
test "compare_depth: an unrecognized operator is rejected" {
  assert_true(
    @value.compare_depth("<>", @value.Value::Int(1N), @value.Value::Int(2N), 10) ==
    Err("unknown comparison operator: <>"),
  )
}

///|
test "compare_values_depth: an extension value without a comparator cannot be ordered" {
  let ext = @value.Value::ExtVal(
    @value.CustomValue::new(fn() { "widget" }, fn() { true }, fn() {
      "widget()"
    }),
  )
  // The extension value as the left operand.
  assert_true(
    @value.compare_values_depth(ext, @value.Value::Int(1N), 10) is Err(_),
  )
  // The extension value as the right operand.
  assert_true(
    @value.compare_values_depth(@value.Value::Int(1N), ext, 10) is Err(_),
  )
}

///|
test "starlark_equals_depth: bound methods are equal only when they share identity" {
  let bound = @value.StarlarkBoundMethod::new(
    @value.Value::String(@value.StarlarkString::new("hello")),
    "upper",
  )
  let same = @value.Value::BoundMethod(bound)
  let same_again = @value.Value::BoundMethod(bound)
  let other = @value.Value::BoundMethod(
    @value.StarlarkBoundMethod::new(
      @value.Value::String(@value.StarlarkString::new("hello")),
      "upper",
    ),
  )
  assert_true(@value.starlark_equals_depth(same, same_again, 10) == Ok(true))
  assert_true(@value.starlark_equals_depth(same, other, 10) == Ok(false))
}

// --- identity equality: same object is always equal to itself ---

///|
test "starlark_equals: same Module object is equal to itself" {
  let m = @value.StarlarkModule::new("a", Map([]))
  assert_true(@value.Value::Module(m).starlark_equals(@value.Value::Module(m)))
}

///|
test "starlark_equals: same StringElems is equal to itself" {
  let e = @value.StarlarkStringElems::new(
    @value.StarlarkString::new("abc"),
    false,
  )
  assert_true(
    @value.Value::StringElems(e).starlark_equals(@value.Value::StringElems(e)),
  )
}

///|
test "starlark_equals: same StringCodepoints is equal to itself" {
  let c = @value.StarlarkStringCodepoints::new(
    @value.StarlarkString::new("abc"),
    false,
  )
  assert_true(
    @value.Value::StringCodepoints(c).starlark_equals(
      @value.Value::StringCodepoints(c),
    ),
  )
}

///|
test "starlark_equals: same BytesElems is equal to itself" {
  let e = @value.StarlarkBytesElems::new(@utf8.encode("hello"))
  assert_true(
    @value.Value::BytesElems(e).starlark_equals(@value.Value::BytesElems(e)),
  )
}

///|
test "starlark_equals_depth: same Module object is equal to itself" {
  let m = @value.StarlarkModule::new("a", Map([]))
  assert_true(
    @value.starlark_equals_depth(
      @value.Value::Module(m),
      @value.Value::Module(m),
      10,
    ) ==
    Ok(true),
  )
}

///|
test "starlark_equals_depth: same StringElems is equal to itself" {
  let e = @value.StarlarkStringElems::new(
    @value.StarlarkString::new("abc"),
    false,
  )
  assert_true(
    @value.starlark_equals_depth(
      @value.Value::StringElems(e),
      @value.Value::StringElems(e),
      10,
    ) ==
    Ok(true),
  )
}

///|
test "starlark_equals_depth: same StringCodepoints is equal to itself" {
  let c = @value.StarlarkStringCodepoints::new(
    @value.StarlarkString::new("abc"),
    false,
  )
  assert_true(
    @value.starlark_equals_depth(
      @value.Value::StringCodepoints(c),
      @value.Value::StringCodepoints(c),
      10,
    ) ==
    Ok(true),
  )
}

///|
test "starlark_equals_depth: same BytesElems is equal to itself" {
  let e = @value.StarlarkBytesElems::new(@utf8.encode("hello"))
  assert_true(
    @value.starlark_equals_depth(
      @value.Value::BytesElems(e),
      @value.Value::BytesElems(e),
      10,
    ) ==
    Ok(true),
  )
}
