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
test "symbol: __id is hidden from user-facing attribute access" {
  let sym = call_builtin(gensym_builtin(), [], [
    ("name", @value.Value::String(@value.StarlarkString::new("S"))),
  ]).unwrap()
  let c = custom_of(sym)
  assert_true(c.get_attr("__id") == Ok(None))
  assert_true(c.get_attr("anything_else") == Ok(None))
}

///|
test "symbol: __id is accessible via internal attribute accessor" {
  let sym = call_builtin(gensym_builtin(), [], [
    ("name", @value.Value::String(@value.StarlarkString::new("S"))),
  ]).unwrap()
  let c = custom_of(sym)
  assert_true(c.get_internal_attr("__id") is Ok(Some(@value.Value::Int(_))))
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
test "struct: internal __n is hidden from user-facing attribute access" {
  let s = make_struct(default_ctor, [("a", @value.Value::Int(1N))])
  let c = custom_of(s)
  assert_true(c.get_attr("__n") is Err(_))
}

///|
test "struct: internal __ctor is hidden from user-facing attribute access" {
  let s = make_struct(default_ctor, [("a", @value.Value::Int(1N))])
  let c = custom_of(s)
  assert_true(c.get_attr("__ctor") is Err(_))
}

///|
test "struct: internal __name_0 is hidden from user-facing attribute access" {
  let s = make_struct(default_ctor, [("a", @value.Value::Int(1N))])
  let c = custom_of(s)
  assert_true(c.get_attr("__name_0") is Err(_))
}

///|
test "struct: internal __val_0 is hidden from user-facing attribute access" {
  let s = make_struct(default_ctor, [("a", @value.Value::Int(1N))])
  let c = custom_of(s)
  assert_true(c.get_attr("__val_0") is Err(_))
}

///|
test "struct: out-of-range synthetic names raise attribute error" {
  let s = make_struct(default_ctor, [("a", @value.Value::Int(1N))])
  let c = custom_of(s)
  assert_true(c.get_attr("__name_99") is Err(_))
  assert_true(c.get_attr("__val_99") is Err(_))
  assert_true(c.get_attr("__name_x") is Err(_))
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
test "str_lex_cmp: supplementary codepoints sort after all BMP characters" {
  assert_true(str_lex_cmp("\u{E000}", "\u{FFFF}") < 0)
  assert_true(str_lex_cmp("\u{FFFF}", "\u{10000}") < 0)
  assert_true(str_lex_cmp("\u{E000}", "\u{10000}") < 0)
  assert_true(str_lex_cmp("\u{10000}", "\u{E000}") > 0)
  assert_true(str_lex_cmp("\u{10000}", "\u{10001}") < 0)
}

///|
test "struct: non-BMP field names sort by codepoint not UTF-16 code unit" {
  let s = make_struct(default_ctor, [
    ("\u{10000}", @value.Value::Int(1N)),
    ("\u{FFFF}", @value.Value::Int(2N)),
    ("\u{E000}", @value.Value::Int(3N)),
  ])
  assert_eq(
    custom_of(s).get_repr(),
    "struct(\u{E000} = 3, \u{FFFF} = 2, \u{10000} = 1)",
  )
}

///|
test "struct: field names are sorted lexicographically not by length" {
  let s = make_struct(default_ctor, [
    ("b", @value.Value::Int(1N)),
    ("aa", @value.Value::Int(2N)),
  ])
  assert_eq(custom_of(s).get_repr(), "struct(aa = 2, b = 1)")
}

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

///|
test "struct: depth guard does not fire at compare_limit minus one nested levels" {
  let a = make_nested_struct_val(@value.compare_limit - 1)
  let b = make_nested_struct_val(@value.compare_limit - 1)
  assert_true(
    @value.starlark_equals_depth(a, b, @value.compare_limit) is Ok(true),
  )
}

///|
test "struct: depth guard fires at exactly compare_limit nested struct levels" {
  let a = make_nested_struct_val(@value.compare_limit)
  let b = make_nested_struct_val(@value.compare_limit)
  assert_true(
    @value.starlark_equals_depth(a, b, @value.compare_limit) ==
    Err("comparison exceeded maximum recursion depth"),
  )
}

// --- hash depth threading across nested struct boundaries ---

///|
test "struct: hashing a struct with shallow values succeeds" {
  let s = make_struct(default_ctor, [("x", @value.Value::Int(1N))])
  assert_true(s.hash() is Ok(_))
}

///|
test "struct: hashing a deeply nested struct exceeding hash_limit returns a graceful error" {
  let n = @value.hash_limit + 1
  let mut v : @value.Value = @value.Value::Int(1N)
  for _ in 0..<n {
    v = make_struct(default_ctor, [("x", v)])
  }
  match v.hash() {
    Err(e) => assert_true(e.contains("maximum recursion depth"))
    Ok(_) => fail("expected depth-limit error for \{n}-deep struct nesting")
  }
}

///|
test "struct: hashing a struct nested within hash_limit succeeds" {
  let mut v : @value.Value = @value.Value::Int(1N)
  for _ in 0..<@value.hash_limit {
    v = make_struct(default_ctor, [("x", v)])
  }
  assert_true(v.hash() is Ok(_))
}
