// --- StarlarkDict ---

///|
test "StarlarkDict: empty dict has length 0" {
  let d = StarlarkDict::new()
  assert_eq(d.length(), 0)
}

///|
test "StarlarkDict: set and get a key" {
  let d = StarlarkDict::new()
  let key = Value::String(StarlarkString::new("x"))
  let val = Value::Int(42N)
  assert_true(d.set(key, val) is Ok(_))
  assert_eq(d.length(), 1)
  assert_true(d.get(key) == Ok(Some(val)))
}

///|
test "StarlarkDict: duplicate key updates value" {
  let d = StarlarkDict::new()
  let key = Value::Int(1N)
  assert_true(d.set(key, Value::Int(10N)) is Ok(_))
  assert_true(d.set(key, Value::Int(20N)) is Ok(_))
  assert_eq(d.length(), 1)
  assert_true(d.get(key) == Ok(Some(Value::Int(20N))))
}

///|
test "StarlarkDict: delete existing key returns true" {
  let d = StarlarkDict::new()
  let key = Value::Int(5N)
  d.set(key, Value::None) |> ignore
  assert_true(d.delete(key) == Ok(true))
  assert_eq(d.length(), 0)
  assert_true(d.get(key) == Ok(None))
}

///|
test "StarlarkDict: delete missing key returns false" {
  let d = StarlarkDict::new()
  assert_true(d.delete(Value::Int(99N)) == Ok(false))
}

///|
test "StarlarkDict: unhashable key (list) returns error" {
  let d = StarlarkDict::new()
  let key = Value::List(StarlarkList::new([]))
  assert_true(d.set(key, Value::None) is Err(_))
}

///|
test "StarlarkDict: truth empty is false" {
  assert_false(Value::Dict(StarlarkDict::new()).truth())
}

///|
test "StarlarkDict: truth nonempty is true" {
  let d = StarlarkDict::new()
  d.set(Value::Int(1N), Value::None) |> ignore
  assert_true(Value::Dict(d).truth())
}

///|
test "StarlarkDict: type_name is dict" {
  assert_eq(Value::Dict(StarlarkDict::new()).type_name(), "dict")
}

///|
test "StarlarkDict: repr empty is {}" {
  assert_eq(Value::Dict(StarlarkDict::new()).repr(), "{}")
}

///|
test "StarlarkDict: repr preserves insertion order" {
  let d = StarlarkDict::new()
  d.set(Value::String(StarlarkString::new("a")), Value::Int(1N)) |> ignore
  d.set(Value::String(StarlarkString::new("b")), Value::Int(2N)) |> ignore
  assert_eq(Value::Dict(d).repr(), "{\"a\": 1, \"b\": 2}")
}

///|
test "StarlarkDict: starlark_equals same content" {
  let d1 = StarlarkDict::new()
  d1.set(Value::Int(1N), Value::Int(10N)) |> ignore
  let d2 = StarlarkDict::new()
  d2.set(Value::Int(1N), Value::Int(10N)) |> ignore
  assert_true(Value::Dict(d1).starlark_equals(Value::Dict(d2)))
}

///|
test "StarlarkDict: starlark_equals different values" {
  let d1 = StarlarkDict::new()
  d1.set(Value::Int(1N), Value::Int(10N)) |> ignore
  let d2 = StarlarkDict::new()
  d2.set(Value::Int(1N), Value::Int(99N)) |> ignore
  assert_false(Value::Dict(d1).starlark_equals(Value::Dict(d2)))
}

///|
test "StarlarkDict: starlark_equals different lengths" {
  let d1 = StarlarkDict::new()
  d1.set(Value::Int(1N), Value::None) |> ignore
  let d2 = StarlarkDict::new()
  assert_false(Value::Dict(d1).starlark_equals(Value::Dict(d2)))
}

///|
test "StarlarkDict: starlark_hash is unhashable" {
  let result = starlark_hash(Value::Dict(StarlarkDict::new()))
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
  assert_true(d.set(Value::Int(1N), Value::None) is Err(_))
}

///|
test "StarlarkDict: freeze prevents delete" {
  let d = StarlarkDict::new()
  d.set(Value::Int(1N), Value::None) |> ignore
  d.freeze()
  assert_true(d.delete(Value::Int(1N)) is Err(_))
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
  assert_true(s.add(Value::Int(1N)) is Ok(_))
  assert_true(s.contains(Value::Int(1N)) == Ok(true))
  assert_true(s.contains(Value::Int(2N)) == Ok(false))
}

///|
test "StarlarkSet: duplicate add does not increase length" {
  let s = StarlarkSet::new()
  s.add(Value::Int(1N)) |> ignore
  s.add(Value::Int(1N)) |> ignore
  assert_eq(s.length(), 1)
}

