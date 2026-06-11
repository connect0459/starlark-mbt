///|
// Verify that parse_json_value immediately returns a depth error when called
// with depth == json_max_nesting_depth, without requiring deep recursion.
test "parse_json_value: depth at limit returns nesting error immediately" {
  let chars = "[".to_array()
  match parse_json_value(chars, 0, json_max_nesting_depth) {
    Err((_, msg)) => assert_true(msg.contains("nesting depth"))
    Ok(_) => fail("expected nesting depth error at limit")
  }
}

///|
// Verify that encode_inner immediately returns a depth error when a container
// is presented at depth == json_max_nesting_depth, without recursing.
test "encode_inner: depth at limit returns nesting error for list" {
  let state = EncodeState::new()
  let v = @value.Value::List(@value.StarlarkList::new([]))
  match encode_inner(v, state, json_max_nesting_depth) {
    Err(e) => assert_true(e.contains("nesting depth"))
    Ok(_) => fail("expected nesting depth error at limit")
  }
}

///|
test "encode_inner: depth at limit returns nesting error for dict" {
  let state = EncodeState::new()
  let d = @value.StarlarkDict::new()
  let _ = d.set(
    @value.Value::String(@value.StarlarkString::new("k")),
    @value.Value::None,
  )
  match encode_inner(@value.Value::Dict(d), state, json_max_nesting_depth) {
    Err(e) => assert_true(e.contains("nesting depth"))
    Ok(_) => fail("expected nesting depth error at limit")
  }
}

///|
// Primitives at the depth limit must NOT be rejected — only containers trigger
// the depth check.
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
