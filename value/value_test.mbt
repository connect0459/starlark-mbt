///|
test "StarlarkList::each visits every element in order" {
  let lst = StarlarkList::new([Value::Int(1N), Value::Int(2N), Value::Int(3N)])
  let seen : Array[Value] = []
  lst.each(fn(v) { seen.push(v) })
  assert_eq(seen.length(), 3)
  assert_true(seen[0] == Value::Int(1N))
  assert_true(seen[2] == Value::Int(3N))
}

///|
test "StarlarkString: ASCII byte length" {
  let s = StarlarkString::new("hello")
  assert_eq(s.byte_len(), 5)
}

///|
test "StarlarkString: multi-byte Unicode byte length" {
  // U+03A9 Ω is 2 bytes in UTF-8: 0xCE 0xA9
  let s = StarlarkString::new("Ω")
  assert_eq(s.byte_len(), 2)
}

///|
test "StarlarkString: ASCII byte access" {
  let s = StarlarkString::new("abc")
  assert_eq(s.byte_at(0), b'a')
  assert_eq(s.byte_at(1), b'b')
  assert_eq(s.byte_at(2), b'c')
}

///|
test "StarlarkString: multi-byte byte access" {
  let s = StarlarkString::new("aΩb")
  assert_eq(s.byte_at(0), b'a')
  assert_eq(s.byte_at(1), b'\xCE')
  assert_eq(s.byte_at(2), b'\xA9')
  assert_eq(s.byte_at(3), b'b')
}

///|
test "StarlarkString: equality compares bytes" {
  let a = StarlarkString::new("hello")
  let b = StarlarkString::new("hello")
  let c = StarlarkString::new("world")
  assert_true(a.equals(b))
  assert_false(a.equals(c))
}

///|
test "Value: type_name for None" {
  assert_eq(Value::None.type_name(), "NoneType")
}

///|
test "Value: type_name for Bool" {
  assert_eq(Value::Bool(true).type_name(), "bool")
  assert_eq(Value::Bool(false).type_name(), "bool")
}

///|
test "Value: type_name for Int" {
  assert_eq(Value::Int(42N).type_name(), "int")
}

///|
test "Value: type_name for Float" {
  assert_eq(Value::Float(1.0).type_name(), "float")
}

///|
test "Value: type_name for String" {
  assert_eq(Value::String(StarlarkString::new("hello")).type_name(), "string")
}

///|
test "Value: type_name for Bytes" {
  assert_eq(Value::Bytes(Bytes::new(0)).type_name(), "bytes")
}

///|
test "Value: truth for None is always false" {
  assert_false(Value::None.truth())
}

///|
test "Value: truth for Bool" {
  assert_true(Value::Bool(true).truth())
  assert_false(Value::Bool(false).truth())
}

///|
test "Value: truth for Int zero is false" {
  assert_false(Value::Int(0N).truth())
}

///|
test "Value: truth for nonzero Int is true" {
  assert_true(Value::Int(1N).truth())
  assert_true(Value::Int(-1N).truth())
}

///|
test "Value: truth for Float zero is false" {
  assert_false(Value::Float(0.0).truth())
}

///|
test "Value: truth for nonzero Float is true" {
  assert_true(Value::Float(1.0).truth())
  assert_true(Value::Float(-1.0).truth())
}

///|
test "Value: truth for empty String is false" {
  assert_false(Value::String(StarlarkString::new("")).truth())
}

///|
test "Value: truth for nonempty String is true" {
  assert_true(Value::String(StarlarkString::new("x")).truth())
}

///|
test "Value: truth for empty Bytes is false" {
  assert_false(Value::Bytes(Bytes::new(0)).truth())
}

///|
test "Value: truth for nonempty Bytes is true" {
  assert_true(Value::Bytes(Bytes::make(1, b'\x00')).truth())
}

///|
test "Value: repr for None" {
  assert_eq(Value::None.repr(), "None")
}

///|
test "Value: repr for Bool" {
  assert_eq(Value::Bool(true).repr(), "True")
  assert_eq(Value::Bool(false).repr(), "False")
}

