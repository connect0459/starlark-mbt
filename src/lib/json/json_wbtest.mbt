///|
fn call_decode(
  pos : Array[@value.Value],
  kw : Array[(String, @value.Value)],
) -> Result[@value.Value, String] {
  let decode_fn = make_decode_fn()
  guard decode_fn is @value.Value::Builtin(bf)
  let dummy_ctx = @value.BuiltinCallCtx::new(fn(_callee, _args, _kwargs) {
    Err("not called")
  })
  match bf.call_body(dummy_ctx, pos, kw) {
    Some(r) => r
    None => Err("no body")
  }
}

///|
fn call_encode(
  pos : Array[@value.Value],
  kw : Array[(String, @value.Value)],
) -> Result[@value.Value, String] {
  let encode_fn = make_encode_fn()
  guard encode_fn is @value.Value::Builtin(bf)
  let dummy_ctx = @value.BuiltinCallCtx::new(fn(_callee, _args, _kwargs) {
    Err("not called")
  })
  match bf.call_body(dummy_ctx, pos, kw) {
    Some(r) => r
    None => Err("no body")
  }
}

///|
fn call_indent(
  pos : Array[@value.Value],
  kw : Array[(String, @value.Value)],
) -> Result[@value.Value, String] {
  let indent_fn = make_indent_fn()
  guard indent_fn is @value.Value::Builtin(bf)
  let dummy_ctx = @value.BuiltinCallCtx::new(fn(_callee, _args, _kwargs) {
    Err("not called")
  })
  match bf.call_body(dummy_ctx, pos, kw) {
    Some(r) => r
    None => Err("no body")
  }
}

///|
test "make_encode_fn: unexpected keyword arguments error is separate from arity error" {
  let int_arg = @value.Value::Int(BigInt::from_int(1))
  let result = call_encode([int_arg], [
    ("foo", @value.Value::Int(BigInt::from_int(2))),
  ])
  match result {
    Err(msg) => assert_eq(msg, "json.encode: unexpected keyword arguments")
    Ok(v) => fail("expected error for kwargs, got: \{v.repr()}")
  }
}

///|
test "make_encode_fn: arity error when zero positional args" {
  let result = call_encode([], [])
  match result {
    Err(msg) => assert_eq(msg, "json.encode: got 0 arguments, want 1")
    Ok(v) => fail("expected arity error, got: \{v.repr()}")
  }
}

///|
test "make_decode_fn: surplus positional args rejected with count and limit" {
  let str_arg = @value.Value::String(@value.StarlarkString::new("1"))
  let int_arg = @value.Value::Int(BigInt::from_int(2))
  let result = call_decode([str_arg, int_arg, int_arg], [])
  match result {
    Err(msg) => assert_eq(msg, "json.decode: got 3 arguments, want at most 2")
    Ok(v) => fail("expected error for 3 positional args, got: \{v.repr()}")
  }
}

///|
test "make_decode_fn: unknown kwarg rejected" {
  let str_arg = @value.Value::String(@value.StarlarkString::new("[1]"))
  let result = call_decode([str_arg], [
    ("foo", @value.Value::Int(BigInt::from_int(2))),
  ])
  match result {
    Err(msg) =>
      assert_eq(msg, "json.decode: unexpected keyword argument \"foo\"")
    Ok(v) => fail("expected error for unknown kwarg, got: \{v.repr()}")
  }
}

///|
test "make_decode_fn: unknown kwarg rejected even alongside valid default kwarg" {
  let str_arg = @value.Value::String(@value.StarlarkString::new("[1]"))
  let result = call_decode([str_arg], [
    ("default", @value.Value::Int(BigInt::from_int(9))),
    ("foo", @value.Value::Int(BigInt::from_int(2))),
  ])
  match result {
    Err(msg) =>
      assert_eq(msg, "json.decode: unexpected keyword argument \"foo\"")
    Ok(v) => fail("expected error for unknown kwarg, got: \{v.repr()}")
  }
}

///|
test "make_decode_fn: wrong type for positional x gives for-parameter message" {
  let result = call_decode([@value.Value::Int(BigInt::from_int(2))], [])
  match result {
    Err(msg) =>
      assert_eq(msg, "json.decode: for parameter x: got int, want string")
    Ok(v) => fail("expected type error, got: \{v.repr()}")
  }
}

///|
test "make_decode_fn: x kwarg with wrong type gives for-parameter message" {
  let result = call_decode([], [("x", @value.Value::Int(BigInt::from_int(2)))])
  match result {
    Err(msg) =>
      assert_eq(msg, "json.decode: for parameter x: got int, want string")
    Ok(v) => fail("expected type error, got: \{v.repr()}")
  }
}

///|
test "make_decode_fn: x string-kwarg is rejected as positional-only" {
  let result = call_decode([], [
    ("x", @value.Value::String(@value.StarlarkString::new("1"))),
  ])
  match result {
    Err(msg) => assert_eq(msg, "json.decode: unexpected keyword argument x")
    Ok(v) => fail("expected error, got: \{v.repr()}")
  }
}

