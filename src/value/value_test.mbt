///|
test "StarlarkList::each visits every element in order" {
  let lst = @value.StarlarkList::new([
    @value.Value::Int(1N),
    @value.Value::Int(2N),
    @value.Value::Int(3N),
  ])
  let seen : Array[@value.Value] = []
  lst.each(fn(v) { seen.push(v) })
  assert_eq(seen.length(), 3)
  assert_true(seen[0] == @value.Value::Int(1N))
  assert_true(seen[2] == @value.Value::Int(3N))
}

///|
test "StarlarkString: ASCII byte length" {
  let s = @value.StarlarkString::new("hello")
  assert_eq(s.byte_len(), 5)
}

///|
test "StarlarkString: multi-byte Unicode byte length" {
  // U+03A9 Ω is 2 bytes in UTF-8: 0xCE 0xA9
  let s = @value.StarlarkString::new("Ω")
  assert_eq(s.byte_len(), 2)
}

///|
test "StarlarkString: ASCII byte access" {
  let s = @value.StarlarkString::new("abc")
  assert_eq(s.byte_at(0), b'a')
  assert_eq(s.byte_at(1), b'b')
  assert_eq(s.byte_at(2), b'c')
}

///|
test "StarlarkString: multi-byte byte access" {
  let s = @value.StarlarkString::new("aΩb")
  assert_eq(s.byte_at(0), b'a')
  assert_eq(s.byte_at(1), b'\xCE')
  assert_eq(s.byte_at(2), b'\xA9')
  assert_eq(s.byte_at(3), b'b')
}

///|
test "StarlarkString: equality compares bytes" {
  let a = @value.StarlarkString::new("hello")
  let b = @value.StarlarkString::new("hello")
  let c = @value.StarlarkString::new("world")
  assert_true(a.equals(b))
  assert_false(a.equals(c))
}

///|
test "Value: type_name for None" {
  assert_eq(@value.Value::None.type_name(), "NoneType")
}

///|
test "Value: type_name for Bool" {
  assert_eq(@value.Value::Bool(true).type_name(), "bool")
  assert_eq(@value.Value::Bool(false).type_name(), "bool")
}

///|
test "Value: type_name for Int" {
  assert_eq(@value.Value::Int(42N).type_name(), "int")
}

///|
test "Value: type_name for Float" {
  assert_eq(@value.Value::Float(1.0).type_name(), "float")
}

///|
test "Value: type_name for String" {
  assert_eq(
    @value.Value::String(@value.StarlarkString::new("hello")).type_name(),
    "string",
  )
}

///|
test "Value: type_name for Bytes" {
  assert_eq(@value.Value::Bytes(Bytes::new(0)).type_name(), "bytes")
}

///|
test "Value: truth for None is always false" {
  assert_false(@value.Value::None.truth())
}

///|
test "Value: truth for Bool" {
  assert_true(@value.Value::Bool(true).truth())
  assert_false(@value.Value::Bool(false).truth())
}

///|
test "Value: truth for Int zero is false" {
  assert_false(@value.Value::Int(0N).truth())
}

///|
test "Value: truth for nonzero Int is true" {
  assert_true(@value.Value::Int(1N).truth())
  assert_true(@value.Value::Int(-1N).truth())
}

///|
test "Value: truth for Float zero is false" {
  assert_false(@value.Value::Float(0.0).truth())
}

///|
test "Value: truth for nonzero Float is true" {
  assert_true(@value.Value::Float(1.0).truth())
  assert_true(@value.Value::Float(-1.0).truth())
}

///|
test "Value: truth for empty String is false" {
  assert_false(@value.Value::String(@value.StarlarkString::new("")).truth())
}

///|
test "Value: truth for nonempty String is true" {
  assert_true(@value.Value::String(@value.StarlarkString::new("x")).truth())
}

///|
test "Value: truth for empty Bytes is false" {
  assert_false(@value.Value::Bytes(Bytes::new(0)).truth())
}

///|
test "Value: truth for nonempty Bytes is true" {
  assert_true(@value.Value::Bytes(Bytes::make(1, b'\x00')).truth())
}

///|
test "Value: repr for None" {
  assert_eq(@value.Value::None.repr(), "None")
}

