///|
fn str_val(s : String) -> @value.Value {
  @value.Value::String(@value.StarlarkString::new(s))
}

///|
fn int_val(n : Int64) -> @value.Value {
  @value.Value::Int(BigInt::from_int64(n))
}

///|
fn float_val(f : Double) -> @value.Value {
  @value.Value::Float(f)
}

///|
fn list_val(items : Array[@value.Value]) -> @value.Value {
  @value.Value::List(@value.StarlarkList::new(items))
}

///|
fn check_encode(v : @value.Value, expected : String) -> Unit raise Error {
  match encode_to_json(v) {
    Ok(s) => assert_eq(s, expected)
    Err(e) => fail("encode failed: \{e}")
  }
}

///|
fn check_encode_err(
  v : @value.Value,
  expected_substr : String,
) -> Unit raise Error {
  match encode_to_json(v) {
    Ok(s) => fail("expected encode error, got: \{s}")
    Err(e) =>
      if !e.contains(expected_substr) {
        fail("encode error mismatch: \{e} (want substring: \{expected_substr})")
      }
  }
}

///|
fn check_indent(
  input : String,
  prefix : String,
  indent_str : String,
  expected : String,
) -> Unit raise Error {
  match indent_json(input, prefix, indent_str) {
    Ok(s) => assert_eq(s, expected)
    Err(e) => fail("indent failed: \{e}")
  }
}

///|
fn assert_decode(
  json_str : String,
  expected : @value.Value,
  msg : String,
) -> Unit raise Error {
  match decode_from_json(json_str, None) {
    Err(e) => fail("decode \{json_str} failed: \{e}")
    Ok(v) =>
      if !v.starlark_equals(expected) {
        fail(
          "decode \{json_str}: \{msg}: got \{v.repr()}, want \{expected.repr()}",
        )
      }
  }
}

///|
test "encode None as null" {
  check_encode(@value.Value::None, "null")
}

///|
test "encode true and false" {
  check_encode(@value.Value::Bool(true), "true")
  check_encode(@value.Value::Bool(false), "false")
}

///|
test "encode integer" {
  check_encode(int_val(-123L), "-123")
  check_encode(int_val(0L), "0")
  check_encode(int_val(42L), "42")
}

///|
test "encode float" {
  check_encode(float_val(12.345e67), "1.2345e+68")
  check_encode(float_val(0.0), "0.0")
  check_encode(float_val(-0.0), "-0.0")
  check_encode(float_val(1.0), "1.0")
}

///|
test "encode float rejects NaN and Inf" {
  check_encode_err(
    float_val(@double.not_a_number),
    "cannot encode non-finite float nan",
  )
  check_encode_err(
    float_val(@double.infinity),
    "cannot encode non-finite float +inf",
  )
  check_encode_err(
    float_val(@double.neg_infinity),
    "cannot encode non-finite float -inf",
  )
}

///|
test "encode string with escaping" {
  check_encode(str_val("hello"), "\"hello\"")
  check_encode(str_val("a\"b"), "\"a\\\"b\"")
  check_encode(str_val("a\\b"), "\"a\\\\b\"")
  check_encode(str_val("\n\t\r"), "\"\\n\\t\\r\"")
}

///|
test "encode list" {
  check_encode(list_val([int_val(1L), int_val(2L), int_val(3L)]), "[1,2,3]")
  check_encode(list_val([]), "[]")
}

///|
test "encode tuple" {
  check_encode(
    @value.Value::Tuple([int_val(1L), int_val(2L), int_val(3L)]),
    "[1,2,3]",
  )
}

///|
test "encode dict with sorted string keys" {
  let d = @value.StarlarkDict::new()
  let _ = d.set(str_val("y"), str_val("two"))
  let _ = d.set(str_val("x"), int_val(1L))
  check_encode(@value.Value::Dict(d), "{\"x\":1,\"y\":\"two\"}")
}

///|
test "encode dict sorts keys lexicographically not by length" {
  let d = @value.StarlarkDict::new()
  let _ = d.set(str_val("b"), int_val(1L))
  let _ = d.set(str_val("aa"), int_val(2L))
  check_encode(@value.Value::Dict(d), "{\"aa\":2,\"b\":1}")
}