///|
test "make_decode_fn: unknown kwarg after x-string-kwarg is detected first" {
  let result = call_decode([], [
    ("x", @value.Value::String(@value.StarlarkString::new("1"))),
    ("foo", @value.Value::Int(BigInt::from_int(1))),
  ])
  match result {
    Err(msg) =>
      assert_eq(msg, "json.decode: unexpected keyword argument \"foo\"")
    Ok(v) => fail("expected error, got: \{v.repr()}")
  }
}

///|
test "make_decode_fn: no args gives missing-argument message matching go format" {
  let result = call_decode([], [])
  match result {
    Err(msg) => assert_eq(msg, "json.decode: missing argument for x")
    Ok(v) => fail("expected error, got: \{v.repr()}")
  }
}

///|
test "make_decode_fn: default kwarg clashes with second positional arg" {
  let str_arg = @value.Value::String(@value.StarlarkString::new("[1]"))
  let result = call_decode([str_arg, @value.Value::Int(BigInt::from_int(5))], [
    ("default", @value.Value::Int(BigInt::from_int(9))),
  ])
  match result {
    Err(msg) =>
      assert_eq(
        msg, "json.decode: got multiple values for keyword argument \"default\"",
      )
    Ok(v) => fail("expected error for duplicate default, got: \{v.repr()}")
  }
}

///|
test "make_decode_fn: positional type error precedes unknown kwarg error" {
  let result = call_decode([@value.Value::Int(BigInt::from_int(2))], [
    ("foo", @value.Value::Int(BigInt::from_int(3))),
  ])
  match result {
    Err(msg) =>
      assert_eq(msg, "json.decode: for parameter x: got int, want string")
    Ok(v) => fail("expected type error, got: \{v.repr()}")
  }
}

///|
test "make_encode_indent_fn: unknown keyword argument name is double-quoted" {
  let fn_val = make_encode_indent_fn()
  guard fn_val is @value.Value::Builtin(bf)
  let dummy_ctx = @value.BuiltinCallCtx::new(fn(_callee, _args, _kwargs) {
    Err("not called")
  })
  let arg = @value.Value::String(@value.StarlarkString::new("{}"))
  let result = bf.call_body(dummy_ctx, [arg], [
    ("bogus", @value.Value::String(@value.StarlarkString::new("x"))),
  ])
  match result {
    Some(Err(msg)) =>
      assert_eq(
        msg, "json.encode_indent: unexpected keyword argument \"bogus\"",
      )
    Some(Ok(v)) => fail("expected error, got: \{v.repr()}")
    None => fail("expected Some result")
  }
}

///|
test "make_indent_fn: unknown keyword argument name is double-quoted" {
  let fn_val = make_indent_fn()
  guard fn_val is @value.Value::Builtin(bf)
  let dummy_ctx = @value.BuiltinCallCtx::new(fn(_callee, _args, _kwargs) {
    Err("not called")
  })
  let arg = @value.Value::String(@value.StarlarkString::new("{}"))
  let result = bf.call_body(dummy_ctx, [arg], [
    ("bogus", @value.Value::String(@value.StarlarkString::new("x"))),
  ])
  match result {
    Some(Err(msg)) =>
      assert_eq(msg, "json.indent: unexpected keyword argument \"bogus\"")
    Some(Ok(v)) => fail("expected error, got: \{v.repr()}")
    None => fail("expected Some result")
  }
}

///|
test "make_indent_fn: indent keyword parameter name is double-quoted in type error" {
  let result = call_indent(
    [@value.Value::String(@value.StarlarkString::new("{}"))],
    [("indent", @value.Value::Int(BigInt::from_int(1)))],
  )
  match result {
    Err(msg) =>
      assert_eq(
        msg, "json.indent: for parameter \"indent\": got int, want string",
      )
    Ok(v) => fail("expected error, got: \{v.repr()}")
  }
}

///|
test "make_indent_fn: prefix keyword parameter name is double-quoted in type error" {
  let result = call_indent(
    [@value.Value::String(@value.StarlarkString::new("{}"))],
    [("prefix", @value.Value::Int(BigInt::from_int(1)))],
  )
  match result {
    Err(msg) =>
      assert_eq(
        msg, "json.indent: for parameter \"prefix\": got int, want string",
      )
    Ok(v) => fail("expected error, got: \{v.repr()}")
  }
}

///|
test "make_indent_fn: keyword type error is checked before positional arity" {
  let result = call_indent(
    [
      @value.Value::Int(BigInt::from_int(1)),
      @value.Value::Int(BigInt::from_int(2)),
    ],
    [("indent", @value.Value::Int(BigInt::from_int(3)))],
  )
  match result {
    Err(msg) =>
      assert_eq(
        msg, "json.indent: for parameter \"indent\": got int, want string",
      )
    Ok(v) => fail("expected error, got: \{v.repr()}")
  }
}

///|
test "make_indent_fn: positional type error uses for-parameter-N wording" {
  let result = call_indent([@value.Value::Int(BigInt::from_int(123))], [])
  match result {
    Err(msg) =>
      assert_eq(msg, "json.indent: for parameter 1: got int, want string")
    Ok(v) => fail("expected error, got: \{v.repr()}")
  }
}

