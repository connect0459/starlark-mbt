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
  let l = StarlarkList::new([
    Value::IntVal(1L),
    Value::IntVal(2L),
    Value::IntVal(3L),
  ])
  let it = must_iterate(Value::ListVal(l))
  assert_true(it.next() == Some(Value::IntVal(1L)))
  assert_true(it.next() == Some(Value::IntVal(2L)))
  assert_true(it.next() == Some(Value::IntVal(3L)))
  assert_true(it.next() == None)
  it.done()
}

///|
test "iterate: empty list is immediately exhausted" {
  let it = must_iterate(Value::ListVal(StarlarkList::new([])))
  assert_true(it.next() == None)
  it.done()
}

///|
test "iterate: tuple yields items in order" {
  let t = Value::TupleVal([
    Value::IntVal(10L),
    Value::StrVal(StarlarkString::new("x")),
  ])
  let it = must_iterate(t)
  assert_true(it.next() == Some(Value::IntVal(10L)))
  assert_true(it.next() == Some(Value::StrVal(StarlarkString::new("x"))))
  assert_true(it.next() == None)
  it.done()
}

///|
test "iterate: string yields one-byte strings per byte" {
  let it = must_iterate(Value::StrVal(StarlarkString::new("abc")))
  let v0 = it.next()
  let v1 = it.next()
  let v2 = it.next()
  assert_true(it.next() == None)
  it.done()
  match v0 {
    Some(Value::StrVal(s)) => {
      assert_eq(s.byte_len(), 1)
      assert_eq(s.byte_at(0), b'a')
    }
    _ => panic()
  }
  match v1 {
    Some(Value::StrVal(s)) => {
      assert_eq(s.byte_len(), 1)
      assert_eq(s.byte_at(0), b'b')
    }
    _ => panic()
  }
  match v2 {
    Some(Value::StrVal(s)) => {
      assert_eq(s.byte_len(), 1)
      assert_eq(s.byte_at(0), b'c')
    }
    _ => panic()
  }
}

///|
test "iterate: multibyte string yields individual bytes as 1-byte strings" {
  let it = must_iterate(Value::StrVal(StarlarkString::new("Ω")))
  let v0 = it.next()
  let v1 = it.next()
  assert_true(it.next() == None)
  it.done()
  match v0 {
    Some(Value::StrVal(s)) => {
      assert_eq(s.byte_len(), 1)
      assert_eq(s.byte_at(0), b'\xCE')
    }
    _ => panic()
  }
  match v1 {
    Some(Value::StrVal(s)) => {
      assert_eq(s.byte_len(), 1)
      assert_eq(s.byte_at(0), b'\xA9')
    }
    _ => panic()
  }
}

///|
test "iterate: bytes yields integer value of each byte" {
  let b = Value::BytesVal(Bytes::from_array([b'\x01', b'\x02', b'\x03']))
  let it = must_iterate(b)
  assert_true(it.next() == Some(Value::IntVal(1L)))
  assert_true(it.next() == Some(Value::IntVal(2L)))
  assert_true(it.next() == Some(Value::IntVal(3L)))
  assert_true(it.next() == None)
  it.done()
}

///|
test "iterate: dict yields keys in insertion order" {
  let d = StarlarkDict::new()
  d.set(Value::StrVal(StarlarkString::new("a")), Value::IntVal(1L)) |> ignore
  d.set(Value::StrVal(StarlarkString::new("b")), Value::IntVal(2L)) |> ignore
  d.set(Value::StrVal(StarlarkString::new("c")), Value::IntVal(3L)) |> ignore
  let it = must_iterate(Value::DictVal(d))
  assert_true(it.next() == Some(Value::StrVal(StarlarkString::new("a"))))
  assert_true(it.next() == Some(Value::StrVal(StarlarkString::new("b"))))
  assert_true(it.next() == Some(Value::StrVal(StarlarkString::new("c"))))
  assert_true(it.next() == None)
  it.done()
}

///|
test "iterate: set yields keys in insertion order" {
  let s = StarlarkSet::new()
  s.add(Value::IntVal(10L)) |> ignore
  s.add(Value::IntVal(20L)) |> ignore
  s.add(Value::IntVal(30L)) |> ignore
  let it = must_iterate(Value::SetVal(s))
  assert_true(it.next() == Some(Value::IntVal(10L)))
  assert_true(it.next() == Some(Value::IntVal(20L)))
  assert_true(it.next() == Some(Value::IntVal(30L)))
  assert_true(it.next() == None)
  it.done()
}

///|
test "iterate: range yields integer values with step" {
  let r = Value::RangeVal(StarlarkRange::new(0L, 5L, 2L))
  let it = must_iterate(r)
  assert_true(it.next() == Some(Value::IntVal(0L)))
  assert_true(it.next() == Some(Value::IntVal(2L)))
  assert_true(it.next() == Some(Value::IntVal(4L)))
  assert_true(it.next() == None)
  it.done()
}

///|
test "iterate: range with negative step yields values in descending order" {
  let r = Value::RangeVal(StarlarkRange::new(5L, 0L, -1L))
  let it = must_iterate(r)
  assert_true(it.next() == Some(Value::IntVal(5L)))
  assert_true(it.next() == Some(Value::IntVal(4L)))
  assert_true(it.next() == Some(Value::IntVal(3L)))
  assert_true(it.next() == Some(Value::IntVal(2L)))
  assert_true(it.next() == Some(Value::IntVal(1L)))
  assert_true(it.next() == None)
  it.done()
}