///|
test "Value: repr for Int" {
  assert_eq(Value::Int(42N).repr(), "42")
  assert_eq(Value::Int(-1N).repr(), "-1")
  assert_eq(Value::Int(0N).repr(), "0")
}

///|
test "Value: repr for Float with decimal point" {
  assert_eq(Value::Float(1.0).repr(), "1.0")
  assert_eq(Value::Float(1.5).repr(), "1.5")
  assert_eq(Value::Float(0.0).repr(), "0.0")
}

///|
test "Value: repr for Float special values" {
  assert_eq(Value::Float(@double.not_a_number).repr(), "nan")
  assert_eq(Value::Float(@double.infinity).repr(), "+inf")
  assert_eq(Value::Float(@double.neg_infinity).repr(), "-inf")
}

///|
test "Value: repr for String with double quotes" {
  assert_eq(Value::String(StarlarkString::new("hello")).repr(), "\"hello\"")
  assert_eq(Value::String(StarlarkString::new("")).repr(), "\"\"")
}

///|
test "Value: repr for String with escape sequences" {
  assert_eq(
    Value::String(StarlarkString::new("say \"hi\"")).repr(),
    "\"say \\\"hi\\\"\"",
  )
  assert_eq(Value::String(StarlarkString::new("a\nb")).repr(), "\"a\\nb\"")
  assert_eq(Value::String(StarlarkString::new("a\\b")).repr(), "\"a\\\\b\"")
}

///|
test "Value: repr for empty Bytes" {
  assert_eq(Value::Bytes(Bytes::new(0)).repr(), "b\"\"")
}

///|
test "Value: repr for Bytes with printable ASCII" {
  // b"abc" should be b"abc"
  let bytes = @utf8.encode("abc")
  assert_eq(Value::Bytes(bytes).repr(), "b\"abc\"")
}

///|
test "Value: repr for Bytes with non-printable bytes" {
  let bytes = Bytes::make(1, b'\xff')
  assert_eq(Value::Bytes(bytes).repr(), "b\"\\xff\"")
}

///|
test "StarlarkModule: type_name is module" {
  let m = StarlarkModule::new("assert", {})
  assert_eq(Value::Module(m).type_name(), "module")
}

///|
test "StarlarkModule: truth is always true" {
  let m = StarlarkModule::new("assert", {})
  assert_true(Value::Module(m).truth())
}

///|
test "StarlarkModule: repr shows module name" {
  let m = StarlarkModule::new("assert", {})
  assert_eq(Value::Module(m).repr(), "<module \"assert\">")
}

///|
test "StarlarkList: new list is empty and mutable" {
  let l = StarlarkList::new([])
  assert_eq(l.length(), 0)
  assert_false(l.is_frozen())
}

///|
test "StarlarkList: push appends item accessible by index" {
  let l = StarlarkList::new([])
  l.push(Value::String(StarlarkString::new("hello"))) |> ignore
  assert_eq(l.length(), 1)
  let elem = l[0]
  match elem {
    Value::String(s) => assert_eq(s.raw(), "hello")
    _ => fail("expected String")
  }
}

///|
test "StarlarkList: push multiple items maintains insertion order" {
  let l = StarlarkList::new([])
  l.push(Value::Int(1N)) |> ignore
  l.push(Value::Int(2N)) |> ignore
  l.push(Value::Int(3N)) |> ignore
  assert_eq(l.length(), 3)
  assert_true(l[0] is Value::Int(1N))
  assert_true(l[1] is Value::Int(2N))
  assert_true(l[2] is Value::Int(3N))
}

///|
test "StarlarkList: get returns Some for in-bounds index and None out of bounds" {
  let l = StarlarkList::new([Value::Int(1N), Value::Int(2N)])
  assert_true(l.get(0) is Some(Value::Int(1N)))
  assert_true(l.get(1) is Some(Value::Int(2N)))
  assert_true(l.get(2) is None)
  assert_true(l.get(-1) is None)
}

///|
test "Value::new_string wraps a string without manual StarlarkString::new" {
  match Value::new_string("hello") {
    String(s) => assert_eq(s.raw(), "hello")
    _ => fail("expected String")
  }
}

///|
test "Value::new_int and new_float wrap scalars consistently with new_string" {
  assert_true(Value::new_int(42L) is Value::Int(42N))
  assert_true(Value::new_float(1.5) is Value::Float(1.5))
}