///|
test "make_indent_fn: indent_json errors are prefixed with json.indent:" {
  let indent_fn = make_indent_fn()
  guard indent_fn is @value.Value::Builtin(bf)
  let dummy_ctx = @value.BuiltinCallCtx::new(fn(_callee, _args, _kwargs) {
    Err("not called")
  })
  let arg = @value.Value::String(@value.StarlarkString::new("]"))
  let result = bf.call_body(dummy_ctx, [arg], [])
  match result {
    Some(Err(msg)) => assert_true(msg.has_prefix("json.indent: "))
    Some(Ok(v)) => fail("expected error, got: \{v.repr()}")
    None => fail("expected Some result")
  }
}

///|
test "make_indent_fn: does not reject syntactically-valid but Float64-overflowing number tokens" {
  let indent_fn = make_indent_fn()
  guard indent_fn is @value.Value::Builtin(bf)
  let dummy_ctx = @value.BuiltinCallCtx::new(fn(_callee, _args, _kwargs) {
    Err("not called")
  })
  let arg = @value.Value::String(@value.StarlarkString::new("[1e999]"))
  let result = bf.call_body(dummy_ctx, [arg], [])
  match result {
    Some(Ok(@value.Value::String(_))) => ()
    Some(Ok(v)) => fail("expected string, got \{v.repr()}")
    Some(Err(e)) => fail("expected success, got error: \{e}")
    None => fail("expected Some result")
  }
}

///|
test "parse_json_value: array at depth limit returns nesting error" {
  let chars = "[".to_array()
  match parse_json_value(chars, 0, json_max_nesting_depth) {
    Err((_, msg)) => assert_eq(msg, "nesting depth limit exceeded")
    Ok(_) => fail("expected nesting depth error at limit")
  }
}

///|
test "parse_json_value: object at depth limit returns nesting error" {
  let chars = "{".to_array()
  match parse_json_value(chars, 0, json_max_nesting_depth) {
    Err((_, msg)) => assert_eq(msg, "nesting depth limit exceeded")
    Ok(_) => fail("expected nesting depth error at limit")
  }
}

///|
test "parse_json_value: leaf values at depth limit succeed" {
  let cases : Array[(String, String)] = [
    ("\"hello\"", "string"),
    ("42", "number"),
    ("null", "null"),
    ("true", "bool"),
  ]
  for pair in cases {
    let (src, label) = pair
    match parse_json_value(src.to_array(), 0, json_max_nesting_depth) {
      Ok(_) => ()
      Err(_) => fail("\{label} at depth limit should succeed")
    }
  }
}

///|
test "encode_inner: list at depth limit returns nesting error" {
  let state = EncodeState::new()
  let v = @value.Value::List(@value.StarlarkList::new([]))
  match encode_inner(v, state, json_max_nesting_depth) {
    Err(e) => assert_eq(e, "nesting depth limit exceeded")
    Ok(_) => fail("expected nesting depth error at limit")
  }
}

///|
test "encode_inner: dict at depth limit returns nesting error" {
  let state = EncodeState::new()
  let d = @value.StarlarkDict::new()
  let _ = d.set(
    @value.Value::String(@value.StarlarkString::new("k")),
    @value.Value::None,
  )
  match encode_inner(@value.Value::Dict(d), state, json_max_nesting_depth) {
    Err(e) => assert_eq(e, "nesting depth limit exceeded")
    Ok(_) => fail("expected nesting depth error at limit")
  }
}

///|
test "encode_inner: primitives at depth limit succeed" {
  let state = EncodeState::new()
  assert_true(
    encode_inner(@value.Value::None, state, json_max_nesting_depth) is Ok(_),
  )
  assert_true(
    encode_inner(
      @value.Value::Int(BigInt::from_int(42)),
      state,
      json_max_nesting_depth,
    )
    is Ok(_),
  )
}

///|
test "decode_from_json: depth error is wrapped with json.decode prefix" {
  let chars = "[".to_array()
  guard parse_json_value(chars, 0, json_max_nesting_depth) is Err((offset, raw))
  let expected = "json.decode: at offset \{offset}, \{raw}"
  assert_eq(expected, "json.decode: at offset 0, nesting depth limit exceeded")
}

///|
test "encode_to_json: depth error is wrapped with json.encode prefix" {
  let state = EncodeState::new()
  let v = @value.Value::List(@value.StarlarkList::new([]))
  guard encode_inner(v, state, json_max_nesting_depth) is Err(raw)
  let expected = "json.encode: \{raw}"
  assert_eq(expected, "json.encode: nesting depth limit exceeded")
}

///|
test "str_lex_cmp: supplementary codepoints sort after all BMP characters" {
  assert_true(str_lex_cmp("\u{E000}", "\u{FFFF}") < 0)
  assert_true(str_lex_cmp("\u{FFFF}", "\u{10000}") < 0)
  assert_true(str_lex_cmp("\u{E000}", "\u{10000}") < 0)
  assert_true(str_lex_cmp("\u{10000}", "\u{E000}") > 0)
  assert_true(str_lex_cmp("\u{10000}", "\u{10001}") < 0)
}
