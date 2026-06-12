///|
fn custom_of(v : @value.Value) -> @value.CustomValue {
  match v {
    @value.Value::ExtVal(c) => c
    _ => abort("expected an ExtVal")
  }
}

///|
fn call_builtin(
  builtin : @value.Value,
  pos_args : Array[@value.Value],
  kw_args : Array[(String, @value.Value)],
) -> Result[@value.Value, String] {
  let ctx = @value.BuiltinCallCtx::new(fn(_v, _p, _k) {
    Err("nested calls are not exercised here")
  })
  match builtin {
    @value.Value::Builtin(f) =>
      match f.call_body(ctx, pos_args, kw_args) {
        Some(r) => r
        None => Err("builtin had no body")
      }
    _ => Err("expected a builtin")
  }
}

///|
test "gensym: positional arguments are rejected" {
  let result = call_builtin(
    gensym_builtin(),
    [@value.Value::String(@value.StarlarkString::new("x"))],
    [],
  )
  assert_true(result == Err("gensym: unexpected positional arguments"))
}

///|
test "gensym: the name keyword must be a string" {
  let result = call_builtin(gensym_builtin(), [], [
    ("name", @value.Value::Int(1N)),
  ])
  assert_true(result == Err("gensym: name must be a string"))
}

///|
test "gensym: the name keyword is required" {
  let result = call_builtin(gensym_builtin(), [], [])
  assert_true(result == Err("gensym: missing required keyword argument 'name'"))
}

///|
test "gensym: produces a callable symbol named after the keyword" {
  let sym = call_builtin(gensym_builtin(), [], [
    ("name", @value.Value::String(@value.StarlarkString::new("Point"))),
  ]).unwrap()
  let c = custom_of(sym)
  assert_eq(c.get_type_name(), "symbol")
  assert_eq(c.get_repr(), "Point")
}

///|
test "symbol: a symbol never equals a non-symbol value" {
  let sym = call_builtin(gensym_builtin(), [], [
    ("name", @value.Value::String(@value.StarlarkString::new("S"))),
  ]).unwrap()
  let c = custom_of(sym)
  assert_true(
    c.get_equals(@value.Value::Int(1N), @value.compare_limit) is Ok(false),
  )
}

///|
test "symbol: distinct symbols are unequal even with the same name" {
  let make = fn() {
    call_builtin(gensym_builtin(), [], [
      ("name", @value.Value::String(@value.StarlarkString::new("S"))),
    ]).unwrap()
  }
  let first = make()
  let second = make()
  assert_true(
    custom_of(first).get_equals(second, @value.compare_limit) is Ok(false),
  )
}

///|
test "symbol: only the synthetic __id attribute resolves" {
  let sym = call_builtin(gensym_builtin(), [], [
    ("name", @value.Value::String(@value.StarlarkString::new("S"))),
  ]).unwrap()
  let c = custom_of(sym)
  assert_true(c.get_attr("__id") is Ok(Some(@value.Value::Int(_))))
  assert_true(c.get_attr("anything_else") == Ok(None))
}

///|
test "symbol: calling a symbol with positional arguments is rejected" {
  let sym = call_builtin(gensym_builtin(), [], [
    ("name", @value.Value::String(@value.StarlarkString::new("Point"))),
  ]).unwrap()
  let c = custom_of(sym)
  let result = c.do_call([@value.Value::Int(1N)], [])
  assert_true(result == Some(Err("Point: unexpected positional arguments")))
}

///|
test "symbol: calling a symbol builds a struct tagged with that symbol" {
  let sym = call_builtin(gensym_builtin(), [], [
    ("name", @value.Value::String(@value.StarlarkString::new("Point"))),
  ]).unwrap()
  let c = custom_of(sym)
  let built = c.do_call([], [("x", @value.Value::Int(1N))]).unwrap().unwrap()
  let s = custom_of(built)
  assert_eq(s.get_type_name(), "struct")
  assert_eq(s.get_repr(), "Point(x = 1)")
}

///|
test "struct: synthetic positional accessors return None when out of range" {
  let s = make_struct(default_ctor, [("a", @value.Value::Int(1N))])
  let c = custom_of(s)
  assert_true(c.get_attr("__name_99") == Ok(None))
  assert_true(c.get_attr("__val_99") == Ok(None))
  // A non-numeric index also yields no attribute rather than an error.
  assert_true(c.get_attr("__name_x") == Ok(None))
}

///|
test "struct: a struct never equals a non-struct value" {
  let s = make_struct(default_ctor, [("a", @value.Value::Int(1N))])
  let c = custom_of(s)
  assert_true(
    c.get_equals(@value.Value::Int(1N), @value.compare_limit) is Ok(false),
  )
}

