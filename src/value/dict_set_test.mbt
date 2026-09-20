// --- StarlarkDict ---

///|
test "StarlarkDict: empty dict has length 0" {
  let d = @value.StarlarkDict::new()
  assert_eq(d.length(), 0)
}

///|
test "StarlarkDict: set and get a key" {
  let d = @value.StarlarkDict::new()
  let key = @value.Value::String(@value.StarlarkString::new("x"))
  let val = @value.Value::Int(42N)
  assert_true(d.set(key, val) is Ok(_))
  assert_eq(d.length(), 1)
  assert_true(d.get(key) == Ok(Some(val)))
}

///|
test "StarlarkDict: iter yields keys in insertion order like List and Set" {
  let d = @value.StarlarkDict::new()
  d.set(@value.Value::Int(1N), @value.Value::Int(10N)) |> ignore
  d.set(@value.Value::Int(2N), @value.Value::Int(20N)) |> ignore
  let seen = d.iter().collect()
  assert_eq(seen.length(), 2)
  assert_true(seen[0] == @value.Value::Int(1N))
  assert_true(seen[1] == @value.Value::Int(2N))
}

///|
test "StarlarkDict: duplicate key updates value" {
  let d = @value.StarlarkDict::new()
  let key = @value.Value::Int(1N)
  assert_true(d.set(key, @value.Value::Int(10N)) is Ok(_))
  assert_true(d.set(key, @value.Value::Int(20N)) is Ok(_))
  assert_eq(d.length(), 1)
  assert_true(d.get(key) == Ok(Some(@value.Value::Int(20N))))
}

///|
test "StarlarkDict: contains returns false for absent key" {
  let d = @value.StarlarkDict::new()
  let key = @value.Value::Int(1N)
  assert_true(d.contains(key) == Ok(false))
}

///|
test "StarlarkDict: contains returns true for present key" {
  let d = @value.StarlarkDict::new()
  let key = @value.Value::Int(1N)
  d.set(key, @value.Value::None) |> ignore
  assert_true(d.contains(key) == Ok(true))
}

///|
test "StarlarkDict: contains returns Err for unhashable key" {
  let d = @value.StarlarkDict::new()
  let key = @value.Value::List(@value.StarlarkList::new([]))
  assert_true(d.contains(key) is Err(_))
}

///|
test "StarlarkDict: delete existing key returns true" {
  let d = @value.StarlarkDict::new()
  let key = @value.Value::Int(5N)
  d.set(key, @value.Value::None) |> ignore
  assert_true(d.delete(key) == Ok(true))
  assert_eq(d.length(), 0)
  assert_true(d.get(key) == Ok(None))
}

///|
test "StarlarkDict: delete missing key returns false" {
  let d = @value.StarlarkDict::new()
  assert_true(d.delete(@value.Value::Int(99N)) == Ok(false))
}

///|
test "StarlarkDict: unhashable key (list) returns error" {
  let d = @value.StarlarkDict::new()
  let key = @value.Value::List(@value.StarlarkList::new([]))
  assert_true(d.set(key, @value.Value::None) is Err(_))
}

///|
test "StarlarkDict: truth empty is false" {
  assert_false(@value.Value::Dict(@value.StarlarkDict::new()).truth())
}

///|
test "StarlarkDict: truth nonempty is true" {
  let d = @value.StarlarkDict::new()
  d.set(@value.Value::Int(1N), @value.Value::None) |> ignore
  assert_true(@value.Value::Dict(d).truth())
}

///|
test "StarlarkDict: type_name is dict" {
  assert_eq(@value.Value::Dict(@value.StarlarkDict::new()).type_name(), "dict")
}

///|
test "StarlarkDict: repr empty is {}" {
  assert_eq(@value.Value::Dict(@value.StarlarkDict::new()).repr(), "{}")
}

