///|
test "Hashtable: empty table has length 0" {
  let ht = Hashtable::new()
  assert_eq(ht.length(), 0)
}

///|
test "Hashtable: lookup on empty table returns None" {
  let ht = Hashtable::new()
  let result = ht.lookup(@value.Value::StrVal(@value.StarlarkString::new("x")))
  assert_true(result == Ok(None))
}

///|
test "Hashtable: insert and lookup a string key" {
  let ht = Hashtable::new()
  let key = @value.Value::StrVal(@value.StarlarkString::new("hello"))
  let val = @value.Value::IntVal(42L)
  assert_true(ht.insert(key, val) is Ok(_))
  assert_eq(ht.length(), 1)
  assert_true(ht.lookup(key) == Ok(Some(val)))
}

///|
test "Hashtable: insert duplicate key updates value" {
  let ht = Hashtable::new()
  let key = @value.Value::IntVal(1L)
  assert_true(ht.insert(key, @value.Value::IntVal(10L)) is Ok(_))
  assert_true(ht.insert(key, @value.Value::IntVal(20L)) is Ok(_))
  assert_eq(ht.length(), 1)
  assert_true(ht.lookup(key) == Ok(Some(@value.Value::IntVal(20L))))
}

///|
test "Hashtable: delete existing key returns true" {
  let ht = Hashtable::new()
  let key = @value.Value::IntVal(5L)
  ht.insert(key, @value.Value::NoneVal) |> ignore
  assert_true(ht.delete(key) == Ok(true))
  assert_eq(ht.length(), 0)
  assert_true(ht.lookup(key) == Ok(None))
}

///|
test "Hashtable: delete missing key returns false" {
  let ht = Hashtable::new()
  let result = ht.delete(@value.Value::IntVal(99L))
  assert_true(result == Ok(false))
}

///|
test "Hashtable: multiple keys coexist" {
  let ht = Hashtable::new()
  for i in 0..<10 {
    let key = @value.Value::IntVal(i.to_int64())
    ht.insert(key, @value.Value::IntVal((i * 2).to_int64())) |> ignore
  }
  assert_eq(ht.length(), 10)
  for i in 0..<10 {
    let key = @value.Value::IntVal(i.to_int64())
    let expected = @value.Value::IntVal((i * 2).to_int64())
    assert_true(ht.lookup(key) == Ok(Some(expected)))
  }
}

///|
test "Hashtable: insertion order preserved during iteration" {
  let ht = Hashtable::new()
  let keys = [
    @value.Value::StrVal(@value.StarlarkString::new("a")),
    @value.Value::StrVal(@value.StarlarkString::new("b")),
    @value.Value::StrVal(@value.StarlarkString::new("c")),
  ]
  for k in keys {
    ht.insert(k, @value.Value::NoneVal) |> ignore
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
  let ht = Hashtable::new()
  let k0 = @value.Value::IntVal(0L)
  let k1 = @value.Value::IntVal(1L)
  let k2 = @value.Value::IntVal(2L)
  ht.insert(k0, @value.Value::NoneVal) |> ignore
  ht.insert(k1, @value.Value::NoneVal) |> ignore
  ht.insert(k2, @value.Value::NoneVal) |> ignore
  ht.delete(k1) |> ignore
  let collected : Array[@value.Value] = []
  ht.each_key(fn(k) { collected.push(k) })
  assert_eq(collected.length(), 2)
  assert_true(@value.starlark_equals(collected[0], k0))
  assert_true(@value.starlark_equals(collected[1], k2))
}

///|
test "Hashtable: None key is hashable" {
  let ht = Hashtable::new()
  assert_true(
    ht.insert(@value.Value::NoneVal, @value.Value::IntVal(1L)) is Ok(_),
  )
  assert_true(
    ht.lookup(@value.Value::NoneVal) == Ok(Some(@value.Value::IntVal(1L))),
  )
}

///|
test "Hashtable: Bool keys are hashable" {
  let ht = Hashtable::new()
  ht.insert(@value.Value::BoolVal(true), @value.Value::IntVal(1L)) |> ignore
  ht.insert(@value.Value::BoolVal(false), @value.Value::IntVal(0L)) |> ignore
  assert_eq(ht.length(), 2)
  assert_true(
    ht.lookup(@value.Value::BoolVal(true)) == Ok(Some(@value.Value::IntVal(1L))),
  )
  assert_true(
    ht.lookup(@value.Value::BoolVal(false)) ==
    Ok(Some(@value.Value::IntVal(0L))),
  )
}

///|
test "Hashtable: Tuple key is hashable" {
  let ht = Hashtable::new()
  let key = @value.Value::TupleVal([
    @value.Value::IntVal(1L),
    @value.Value::IntVal(2L),
  ])
  assert_true(
    ht.insert(key, @value.Value::StrVal(@value.StarlarkString::new("ok")))
    is Ok(_),
  )
  assert_true(
    ht.lookup(key) ==
    Ok(Some(@value.Value::StrVal(@value.StarlarkString::new("ok")))),
  )
}

///|
test "Hashtable: List key is unhashable" {
  let ht = Hashtable::new()
  let key = @value.Value::ListVal(@value.StarlarkList::new([]))
  let result = ht.insert(key, @value.Value::NoneVal)
  assert_true(result is Err(_))
}

///|
test "Hashtable: freeze prevents insert" {
  let ht = Hashtable::new()
  ht.freeze()
  let result = ht.insert(@value.Value::IntVal(1L), @value.Value::NoneVal)
  assert_true(result is Err(_))
}

///|
test "Hashtable: freeze prevents delete" {
  let ht = Hashtable::new()
  ht.insert(@value.Value::IntVal(1L), @value.Value::NoneVal) |> ignore
  ht.freeze()
  let result = ht.delete(@value.Value::IntVal(1L))
  assert_true(result is Err(_))
}

///|
test "Hashtable: handles many entries (stress test for grow)" {
  let ht = Hashtable::new()
  // Insert enough to trigger at least one grow (more than initial capacity)
  for i in 0..<100 {
    ht.insert(
      @value.Value::IntVal(i.to_int64()),
      @value.Value::IntVal(i.to_int64()),
    )
    |> ignore
  }
  assert_eq(ht.length(), 100)
  for i in 0..<100 {
    let key = @value.Value::IntVal(i.to_int64())
    let expected = Some(@value.Value::IntVal(i.to_int64()))
    assert_true(ht.lookup(key) == Ok(expected))
  }
}

///|
test "Hashtable: contains returns true for existing key" {
  let ht = Hashtable::new()
  let key = @value.Value::IntVal(7L)
  ht.insert(key, @value.Value::NoneVal) |> ignore
  assert_true(ht.contains(key) == Ok(true))
  assert_true(ht.contains(@value.Value::IntVal(99L)) == Ok(false))
}
