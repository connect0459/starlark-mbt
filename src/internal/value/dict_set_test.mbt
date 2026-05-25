// --- StarlarkDict ---

///|
test "StarlarkDict: empty dict has length 0" {
  let d = StarlarkDict::new()
  assert_eq(d.length(), 0)
}

///|
test "StarlarkDict: set and get a key" {
  let d = StarlarkDict::new()
  let key = Value::StrVal(StarlarkString::new("x"))
  let val = Value::IntVal(42L)
  assert_true(d.set(key, val) is Ok(_))
  assert_eq(d.length(), 1)
  assert_true(d.get(key) == Ok(Some(val)))
}

///|
test "StarlarkDict: duplicate key updates value" {
  let d = StarlarkDict::new()
  let key = Value::IntVal(1L)
  assert_true(d.set(key, Value::IntVal(10L)) is Ok(_))
  assert_true(d.set(key, Value::IntVal(20L)) is Ok(_))
  assert_eq(d.length(), 1)
  assert_true(d.get(key) == Ok(Some(Value::IntVal(20L))))
}

///|
test "StarlarkDict: delete existing key returns true" {
  let d = StarlarkDict::new()
  let key = Value::IntVal(5L)
  d.set(key, Value::NoneVal) |> ignore
  assert_true(d.delete(key) == Ok(true))
  assert_eq(d.length(), 0)
  assert_true(d.get(key) == Ok(None))
}

///|
test "StarlarkDict: delete missing key returns false" {
  let d = StarlarkDict::new()
  assert_true(d.delete(Value::IntVal(99L)) == Ok(false))
}

///|
test "StarlarkDict: unhashable key (list) returns error" {
  let d = StarlarkDict::new()
  let key = Value::ListVal(StarlarkList::new([]))
  assert_true(d.set(key, Value::NoneVal) is Err(_))
}

///|
test "StarlarkDict: truth empty is false" {
  assert_false(truth(Value::DictVal(StarlarkDict::new())))
}

///|
test "StarlarkDict: truth nonempty is true" {
  let d = StarlarkDict::new()
  d.set(Value::IntVal(1L), Value::NoneVal) |> ignore
  assert_true(truth(Value::DictVal(d)))
}

///|
test "StarlarkDict: type_name is dict" {
  assert_eq(type_name(Value::DictVal(StarlarkDict::new())), "dict")
}

///|
test "StarlarkDict: repr empty is {}" {
  assert_eq(repr(Value::DictVal(StarlarkDict::new())), "{}")
}

///|
test "StarlarkDict: repr preserves insertion order" {
  let d = StarlarkDict::new()
  d.set(Value::StrVal(StarlarkString::new("a")), Value::IntVal(1L)) |> ignore
  d.set(Value::StrVal(StarlarkString::new("b")), Value::IntVal(2L)) |> ignore
  assert_eq(repr(Value::DictVal(d)), "{\"a\": 1, \"b\": 2}")
}

///|
test "StarlarkDict: starlark_equals same content" {
  let d1 = StarlarkDict::new()
  d1.set(Value::IntVal(1L), Value::IntVal(10L)) |> ignore
  let d2 = StarlarkDict::new()
  d2.set(Value::IntVal(1L), Value::IntVal(10L)) |> ignore
  assert_true(starlark_equals(Value::DictVal(d1), Value::DictVal(d2)))
}

///|
test "StarlarkDict: starlark_equals different values" {
  let d1 = StarlarkDict::new()
  d1.set(Value::IntVal(1L), Value::IntVal(10L)) |> ignore
  let d2 = StarlarkDict::new()
  d2.set(Value::IntVal(1L), Value::IntVal(99L)) |> ignore
  assert_false(starlark_equals(Value::DictVal(d1), Value::DictVal(d2)))
}

///|
test "StarlarkDict: starlark_equals different lengths" {
  let d1 = StarlarkDict::new()
  d1.set(Value::IntVal(1L), Value::NoneVal) |> ignore
  let d2 = StarlarkDict::new()
  assert_false(starlark_equals(Value::DictVal(d1), Value::DictVal(d2)))
}

///|
test "StarlarkDict: starlark_hash is unhashable" {
  let result = starlark_hash(Value::DictVal(StarlarkDict::new()))
  assert_true(result is Err(_))
  match result {
    Err(msg) => assert_true(msg.contains("dict"))
    _ => ()
  }
}

