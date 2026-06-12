// Tests for the iterator protocol: iterate(), StarlarkIterator, length_of().

///|
fn must_iterate(v : Value) -> StarlarkIterator {
  match iterate(v) {
    Ok(it) => it
    Err(_) => panic()
  }
}

// --- iterate: basic iteration ---

///|
test "iterate: list yields items in insertion order" {
  let l = StarlarkList::new([Value::Int(1N), Value::Int(2N), Value::Int(3N)])
  let it = must_iterate(Value::List(l))
  assert_true(it.next() == Some(Value::Int(1N)))
  assert_true(it.next() == Some(Value::Int(2N)))
  assert_true(it.next() == Some(Value::Int(3N)))
  assert_true(it.next() == None)
  it.done()
}

///|
test "iterate: empty list is immediately exhausted" {
  let it = must_iterate(Value::List(StarlarkList::new([])))
  assert_true(it.next() == None)
  it.done()
}

///|
test "iterate: tuple yields items in order" {
  let t = Value::Tuple([
    Value::Int(10N),
    Value::String(StarlarkString::new("x")),
  ])
  let it = must_iterate(t)
  assert_true(it.next() == Some(Value::Int(10N)))
  assert_true(it.next() == Some(Value::String(StarlarkString::new("x"))))
  assert_true(it.next() == None)
  it.done()
}

///|
test "iterate: string is not iterable" {
  match iterate(Value::String(StarlarkString::new("abc"))) {
    Err(msg) => assert_true(msg.contains("not iterable"))
    Ok(_) => panic()
  }
}

///|
test "iterate: string with multibyte is not iterable" {
  match iterate(Value::String(StarlarkString::new("Ω"))) {
    Err(msg) => assert_true(msg.contains("not iterable"))
    Ok(_) => panic()
  }
}

///|
test "iterate: bytes is not iterable" {
  let b = Value::Bytes(Bytes::from_array([b'\x01', b'\x02', b'\x03']))
  match iterate(b) {
    Err(msg) => assert_eq(msg, "bytes value is not iterable")
    Ok(_) => panic()
  }
}

///|
test "iterate: dict yields keys in insertion order" {
  let d = StarlarkDict::new()
  d.set(Value::String(StarlarkString::new("a")), Value::Int(1N)) |> ignore
  d.set(Value::String(StarlarkString::new("b")), Value::Int(2N)) |> ignore
  d.set(Value::String(StarlarkString::new("c")), Value::Int(3N)) |> ignore
  let it = must_iterate(Value::Dict(d))
  assert_true(it.next() == Some(Value::String(StarlarkString::new("a"))))
  assert_true(it.next() == Some(Value::String(StarlarkString::new("b"))))
  assert_true(it.next() == Some(Value::String(StarlarkString::new("c"))))
  assert_true(it.next() == None)
  it.done()
}

///|
test "iterate: set yields keys in insertion order" {
  let s = StarlarkSet::new()
  s.add(Value::Int(10N)) |> ignore
  s.add(Value::Int(20N)) |> ignore
  s.add(Value::Int(30N)) |> ignore
  let it = must_iterate(Value::Set(s))
  assert_true(it.next() == Some(Value::Int(10N)))
  assert_true(it.next() == Some(Value::Int(20N)))
  assert_true(it.next() == Some(Value::Int(30N)))
  assert_true(it.next() == None)
  it.done()
}

///|
test "iterate: range yields integer values with step" {
  let r = Value::Range(StarlarkRange::new(0L, 5L, 2L))
  let it = must_iterate(r)
  assert_true(it.next() == Some(Value::Int(0N)))
  assert_true(it.next() == Some(Value::Int(2N)))
  assert_true(it.next() == Some(Value::Int(4N)))
  assert_true(it.next() == None)
  it.done()
}

///|
test "iterate: range with negative step yields values in descending order" {
  let r = Value::Range(StarlarkRange::new(5L, 0L, -1L))
  let it = must_iterate(r)
  assert_true(it.next() == Some(Value::Int(5N)))
  assert_true(it.next() == Some(Value::Int(4N)))
  assert_true(it.next() == Some(Value::Int(3N)))
  assert_true(it.next() == Some(Value::Int(2N)))
  assert_true(it.next() == Some(Value::Int(1N)))
  assert_true(it.next() == None)
  it.done()
}

///|
test "iterate: non-iterable int returns error naming the type" {
  let result = iterate(Value::Int(42N))
  assert_true(result is Err(_))
  match result {
    Err(e) => assert_true(e.contains("int"))
    Ok(_) => panic()
  }
}

///|
test "iterate: non-iterable None returns error" {
  assert_true(iterate(Value::None) is Err(_))
}

///|
test "iterate: non-iterable callable returns error" {
  let f = Value::Builtin(StarlarkBuiltinFunc::dispatch("f"))
  assert_true(iterate(f) is Err(_))
}

// --- mutation safety during iteration ---

///|
test "iterate: list is mutable before iteration starts" {
  let l = StarlarkList::new([Value::Int(1N)])
  assert_true(l.check_mutable("append to") is Ok(_))
}

///|
test "iterate: list becomes immutable while iterator is active" {
  let l = StarlarkList::new([Value::Int(1N)])
  let it = must_iterate(Value::List(l))
  assert_true(l.check_mutable("append to") is Err(_))
  it.done()
  assert_true(l.check_mutable("append to") is Ok(_))
}

