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
test "Int: floor_div positive operands" {
  assert_true(floor_div(7N, 2N) == Ok(3N))
  assert_true(floor_div(6N, 2N) == Ok(3N))
}

///|
test "Int: floor_div truncates toward negative infinity" {
  // -7 // 2 = -4 (not -3)
  assert_true(floor_div(-7N, 2N) == Ok(-4N))
  // 7 // -2 = -4 (not -3)
  assert_true(floor_div(7N, -2N) == Ok(-4N))
  // -7 // -2 = 3
  assert_true(floor_div(-7N, -2N) == Ok(3N))
}

///|
test "Int: floor_div by zero is error" {
  assert_true(floor_div(7N, 0N) is Err(_))
}

///|
test "Int: starlark_mod result has same sign as divisor" {
  // positive % positive
  assert_true(starlark_mod(7N, 2N) == Ok(1N))
  // negative dividend, positive divisor: result is positive
  assert_true(starlark_mod(-7N, 2N) == Ok(1N))
  // positive dividend, negative divisor: result is negative
  assert_true(starlark_mod(7N, -2N) == Ok(-1N))
  // negative % negative
  assert_true(starlark_mod(-7N, -2N) == Ok(-1N))
}

///|
test "Int: starlark_mod by zero is error" {
  assert_true(starlark_mod(7N, 0N) is Err(_))
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
test "Value: format_float switches to scientific at magnitude 1e6" {
  // Go's strconv FormatFloat 'g' uses %e once the decimal exponent reaches 6.
  assert_eq(format_float(9999999.9), "9.9999999e+06")
  assert_eq(format_float(1234567.8), "1.2345678e+06")
  assert_eq(format_float(1200000.5), "1.2000005e+06")
  assert_eq(format_float(-9999999.9), "-9.9999999e+06")
}

///|
test "Value: format_float keeps decimal form below magnitude 1e6" {
  assert_eq(format_float(123456.7), "123456.7")
  assert_eq(format_float(100000.0), "100000.0")
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
