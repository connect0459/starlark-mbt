///|
test "encode_str: plain ASCII is double-quoted" {
  assert_eq(encode_str("hello"), "\"hello\"")
}

///|
test "encode_str: empty string produces empty JSON string" {
  assert_eq(encode_str(""), "\"\"")
}

///|
test "encode_str: tab and newline use shorthand escapes" {
  assert_eq(encode_str("\t\n"), "\"\\t\\n\"")
}

///|
test "encode_str: control char below 0x20 uses unicode escape" {
  assert_eq(encode_str("\u{0001}"), "\"\\u0001\"")
}

///|
test "encode_str: printable ASCII angle brackets and ampersand pass through verbatim" {
  assert_eq(encode_str("<a>&</a>"), "\"<a>&</a>\"")
}

///|
test "value_to_json: None maps to null" {
  assert_eq(value_to_json(@value.Value::None), "null")
}

///|
test "value_to_json: Bool maps to true and false" {
  assert_eq(value_to_json(@value.Value::Bool(true)), "true")
  assert_eq(value_to_json(@value.Value::Bool(false)), "false")
}

///|
test "value_to_json: Int maps to bare JSON number" {
  assert_eq(value_to_json(@value.Value::Int(BigInt::from_int(42))), "42")
}

///|
test "value_to_json: finite Float maps to number" {
  assert_eq(value_to_json(@value.Value::Float(3.0)), "3.0")
}

///|
test "value_to_json: NaN falls back to repr string" {
  assert_eq(value_to_json(@value.Value::Float(@double.not_a_number)), "\"nan\"")
}

///|
test "value_to_json: positive Inf falls back to repr string" {
  assert_eq(value_to_json(@value.Value::Float(@double.infinity)), "\"+inf\"")
}

///|
test "value_to_json: negative Inf falls back to repr string" {
  assert_eq(
    value_to_json(@value.Value::Float(@double.neg_infinity)),
    "\"-inf\"",
  )
}

///|
test "value_to_json: String maps to JSON string" {
  assert_eq(
    value_to_json(@value.Value::String(@value.StarlarkString::new("hi"))),
    "\"hi\"",
  )
}

///|
test "value_to_json: List maps to JSON array" {
  let items : Array[@value.Value] = [
    @value.Value::Int(BigInt::from_int(1)),
    @value.Value::Int(BigInt::from_int(2)),
    @value.Value::Int(BigInt::from_int(3)),
  ]
  assert_eq(
    value_to_json(@value.Value::List(@value.StarlarkList::new(items))),
    "[1,2,3]",
  )
}

///|
test "value_to_json: Dict maps to JSON object" {
  let d = @value.StarlarkDict::new()
  let _ = d.set(
    @value.Value::String(@value.StarlarkString::new("x")),
    @value.Value::Int(BigInt::from_int(1)),
  )
  assert_eq(value_to_json(@value.Value::Dict(d)), "{\"x\":1}")
}

///|
test "value_to_json: nested List maps to nested JSON array" {
  let inner : Array[@value.Value] = [
    @value.Value::Int(BigInt::from_int(1)),
    @value.Value::Int(BigInt::from_int(2)),
  ]
  let outer : Array[@value.Value] = [
    @value.Value::List(@value.StarlarkList::new(inner)),
  ]
  assert_eq(
    value_to_json(@value.Value::List(@value.StarlarkList::new(outer))),
    "[[1,2]]",
  )
}

///|
test "parse_options_json: empty object returns default allow_set=true" {
  match parse_options_json("{}") {
    Ok(opts) => assert_eq(opts.allow_set(), true)
    Err(e) => fail("unexpected error: \{e}")
  }
}

///|
test "parse_options_json: allow_recursion true sets flag" {
  match parse_options_json("{\"allow_recursion\": true}") {
    Ok(opts) => assert_eq(opts.allow_recursion(), true)
    Err(e) => fail("unexpected error: \{e}")
  }
}

///|
test "parse_options_json: allow_set false overrides default true" {
  match parse_options_json("{\"allow_set\": false}") {
    Ok(opts) => assert_eq(opts.allow_set(), false)
    Err(e) => fail("unexpected error: \{e}")
  }
}

///|
test "parse_options_json: all nine flags are accepted" {
  let json_str = "{\"allow_set\":false,\"allow_recursion\":true,\"allow_lambda\":false,\"allow_while\":false,\"allow_bytes\":false,\"allow_float\":false,\"allow_global_reassign\":true,\"allow_top_level_control\":true,\"load_binds_globally\":true}"
  match parse_options_json(json_str) {
    Ok(opts) => {
      assert_eq(opts.allow_set(), false)
      assert_eq(opts.allow_recursion(), true)
      assert_eq(opts.allow_top_level_control(), true)
    }
    Err(e) => fail("unexpected error: \{e}")
  }
}

///|
test "parse_options_json: unknown key returns error containing the key name" {
  match parse_options_json("{\"unknown_flag\": true}") {
    Ok(_) => fail("expected error for unknown key")
    Err(e) => assert_true(e.contains("unknown_flag"))
  }
}

///|
test "parse_options_json: non-boolean value returns error mentioning key and boolean" {
  match parse_options_json("{\"allow_set\": 1}") {
    Ok(_) => fail("expected error for non-boolean value")
    Err(e) => assert_true(e.contains("allow_set") && e.contains("boolean"))
  }
}

///|
test "parse_options_json: non-object JSON returns error mentioning object" {
  match parse_options_json("[true, false]") {
    Ok(_) => fail("expected error for non-object JSON")
    Err(e) => assert_true(e.contains("object"))
  }
}

///|
test "parse_options_json: invalid JSON string returns error" {
  match parse_options_json("not-valid-json") {
    Ok(_) => fail("expected error for invalid JSON")
    Err(_) => ()
  }
}
