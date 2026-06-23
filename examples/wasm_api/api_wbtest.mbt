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
  assert_eq(
    value_to_json(@value.Value::Float(@double.not_a_number)),
    "\"nan\"",
  )
}

///|
test "value_to_json: positive Inf falls back to repr string" {
  assert_eq(
    value_to_json(@value.Value::Float(@double.infinity)),
    "\"+inf\"",
  )
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