///|
test "Value: repr for Bool" {
  assert_eq(@value.Value::Bool(true).repr(), "True")
  assert_eq(@value.Value::Bool(false).repr(), "False")
}

///|
test "Value: repr for Int" {
  assert_eq(@value.Value::Int(42N).repr(), "42")
  assert_eq(@value.Value::Int(-1N).repr(), "-1")
  assert_eq(@value.Value::Int(0N).repr(), "0")
}

///|
test "Value: repr for Float with decimal point" {
  assert_eq(@value.Value::Float(1.0).repr(), "1.0")
  assert_eq(@value.Value::Float(1.5).repr(), "1.5")
  assert_eq(@value.Value::Float(0.0).repr(), "0.0")
}

///|
test "Value: repr for Float special values" {
  assert_eq(@value.Value::Float(@double.not_a_number).repr(), "nan")
  assert_eq(@value.Value::Float(@double.infinity).repr(), "+inf")
  assert_eq(@value.Value::Float(@double.neg_infinity).repr(), "-inf")
}

///|
test "Value: repr for String with double quotes" {
  assert_eq(
    @value.Value::String(@value.StarlarkString::new("hello")).repr(),
    "\"hello\"",
  )
  assert_eq(@value.Value::String(@value.StarlarkString::new("")).repr(), "\"\"")
}

///|
test "Value: repr for String with escape sequences" {
  assert_eq(
    @value.Value::String(@value.StarlarkString::new("say \"hi\"")).repr(),
    "\"say \\\"hi\\\"\"",
  )
  assert_eq(
    @value.Value::String(@value.StarlarkString::new("a\nb")).repr(),
    "\"a\\nb\"",
  )
  assert_eq(
    @value.Value::String(@value.StarlarkString::new("a\\b")).repr(),
    "\"a\\\\b\"",
  )
}

///|
test "Value: repr for empty Bytes" {
  assert_eq(@value.Value::Bytes(Bytes::new(0)).repr(), "b\"\"")
}

///|
test "Value: repr for Bytes with printable ASCII" {
  // b"abc" should be b"abc"
  let bytes = @utf8.encode("abc")
  assert_eq(@value.Value::Bytes(bytes).repr(), "b\"abc\"")
}

///|
test "Value: repr for Bytes with non-printable bytes" {
  let bytes = Bytes::make(1, b'\xff')
  assert_eq(@value.Value::Bytes(bytes).repr(), "b\"\\xff\"")
}

///|
test "StarlarkModule: type_name is module" {
  let m = @value.StarlarkModule::new("assert", Map([]))
  assert_eq(@value.Value::Module(m).type_name(), "module")
}

///|
test "StarlarkModule: truth is always true" {
  let m = @value.StarlarkModule::new("assert", Map([]))
  assert_true(@value.Value::Module(m).truth())
}

///|
test "StarlarkModule: repr shows module name" {
  let m = @value.StarlarkModule::new("assert", Map([]))
  assert_eq(@value.Value::Module(m).repr(), "<module \"assert\">")
}

///|
test "StarlarkList: new list is empty and mutable" {
  let l = @value.StarlarkList::new([])
  assert_eq(l.length(), 0)
  assert_false(l.is_frozen())
}

///|
test "StarlarkList: push appends item accessible by index" {
  let l = @value.StarlarkList::new([])
  l.push(@value.Value::String(@value.StarlarkString::new("hello"))) |> ignore
  assert_eq(l.length(), 1)
  let elem = l[0]
  match elem {
    @value.Value::String(s) => assert_eq(s.raw(), "hello")
    _ => fail("expected String")
  }
}

///|
test "StarlarkList: push multiple items maintains insertion order" {
  let l = @value.StarlarkList::new([])
  l.push(@value.Value::Int(1N)) |> ignore
  l.push(@value.Value::Int(2N)) |> ignore
  l.push(@value.Value::Int(3N)) |> ignore
  assert_eq(l.length(), 3)
  assert_true(l[0] is @value.Value::Int(1N))
  assert_true(l[1] is @value.Value::Int(2N))
  assert_true(l[2] is @value.Value::Int(3N))
}

///|
test "StarlarkList: get returns Some for in-bounds index and None out of bounds" {
  let l = @value.StarlarkList::new([
    @value.Value::Int(1N),
    @value.Value::Int(2N),
  ])
  assert_true(l.get(0) is Some(@value.Value::Int(1N)))
  assert_true(l.get(1) is Some(@value.Value::Int(2N)))
  assert_true(l.get(2) is None)
  assert_true(l.get(-1) is None)
}

