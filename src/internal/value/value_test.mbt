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
  assert_eq(type_name(Value::NoneVal), "NoneType")
}

///|
test "Value: type_name for Bool" {
  assert_eq(type_name(Value::BoolVal(true)), "bool")
  assert_eq(type_name(Value::BoolVal(false)), "bool")
}

///|
test "Value: type_name for Int" {
  assert_eq(type_name(Value::IntVal(42L)), "int")
}

///|
test "Value: type_name for Float" {
  assert_eq(type_name(Value::FloatVal(1.0)), "float")
}

///|
test "Value: type_name for String" {
  assert_eq(type_name(Value::StrVal(StarlarkString::new("hello"))), "string")
}

///|
test "Value: type_name for Bytes" {
  assert_eq(type_name(Value::BytesVal(Bytes::new(0))), "bytes")
}

///|
test "Value: truth for None is always false" {
  assert_false(truth(Value::NoneVal))
}

///|
test "Value: truth for Bool" {
  assert_true(truth(Value::BoolVal(true)))
  assert_false(truth(Value::BoolVal(false)))
}

///|
test "Value: truth for Int zero is false" {
  assert_false(truth(Value::IntVal(0L)))
}

///|
test "Value: truth for nonzero Int is true" {
  assert_true(truth(Value::IntVal(1L)))
  assert_true(truth(Value::IntVal(-1L)))
}

///|
test "Value: truth for Float zero is false" {
  assert_false(truth(Value::FloatVal(0.0)))
}

///|
test "Value: truth for nonzero Float is true" {
  assert_true(truth(Value::FloatVal(1.0)))
  assert_true(truth(Value::FloatVal(-1.0)))
}

///|
test "Value: truth for empty String is false" {
  assert_false(truth(Value::StrVal(StarlarkString::new(""))))
}

///|
test "Value: truth for nonempty String is true" {
  assert_true(truth(Value::StrVal(StarlarkString::new("x"))))
}

///|
test "Value: truth for empty Bytes is false" {
  assert_false(truth(Value::BytesVal(Bytes::new(0))))
}

///|
test "Value: truth for nonempty Bytes is true" {
  assert_true(truth(Value::BytesVal(Bytes::make(1, b'\x00'))))
}

///|
test "Int: floor_div positive operands" {
  assert_true(floor_div(7L, 2L) == Ok(3L))
  assert_true(floor_div(6L, 2L) == Ok(3L))
}

///|
test "Int: floor_div truncates toward negative infinity" {
  // -7 // 2 = -4 (not -3)
  assert_true(floor_div(-7L, 2L) == Ok(-4L))
  // 7 // -2 = -4 (not -3)
  assert_true(floor_div(7L, -2L) == Ok(-4L))
  // -7 // -2 = 3
  assert_true(floor_div(-7L, -2L) == Ok(3L))
}

///|
test "Int: floor_div by zero is error" {
  assert_true(floor_div(7L, 0L) is Err(_))
}

///|
test "Int: starlark_mod result has same sign as divisor" {
  // positive % positive
  assert_true(starlark_mod(7L, 2L) == Ok(1L))
  // negative dividend, positive divisor: result is positive
  assert_true(starlark_mod(-7L, 2L) == Ok(1L))
  // positive dividend, negative divisor: result is negative
  assert_true(starlark_mod(7L, -2L) == Ok(-1L))
  // negative % negative
  assert_true(starlark_mod(-7L, -2L) == Ok(-1L))
}

///|
test "Int: starlark_mod by zero is error" {
  assert_true(starlark_mod(7L, 0L) is Err(_))
}

///|
test "Value: repr for None" {
  assert_eq(repr(Value::NoneVal), "None")
}

///|
test "Value: repr for Bool" {
  assert_eq(repr(Value::BoolVal(true)), "True")
  assert_eq(repr(Value::BoolVal(false)), "False")
}

///|
test "Value: repr for Int" {
  assert_eq(repr(Value::IntVal(42L)), "42")
  assert_eq(repr(Value::IntVal(-1L)), "-1")
  assert_eq(repr(Value::IntVal(0L)), "0")
}

///|
test "Value: repr for Float with decimal point" {
  assert_eq(repr(Value::FloatVal(1.0)), "1.0")
  assert_eq(repr(Value::FloatVal(1.5)), "1.5")
  assert_eq(repr(Value::FloatVal(0.0)), "0.0")
}

