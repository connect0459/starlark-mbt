// Whitebox tests for Value::Function properties. StarlarkFunction::new is an
// internal constructor (marked #internal; not part of the public embedding API).

///|
test "Value: type_name for user-defined function is function" {
  let f = StarlarkFunction::new("add", @errors.Position::new("", 0, 0))
  assert_eq(Value::Function(f).type_name(), "function")
}

///|
test "Value: repr for function shows name in angle brackets" {
  let f = StarlarkFunction::new("my_func", @errors.Position::new("", 0, 0))
  assert_eq(Value::Function(f).repr(), "<function my_func>")
}

///|
test "Value: truth for function is always true" {
  let f = StarlarkFunction::new("f", @errors.Position::new("", 0, 0))
  assert_true(Value::Function(f).truth())
}

///|
test "starlark_equals: function equality uses object identity, not name" {
  let pos = @errors.Position::new("", 0, 0)
  let f1 = Value::Function(StarlarkFunction::new("f", pos))
  let f2 = Value::Function(StarlarkFunction::new("f", pos))
  assert_false(f1.starlark_equals(f2))
}

///|
test "starlark_equals: a Function is equal to itself" {
  let f = StarlarkFunction::new("f", @errors.Position::new("", 0, 0))
  let v = Value::Function(f)
  assert_true(v.starlark_equals(v))
}