///|
test "Value::new_string wraps a string without manual StarlarkString::new" {
  match @value.Value::new_string("hello") {
    String(s) => assert_eq(s.raw(), "hello")
    _ => fail("expected String")
  }
}

///|
test "Value::new_int and new_float wrap scalars consistently with new_string" {
  assert_true(@value.Value::new_int(42L) is @value.Value::Int(42N))
  assert_true(@value.Value::new_float(1.5) is @value.Value::Float(1.5))
}

///|
test "Value::new_list wraps an array as a mutable list" {
  let v = @value.Value::new_list([@value.Value::Int(1N), @value.Value::Int(2N)])
  match v {
    List(l) => assert_eq(l.length(), 2)
    _ => fail("expected List")
  }
}

///|
test "Value::new_dict creates an empty dict" {
  match @value.Value::new_dict() {
    Dict(d) => assert_eq(d.length(), 0)
    _ => fail("expected Dict")
  }
}

///|
test "Value::new_set creates an empty set" {
  match @value.Value::new_set() {
    Set(s) => assert_eq(s.length(), 0)
    _ => fail("expected Set")
  }
}

///|
test "Value::new_builtin wraps a named host function" {
  let f = @value.Value::new_builtin("double", fn(_ctx, args, _kw) {
    match args[0] {
      @value.Value::Int(n) => Ok(@value.Value::Int(n * 2N))
      _ => Err("expected int")
    }
  })
  match f {
    @value.Value::Builtin(b) => assert_eq(b.name(), "double")
    _ => fail("expected Builtin")
  }
}

///|
test "StarlarkList::iter allows for-in iteration over elements" {
  let l = @value.StarlarkList::new([
    @value.Value::Int(10N),
    @value.Value::Int(20N),
    @value.Value::Int(30N),
  ])
  let elems : Array[@value.Value] = []
  for v in l.iter() {
    elems.push(v)
  }
  assert_eq(elems.length(), 3)
  assert_true(elems[0] == @value.Value::Int(10N))
  assert_true(elems[2] == @value.Value::Int(30N))
}

///|
test "StarlarkList: empty list is empty" {
  let l = @value.StarlarkList::new([])
  assert_true(l.is_empty())
}

///|
test "StarlarkList: nonempty list is not empty" {
  let l = @value.StarlarkList::new([@value.Value::Int(1N)])
  assert_false(l.is_empty())
}

///|
test "StarlarkList::eachi visits each index-value pair in order" {
  let l = @value.StarlarkList::new([
    @value.Value::Int(10N),
    @value.Value::Int(20N),
    @value.Value::Int(30N),
  ])
  let pairs : Array[(Int, @value.Value)] = []
  l.eachi(fn(i, v) { pairs.push((i, v)) })
  assert_eq(pairs.length(), 3)
  assert_eq(pairs[0].0, 0)
  assert_true(pairs[0].1 == @value.Value::Int(10N))
  assert_eq(pairs[2].0, 2)
  assert_true(pairs[2].1 == @value.Value::Int(30N))
}

///|
test "StarlarkList: popping from a frozen list raises an error" {
  let l = @value.StarlarkList::new([@value.Value::Int(1N)])
  l.freeze()
  let result = l.pop()
  assert_true(result is Err(_))
  match result {
    Err(msg) => assert_true(msg.contains("frozen"))
    _ => ()
  }
}

///|
test "StarlarkList: sorting a frozen list raises an error" {
  let l = @value.StarlarkList::new([
    @value.Value::Int(2N),
    @value.Value::Int(1N),
  ])
  l.freeze()
  let result = l.sort_by(fn(_a, _b) { 0 })
  assert_true(result is Err(_))
  match result {
    Err(msg) => assert_true(msg.contains("frozen"))
    _ => ()
  }
}

///|
test "StarlarkList: reversing a frozen list raises an error" {
  let l = @value.StarlarkList::new([
    @value.Value::Int(1N),
    @value.Value::Int(2N),
  ])
  l.freeze()
  let result = l.reverse()
  assert_true(result is Err(_))
  match result {
    Err(msg) => assert_true(msg.contains("frozen"))
    _ => ()
  }
}