///|
test "iterate: non-iterable int returns error naming the type" {
  let result = iterate(Value::IntVal(42L))
  assert_true(result is Err(_))
  match result {
    Err(e) => assert_true(e.contains("int"))
    Ok(_) => panic()
  }
}

///|
test "iterate: non-iterable None returns error" {
  assert_true(iterate(Value::NoneVal) is Err(_))
}

///|
test "iterate: non-iterable function returns error" {
  let f = Value::FuncVal(StarlarkFunction::{
    name: "f",
    params: [],
    body: [],
    defaults: [],
    freevars: [],
  })
  assert_true(iterate(f) is Err(_))
}

// --- itercount: mutation safety during iteration ---

///|
test "iterate: list itercount is 0 before iteration" {
  let l = StarlarkList::new([Value::IntVal(1L)])
  assert_eq(l.itercount, 0)
}

///|
test "iterate: list itercount increments to 1 while iterator active" {
  let l = StarlarkList::new([Value::IntVal(1L)])
  let it = must_iterate(Value::ListVal(l))
  assert_eq(l.itercount, 1)
  it.done()
  assert_eq(l.itercount, 0)
}

///|
test "iterate: two concurrent list iterators raise itercount to 2" {
  let l = StarlarkList::new([Value::IntVal(1L)])
  let it1 = must_iterate(Value::ListVal(l))
  let it2 = must_iterate(Value::ListVal(l))
  assert_eq(l.itercount, 2)
  it1.done()
  assert_eq(l.itercount, 1)
  it2.done()
  assert_eq(l.itercount, 0)
}

///|
test "iterate: frozen list does not increment itercount" {
  let l = StarlarkList::new([Value::IntVal(1L)])
  l.freeze()
  let it = must_iterate(Value::ListVal(l))
  assert_eq(l.itercount, 0)
  it.done()
  assert_eq(l.itercount, 0)
}

///|
test "iterate: check_mutable blocks mutation while list is being iterated" {
  let l = StarlarkList::new([Value::IntVal(1L), Value::IntVal(2L)])
  let it = must_iterate(Value::ListVal(l))
  assert_true(l.check_mutable("append to") is Err(_))
  it.done()
  assert_true(l.check_mutable("append to") is Ok(_))
}

///|
test "iterate: dict blocks insertion while iterator is active" {
  let d = StarlarkDict::new()
  d.set(Value::IntVal(1L), Value::IntVal(1L)) |> ignore
  let it = must_iterate(Value::DictVal(d))
  assert_true(d.set(Value::IntVal(2L), Value::IntVal(2L)) is Err(_))
  it.done()
  assert_true(d.set(Value::IntVal(2L), Value::IntVal(2L)) is Ok(_))
}

///|
test "iterate: set blocks insertion while iterator is active" {
  let s = StarlarkSet::new()
  s.add(Value::IntVal(1L)) |> ignore
  let it = must_iterate(Value::SetVal(s))
  assert_true(s.add(Value::IntVal(2L)) is Err(_))
  it.done()
  assert_true(s.add(Value::IntVal(2L)) is Ok(_))
}

// --- length_of ---

///|
test "length_of: string returns byte count not codepoint count" {
  assert_true(length_of(Value::StrVal(StarlarkString::new("hello"))) == Ok(5))
  // Ω is 2 bytes in UTF-8
  assert_true(length_of(Value::StrVal(StarlarkString::new("Ω"))) == Ok(2))
}

///|
test "length_of: bytes returns byte count" {
  let b = Bytes::from_array([b'\x01', b'\x02', b'\x03'])
  assert_true(length_of(Value::BytesVal(b)) == Ok(3))
}

///|
test "length_of: list returns item count" {
  let l = StarlarkList::new([Value::IntVal(1L), Value::IntVal(2L)])
  assert_true(length_of(Value::ListVal(l)) == Ok(2))
  assert_true(length_of(Value::ListVal(StarlarkList::new([]))) == Ok(0))
}

///|
test "length_of: tuple returns item count" {
  assert_true(
    length_of(
      Value::TupleVal([Value::IntVal(1L), Value::IntVal(2L), Value::IntVal(3L)]),
    ) ==
    Ok(3),
  )
  assert_true(length_of(Value::TupleVal([])) == Ok(0))
}

///|
test "length_of: dict returns number of key-value pairs" {
  let d = StarlarkDict::new()
  assert_true(length_of(Value::DictVal(d)) == Ok(0))
  d.set(Value::IntVal(1L), Value::IntVal(1L)) |> ignore
  d.set(Value::IntVal(2L), Value::IntVal(2L)) |> ignore
  assert_true(length_of(Value::DictVal(d)) == Ok(2))
}

///|
test "length_of: set returns number of elements" {
  let s = StarlarkSet::new()
  assert_true(length_of(Value::SetVal(s)) == Ok(0))
  s.add(Value::IntVal(1L)) |> ignore
  assert_true(length_of(Value::SetVal(s)) == Ok(1))
}

///|
test "length_of: range returns computed length" {
  assert_true(
    length_of(Value::RangeVal(StarlarkRange::new(0L, 10L, 1L))) == Ok(10),
  )
  assert_true(
    length_of(Value::RangeVal(StarlarkRange::new(0L, 10L, 2L))) == Ok(5),
  )
}

///|
test "length_of: non-sized type returns error" {
  assert_true(length_of(Value::IntVal(42L)) is Err(_))
  assert_true(length_of(Value::NoneVal) is Err(_))
  assert_true(
    length_of(
      Value::FuncVal(StarlarkFunction::{
        name: "f",
        params: [],
        body: [],
        defaults: [],
        freevars: [],
      }),
    )
    is Err(_),
  )
}