///|
test "struct: addition merges fields regardless of operand position" {
  let left = make_struct(default_ctor, [("a", @value.Value::Int(1N))])
  let right = make_struct(default_ctor, [("b", @value.Value::Int(2N))])
  // Left-operand addition (the struct is the left side of `+`).
  let from_left = custom_of(left).get_binary("+", right, true)
  assert_true(from_left is Some(Ok(_)))
  match from_left {
    Some(Ok(v)) => assert_eq(custom_of(v).get_repr(), "struct(a = 1, b = 2)")
    _ => abort("expected a merged struct")
  }
  // Right-operand addition (the struct is the right side of `+`).
  let from_right = custom_of(right).get_binary("+", left, false)
  match from_right {
    Some(Ok(v)) => assert_eq(custom_of(v).get_repr(), "struct(a = 1, b = 2)")
    _ => abort("expected a merged struct")
  }
}

///|
test "struct: adding structs with different constructors is an error" {
  let plain = make_struct(default_ctor, [("a", @value.Value::Int(1N))])
  let tagged = make_struct(
    @value.Value::String(@value.StarlarkString::new("Point")),
    [("b", @value.Value::Int(2N))],
  )
  let left = custom_of(plain).get_binary("+", tagged, true)
  assert_true(
    left ==
    Some(Err("cannot add structs of different constructors: struct + Point")),
  )
  let right = custom_of(plain).get_binary("+", tagged, false)
  assert_true(
    right ==
    Some(Err("cannot add structs of different constructors: Point + struct")),
  )
}

///|
test "struct: only the plus operator participates in binary dispatch" {
  let left = make_struct(default_ctor, [("a", @value.Value::Int(1N))])
  let right = make_struct(default_ctor, [("b", @value.Value::Int(2N))])
  assert_true(custom_of(left).get_binary("-", right, true) == None)
}

///|
test "struct: field names are sorted lexicographically not by length" {
  let s = make_struct(default_ctor, [
    ("b", @value.Value::Int(1N)),
    ("aa", @value.Value::Int(2N)),
  ])
  assert_eq(custom_of(s).get_repr(), "struct(aa = 2, b = 1)")
}

// --- struct equality with deeply nested values (M-27) ---

///|
fn make_nested_tuple_val(depth : Int) -> @value.Value {
  let mut v : @value.Value = @value.Value::Int(1N)
  for _ in 0..<depth {
    v = @value.Value::Tuple([v])
  }
  v
}

///|
test "struct: structs with same shallow value compare as equal" {
  let a = make_struct(default_ctor, [("x", @value.Value::Int(42N))])
  let b = make_struct(default_ctor, [("x", @value.Value::Int(42N))])
  assert_true(custom_of(a).get_equals(b, @value.compare_limit) is Ok(true))
}

///|
test "struct: structs with different values compare as not equal" {
  let a = make_struct(default_ctor, [("x", @value.Value::Int(1N))])
  let b = make_struct(default_ctor, [("x", @value.Value::Int(2N))])
  assert_true(custom_of(a).get_equals(b, @value.compare_limit) is Ok(false))
}

///|
test "struct: structs with values nesting beyond compare_limit propagate comparison depth error" {
  let deep = make_nested_tuple_val(@value.compare_limit + 2)
  let a = make_struct(default_ctor, [("x", deep)])
  let b = make_struct(default_ctor, [("x", deep)])
  assert_true(
    custom_of(a).get_equals(b, @value.compare_limit) ==
    Err("comparison exceeded maximum recursion depth"),
  )
}

// --- depth threading across nested ExtVal boundaries (issue #137) ---

///|
fn make_nested_struct_val(n : Int) -> @value.Value {
  let mut v : @value.Value = @value.Value::Int(1N)
  for _ in 0..<n {
    v = make_struct(default_ctor, [("x", v)])
  }
  v
}

///|
test "struct: depth guard fires when nesting exceeds compare_limit across ExtVal boundaries" {
  let deep_a = make_nested_struct_val(@value.compare_limit + 2)
  let deep_b = make_nested_struct_val(@value.compare_limit + 2)
  assert_true(
    @value.starlark_equals_depth(deep_a, deep_b, @value.compare_limit) ==
    Err("comparison exceeded maximum recursion depth"),
  )
}

///|
test "struct: structs nested within compare_limit compare correctly" {
  let a = make_nested_struct_val(3)
  let b = make_nested_struct_val(3)
  assert_true(
    @value.starlark_equals_depth(a, b, @value.compare_limit) is Ok(true),
  )
}
