// Tests for StarlarkRange, StarlarkFunction, StarlarkBuiltinFunc,
// StarlarkBoundMethod, and freeze semantics.

// --- StarlarkRange ---

///|
test "StarlarkRange: length of range(10) is 10" {
  let r = @value.StarlarkRange::new(0L, 10L, 1L)
  assert_eq(r.length(), 10L)
}

///|
test "StarlarkRange: length of range(0, 1<<32) is 4294967296 without truncation" {
  let r = @value.StarlarkRange::new(0L, 4294967296L, 1L)
  assert_eq(r.length(), 4294967296L)
}

///|
test "StarlarkRange: length of range(0, 1<<31) is 2147483648 without truncation" {
  let r = @value.StarlarkRange::new(0L, 2147483648L, 1L)
  assert_eq(r.length(), 2147483648L)
}

///|
test "Value: truth of range(0, 1<<32) is true" {
  let r = @value.StarlarkRange::new(0L, 4294967296L, 1L)
  assert_true(@value.Value::Range(r).truth())
}

///|
test "StarlarkRange: length of range(0, 10, 2) is 5" {
  let r = @value.StarlarkRange::new(0L, 10L, 2L)
  assert_eq(r.length(), 5)
}

///|
test "StarlarkRange: length of range(1, 10) is 9" {
  let r = @value.StarlarkRange::new(1L, 10L, 1L)
  assert_eq(r.length(), 9)
}

///|
test "StarlarkRange: empty when start equals stop" {
  let r = @value.StarlarkRange::new(5L, 5L, 1L)
  assert_eq(r.length(), 0)
}

///|
test "StarlarkRange: empty when start exceeds stop with positive step" {
  let r = @value.StarlarkRange::new(10L, 3L, 1L)
  assert_eq(r.length(), 0)
}

///|
test "StarlarkRange: negative step produces reversed range" {
  let r = @value.StarlarkRange::new(10L, 0L, -1L)
  assert_eq(r.length(), 10)
}

///|
test "StarlarkRange: negative step with large step size" {
  let r = @value.StarlarkRange::new(10L, 0L, -3L)
  assert_eq(r.length(), 4) // 10, 7, 4, 1
}

///|
test "StarlarkRange: length of range(Int64::MIN, Int64::MAX, 2) is negative overflow sentinel" {
  let r = @value.StarlarkRange::new(@int64.MIN_VALUE, @int64.MAX_VALUE, 2L)
  assert_true(r.length() < 0L)
}

///|
test "StarlarkRange: length of range(Int64::MAX, Int64::MIN, -2) is negative overflow sentinel" {
  let r = @value.StarlarkRange::new(@int64.MAX_VALUE, @int64.MIN_VALUE, -2L)
  assert_true(r.length() < 0L)
}

///|
test "StarlarkRange: index_at returns correct element" {
  let r = @value.StarlarkRange::new(0L, 10L, 2L)
  assert_eq(r.index_at(0), 0L)
  assert_eq(r.index_at(1), 2L)
  assert_eq(r.index_at(4), 8L)
}

///|
test "StarlarkRange: index_at with negative step" {
  let r = @value.StarlarkRange::new(10L, 0L, -2L)
  assert_eq(r.index_at(0), 10L)
  assert_eq(r.index_at(1), 8L)
  assert_eq(r.index_at(4), 2L)
}

///|
test "StarlarkRange: contains value in range" {
  let r = @value.StarlarkRange::new(0L, 10L, 2L)
  assert_true(r.contains(0L))
  assert_true(r.contains(4L))
  assert_true(r.contains(8L))
}

///|
test "StarlarkRange: does not contain value outside range" {
  let r = @value.StarlarkRange::new(0L, 10L, 2L)
  assert_false(r.contains(1L))
  assert_false(r.contains(10L))
  assert_false(r.contains(-2L))
}

///|
test "Value: type_name for Range is range" {
  let r = @value.StarlarkRange::new(0L, 10L, 1L)
  assert_eq(@value.Value::Range(r).type_name(), "range")
}

