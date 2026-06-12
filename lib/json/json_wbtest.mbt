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