///|
test "iterate: list stays immutable until all concurrent iterators complete" {
  let l = StarlarkList::new([Value::Int(1N)])
  let it1 = must_iterate(Value::List(l))
  let it2 = must_iterate(Value::List(l))
  assert_true(l.check_mutable("append to") is Err(_))
  it1.done()
  assert_true(l.check_mutable("append to") is Err(_))
  it2.done()
  assert_true(l.check_mutable("append to") is Ok(_))
}

///|
test "iterate: frozen list remains immutable after iterator completes" {
  let l = StarlarkList::new([Value::Int(1N)])
  l.freeze()
  let it = must_iterate(Value::List(l))
  assert_true(l.check_mutable("append to") is Err(_))
  it.done()
  assert_true(l.check_mutable("append to") is Err(_))
}

///|
test "iterate: check_mutable blocks mutation while list is being iterated" {
  let l = StarlarkList::new([Value::Int(1N), Value::Int(2N)])
  let it = must_iterate(Value::List(l))
  assert_true(l.check_mutable("append to") is Err(_))
  it.done()
  assert_true(l.check_mutable("append to") is Ok(_))
}

///|
test "iterate: dict blocks insertion while iterator is active" {
  let d = StarlarkDict::new()
  d.set(Value::Int(1N), Value::Int(1N)) |> ignore
  let it = must_iterate(Value::Dict(d))
  assert_true(d.set(Value::Int(2N), Value::Int(2N)) is Err(_))
  it.done()
  assert_true(d.set(Value::Int(2N), Value::Int(2N)) is Ok(_))
}

///|
test "iterate: set blocks insertion while iterator is active" {
  let s = StarlarkSet::new()
  s.add(Value::Int(1N)) |> ignore
  let it = must_iterate(Value::Set(s))
  assert_true(s.add(Value::Int(2N)) is Err(_))
  it.done()
  assert_true(s.add(Value::Int(2N)) is Ok(_))
}

// --- length_of ---

///|
test "length_of: string returns byte count not codepoint count" {
  assert_true(length_of(Value::String(StarlarkString::new("hello"))) == Ok(5))
  // Ω is 2 bytes in UTF-8
  assert_true(length_of(Value::String(StarlarkString::new("Ω"))) == Ok(2))
}

///|
test "length_of: bytes returns byte count" {
  let b = Bytes::from_array([b'\x01', b'\x02', b'\x03'])
  assert_true(length_of(Value::Bytes(b)) == Ok(3))
}

///|
test "length_of: list returns item count" {
  let l = StarlarkList::new([Value::Int(1N), Value::Int(2N)])
  assert_true(length_of(Value::List(l)) == Ok(2))
  assert_true(length_of(Value::List(StarlarkList::new([]))) == Ok(0))
}

///|
test "length_of: tuple returns item count" {
  assert_true(
    length_of(Value::Tuple([Value::Int(1N), Value::Int(2N), Value::Int(3N)])) ==
    Ok(3),
  )
  assert_true(length_of(Value::Tuple([])) == Ok(0))
}

///|
test "length_of: dict returns number of key-value pairs" {
  let d = StarlarkDict::new()
  assert_true(length_of(Value::Dict(d)) == Ok(0))
  d.set(Value::Int(1N), Value::Int(1N)) |> ignore
  d.set(Value::Int(2N), Value::Int(2N)) |> ignore
  assert_true(length_of(Value::Dict(d)) == Ok(2))
}

///|
test "length_of: set returns number of elements" {
  let s = StarlarkSet::new()
  assert_true(length_of(Value::Set(s)) == Ok(0))
  s.add(Value::Int(1N)) |> ignore
  assert_true(length_of(Value::Set(s)) == Ok(1))
}

///|
test "length_of: range returns computed length" {
  assert_true(
    length_of(Value::Range(StarlarkRange::new(0L, 10L, 1L))) == Ok(10L),
  )
  assert_true(
    length_of(Value::Range(StarlarkRange::new(0L, 10L, 2L))) == Ok(5L),
  )
}

///|
test "length_of: range with 2^32 elements returns 4294967296 without truncation" {
  assert_true(
    length_of(Value::Range(StarlarkRange::new(0L, 4294967296L, 1L))) ==
    Ok(4294967296L),
  )
}

///|
test "length_of: non-sized type returns error" {
  assert_true(length_of(Value::Int(42N)) is Err(_))
  assert_true(length_of(Value::None) is Err(_))
  assert_true(
    length_of(Value::Builtin(StarlarkBuiltinFunc::dispatch("f"))) is Err(_),
  )
}

///|
test "iterate: range with overflowing length returns no-len error" {
  let r = StarlarkRange::new(-4611686018427387904L, 4611686018427387904L, 1L)
  match iterate(Value::Range(r)) {
    Err(msg) => assert_true(msg.contains("has no len"))
    Ok(_) => assert_true(false)
  }
}

///|
test "iterate: range with double-overflowing length returns no-len error" {
  let r = StarlarkRange::new(@int64.MIN_VALUE, @int64.MAX_VALUE, 2L)
  match iterate(Value::Range(r)) {
    Err(msg) => assert_true(msg.contains("has no len"))
    Ok(_) => assert_true(false)
  }
}