///|
test "encode ExtVal attrs sorts keys lexicographically not by length" {
  let cv = @value.CustomValue::new(fn() { "myobj" }, fn() { true }, fn() {
    "myobj()"
  }).with_attrs(
    fn(name) {
      match name {
        "b" => Ok(Some(int_val(1L)))
        "aa" => Ok(Some(int_val(2L)))
        _ => Ok(None)
      }
    },
    fn() { ["b", "aa"] },
  )
  check_encode(@value.Value::ExtVal(cv), "{\"aa\":2,\"b\":1}")
}

///|
test "encode dict rejects non-string keys" {
  let d = @value.StarlarkDict::new()
  let _ = d.set(int_val(1L), str_val("two"))
  check_encode_err(@value.Value::Dict(d), "dict has int key, want string")
}

///|
test "encode range" {
  let r = @value.StarlarkRange::new(0L, 3L, 1L)
  check_encode(@value.Value::Range(r), "[0,1,2]")
}

///|
test "encode unrepresentable type returns error" {
  let bf : @value.Value = @value.Value::Builtin(
    @value.StarlarkBuiltinFunc::dispatch("len"),
  )
  check_encode_err(bf, "cannot encode builtin_function_or_method as JSON")
}

///|
test "encode set with a single element produces a single-element JSON array" {
  let s = @value.StarlarkSet::new()
  s.add(@value.Value::Int(42N)) |> ignore
  match encode_to_json(@value.Value::Set(s)) {
    Ok(json) => assert_eq(json, "[42]")
    Err(e) => fail("encode set failed: \{e}")
  }
}

///|
test "encode empty set produces an empty JSON array" {
  let s = @value.StarlarkSet::new()
  check_encode(@value.Value::Set(s), "[]")
}

///|
test "decode null" {
  assert_decode("null", @value.Value::None, "null")
}

///|
test "decode booleans" {
  assert_decode("true", @value.Value::Bool(true), "true")
  assert_decode("false", @value.Value::Bool(false), "false")
}

///|
test "decode integer" {
  assert_decode("-123", int_val(-123L), "-123")
  assert_decode("0", int_val(0L), "0")
}

///|
test "decode float" {
  assert_decode("1.5", float_val(1.5), "1.5")
  assert_decode("0e+1", float_val(0.0), "0e+1")
}

///|
test "decode negative zero float" {
  match decode_from_json("-0.0", None) {
    Err(e) => fail("decode -0.0 failed: \{e}")
    Ok(v) =>
      match v {
        @value.Value::Float(f) =>
          if !(f == -0.0 && 1.0 / f == @double.neg_infinity) {
            fail("expected -0.0, got \{f}")
          }
        _ => fail("expected Float, got \{v.repr()}")
      }
  }
}

///|
test "decode string" {
  assert_decode("\"hello\"", str_val("hello"), "plain string")
  assert_decode("\"\\n\\t\"", str_val("\n\t"), "escaped string")
}

///|
test "decode surrogate pairs" {
  assert_decode("\"\\ud83d\\ude39\"", str_val("😹"), "surrogate pair emoji")
}

///|
test "decode array" {
  assert_decode(
    "[1,2,3]",
    list_val([int_val(1L), int_val(2L), int_val(3L)]),
    "[1,2,3]",
  )
  assert_decode("[]", list_val([]), "[]")
}

///|
test "decode with default on invalid input" {
  match decode_from_json("{bad json", Some(str_val("fallback"))) {
    Ok(v) =>
      if !v.starlark_equals(str_val("fallback")) {
        fail("expected fallback, got \{v.repr()}")
      }
    Err(e) => fail("expected default, got error: \{e}")
  }
}

///|
test "decode rejects trailing content" {
  assert_true(decode_from_json("truefalse", None) is Err(_))
}

///|
test "decode rejects invalid numbers" {
  assert_true(decode_from_json("00", None) is Err(_))
  assert_true(decode_from_json("1.2.3", None) is Err(_))
  assert_true(decode_from_json("-00", None) is Err(_))
}

///|
test "decode rejects truncated unicode escape with fewer than four hex digits" {
  assert_true(decode_from_json("\"\\u00\"", None) is Err(_))
}

///|
test "decode rejects unicode escape containing non-hex characters" {
  assert_true(decode_from_json("\"\\uGGGG\"", None) is Err(_))
}

///|
test "indent_json pretty-prints with tab" {
  let input = "{\"x\":1,\"y\":[\"one\",\"two\"]}"
  let expected =
    #|{
    #|	"x": 1,
    #|	"y": [
    #|		"one",
    #|		"two"
    #|	]
    #|}
  check_indent(input, "", "\t", expected)
}