///|
test "Value: repr for Float special values" {
  assert_eq(repr(Value::FloatVal(@double.not_a_number)), "nan")
  assert_eq(repr(Value::FloatVal(@double.infinity)), "+inf")
  assert_eq(repr(Value::FloatVal(@double.neg_infinity)), "-inf")
}

///|
test "Value: repr for String with double quotes" {
  assert_eq(repr(Value::StrVal(StarlarkString::new("hello"))), "\"hello\"")
  assert_eq(repr(Value::StrVal(StarlarkString::new(""))), "\"\"")
}

///|
test "Value: repr for String with escape sequences" {
  assert_eq(
    repr(Value::StrVal(StarlarkString::new("say \"hi\""))),
    "\"say \\\"hi\\\"\"",
  )
  assert_eq(repr(Value::StrVal(StarlarkString::new("a\nb"))), "\"a\\nb\"")
  assert_eq(repr(Value::StrVal(StarlarkString::new("a\\b"))), "\"a\\\\b\"")
}

///|
test "Value: repr for empty Bytes" {
  assert_eq(repr(Value::BytesVal(Bytes::new(0))), "b\"\"")
}

///|
test "Value: repr for Bytes with printable ASCII" {
  // b"abc" should be b"abc"
  let bytes = @utf8.encode("abc")
  assert_eq(repr(Value::BytesVal(bytes)), "b\"abc\"")
}

///|
test "Value: repr for Bytes with non-printable bytes" {
  let bytes = Bytes::make(1, b'\xff')
  assert_eq(repr(Value::BytesVal(bytes)), "b\"\\xff\"")
}

///|
test "StarlarkModule: type_name is module" {
  let m = StarlarkModule::new("assert", {})
  assert_eq(type_name(Value::ModuleVal(m)), "module")
}

///|
test "StarlarkModule: truth is always true" {
  let m = StarlarkModule::new("assert", {})
  assert_true(truth(Value::ModuleVal(m)))
}

///|
test "StarlarkModule: repr shows module name" {
  let m = StarlarkModule::new("assert", {})
  assert_eq(repr(Value::ModuleVal(m)), "<module \"assert\">")
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
  l.push(Value::StrVal(StarlarkString::new("hello"))) |> ignore
  assert_eq(l.length(), 1)
  let elem = l.get(0)
  match elem {
    Value::StrVal(s) => assert_eq(s.raw(), "hello")
    _ => fail("expected StrVal")
  }
}

///|
test "StarlarkList: push multiple items maintains insertion order" {
  let l = StarlarkList::new([])
  l.push(Value::IntVal(1L)) |> ignore
  l.push(Value::IntVal(2L)) |> ignore
  l.push(Value::IntVal(3L)) |> ignore
  assert_eq(l.length(), 3)
  assert_true(l.get(0) is Value::IntVal(1L))
  assert_true(l.get(1) is Value::IntVal(2L))
  assert_true(l.get(2) is Value::IntVal(3L))
}

///|
test "Value::of_string wraps a string without manual StarlarkString::new" {
  match Value::of_string("hello") {
    StrVal(s) => assert_eq(s.raw(), "hello")
    _ => fail("expected StrVal")
  }
}

///|
test "Value::new_list wraps an array as a mutable list" {
  let v = Value::new_list([Value::IntVal(1L), Value::IntVal(2L)])
  match v {
    ListVal(l) => assert_eq(l.length(), 2)
    _ => fail("expected ListVal")
  }
}

///|
test "Value::new_dict creates an empty dict" {
  match Value::new_dict() {
    DictVal(d) => assert_eq(d.length(), 0)
    _ => fail("expected DictVal")
  }
}

///|
test "Value::new_set creates an empty set" {
  match Value::new_set() {
    SetVal(s) => assert_eq(s.length(), 0)
    _ => fail("expected SetVal")
  }
}

///|
test "Value::new_builtin wraps a named host function" {
  let f = Value::new_builtin("double", fn(_ctx, args, _kw) {
    match args[0] {
      Value::IntVal(n) => Ok(Value::IntVal(n * 2L))
      _ => Err("expected int")
    }
  })
  match f {
    Value::BuiltinFuncVal(b) => assert_eq(b.name(), "double")
    _ => fail("expected BuiltinFuncVal")
  }
}
