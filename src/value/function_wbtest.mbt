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

///|
test "starlark_equals_depth: a Function is equal to itself" {
  let f = StarlarkFunction::new("f", @errors.Position::new("", 0, 0))
  let v = Value::Function(f)
  assert_true(starlark_equals_depth(v, v, 10) == Ok(true))
}

///|
test "iterate: Value::Function is not iterable" {
  let f = StarlarkFunction::new("f", @errors.Position::new("", 0, 0))
  assert_true(iterate(Value::Function(f)) is Err(_))
}

///|
test "length_of: Value::Function has no sequence length" {
  let f = StarlarkFunction::new("f", @errors.Position::new("", 0, 0))
  assert_true(length_of(Value::Function(f)) is Err(_))
}

///|
test "freeze_value: distinct closures sharing a name are both frozen" {
  let pos = @errors.Position::new("", 0, 0)
  let l1 = StarlarkList::new([])
  let l2 = StarlarkList::new([])
  let f1 = {
    ..StarlarkFunction::new("f", pos),
    defaults: [Some(Value::List(l1))],
  }
  let f2 = {
    ..StarlarkFunction::new("f", pos),
    defaults: [Some(Value::List(l2))],
  }
  let outer = StarlarkList::new([Value::Function(f1), Value::Function(f2)])
  Value::freeze(Value::List(outer))
  assert_true(l1.is_frozen())
  assert_true(l2.is_frozen())
}

///|
test "freeze_value: BoundMethod receiver is transitively frozen" {
  let l = StarlarkList::new([])
  let m = StarlarkBoundMethod::new(Value::List(l), "append")
  Value::freeze(Value::BoundMethod(m))
  assert_true(l.is_frozen())
}

///|
test "freeze_value: Builtin with receiver is transitively frozen" {
  let l = StarlarkList::new([])
  let b = StarlarkBuiltinFunc::dispatch("append").bind_receiver(Value::List(l))
  Value::freeze(Value::Builtin(b))
  assert_true(l.is_frozen())
}