///|
test "Value: repr for range(10) shows compact form" {
  let r = @value.StarlarkRange::new(0L, 10L, 1L)
  assert_eq(@value.Value::Range(r).repr(), "range(10)")
}

///|
test "Value: repr for range(1, 10) shows start and stop" {
  let r = @value.StarlarkRange::new(1L, 10L, 1L)
  assert_eq(@value.Value::Range(r).repr(), "range(1, 10)")
}

///|
test "Value: repr for range(0, 10, 2) shows step when not 1" {
  let r = @value.StarlarkRange::new(0L, 10L, 2L)
  assert_eq(@value.Value::Range(r).repr(), "range(0, 10, 2)")
}

///|
test "Value: truth for non-empty range is true" {
  let r = @value.StarlarkRange::new(0L, 10L, 1L)
  assert_true(@value.Value::Range(r).truth())
}

///|
test "Value: truth for empty range is false" {
  let r = @value.StarlarkRange::new(5L, 3L, 1L)
  assert_false(@value.Value::Range(r).truth())
}

// --- StarlarkBuiltinFunc ---

///|
test "Value: type_name for builtin function is builtin_function_or_method" {
  let f = @value.StarlarkBuiltinFunc::dispatch("len")
  assert_eq(@value.Value::Builtin(f).type_name(), "builtin_function_or_method")
}

///|
test "Value: repr for builtin function shows name" {
  let f = @value.StarlarkBuiltinFunc::dispatch("len")
  assert_eq(@value.Value::Builtin(f).repr(), "<built-in function len>")
}

///|
test "Value: truth for builtin function is always true" {
  let f = @value.StarlarkBuiltinFunc::dispatch("len")
  assert_true(@value.Value::Builtin(f).truth())
}

// --- StarlarkBoundMethod ---

///|
test "Value: type_name for bound method is builtin_function_or_method" {
  let recv = @value.Value::String(@value.StarlarkString::new("hello"))
  let m = @value.StarlarkBoundMethod::new(recv, "upper")
  assert_eq(
    @value.Value::BoundMethod(m).type_name(),
    "builtin_function_or_method",
  )
}

///|
test "Value: repr for bound method shows receiver type and method name" {
  let recv = @value.Value::String(@value.StarlarkString::new("hello"))
  let m = @value.StarlarkBoundMethod::new(recv, "upper")
  assert_eq(
    @value.Value::BoundMethod(m).repr(),
    "<built-in method upper of string value>",
  )
}

///|
test "Value: truth for bound method is always true" {
  let recv = @value.Value::None
  let m = @value.StarlarkBoundMethod::new(recv, "something")
  assert_true(@value.Value::BoundMethod(m).truth())
}

// --- freeze semantics ---

///|
test "StarlarkList: is_frozen returns false for new list" {
  let l = @value.StarlarkList::new([])
  assert_false(l.is_frozen())
}

///|
test "StarlarkList: freeze marks list as frozen" {
  let l = @value.StarlarkList::new([])
  l.freeze()
  assert_true(l.is_frozen())
}

///|
test "freeze_value: freezes a list and its mutable nested values" {
  let inner = @value.StarlarkList::new([@value.Value::Int(1N)])
  let outer = @value.StarlarkList::new([@value.Value::List(inner)])
  @value.Value::freeze(@value.Value::List(outer))
  assert_true(outer.is_frozen())
  assert_true(inner.is_frozen())
}

///|
test "freeze_value: freezes a dict and its mutable nested values" {
  let inner = @value.StarlarkList::new([])
  let d = @value.StarlarkDict::new()
  d.set(
    @value.Value::String(@value.StarlarkString::new("k")),
    @value.Value::List(inner),
  )
  |> ignore
  @value.Value::freeze(@value.Value::Dict(d))
  assert_true(d.is_frozen())
  assert_true(inner.is_frozen())
}