///|
test "StarlarkDict: freeze prevents set" {
  let d = StarlarkDict::new()
  d.freeze()
  assert_true(d.set(Value::IntVal(1L), Value::NoneVal) is Err(_))
}

///|
test "StarlarkDict: freeze prevents delete" {
  let d = StarlarkDict::new()
  d.set(Value::IntVal(1L), Value::NoneVal) |> ignore
  d.freeze()
  assert_true(d.delete(Value::IntVal(1L)) is Err(_))
}

// --- StarlarkSet ---

///|
test "StarlarkSet: empty set has length 0" {
  let s = StarlarkSet::new()
  assert_eq(s.length(), 0)
}

///|
test "StarlarkSet: add and contains" {
  let s = StarlarkSet::new()
  assert_true(s.add(Value::IntVal(1L)) is Ok(_))
  assert_true(s.contains(Value::IntVal(1L)) == Ok(true))
  assert_true(s.contains(Value::IntVal(2L)) == Ok(false))
}

///|
test "StarlarkSet: duplicate add does not increase length" {
  let s = StarlarkSet::new()
  s.add(Value::IntVal(1L)) |> ignore
  s.add(Value::IntVal(1L)) |> ignore
  assert_eq(s.length(), 1)
}

///|
test "StarlarkSet: remove existing returns true" {
  let s = StarlarkSet::new()
  s.add(Value::IntVal(1L)) |> ignore
  assert_true(s.remove(Value::IntVal(1L)) == Ok(true))
  assert_eq(s.length(), 0)
}

///|
test "StarlarkSet: remove missing returns false" {
  let s = StarlarkSet::new()
  assert_true(s.remove(Value::IntVal(99L)) == Ok(false))
}

///|
test "StarlarkSet: unhashable element returns error" {
  let s = StarlarkSet::new()
  assert_true(s.add(Value::ListVal(StarlarkList::new([]))) is Err(_))
}

///|
test "StarlarkSet: truth empty is false" {
  assert_false(truth(Value::SetVal(StarlarkSet::new())))
}

///|
test "StarlarkSet: truth nonempty is true" {
  let s = StarlarkSet::new()
  s.add(Value::IntVal(1L)) |> ignore
  assert_true(truth(Value::SetVal(s)))
}

///|
test "StarlarkSet: type_name is set" {
  assert_eq(type_name(Value::SetVal(StarlarkSet::new())), "set")
}

///|
test "StarlarkSet: repr empty is set()" {
  assert_eq(repr(Value::SetVal(StarlarkSet::new())), "set()")
}

///|
test "StarlarkSet: repr nonempty uses brace notation" {
  let s = StarlarkSet::new()
  s.add(Value::IntVal(1L)) |> ignore
  assert_eq(repr(Value::SetVal(s)), "{1}")
}

///|
test "StarlarkSet: starlark_equals same elements" {
  let s1 = StarlarkSet::new()
  s1.add(Value::IntVal(1L)) |> ignore
  s1.add(Value::IntVal(2L)) |> ignore
  let s2 = StarlarkSet::new()
  s2.add(Value::IntVal(2L)) |> ignore
  s2.add(Value::IntVal(1L)) |> ignore
  assert_true(starlark_equals(Value::SetVal(s1), Value::SetVal(s2)))
}

///|
test "StarlarkSet: starlark_equals different elements" {
  let s1 = StarlarkSet::new()
  s1.add(Value::IntVal(1L)) |> ignore
  let s2 = StarlarkSet::new()
  s2.add(Value::IntVal(2L)) |> ignore
  assert_false(starlark_equals(Value::SetVal(s1), Value::SetVal(s2)))
}

///|
test "StarlarkSet: starlark_hash is unhashable" {
  let result = starlark_hash(Value::SetVal(StarlarkSet::new()))
  assert_true(result is Err(_))
  match result {
    Err(msg) => assert_true(msg.contains("set"))
    _ => ()
  }
}

///|
test "StarlarkSet: freeze prevents add" {
  let s = StarlarkSet::new()
  s.freeze()
  assert_true(s.add(Value::IntVal(1L)) is Err(_))
}

///|
test "StarlarkSet: freeze prevents remove" {
  let s = StarlarkSet::new()
  s.add(Value::IntVal(1L)) |> ignore
  s.freeze()
  assert_true(s.remove(Value::IntVal(1L)) is Err(_))
}