///|
test "StarlarkList: pop removes and returns the last element" {
  let l = @value.StarlarkList::new([
    @value.Value::Int(1N),
    @value.Value::Int(2N),
    @value.Value::Int(3N),
  ])
  let result = l.pop()
  assert_true(result == Ok(Some(@value.Value::Int(3N))))
  assert_eq(l.length(), 2)
}

///|
test "StarlarkList: pop on empty list returns None" {
  let l = @value.StarlarkList::new([])
  let result = l.pop()
  assert_true(result == Ok(None))
}

///|
test "StarlarkList: sort_by reorders elements according to the comparator" {
  let l = @value.StarlarkList::new([
    @value.Value::Int(3N),
    @value.Value::Int(1N),
    @value.Value::Int(2N),
  ])
  let _ = l.sort_by(fn(a, b) {
    match (a, b) {
      (@value.Value::Int(x), @value.Value::Int(y)) =>
        if x < y {
          -1
        } else if x > y {
          1
        } else {
          0
        }
      _ => 0
    }
  })
  assert_true(l[0] == @value.Value::Int(1N))
  assert_true(l[1] == @value.Value::Int(2N))
  assert_true(l[2] == @value.Value::Int(3N))
}

///|
test "StarlarkList: reverse swaps the element order in place" {
  let l = @value.StarlarkList::new([
    @value.Value::Int(1N),
    @value.Value::Int(2N),
    @value.Value::Int(3N),
  ])
  let _ = l.reverse()
  assert_true(l[0] == @value.Value::Int(3N))
  assert_true(l[1] == @value.Value::Int(2N))
  assert_true(l[2] == @value.Value::Int(1N))
}

///|
test "repr_checked: shallow list repr succeeds" {
  let l = @value.StarlarkList::new([
    @value.Value::Int(1N),
    @value.Value::Int(2N),
    @value.Value::Int(3N),
  ])
  match @value.Value::List(l).repr_checked() {
    Ok(s) => assert_eq(s, "[1, 2, 3]")
    Err(e) => fail("unexpected error: \{e}")
  }
}

///|
test "repr_checked: deeply nested list exceeding depth limit returns an error" {
  let n = @value.repr_limit + 1
  let mut v : @value.Value = @value.Value::Int(0N)
  for _ in 0..<n {
    v = @value.Value::List(@value.StarlarkList::new([v]))
  }
  match v.repr_checked() {
    Err(e) => assert_true(e.contains("maximum recursion depth"))
    Ok(_) => fail("expected depth-limit error for \{n}-deep list nesting")
  }
}

///|
test "repr_checked: nesting exactly at depth limit succeeds" {
  let mut v : @value.Value = @value.Value::Int(0N)
  for _ in 0..<@value.repr_limit {
    v = @value.Value::List(@value.StarlarkList::new([v]))
  }
  assert_true(v.repr_checked() is Ok(_))
}

///|
test "repr_checked: cyclic list still shows placeholder without depth error" {
  let l = @value.StarlarkList::new([@value.Value::Int(1N)])
  l.push(@value.Value::List(l)) |> ignore
  match @value.Value::List(l).repr_checked() {
    Ok(s) => assert_true(s.contains("[...]"))
    Err(_) => fail("expected cycle placeholder, not depth error")
  }
}

///|
test "to_str_checked: deeply nested list exceeding depth limit returns an error" {
  let n = @value.repr_limit + 1
  let mut v : @value.Value = @value.Value::Int(0N)
  for _ in 0..<n {
    v = @value.Value::List(@value.StarlarkList::new([v]))
  }
  match v.to_str_checked() {
    Err(e) => assert_true(e.contains("maximum recursion depth"))
    Ok(_) => fail("expected depth-limit error for \{n}-deep list nesting")
  }
}

///|
test "to_str_checked: string returns raw value without quotes" {
  let s = @value.Value::String(@value.StarlarkString::new("hello"))
  match s.to_str_checked() {
    Ok(raw) => assert_eq(raw, "hello")
    Err(e) => fail("unexpected error: \{e}")
  }
}

///|
test "hash: shallow tuple returns a stable hash value" {
  let t = @value.Value::Tuple([@value.Value::Int(1N), @value.Value::Int(2N)])
  match t.hash() {
    Ok(_) => ()
    Err(e) => fail("unexpected error: \{e}")
  }
}