///|
test "StarlarkDict: repr preserves insertion order" {
  let d = @value.StarlarkDict::new()
  d.set(
    @value.Value::String(@value.StarlarkString::new("a")),
    @value.Value::Int(1N),
  )
  |> ignore
  d.set(
    @value.Value::String(@value.StarlarkString::new("b")),
    @value.Value::Int(2N),
  )
  |> ignore
  assert_eq(@value.Value::Dict(d).repr(), "{\"a\": 1, \"b\": 2}")
}

///|
test "StarlarkDict: starlark_equals same content" {
  let d1 = @value.StarlarkDict::new()
  d1.set(@value.Value::Int(1N), @value.Value::Int(10N)) |> ignore
  let d2 = @value.StarlarkDict::new()
  d2.set(@value.Value::Int(1N), @value.Value::Int(10N)) |> ignore
  assert_true(@value.Value::Dict(d1).starlark_equals(@value.Value::Dict(d2)))
}

///|
test "StarlarkDict: starlark_equals different values" {
  let d1 = @value.StarlarkDict::new()
  d1.set(@value.Value::Int(1N), @value.Value::Int(10N)) |> ignore
  let d2 = @value.StarlarkDict::new()
  d2.set(@value.Value::Int(1N), @value.Value::Int(99N)) |> ignore
  assert_false(@value.Value::Dict(d1).starlark_equals(@value.Value::Dict(d2)))
}

///|
test "StarlarkDict: starlark_equals different lengths" {
  let d1 = @value.StarlarkDict::new()
  d1.set(@value.Value::Int(1N), @value.Value::None) |> ignore
  let d2 = @value.StarlarkDict::new()
  assert_false(@value.Value::Dict(d1).starlark_equals(@value.Value::Dict(d2)))
}

///|
test "StarlarkDict: starlark_hash is unhashable" {
  let result = @value.Value::hash(
    @value.Value::Dict(@value.StarlarkDict::new()),
  )
  assert_true(result is Err(_))
  match result {
    Err(msg) => assert_true(msg.contains("dict"))
    _ => ()
  }
}

///|
test "StarlarkDict: freeze prevents set" {
  let d = @value.StarlarkDict::new()
  d.freeze()
  assert_true(d.set(@value.Value::Int(1N), @value.Value::None) is Err(_))
}

///|
test "StarlarkDict: freeze prevents delete" {
  let d = @value.StarlarkDict::new()
  d.set(@value.Value::Int(1N), @value.Value::None) |> ignore
  d.freeze()
  assert_true(d.delete(@value.Value::Int(1N)) is Err(_))
}

// --- StarlarkSet ---

///|
test "StarlarkSet: empty set has length 0" {
  let s = @value.StarlarkSet::new()
  assert_eq(s.length(), 0)
}

///|
test "StarlarkSet: add and contains" {
  let s = @value.StarlarkSet::new()
  assert_true(s.add(@value.Value::Int(1N)) is Ok(_))
  assert_true(s.contains(@value.Value::Int(1N)) == Ok(true))
  assert_true(s.contains(@value.Value::Int(2N)) == Ok(false))
}

///|
test "StarlarkSet: duplicate add does not increase length" {
  let s = @value.StarlarkSet::new()
  s.add(@value.Value::Int(1N)) |> ignore
  s.add(@value.Value::Int(1N)) |> ignore
  assert_eq(s.length(), 1)
}

///|
test "StarlarkSet: remove existing returns true" {
  let s = @value.StarlarkSet::new()
  s.add(@value.Value::Int(1N)) |> ignore
  assert_true(s.remove(@value.Value::Int(1N)) == Ok(true))
  assert_eq(s.length(), 0)
}

///|
test "StarlarkSet: remove missing returns false" {
  let s = @value.StarlarkSet::new()
  assert_true(s.remove(@value.Value::Int(99N)) == Ok(false))
}

///|
test "StarlarkSet: unhashable element returns error" {
  let s = @value.StarlarkSet::new()
  assert_true(s.add(@value.Value::List(@value.StarlarkList::new([]))) is Err(_))
}

