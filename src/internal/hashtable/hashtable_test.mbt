// Helper to construct a Starlark-typed hashtable in tests

///|
fn new_dict() -> Hashtable[@value.Value, @value.Value] {
  Hashtable::new(
    @value.starlark_hash,
    @value.starlark_equals,
    @value.Value::None,
    @value.Value::None,
  )
}

///|
test "Hashtable: empty table has length 0" {
  let ht = new_dict()
  assert_eq(ht.length(), 0)
}

///|
test "Hashtable: lookup on empty table returns None" {
  let ht = new_dict()
  let result = ht.lookup(@value.Value::String(@value.StarlarkString::new("x")))
  assert_true(result == Ok(None))
}

///|
test "Hashtable: insert and lookup a string key" {
  let ht = new_dict()
  let key = @value.Value::String(@value.StarlarkString::new("hello"))
  let val = @value.Value::Int(42L)
  assert_true(ht.insert(key, val) is Ok(_))
  assert_eq(ht.length(), 1)
  assert_true(ht.lookup(key) == Ok(Some(val)))
}

///|
test "Hashtable: insert duplicate key updates value" {
  let ht = new_dict()
  let key = @value.Value::Int(1L)
  assert_true(ht.insert(key, @value.Value::Int(10L)) is Ok(_))
  assert_true(ht.insert(key, @value.Value::Int(20L)) is Ok(_))
  assert_eq(ht.length(), 1)
  assert_true(ht.lookup(key) == Ok(Some(@value.Value::Int(20L))))
}

///|
test "Hashtable: delete existing key returns true" {
  let ht = new_dict()
  let key = @value.Value::Int(5L)
  ht.insert(key, @value.Value::None) |> ignore
  assert_true(ht.delete(key) == Ok(true))
  assert_eq(ht.length(), 0)
  assert_true(ht.lookup(key) == Ok(None))
}

///|
test "Hashtable: delete missing key returns false" {
  let ht = new_dict()
  let result = ht.delete(@value.Value::Int(99L))
  assert_true(result == Ok(false))
}

///|
test "Hashtable: multiple keys coexist" {
  let ht = new_dict()
  for i in 0..<10 {
    let key = @value.Value::Int(i.to_int64())
    ht.insert(key, @value.Value::Int((i * 2).to_int64())) |> ignore
  }
  assert_eq(ht.length(), 10)
  for i in 0..<10 {
    let key = @value.Value::Int(i.to_int64())
    let expected = @value.Value::Int((i * 2).to_int64())
    assert_true(ht.lookup(key) == Ok(Some(expected)))
  }
}

///|
test "Hashtable: insertion order preserved during iteration" {
  let ht = new_dict()
  let keys = [
    @value.Value::String(@value.StarlarkString::new("a")),
    @value.Value::String(@value.StarlarkString::new("b")),
    @value.Value::String(@value.StarlarkString::new("c")),
  ]
  for k in keys {
    ht.insert(k, @value.Value::None) |> ignore
  }
  let collected : Array[@value.Value] = []
  ht.each_key(fn(k) { collected.push(k) })
  assert_eq(collected.length(), 3)
  assert_true(@value.starlark_equals(collected[0], keys[0]))
  assert_true(@value.starlark_equals(collected[1], keys[1]))
  assert_true(@value.starlark_equals(collected[2], keys[2]))
}

///|
test "Hashtable: insertion order maintained after delete" {
  let ht = new_dict()
  let k0 = @value.Value::Int(0L)
  let k1 = @value.Value::Int(1L)
  let k2 = @value.Value::Int(2L)
  ht.insert(k0, @value.Value::None) |> ignore
  ht.insert(k1, @value.Value::None) |> ignore
  ht.insert(k2, @value.Value::None) |> ignore
  ht.delete(k1) |> ignore
  let collected : Array[@value.Value] = []
  ht.each_key(fn(k) { collected.push(k) })
  assert_eq(collected.length(), 2)
  assert_true(@value.starlark_equals(collected[0], k0))
  assert_true(@value.starlark_equals(collected[1], k2))
}

///|
test "Hashtable: None key is hashable" {
  let ht = new_dict()
  assert_true(ht.insert(@value.Value::None, @value.Value::Int(1L)) is Ok(_))
  assert_true(ht.lookup(@value.Value::None) == Ok(Some(@value.Value::Int(1L))))
}

///|
test "Hashtable: Bool keys are hashable" {
  let ht = new_dict()
  ht.insert(@value.Value::Bool(true), @value.Value::Int(1L)) |> ignore
  ht.insert(@value.Value::Bool(false), @value.Value::Int(0L)) |> ignore
  assert_eq(ht.length(), 2)
  assert_true(
    ht.lookup(@value.Value::Bool(true)) == Ok(Some(@value.Value::Int(1L))),
  )
  assert_true(
    ht.lookup(@value.Value::Bool(false)) == Ok(Some(@value.Value::Int(0L))),
  )
}

///|
test "Hashtable: Tuple key is hashable" {
  let ht = new_dict()
  let key = @value.Value::Tuple([@value.Value::Int(1L), @value.Value::Int(2L)])
  assert_true(
    ht.insert(key, @value.Value::String(@value.StarlarkString::new("ok")))
    is Ok(_),
  )
  assert_true(
    ht.lookup(key) ==
    Ok(Some(@value.Value::String(@value.StarlarkString::new("ok")))),
  )
}

///|
test "Hashtable: List key is unhashable" {
  let ht = new_dict()
  let key = @value.Value::List(@value.StarlarkList::new([]))
  let result = ht.insert(key, @value.Value::None)
  assert_true(result is Err(_))
}

///|
test "Hashtable: freeze prevents insert" {
  let ht = new_dict()
  ht.freeze()
  let result = ht.insert(@value.Value::Int(1L), @value.Value::None)
  assert_true(result is Err(_))
}

///|
test "Hashtable: freeze prevents delete" {
  let ht = new_dict()
  ht.insert(@value.Value::Int(1L), @value.Value::None) |> ignore
  ht.freeze()
  let result = ht.delete(@value.Value::Int(1L))
  assert_true(result is Err(_))
}

///|
test "Hashtable: maintains correctness when storing many entries" {
  let ht = new_dict()
  for i in 0..<100 {
    ht.insert(@value.Value::Int(i.to_int64()), @value.Value::Int(i.to_int64()))
    |> ignore
  }
  assert_eq(ht.length(), 100)
  for i in 0..<100 {
    let key = @value.Value::Int(i.to_int64())
    let expected = Some(@value.Value::Int(i.to_int64()))
    assert_true(ht.lookup(key) == Ok(expected))
  }
}

///|
test "Hashtable: contains returns true for existing key" {
  let ht = new_dict()
  let key = @value.Value::Int(7L)
  ht.insert(key, @value.Value::None) |> ignore
  assert_true(ht.contains(key) == Ok(true))
  assert_true(ht.contains(@value.Value::Int(99L)) == Ok(false))
}