///|
test "hash: deeply nested tuple exceeding depth limit returns a graceful error" {
  let n = @value.hash_limit + 1
  let mut v : @value.Value = @value.Value::Int(1N)
  for _ in 0..<n {
    v = @value.Value::Tuple([v])
  }
  match v.hash() {
    Err(e) => assert_true(e.contains("maximum recursion depth"))
    Ok(_) => fail("expected depth-limit error for \{n}-deep tuple nesting")
  }
}

///|
test "hash: nesting exactly at depth limit succeeds" {
  let mut v : @value.Value = @value.Value::Int(1N)
  for _ in 0..<@value.hash_limit {
    v = @value.Value::Tuple([v])
  }
  assert_true(v.hash() is Ok(_))
}

///|
test "hash: ExtVal with with_hash_depth threads depth to callback" {
  let received_depth : Ref[Int] = { val: -1, }
  let cv = @value.CustomValue::new(fn() { "T" }, fn() { true }, fn() { "T()" }).with_hash_depth(fn(
      d,
    ) {
      received_depth.val = d
      Ok(42U)
    },
  )
  assert_true(@value.hash_value_depth(@value.Value::ExtVal(cv), 7) is Ok(42U))
  assert_eq(received_depth.val, 7)
}

///|
test "hash: ExtVal with only with_hash returns error when depth is exhausted" {
  let cv = @value.CustomValue::new(fn() { "T" }, fn() { true }, fn() { "T()" }).with_hash(fn() {
      Ok(99U)
    },
  )
  match @value.hash_value_depth(@value.Value::ExtVal(cv), 0) {
    Err(e) => assert_true(e.contains("maximum recursion depth"))
    Ok(_) => fail("expected depth error")
  }
}

///|
test "hash: ExtVal with only with_hash succeeds when depth is available" {
  let cv = @value.CustomValue::new(fn() { "T" }, fn() { true }, fn() { "T()" }).with_hash(fn() {
      Ok(99U)
    },
  )
  assert_true(@value.hash_value_depth(@value.Value::ExtVal(cv), 1) is Ok(99U))
}

///|
test "freeze_checked: shallow list freezes successfully" {
  let l = @value.StarlarkList::new([
    @value.Value::Int(1N),
    @value.Value::Int(2N),
  ])
  assert_true(@value.Value::List(l).freeze_checked() is Ok(_))
  assert_true(l.is_frozen())
}

///|
test "freeze_checked: deeply nested list exceeding depth limit returns an error" {
  let n = @value.freeze_limit + 1
  let mut v : @value.Value = @value.Value::Int(0N)
  for _ in 0..<n {
    v = @value.Value::List(@value.StarlarkList::new([v]))
  }
  match v.freeze_checked() {
    Err(e) => assert_true(e.contains("maximum recursion depth"))
    Ok(_) => fail("expected depth-limit error for \{n}-deep list nesting")
  }
}

///|
test "freeze_checked: nesting exactly at depth limit succeeds" {
  let mut v : @value.Value = @value.Value::Int(0N)
  for _ in 0..<@value.freeze_limit {
    v = @value.Value::List(@value.StarlarkList::new([v]))
  }
  assert_true(v.freeze_checked() is Ok(_))
}

///|
test "freeze_checked: deeply nested dict exceeding depth limit returns an error" {
  let n = @value.freeze_limit + 1
  let mut v : @value.Value = @value.Value::Int(0N)
  for _ in 0..<n {
    let d = @value.StarlarkDict::new()
    d.set(@value.Value::String(@value.StarlarkString::new("k")), v) |> ignore
    v = @value.Value::Dict(d)
  }
  match v.freeze_checked() {
    Err(e) => assert_true(e.contains("maximum recursion depth"))
    Ok(_) => fail("expected depth-limit error for \{n}-deep dict nesting")
  }
}

///|
test "freeze_checked: already-frozen container skips re-traversal" {
  let inner = @value.StarlarkList::new([@value.Value::Int(1N)])
  inner.freeze()
  let outer = @value.StarlarkList::new([@value.Value::List(inner)])
  assert_true(@value.Value::List(outer).freeze_checked() is Ok(_))
  assert_true(outer.is_frozen())
}