///|
test "StarlarkSet: remove existing returns true" {
  let s = StarlarkSet::new()
  s.add(Value::Int(1N)) |> ignore
  assert_true(s.remove(Value::Int(1N)) == Ok(true))
  assert_eq(s.length(), 0)
}

///|
test "StarlarkSet: remove missing returns false" {
  let s = StarlarkSet::new()
  assert_true(s.remove(Value::Int(99N)) == Ok(false))
}

///|
test "StarlarkSet: unhashable element returns error" {
  let s = StarlarkSet::new()
  assert_true(s.add(Value::List(StarlarkList::new([]))) is Err(_))
}

///|
test "StarlarkSet: truth empty is false" {
  assert_false(Value::Set(StarlarkSet::new()).truth())
}

///|
test "StarlarkSet: truth nonempty is true" {
  let s = StarlarkSet::new()
  s.add(Value::Int(1N)) |> ignore
  assert_true(Value::Set(s).truth())
}

///|
test "StarlarkSet: type_name is set" {
  assert_eq(Value::Set(StarlarkSet::new()).type_name(), "set")
}

///|
test "StarlarkSet: repr empty is set([])" {
  assert_eq(Value::Set(StarlarkSet::new()).repr(), "set([])")
}

///|
test "StarlarkSet: repr nonempty uses set([...]) notation" {
  let s = StarlarkSet::new()
  s.add(Value::Int(1N)) |> ignore
  assert_eq(Value::Set(s).repr(), "set([1])")
}

///|
test "StarlarkSet: starlark_equals same elements" {
  let s1 = StarlarkSet::new()
  s1.add(Value::Int(1N)) |> ignore
  s1.add(Value::Int(2N)) |> ignore
  let s2 = StarlarkSet::new()
  s2.add(Value::Int(2N)) |> ignore
  s2.add(Value::Int(1N)) |> ignore
  assert_true(Value::Set(s1).starlark_equals(Value::Set(s2)))
}

///|
test "StarlarkSet: starlark_equals different elements" {
  let s1 = StarlarkSet::new()
  s1.add(Value::Int(1N)) |> ignore
  let s2 = StarlarkSet::new()
  s2.add(Value::Int(2N)) |> ignore
  assert_false(Value::Set(s1).starlark_equals(Value::Set(s2)))
}

///|
test "StarlarkSet: starlark_hash is unhashable" {
  let result = starlark_hash(Value::Set(StarlarkSet::new()))
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
  assert_true(s.add(Value::Int(1N)) is Err(_))
}

///|
test "StarlarkSet: freeze prevents remove" {
  let s = StarlarkSet::new()
  s.add(Value::Int(1N)) |> ignore
  s.freeze()
  assert_true(s.remove(Value::Int(1N)) is Err(_))
}

// --- Iter[T] typed iterator adaptors ---

///|
test "StarlarkDict::to_entries yields all key-value pairs" {
  let d = StarlarkDict::new()
  d.set(Value::String(StarlarkString::new("a")), Value::Int(1N)) |> ignore
  d.set(Value::String(StarlarkString::new("b")), Value::Int(2N)) |> ignore
  let result : Array[(Value, Value)] = []
  for entry in d.to_entries() {
    result.push(entry)
  }
  assert_eq(result.length(), 2)
}

///|
test "StarlarkDict::to_keys yields all keys" {
  let d = StarlarkDict::new()
  d.set(Value::String(StarlarkString::new("x")), Value::Int(10N)) |> ignore
  d.set(Value::String(StarlarkString::new("y")), Value::Int(20N)) |> ignore
  let keys : Array[Value] = []
  for k in d.to_keys() {
    keys.push(k)
  }
  assert_eq(keys.length(), 2)
}

///|
test "StarlarkDict::to_entries preserves insertion order" {
  let d = StarlarkDict::new()
  d.set(Value::Int(3N), Value::String(StarlarkString::new("three"))) |> ignore
  d.set(Value::Int(1N), Value::String(StarlarkString::new("one"))) |> ignore
  d.set(Value::Int(2N), Value::String(StarlarkString::new("two"))) |> ignore
  let keys : Array[Value] = []
  for entry in d.to_entries() {
    keys.push(entry.0)
  }
  assert_true(keys[0] == Value::Int(3N))
  assert_true(keys[1] == Value::Int(1N))
  assert_true(keys[2] == Value::Int(2N))
}

///|
test "StarlarkSet::to_iter yields all elements" {
  let s = StarlarkSet::new()
  s.add(Value::Int(1N)) |> ignore
  s.add(Value::Int(2N)) |> ignore
  s.add(Value::Int(3N)) |> ignore
  let elems : Array[Value] = []
  for v in s.to_iter() {
    elems.push(v)
  }
  assert_eq(elems.length(), 3)
}
