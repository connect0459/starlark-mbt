// Integration tests derived from json.star.

///|
let json_encode_basics_src : String =
  #|load("assert.star", "assert")
  #|load("json.star", "json")
  #|
  #|assert.eq(json.encode(None), "null")
  #|assert.eq(json.encode(True), "true")
  #|assert.eq(json.encode(False), "false")
  #|assert.eq(json.encode(-123), "-123")
  #|assert.eq(json.encode(3.539537889086625e+24), "3.539537889086625e+24")
  #|assert.eq(json.encode(12.345e67), "1.2345e+68")
  #|assert.eq(json.encode("hello"), '"hello"')
  #|assert.eq(json.encode([1, 2, 3]), "[1,2,3]")
  #|assert.eq(json.encode((1, 2, 3)), "[1,2,3]")
  #|assert.eq(json.encode(range(3)), "[0,1,2]")
  #|assert.eq(json.encode(dict(x = 1, y = "two")), '{"x":1,"y":"two"}')
  #|assert.eq(json.encode(dict(y = "two", x = 1)), '{"x":1,"y":"two"}')

///|
test "json.star: encode basic values" {
  let errs = run_star_string(json_encode_basics_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let json_encode_float_format_src : String =
  #|load("assert.star", "assert")
  #|load("json.star", "json")
  #|# json.encode formats floats with Go's shortest-'g', not Double.to_string
  #|assert.eq(json.encode(1234567.0), "1.234567e+06")
  #|assert.eq(json.encode(1e-7), "1e-07")
  #|assert.eq(json.encode(-0.0), "-0.0")
  #|assert.eq(json.encode(100.0), "100.0")

///|
test "json.star: encode formats floats with Go shortest-g" {
  let errs = run_star_string(json_encode_float_format_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let json_indent_validates_src : String =
  #|load("assert.star", "assert")
  #|load("json.star", "json")
  #|# json.indent and encode_indent validate their JSON / argument types
  #|assert.fails(lambda: json.indent('{"a" 1}'), "json.indent")
  #|assert.fails(lambda: json.indent('truex'), "json.indent")
  #|assert.fails(lambda: json.encode_indent(1, prefix = 5), "json.encode_indent: for parameter prefix: got int, want string")
  #|assert.fails(lambda: json.indent("{}", indent = 5), "json.indent: for parameter indent: got int, want string")

///|
test "json.star: indent validates input and argument types" {
  let errs = run_star_string(json_indent_validates_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let json_encode_errors_src : String =
  #|load("assert.star", "assert")
  #|load("json.star", "json")
  #|
  #|def encode_error(expr, error):
  #|    assert.fails(lambda: json.encode(expr), error)
  #|
  #|encode_error(float("NaN"), "json.encode: cannot encode non-finite float nan")
  #|encode_error({1: "two"}, "dict has int key, want string")
  #|encode_error(len, "cannot encode builtin_function_or_method as JSON")
  #|encode_error({1: 2}, 'dict has int key, want string')

///|
test "json.star: encode non-encodable values raise errors" {
  let errs = run_star_string(json_encode_errors_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let json_encode_cycles_src : String =
  #|load("assert.star", "assert")
  #|load("json.star", "json")
  #|
  #|def encode_error(expr, error):
  #|    assert.fails(lambda: json.encode(expr), error)
  #|
  #|recursive_map = {}
  #|recursive_map["r"] = recursive_map
  #|encode_error(recursive_map, 'json.encode: in dict key "r": cycle in JSON structure')
  #|
  #|recursive_list = []
  #|recursive_list.append(recursive_list)
  #|encode_error(recursive_list, 'json.encode: at list index 0: cycle in JSON structure')
  #|
  #|recursive_tuple = (1, 2, [])
  #|recursive_tuple[2].append(recursive_tuple)
  #|encode_error(recursive_tuple, 'json.encode: at tuple index 2: at list index 0: cycle in JSON structure')

///|
test "json.star: encode detects cycles in lists, dicts, tuples" {
  let errs = run_star_string(json_encode_cycles_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let json_encode_indent_src : String =
  #|load("assert.star", "assert")
  #|load("json.star", "json")
  #|
  #|assert.eq(
  #|    json.encode_indent({"x": 1, "y": ["one", "two"]}, prefix="¶", indent="–––"),
  #|    json.indent(json.encode({"x": 1, "y": ["one", "two"]}), prefix="¶", indent="–––")
  #|)
  #|assert.eq(
  #|    json.encode_indent({"x": 1, "y": ["one", "two"]}),
  #|    json.indent(json.encode({"x": 1, "y": ["one", "two"]}), prefix="", indent="\t")
  #|)
  #|assert.fails(lambda: json.encode_indent('foo', 'bar'), 'json.encode_indent: got 2 arguments, want 1')
  #|
  #|recursive_map = {}
  #|recursive_map["r"] = recursive_map
  #|assert.fails(lambda: json.encode_indent(recursive_map), 'in dict key "r": cycle in JSON structure')

///|
test "json.star: encode_indent is consistent with indent(encode(...))" {
  let errs = run_star_string(json_encode_indent_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let json_decode_basics_src : String =
  #|load("assert.star", "assert")
  #|load("json.star", "json")
  #|
  #|assert.eq(json.decode("null"), None)
  #|assert.eq(json.decode("true"), True)
  #|assert.eq(json.decode("false"), False)
  #|assert.eq(json.decode("-123"), -123)
  #|assert.eq(json.decode("-0"), 0)
  #|assert.eq(json.decode("3.539537889086625e+24"), 3.539537889086625e+24)
  #|assert.eq(json.decode("0e+1"), 0.0)
  #|assert.eq(json.decode("-0.0"), -0.0)
  #|assert.eq(json.decode('[]'), [])
  #|assert.eq(json.decode('[1]'), [1])
  #|assert.eq(json.decode('[1,2,3]'), [1, 2, 3])
  #|assert.eq(json.decode('{"one": 1, "two": 2}'), dict(one=1, two=2))
  #|assert.eq(json.decode('{"foo\\u0000bar": 42}'), {"foo\x00bar": 42})
  #|assert.eq(json.decode('"\\ud83d\\ude39\\ud83d\\udc8d"'), "😹💍")
  #|assert.eq(json.decode('"\\u0123"'), 'ģ')
  #|assert.eq(json.decode('"\x7f"'), "\x7f")

///|
test "json.star: decode basic JSON values" {
  let errs = run_star_string(json_decode_basics_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let json_decode_errors_src : String =
  #|load("assert.star", "assert")
  #|load("json.star", "json")
  #|
  #|def decode_error(expr, error):
  #|    assert.fails(lambda: json.decode(expr), error)
  #|
  #|decode_error('truefalse', "json.decode: at offset 4, unexpected character 'f' after value")
  #|decode_error('"abc', "unclosed string literal")
  #|decode_error('"ab\\gc"', "invalid.*escape")
  #|decode_error("'abc'", "unexpected character")
  #|decode_error("1.2.3", "invalid number: 1.2.3")
  #|decode_error("+1", "unexpected character '\\+'")
  #|decode_error("-abc", "invalid number: -")
  #|decode_error("-", "invalid number: -")
  #|decode_error("-00", "invalid number: -00")
  #|decode_error("00", "invalid number: 00")
  #|decode_error("--1", "invalid number: --1")
  #|decode_error("-+1", "invalid number: -\\+1")
  #|decode_error("1e1e1", "invalid number: 1e1e1")
  #|decode_error("0123", "invalid number: 0123")
  #|decode_error("000.123", "invalid number: 000.123")
  #|decode_error("-0123", "invalid number: -0123")
  #|decode_error("-000.123", "invalid number: -000.123")
  #|decode_error("0x123", "unexpected character 'x' after value")
  #|decode_error('[1, 2 ', "unexpected end of file")
  #|decode_error('[1, 2, ', "unexpected end of file")
  #|decode_error('[1, 2, ]', "unexpected character ']'")
  #|decode_error('[1, 2, }', "unexpected character '}'")
  #|decode_error('[1, 2}', "got '}', want ',' or ']'")
  #|decode_error('{"one": 1', "unexpected end of file")
  #|decode_error('{"one" 1', "after object key, got '1', want ':'")
  #|decode_error('{"one": 1 "two": 2', "in object, got '\"', want ',' or '}'")
  #|decode_error('{"one": 1,', "unexpected end of file")
  #|decode_error('{"one": 1, }', "unexpected character '}'")
  #|decode_error('{"one": 1]', "in object, got ']', want ',' or '}'")

///|
test "json.star: decode rejects malformed JSON with descriptive errors" {
  let errs = run_star_string(json_decode_errors_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let json_decode_default_src : String =
  #|load("assert.star", "assert")
  #|load("json.star", "json")
  #|
  #|assert.eq(json.decode('{"valid": "json"}', default = "default value"), {"valid": "json"})
  #|assert.eq(json.decode('{"valid": "json"}', "default value"), {"valid": "json"})
  #|assert.eq(json.decode('{"invalid": "json"', default = "default value"), "default value")
  #|assert.eq(json.decode('{"invalid": "json"', "default value"), "default value")
  #|assert.eq(json.decode('{"invalid": "json"', default = None), None)
  #|assert.eq(json.decode('{"invalid": "json"', None), None)
  #|assert.fails(
  #|    lambda: json.decode(x = '{"invalid": "json"', default = "default value"),
  #|    "unexpected keyword argument x"
  #|)

///|
test "json.star: decode with default falls back on invalid JSON" {
  let errs = run_star_string(json_decode_default_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let json_roundtrip_src : String =
  #|load("assert.star", "assert")
  #|load("json.star", "json")
  #|
  #|def codec(x):
  #|    return json.decode(json.encode(x))
  #|
  #|strings = [
  #|    "😿",
  #|    "🐱‍👤",
  #|]
  #|assert.eq(codec(strings), strings)
  #|
  #|numbers = [
  #|    0, 1, -1, 1.23e45, -1.23e-45,
  #|    float(1.0),
  #|]
  #|def number_roundtrip():
  #|    show = lambda n: (n, type(n))
  #|    for n in numbers:
  #|      assert.eq(show(codec(n)), show(n))
  #|number_roundtrip()

///|
test "json.star: encode/decode round-trip preserves strings and numbers" {
  let errs = run_star_string(json_roundtrip_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let json_indent_src : String =
  #|load("assert.star", "assert")
  #|load("json.star", "json")
  #|
  #|s = json.encode(dict(x = 1, y = ["one", "two"]))
  #|
  #|assert.eq(json.indent(s), '''{
  #|	"x": 1,
  #|	"y": [
  #|		"one",
  #|		"two"
  #|	]
  #|}''')
  #|
  #|assert.eq(json.decode(json.indent(s)), {"x": 1, "y": ["one", "two"]})
  #|
  #|assert.eq(json.indent(s, prefix='¶', indent='–––'), '''{
  #|¶–––"x": 1,
  #|¶–––"y": [
  #|¶––––––"one",
  #|¶––––––"two"
  #|¶–––]
  #|¶}''')
  #|
  #|assert.fails(lambda: json.indent("!@#$%^& this is not json"), 'invalid character')

///|
test "json.star: indent pretty-prints JSON with prefix and indent" {
  let errs = run_star_string(json_indent_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let json_encode_struct_src : String =
  #|load("assert.star", "assert")
  #|load("json.star", "json")
  #|load("struct.star", "struct")
  #|
  #|assert.eq(json.encode(struct(x=1, y="two")), '{"x":1,"y":"two"}')
  #|assert.eq(json.encode(struct(y="two", x=1)), '{"x":1,"y":"two"}')
  #|
  #|def encode_error(expr, error):
  #|    assert.fails(lambda: json.encode(expr), error)
  #|
  #|encode_error(struct(x=[1, {"x": len}]),
  #|             'in field .x: at list index 1: in dict key "x": cannot encode')

///|
test "json.star: encode struct/HasAttrs as JSON object" {
  let errs = run_star_string(json_encode_struct_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let json_bigint_src : String =
  #|load("assert.star", "assert")
  #|load("json.star", "json")
  #|
  #|assert.eq(json.encode(12345*12345*12345*12345*12345*12345), "3539537889086624823140625")
  #|assert.eq(json.decode("3539537889086624823140625"), 3539537889086624823140625)

///|
test "json.star: BigInt encode and decode" {
  let errs = run_star_string(json_bigint_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let json_dir_src : String =
  #|load("assert.star", "assert")
  #|load("json.star", "json")
  #|
  #|assert.eq(dir(json), ["decode", "encode", "encode_indent", "indent"])

///|
test "json.star: dir(json) lists all exported names in sorted order" {
  let errs = run_star_string(json_dir_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let json_invalid_utf8_src : String =
  #|load("assert.star", "assert")
  #|load("json.star", "json")
  #|
  #|assert.contains(['"\\ufffd"', '"�"'], json.encode("😹"[:1]))

///|
test "json.star: encode invalid UTF-8 bytes produces replacement char" {
  let errs = run_star_string(json_invalid_utf8_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let json_bigint_float_decode_src : String =
  #|load("assert.star", "assert")
  #|load("json.star", "json")
  #|
  #|assert.eq(json.decode("3539537889086624823140625.0"), float(3539537889086624823140625))

///|
test "json.star: decode large integer-valued float literal to Float" {
  let errs = run_star_string(json_bigint_float_decode_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let json_tiny_float_decode_src : String =
  #|load("assert.star", "assert")
  #|load("json.star", "json")
  #|
  #|assert.eq(
  #|    json.decode("-0.000000000000000000000000000000000000000000000000000000000000000000000000000001"),
  #|    -0.000000000000000000000000000000000000000000000000000000000000000000000000000001)

///|
test "json.star: decode very small negative float with long mantissa" {
  let errs = run_star_string(json_tiny_float_decode_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let json_roundtrip_extended_src : String =
  #|load("assert.star", "assert")
  #|load("json.star", "json")
  #|
  #|def codec(x):
  #|    return json.decode(json.encode(x))
  #|
  #|numbers = [
  #|    0, 1, -1, +1, 1.23e45, -1.23e-45,
  #|    3539537889086624823140625,
  #|    float(3539537889086624823140625),
  #|    float(1.0),
  #|]
  #|def number_roundtrip():
  #|    show = lambda n: (n, type(n))
  #|    for n in numbers:
  #|      assert.eq(show(codec(n)), show(n))
  #|number_roundtrip()

///|
test "json.star: number round-trip with BigInt and float(BigInt)" {
  let errs = run_star_string(json_roundtrip_extended_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let json_codepoint_roundtrip_src : String =
  #|load("assert.star", "assert")
  #|load("json.star", "json")
  #|
  #|def codec(x):
  #|    return json.decode(json.encode(x))
  #|
  #|codepoints = ''.join(['%c' % c for c in range(65536)])
  #|assert.eq(codec(codepoints), codepoints)

///|
test "json.star: every 16-bit codepoint survives JSON encode/decode round-trip" {
  let errs = run_star_string(json_codepoint_roundtrip_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}