///|
test "StarlarkSet: truth empty is false" {
  assert_false(@value.Value::Set(@value.StarlarkSet::new()).truth())
}

///|
test "StarlarkSet: truth nonempty is true" {
  let s = @value.StarlarkSet::new()
  s.add(@value.Value::Int(1N)) |> ignore
  assert_true(@value.Value::Set(s).truth())
}

///|
test "StarlarkSet: type_name is set" {
  assert_eq(@value.Value::Set(@value.StarlarkSet::new()).type_name(), "set")
}

///|
test "StarlarkSet: repr empty is set([])" {
  assert_eq(@value.Value::Set(@value.StarlarkSet::new()).repr(), "set([])")
}

///|
test "StarlarkSet: repr nonempty uses set([...]) notation" {
  let s = @value.StarlarkSet::new()
  s.add(@value.Value::Int(1N)) |> ignore
  assert_eq(@value.Value::Set(s).repr(), "set([1])")
}

///|
test "StarlarkSet: starlark_equals same elements" {
  let s1 = @value.StarlarkSet::new()
  s1.add(@value.Value::Int(1N)) |> ignore
  s1.add(@value.Value::Int(2N)) |> ignore
  let s2 = @value.StarlarkSet::new()
  s2.add(@value.Value::Int(2N)) |> ignore
  s2.add(@value.Value::Int(1N)) |> ignore
  assert_true(@value.Value::Set(s1).starlark_equals(@value.Value::Set(s2)))
}

///|
test "StarlarkSet: starlark_equals different elements" {
  let s1 = @value.StarlarkSet::new()
  s1.add(@value.Value::Int(1N)) |> ignore
  let s2 = @value.StarlarkSet::new()
  s2.add(@value.Value::Int(2N)) |> ignore
  assert_false(@value.Value::Set(s1).starlark_equals(@value.Value::Set(s2)))
}

///|
test "StarlarkSet: starlark_hash is unhashable" {
  let result = @value.Value::hash(@value.Value::Set(@value.StarlarkSet::new()))
  assert_true(result is Err(_))
  match result {
    Err(msg) => assert_true(msg.contains("set"))
    _ => ()
  }
}

///|
test "StarlarkSet: freeze prevents add" {
  let s = @value.StarlarkSet::new()
  s.freeze()
  assert_true(s.add(@value.Value::Int(1N)) is Err(_))
}

///|
test "StarlarkSet: freeze prevents remove" {
  let s = @value.StarlarkSet::new()
  s.add(@value.Value::Int(1N)) |> ignore
  s.freeze()
  assert_true(s.remove(@value.Value::Int(1N)) is Err(_))
}

// --- Iter[T] typed iterator adaptors ---

///|
test "StarlarkDict::entries yields all key-value pairs" {
  let d = @value.StarlarkDict::new()
  d.set(
    @value.Value::String(@value.StarlarkString::new("a")),
    @value.Value::Int(1N),
  )
  |> ignore
  d.set(
    @value.Value::String(@value.StarlarkString::new("b")),
    @value.Value::Int(2N),
  )
  |> ignore
  let result : Array[(@value.Value, @value.Value)] = []
  for entry in d.entries() {
    result.push(entry)
  }
  assert_eq(result.length(), 2)
}

///|
test "StarlarkDict::entries preserves insertion order" {
  let d = @value.StarlarkDict::new()
  d.set(
    @value.Value::Int(3N),
    @value.Value::String(@value.StarlarkString::new("three")),
  )
  |> ignore
  d.set(
    @value.Value::Int(1N),
    @value.Value::String(@value.StarlarkString::new("one")),
  )
  |> ignore
  d.set(
    @value.Value::Int(2N),
    @value.Value::String(@value.StarlarkString::new("two")),
  )
  |> ignore
  let keys : Array[@value.Value] = []
  for entry in d.entries() {
    keys.push(entry.0)
  }
  assert_true(keys[0] == @value.Value::Int(3N))
  assert_true(keys[1] == @value.Value::Int(1N))
  assert_true(keys[2] == @value.Value::Int(2N))
}