///|
test "Value::new_list wraps an array as a mutable list" {
  let v = Value::new_list([Value::Int(1N), Value::Int(2N)])
  match v {
    List(l) => assert_eq(l.length(), 2)
    _ => fail("expected List")
  }
}

///|
test "Value::new_dict creates an empty dict" {
  match Value::new_dict() {
    Dict(d) => assert_eq(d.length(), 0)
    _ => fail("expected Dict")
  }
}

///|
test "Value::new_set creates an empty set" {
  match Value::new_set() {
    Set(s) => assert_eq(s.length(), 0)
    _ => fail("expected Set")
  }
}

///|
test "Value::new_builtin wraps a named host function" {
  let f = Value::new_builtin("double", fn(_ctx, args, _kw) {
    match args[0] {
      Value::Int(n) => Ok(Value::Int(n * 2N))
      _ => Err("expected int")
    }
  })
  match f {
    Value::Builtin(b) => assert_eq(b.name(), "double")
    _ => fail("expected Builtin")
  }
}

///|
test "StarlarkList::iter allows for-in iteration over elements" {
  let l = StarlarkList::new([Value::Int(10N), Value::Int(20N), Value::Int(30N)])
  let elems : Array[Value] = []
  for v in l.iter() {
    elems.push(v)
  }
  assert_eq(elems.length(), 3)
  assert_true(elems[0] == Value::Int(10N))
  assert_true(elems[2] == Value::Int(30N))
}

///|
test "StarlarkList: empty list is empty" {
  let l = StarlarkList::new([])
  assert_true(l.is_empty())
}

///|
test "StarlarkList: nonempty list is not empty" {
  let l = StarlarkList::new([Value::Int(1N)])
  assert_false(l.is_empty())
}

///|
test "StarlarkList::eachi visits each index-value pair in order" {
  let l = StarlarkList::new([Value::Int(10N), Value::Int(20N), Value::Int(30N)])
  let pairs : Array[(Int, Value)] = []
  l.eachi(fn(i, v) { pairs.push((i, v)) })
  assert_eq(pairs.length(), 3)
  assert_eq(pairs[0].0, 0)
  assert_true(pairs[0].1 == Value::Int(10N))
  assert_eq(pairs[2].0, 2)
  assert_true(pairs[2].1 == Value::Int(30N))
}

///|
test "StarlarkList: popping from a frozen list raises an error" {
  let l = StarlarkList::new([Value::Int(1N)])
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
  let l = StarlarkList::new([Value::Int(2N), Value::Int(1N)])
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
  let l = StarlarkList::new([Value::Int(1N), Value::Int(2N)])
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
  let l = StarlarkList::new([Value::Int(1N), Value::Int(2N), Value::Int(3N)])
  let result = l.pop()
  assert_true(result == Ok(Some(Value::Int(3N))))
  assert_eq(l.length(), 2)
}

///|
test "StarlarkList: pop on empty list returns None" {
  let l = StarlarkList::new([])
  let result = l.pop()
  assert_true(result == Ok(None))
}

