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