///|
test "StarlarkSet::iter yields all elements" {
  let s = @value.StarlarkSet::new()
  s.add(@value.Value::Int(1N)) |> ignore
  s.add(@value.Value::Int(2N)) |> ignore
  s.add(@value.Value::Int(3N)) |> ignore
  let elems : Array[@value.Value] = []
  for v in s.iter() {
    elems.push(v)
  }
  assert_eq(elems.length(), 3)
}

///|
test "StarlarkDict: starlark_equals same size but disjoint keys returns false" {
  let d1 = @value.StarlarkDict::new()
  d1.set(@value.Value::Int(1N), @value.Value::Int(10N)) |> ignore
  let d2 = @value.StarlarkDict::new()
  d2.set(@value.Value::Int(2N), @value.Value::Int(10N)) |> ignore
  assert_false(@value.Value::Dict(d1).starlark_equals(@value.Value::Dict(d2)))
}

///|
test "StarlarkSet: starlark_equals different sizes returns false" {
  let s1 = @value.StarlarkSet::new()
  s1.add(@value.Value::Int(1N)) |> ignore
  let s2 = @value.StarlarkSet::new()
  s2.add(@value.Value::Int(1N)) |> ignore
  s2.add(@value.Value::Int(2N)) |> ignore
  assert_false(@value.Value::Set(s1).starlark_equals(@value.Value::Set(s2)))
}

// --- depth-limit consistency (hash_limit vs compare_limit alignment) ---

///|
test "StarlarkDict: tuple key nested at compare_limit returns an error on insert" {
  let d = @value.StarlarkDict::new()
  let mut v : @value.Value = @value.Value::Int(1N)
  for _ in 0..<@value.compare_limit {
    v = @value.Value::Tuple([v])
  }
  match d.set(v, @value.Value::None) {
    Err(e) => assert_true(e.contains("maximum recursion depth"))
    Ok(_) => fail("expected depth-limit error for deeply nested tuple key")
  }
}

///|
test "StarlarkDict: tuple key nested at compare_limit - 1 can be inserted and retrieved" {
  let d = @value.StarlarkDict::new()
  let mut v : @value.Value = @value.Value::Int(1N)
  for _ in 0..<(@value.compare_limit - 1) {
    v = @value.Value::Tuple([v])
  }
  let expected = @value.Value::String(@value.StarlarkString::new("value"))
  assert_true(d.set(v, expected) is Ok(_))
  match d.get(v) {
    Ok(Some(val)) => assert_true(val.starlark_equals(expected))
    Ok(None) => fail("key not found after insertion")
    Err(e) => fail("unexpected error on get: \{e}")
  }
}

///|
test "StarlarkSet: element nested at compare_limit returns an error on add" {
  let s = @value.StarlarkSet::new()
  let mut v : @value.Value = @value.Value::Int(1N)
  for _ in 0..<@value.compare_limit {
    v = @value.Value::Tuple([v])
  }
  match s.add(v) {
    Err(e) => assert_true(e.contains("maximum recursion depth"))
    Ok(_) => fail("expected depth-limit error for deeply nested tuple element")
  }
}

///|
test "StarlarkSet: element nested at compare_limit - 1 can be added and found" {
  let s = @value.StarlarkSet::new()
  let mut v : @value.Value = @value.Value::Int(1N)
  for _ in 0..<(@value.compare_limit - 1) {
    v = @value.Value::Tuple([v])
  }
  assert_true(s.add(v) is Ok(_))
  match s.contains(v) {
    Ok(found) => assert_true(found)
    Err(e) => fail("unexpected error on contains: \{e}")
  }
}