///|
test "StarlarkList: sort_by reorders elements according to the comparator" {
  let l = StarlarkList::new([Value::Int(3N), Value::Int(1N), Value::Int(2N)])
  let _ = l.sort_by(fn(a, b) {
    match (a, b) {
      (Value::Int(x), Value::Int(y)) =>
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
  assert_true(l[0] == Value::Int(1N))
  assert_true(l[1] == Value::Int(2N))
  assert_true(l[2] == Value::Int(3N))
}

///|
test "StarlarkList: reverse swaps the element order in place" {
  let l = StarlarkList::new([Value::Int(1N), Value::Int(2N), Value::Int(3N)])
  let _ = l.reverse()
  assert_true(l[0] == Value::Int(3N))
  assert_true(l[1] == Value::Int(2N))
  assert_true(l[2] == Value::Int(1N))
}

///|
test "repr_checked: shallow list repr succeeds" {
  let l = StarlarkList::new([Value::Int(1N), Value::Int(2N), Value::Int(3N)])
  match Value::List(l).repr_checked() {
    Ok(s) => assert_eq(s, "[1, 2, 3]")
    Err(e) => fail("unexpected error: \{e}")
  }
}

///|
test "repr_checked: deeply nested list exceeding depth limit returns an error" {
  let n = repr_limit + 1
  let mut v : Value = Value::Int(0N)
  for _ in 0..<n {
    v = Value::List(StarlarkList::new([v]))
  }
  match v.repr_checked() {
    Err(e) => assert_true(e.contains("maximum recursion depth"))
    Ok(_) => fail("expected depth-limit error for \{n}-deep list nesting")
  }
}

///|
test "repr_checked: nesting exactly at depth limit succeeds" {
  let mut v : Value = Value::Int(0N)
  for _ in 0..<repr_limit {
    v = Value::List(StarlarkList::new([v]))
  }
  assert_true(v.repr_checked() is Ok(_))
}

///|
test "repr_checked: cyclic list still shows placeholder without depth error" {
  let l = StarlarkList::new([Value::Int(1N)])
  l.push(Value::List(l)) |> ignore
  match Value::List(l).repr_checked() {
    Ok(s) => assert_true(s.contains("[...]"))
    Err(_) => fail("expected cycle placeholder, not depth error")
  }
}

///|
test "to_str_checked: deeply nested list exceeding depth limit returns an error" {
  let n = repr_limit + 1
  let mut v : Value = Value::Int(0N)
  for _ in 0..<n {
    v = Value::List(StarlarkList::new([v]))
  }
  match v.to_str_checked() {
    Err(e) => assert_true(e.contains("maximum recursion depth"))
    Ok(_) => fail("expected depth-limit error for \{n}-deep list nesting")
  }
}

///|
test "to_str_checked: string returns raw value without quotes" {
  let s = Value::String(StarlarkString::new("hello"))
  match s.to_str_checked() {
    Ok(raw) => assert_eq(raw, "hello")
    Err(e) => fail("unexpected error: \{e}")
  }
}

///|
test "hash: shallow tuple returns a stable hash value" {
  let t = Value::Tuple([Value::Int(1N), Value::Int(2N)])
  match t.hash() {
    Ok(_) => ()
    Err(e) => fail("unexpected error: \{e}")
  }
}

///|
test "hash: deeply nested tuple exceeding depth limit returns a graceful error" {
  let n = hash_limit + 1
  let mut v : Value = Value::Int(1N)
  for _ in 0..<n {
    v = Value::Tuple([v])
  }
  match v.hash() {
    Err(e) => assert_true(e.contains("maximum recursion depth"))
    Ok(_) => fail("expected depth-limit error for \{n}-deep tuple nesting")
  }
}

///|
test "hash: nesting exactly at depth limit succeeds" {
  let mut v : Value = Value::Int(1N)
  for _ in 0..<hash_limit {
    v = Value::Tuple([v])
  }
  assert_true(v.hash() is Ok(_))
}

///|
test "hash: ExtVal with with_hash_depth threads depth to callback" {
  let received_depth : Ref[Int] = { val: -1 }
  let cv = CustomValue::new(fn() { "T" }, fn() { true }, fn() { "T()" }).with_hash_depth(fn(
      d,
    ) {
      received_depth.val = d
      Ok(42U)
    },
  )
  assert_true(hash_value_depth(Value::ExtVal(cv), 7) is Ok(42U))
  assert_eq(received_depth.val, 7)
}

///|
test "hash: ExtVal with only with_hash returns error when depth is exhausted" {
  let cv = CustomValue::new(fn() { "T" }, fn() { true }, fn() { "T()" }).with_hash(fn() {
      Ok(99U)
    },
  )
  match hash_value_depth(Value::ExtVal(cv), 0) {
    Err(e) => assert_true(e.contains("maximum recursion depth"))
    Ok(_) => fail("expected depth error")
  }
}

///|
test "hash: ExtVal with only with_hash succeeds when depth is available" {
  let cv = CustomValue::new(fn() { "T" }, fn() { true }, fn() { "T()" }).with_hash(fn() {
      Ok(99U)
    },
  )
  assert_true(hash_value_depth(Value::ExtVal(cv), 1) is Ok(99U))
}