///|
test "indent_json with custom prefix and indent" {
  let input = "{\"a\":1}"
  let expected =
    #|{
    #|>>--"a": 1
    #|>>}
  check_indent(input, ">>", "--", expected)
}

///|
test "indent_json empty object and array" {
  check_indent("{}", "", "  ", "{}")
  check_indent("[]", "", "  ", "[]")
}

///|
test "indent_json rejects invalid JSON" {
  assert_true(indent_json("!invalid", "", "\t") is Err(_))
}

///|
test "encode ExtVal with attrs as JSON object" {
  let cv = @value.CustomValue::new(fn() { "myobj" }, fn() { true }, fn() {
    "myobj(x=1, y=\"two\")"
  }).with_attrs(
    fn(name) {
      match name {
        "x" => Ok(Some(int_val(1L)))
        "y" => Ok(Some(str_val("two")))
        _ => Ok(None)
      }
    },
    fn() { ["x", "y"] },
  )
  check_encode(@value.Value::ExtVal(cv), "{\"x\":1,\"y\":\"two\"}")
}

///|
test "encode ExtVal with attrs uses sorted key order" {
  let cv = @value.CustomValue::new(fn() { "myobj" }, fn() { true }, fn() {
    "myobj()"
  }).with_attrs(
    fn(name) {
      match name {
        "y" => Ok(Some(str_val("two")))
        "x" => Ok(Some(int_val(1L)))
        _ => Ok(None)
      }
    },
    fn() { ["y", "x"] },
  )
  check_encode(@value.Value::ExtVal(cv), "{\"x\":1,\"y\":\"two\"}")
}

///|
test "encode ExtVal without attrs raises error" {
  let cv = @value.CustomValue::new(fn() { "opaque" }, fn() { true }, fn() {
    "opaque()"
  })
  check_encode_err(@value.Value::ExtVal(cv), "cannot encode opaque as JSON")
}

///|
test "encode ExtVal field error propagates with field name prefix" {
  let cv = @value.CustomValue::new(fn() { "myobj" }, fn() { true }, fn() {
    "myobj()"
  }).with_attrs(
    fn(name) {
      match name {
        "bad" => Ok(Some(@value.Value::Float(@double.not_a_number)))
        _ => Ok(None)
      }
    },
    fn() { ["bad"] },
  )
  check_encode_err(@value.Value::ExtVal(cv), "in field .bad:")
}

///|
test "encode then decode round-trips values" {
  let values : Array[@value.Value] = [
    @value.Value::None,
    @value.Value::Bool(true),
    @value.Value::Bool(false),
    int_val(42L),
    int_val(-1L),
    float_val(1.5),
    str_val("hello"),
    list_val([int_val(1L), int_val(2L)]),
  ]
  for v in values {
    match encode_to_json(v) {
      Ok(json_str) =>
        match decode_from_json(json_str, None) {
          Ok(decoded) =>
            if !v.starlark_equals(decoded) {
              fail("round-trip failed for \{v.repr()}: got \{decoded.repr()}")
            }
          Err(e) => fail("decode failed for \{v.repr()}: \{e}")
        }
      Err(e) => fail("encode failed for \{v.repr()}: \{e}")
    }
  }
}

///|
test "encode dict reports the first non-string key when several are present" {
  // Once a non-string key is seen the encoder stops scanning further keys, so
  // the reported error reflects the first offending key only. Keys of distinct
  // types are inserted so the error type distinguishes "first key" from "any
  // non-string key"; dicts iterate in insertion order, so the float comes first.
  let d = @value.StarlarkDict::new()
  let _ = d.set(float_val(1.0), str_val("one"))
  let _ = d.set(int_val(2L), str_val("two"))
  check_encode_err(@value.Value::Dict(d), "dict has float key, want string")
}

///|
test "encode surfaces an attribute that dir() advertises but cannot be read" {
  let unreadable = @value.Value::ExtVal(
    @value.CustomValue::new(fn() { "widget" }, fn() { true }, fn() {
      "widget()"
    }).with_attrs(fn(_name) { Err("boom") }, fn() { ["x"] }),
  )
  check_encode_err(unreadable, "cannot access attribute widget.x: boom")
}

///|
test "encode surfaces an advertised attribute that resolves to nothing" {
  let missing = @value.Value::ExtVal(
    @value.CustomValue::new(fn() { "widget" }, fn() { true }, fn() {
      "widget()"
    }).with_attrs(fn(_name) { Ok(None) }, fn() { ["x"] }),
  )
  check_encode_err(missing, "missing attribute widget.x")
}
