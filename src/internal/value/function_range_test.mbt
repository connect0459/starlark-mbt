// Tests for StarlarkRange, StarlarkFunction, StarlarkBuiltinFunc,
// StarlarkBoundMethod, and freeze semantics.

// --- StarlarkRange ---

///|
test "StarlarkRange: length of range(10) is 10" {
  let r = StarlarkRange::new(0L, 10L, 1L)
  assert_eq(r.length(), 10)
}

///|
test "StarlarkRange: length of range(0, 10, 2) is 5" {
  let r = StarlarkRange::new(0L, 10L, 2L)
  assert_eq(r.length(), 5)
}

///|
test "StarlarkRange: length of range(1, 10) is 9" {
  let r = StarlarkRange::new(1L, 10L, 1L)
  assert_eq(r.length(), 9)
}

///|
test "StarlarkRange: empty when start equals stop" {
  let r = StarlarkRange::new(5L, 5L, 1L)
  assert_eq(r.length(), 0)
}

///|
test "StarlarkRange: empty when start exceeds stop with positive step" {
  let r = StarlarkRange::new(10L, 3L, 1L)
  assert_eq(r.length(), 0)
}

///|
test "StarlarkRange: negative step produces reversed range" {
  let r = StarlarkRange::new(10L, 0L, -1L)
  assert_eq(r.length(), 10)
}

///|
test "StarlarkRange: negative step with large step size" {
  let r = StarlarkRange::new(10L, 0L, -3L)
  assert_eq(r.length(), 4) // 10, 7, 4, 1
}

///|
test "StarlarkRange: index_at returns correct element" {
  let r = StarlarkRange::new(0L, 10L, 2L)
  assert_eq(r.index_at(0), 0L)
  assert_eq(r.index_at(1), 2L)
  assert_eq(r.index_at(4), 8L)
}

///|
test "StarlarkRange: index_at with negative step" {
  let r = StarlarkRange::new(10L, 0L, -2L)
  assert_eq(r.index_at(0), 10L)
  assert_eq(r.index_at(1), 8L)
  assert_eq(r.index_at(4), 2L)
}

///|
test "StarlarkRange: contains value in range" {
  let r = StarlarkRange::new(0L, 10L, 2L)
  assert_true(r.contains(0L))
  assert_true(r.contains(4L))
  assert_true(r.contains(8L))
}

///|
test "StarlarkRange: does not contain value outside range" {
  let r = StarlarkRange::new(0L, 10L, 2L)
  assert_false(r.contains(1L))
  assert_false(r.contains(10L))
  assert_false(r.contains(-2L))
}

///|
test "Value: type_name for Range is range" {
  let r = StarlarkRange::new(0L, 10L, 1L)
  assert_eq(type_name(Value::RangeVal(r)), "range")
}

///|
test "Value: repr for range(10) shows compact form" {
  let r = StarlarkRange::new(0L, 10L, 1L)
  assert_eq(repr(Value::RangeVal(r)), "range(10)")
}

///|
test "Value: repr for range(1, 10) shows start and stop" {
  let r = StarlarkRange::new(1L, 10L, 1L)
  assert_eq(repr(Value::RangeVal(r)), "range(1, 10)")
}

///|
test "Value: repr for range(0, 10, 2) shows step when not 1" {
  let r = StarlarkRange::new(0L, 10L, 2L)
  assert_eq(repr(Value::RangeVal(r)), "range(0, 10, 2)")
}

///|
test "Value: truth for non-empty range is true" {
  let r = StarlarkRange::new(0L, 10L, 1L)
  assert_true(truth(Value::RangeVal(r)))
}

///|
test "Value: truth for empty range is false" {
  let r = StarlarkRange::new(5L, 3L, 1L)
  assert_false(truth(Value::RangeVal(r)))
}

// --- StarlarkFunction ---