///|
test "freeze_value: freezes a set" {
  let s = @value.StarlarkSet::new()
  s.add(@value.Value::Int(1N)) |> ignore
  @value.Value::freeze(@value.Value::Set(s))
  assert_true(s.is_frozen())
}

///|
test "freeze_value: is idempotent on already-frozen values" {
  let l = @value.StarlarkList::new([])
  l.freeze()
  @value.Value::freeze(@value.Value::List(l))
  assert_true(l.is_frozen())
}

///|
test "freeze_value: primitives are not mutable, freeze is no-op" {
  @value.Value::freeze(@value.Value::Int(42N))
  @value.Value::freeze(
    @value.Value::String(@value.StarlarkString::new("hello")),
  )
  @value.Value::freeze(@value.Value::None)
}

///|
test "StarlarkRange: stop reports the exclusive upper bound" {
  let r = @value.StarlarkRange::new(3L, 10L, 1L)
  assert_eq(r.stop(), 10L)
}

///|
test "StarlarkRange: contains with negative step includes aligned elements" {
  let r = @value.StarlarkRange::new(10L, 0L, -2L)
  assert_true(r.contains(10L))
  assert_true(r.contains(8L))
  assert_true(r.contains(2L))
  assert_false(r.contains(9L))
  assert_false(r.contains(1L))
  assert_false(r.contains(0L))
}

///|
test "StarlarkRange: contains treats a zero-step range as having no elements, guarding against a constructor precondition violation" {
  let r = @value.StarlarkRange::new(0L, 10L, 0L)
  assert_false(r.contains(0L))
  assert_false(r.contains(5L))
}

// --- StarlarkFunction::new reflection API (no bytecode) ---

///|
test "StarlarkFunction::new: globals returns empty map when no module is bound" {
  let f = @value.StarlarkFunction::new(
    "f",
    @errors.Position::new("<test>", 1, 0),
  )
  assert_eq(f.globals().length(), 0)
}

///|
test "StarlarkFunction::new: defining_module returns None when no module is bound" {
  let f = @value.StarlarkFunction::new(
    "f",
    @errors.Position::new("<test>", 1, 0),
  )
  assert_true(f.defining_module() is None)
}

///|
test "StarlarkFunction::new: doc returns empty string when no bytecode is present" {
  let f = @value.StarlarkFunction::new(
    "f",
    @errors.Position::new("<test>", 1, 0),
  )
  assert_eq(f.doc(), "")
}

///|
test "StarlarkFunction::new: has_varargs returns false when no bytecode is present" {
  let f = @value.StarlarkFunction::new(
    "f",
    @errors.Position::new("<test>", 1, 0),
  )
  assert_false(f.has_varargs())
}

///|
test "StarlarkFunction::new: has_kwargs returns false when no bytecode is present" {
  let f = @value.StarlarkFunction::new(
    "f",
    @errors.Position::new("<test>", 1, 0),
  )
  assert_false(f.has_kwargs())
}

///|
test "StarlarkFunction::new: num_params returns 0 when no bytecode is present" {
  let f = @value.StarlarkFunction::new(
    "f",
    @errors.Position::new("<test>", 1, 0),
  )
  assert_eq(f.num_params(), 0)
}

///|
test "StarlarkFunction::new: num_kwonly_params returns 0 when no bytecode is present" {
  let f = @value.StarlarkFunction::new(
    "f",
    @errors.Position::new("<test>", 1, 0),
  )
  assert_eq(f.num_kwonly_params(), 0)
}

///|
test "StarlarkFunction::new: num_free_vars returns 0 when no bytecode is present" {
  let f = @value.StarlarkFunction::new(
    "f",
    @errors.Position::new("<test>", 1, 0),
  )
  assert_eq(f.num_free_vars(), 0)
}

///|
test "StarlarkFunction::new: free_var returns None when no bytecode is present" {
  let f = @value.StarlarkFunction::new(
    "f",
    @errors.Position::new("<test>", 1, 0),
  )
  assert_true(f.free_var(0) is None)
}