///|
test "Value: type_name for user-defined function is function" {
  let f = StarlarkFunction::new("add", [], [], [], [])
  assert_eq(type_name(Value::FuncVal(f)), "function")
}

///|
test "Value: repr for function shows name in angle brackets" {
  let f = StarlarkFunction::new("my_func", [], [], [], [])
  assert_eq(repr(Value::FuncVal(f)), "<function my_func>")
}

///|
test "Value: truth for function is always true" {
  let f = StarlarkFunction::new("f", [], [], [], [])
  assert_true(truth(Value::FuncVal(f)))
}

// --- StarlarkBuiltinFunc ---

///|
test "Value: type_name for builtin function is builtin_function_or_method" {
  let f = StarlarkBuiltinFunc::dispatch("len")
  assert_eq(type_name(Value::BuiltinFuncVal(f)), "builtin_function_or_method")
}

///|
test "Value: repr for builtin function shows name" {
  let f = StarlarkBuiltinFunc::dispatch("len")
  assert_eq(repr(Value::BuiltinFuncVal(f)), "<built-in function len>")
}

///|
test "Value: truth for builtin function is always true" {
  let f = StarlarkBuiltinFunc::dispatch("len")
  assert_true(truth(Value::BuiltinFuncVal(f)))
}

// --- StarlarkBoundMethod ---

///|
test "Value: type_name for bound method is builtin_function_or_method" {
  let recv = Value::StrVal(StarlarkString::new("hello"))
  let m = StarlarkBoundMethod::new(recv, "upper")
  assert_eq(type_name(Value::BoundMethodVal(m)), "builtin_function_or_method")
}

///|
test "Value: repr for bound method shows receiver type and method name" {
  let recv = Value::StrVal(StarlarkString::new("hello"))
  let m = StarlarkBoundMethod::new(recv, "upper")
  assert_eq(
    repr(Value::BoundMethodVal(m)),
    "<built-in method upper of string value>",
  )
}

///|
test "Value: truth for bound method is always true" {
  let recv = Value::NoneVal
  let m = StarlarkBoundMethod::new(recv, "something")
  assert_true(truth(Value::BoundMethodVal(m)))
}

// --- freeze semantics ---

///|
test "StarlarkList: is_frozen returns false for new list" {
  let l = StarlarkList::new([])
  assert_false(l.is_frozen())
}

///|
test "StarlarkList: freeze marks list as frozen" {
  let l = StarlarkList::new([])
  l.freeze()
  assert_true(l.is_frozen())
}

///|
test "freeze_value: freezes a list and its mutable nested values" {
  let inner = StarlarkList::new([Value::IntVal(1L)])
  let outer = StarlarkList::new([Value::ListVal(inner)])
  freeze_value(Value::ListVal(outer))
  assert_true(outer.is_frozen())
  assert_true(inner.is_frozen())
}

///|
test "freeze_value: freezes a dict and its mutable nested values" {
  let inner = StarlarkList::new([])
  let d = StarlarkDict::new()
  d.set(Value::StrVal(StarlarkString::new("k")), Value::ListVal(inner))
  |> ignore
  freeze_value(Value::DictVal(d))
  assert_true(d.is_frozen())
  assert_true(inner.is_frozen())
}

///|
test "freeze_value: freezes a set" {
  let s = StarlarkSet::new()
  s.add(Value::IntVal(1L)) |> ignore
  freeze_value(Value::SetVal(s))
  assert_true(s.is_frozen())
}

///|
test "freeze_value: is idempotent on already-frozen values" {
  let l = StarlarkList::new([])
  l.freeze()
  freeze_value(Value::ListVal(l))
  assert_true(l.is_frozen())
}

///|
test "freeze_value: primitives are not mutable, freeze is no-op" {
  freeze_value(Value::IntVal(42L))
  freeze_value(Value::StrVal(StarlarkString::new("hello")))
  freeze_value(Value::NoneVal)
}
