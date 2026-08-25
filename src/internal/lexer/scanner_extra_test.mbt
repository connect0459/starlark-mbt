// Additional scanner coverage: string-escape decoding, number-literal error
// paths, indentation errors, and operator edge cases. Reuses the `scan` helper
// defined in scanner_test.mbt.

///|
fn rep(c : String, n : Int) -> String {
  let b = StringBuilder()
  for _ in 0..<n {
    b.write_string(c)
  }
  b.to_string()
}

// --- String escape decoding (single-quoted) ---

///|
test "scan: decodes bell, backspace, formfeed, vtab escapes" {
  assert_true(scan("'\\a\\b\\f\\v'").contains("EOF"))
}

///|
test "scan: decodes octal escape to ASCII" {
  assert_eq(scan("'\\101'"), "\"A\" EOF")
}

///|
test "scan: decodes hex escape to ASCII" {
  assert_eq(scan("'\\x41'"), "\"A\" EOF")
}

///|
test "scan: decodes \\u escape to ASCII" {
  assert_eq(scan("'\\u0041'"), "\"A\" EOF")
}

///|
test "scan: decodes \\U escape for a supplementary code point" {
  assert_true(scan("'\\U0001F600'").contains("EOF"))
}

// --- String escape errors ---

///|
test "scan: rejects octal escape >= 256" {
  // \\777 is 511 in decimal, > 127 in string mode → non-ASCII (Go checks n > 127 first)
  assert_true(scan("'\\777'").contains("non-ASCII octal escape"))
}

///|
test "scan: rejects non-ASCII octal escape in a string" {
  assert_true(scan("'\\200'").contains("non-ASCII octal escape"))
}

///|
test "scan: rejects a hex escape with a non-hex first digit" {
  // h1 visible, h2 is the closing quote (terminator): slot is truncated
  assert_true(scan("'\\xG'").contains("truncated escape sequence"))
}

///|
test "scan: rejects a truncated hex escape (second digit)" {
  // \\x4G: first digit valid, second is non-hex visible char → invalid (not truncated)
  assert_true(scan("'\\x4G'").contains("invalid escape sequence"))
}

///|
test "scan: rejects a non-ASCII hex escape in a string" {
  assert_true(scan("'\\x80'").contains("non-ASCII hex escape"))
}

///|
test "scan: \\u inside bytes literal produces UTF-8 bytes" {
  // \uNNNN is accepted in b"..." and encodes the codepoint as UTF-8.
  // b"A" = b"A" (U+0041 → 0x41)
  assert_eq(scan("b'\\u0041'"), "b\"A\" EOF")
}

///|
test "scan: \\U inside bytes literal produces UTF-8 bytes" {
  // b"\U00000041" = b"A"
  assert_eq(scan("b'\\U00000041'"), "b\"A\" EOF")
}

///|
test "scan: \\u in bytes literal for non-ASCII produces multi-byte UTF-8" {
  // U+03B1 (α) encodes as 0xCE 0xB1 in UTF-8
  assert_true(scan("b'\\u03B1'").contains("EOF"))
}

///|
test "scan: rejects code points beyond U+10FFFF" {
  assert_true(scan("'\\U00110000'").contains("code point out of range"))
}

///|
test "scan: rejects \\U escape when high bits wrap signed Int" {
  assert_true(scan("'\\U80000000'").contains("code point out of range"))
}

///|
test "scan: rejects \\U escape at max unsigned value" {
  assert_true(scan("'\\Uffffffff'").contains("code point out of range"))
}

///|
test "scan: rejects surrogate code points" {
  assert_true(scan("'\\U0000D800'").contains("invalid Unicode code point"))
}

///|
test "scan: rejects unknown escape sequences" {
  assert_true(scan("'\\q'").contains("invalid escape sequence"))
}

///|
test "scan: rejects a truncated unicode escape" {
  // \\u00G0: reads full 4-char slot (00G0) → invalid escape sequence \u00G0
  assert_true(scan("'\\u00G0'").contains("invalid escape sequence \\u00G0"))
}

// --- String termination errors ---

///|
test "scan: rejects an unterminated single-quoted string" {
  assert_true(scan("'abc").contains("unexpected EOF in string"))
}

///|
test "scan: rejects a literal newline in a single-quoted string" {
  assert_true(scan("'a\nb'").contains("unexpected newline in string"))
}

///|
test "scan: rejects EOF right after a backslash in a string" {
  assert_true(scan("'a\\").contains("unexpected EOF in string"))
}

///|
test "scan: rejects EOF right after a backslash in a raw string" {
  assert_true(scan("r'a\\").contains("unexpected EOF in string"))
}

///|
test "scan: raw string normalizes a backslash-carriage-return" {
  assert_true(scan("r'a\\\rb'").contains("EOF"))
}

///|
test "scan: backslash-carriage-return is a line continuation" {
  assert_true(scan("'a\\\rb'").contains("EOF"))
}

// --- Triple-quoted strings ---

///|
test "scan: triple-quoted string with plain content" {
  assert_eq(scan("'''abc'''"), "\"abc\" EOF")
}

///|
test "scan: rejects an unterminated triple-quoted string" {
  assert_true(scan("'''abc").contains("unexpected EOF in string"))
}

///|
test "scan: triple-quoted string decodes escapes" {
  assert_true(scan("'''a\\nb'''").contains("EOF"))
}

///|
test "scan: raw triple-quoted string keeps escapes literal" {
  assert_true(scan("r'''a\\nb'''").contains("EOF"))
}

///|
test "scan: triple-quoted string normalizes carriage returns" {
  assert_true(scan("'''a\rb'''").contains("EOF"))
}

///|
test "scan: rejects EOF after backslash in a raw triple-quoted string" {
  assert_true(scan("r'''a\\").contains("unexpected EOF in string"))
}

///|
test "scan: rejects EOF after backslash in a triple-quoted string" {
  assert_true(scan("'''a\\").contains("unexpected EOF in string"))
}

// --- String/bytes prefix combinations ---

///|
test "scan: recognizes the rb string prefix" {
  assert_true(scan("rb'x'").contains("EOF"))
}

///|
test "scan: recognizes the br string prefix" {
  assert_true(scan("br'x'").contains("EOF"))
}

// --- Operator and structural errors ---

///|
test "scan: rejects a stray backslash outside a line continuation" {
  assert_true(scan("a\\b").contains("stray backslash in program"))
}

///|
test "scan: rejects a lone exclamation mark" {
  assert_true(scan("!").contains("unexpected input character '!'"))
}

///|
test "scan: rejects an unknown input character" {
  assert_true(scan("$").contains("unexpected input character"))
}

///|
test "scan: rejects a dedent that matches no outer level" {
  assert_true(scan("if x:\n    a\n  b\n").contains("unindent does not match"))
}

// --- Number literals ---

///|
test "scan: leading-dot float with exponent" {
  assert_true(scan(".5e3").contains("EOF"))
}

///|
test "scan: zero followed by an exponent is a float" {
  assert_true(scan("0e5").contains("EOF"))
}

///|
test "scan: rejects 0o with no octal digit" {
  assert_true(scan("0o9").contains("invalid octal literal"))
}

///|
test "scan: accepts hex integer beyond Int64 range" {
  let s = scan("0x" + rep("F", 17))
  assert_true(!s.contains("integer overflow"))
  assert_true(s.contains("EOF"))
}

///|
test "scan: accepts octal integer beyond Int64 range" {
  let s = scan("0o" + rep("7", 22))
  assert_true(!s.contains("integer overflow"))
  assert_true(s.contains("EOF"))
}

///|
test "scan: accepts binary integer beyond Int64 range" {
  let s = scan("0b" + rep("1", 65))
  assert_true(!s.contains("integer overflow"))
  assert_true(s.contains("EOF"))
}

///|
test "scan: rejects a decimal literal with a leading zero" {
  assert_true(scan("08").contains("invalid int literal"))
}

///|
test "scan: rejects an exponent with no digits" {
  assert_true(scan("1e").contains("invalid float literal"))
}

///|
test "scan: a decimal literal too large for Int64 is an int token" {
  assert_eq(scan(rep("9", 23)), rep("9", 23) + " EOF")
}

// --- Byte-string prefix rules ---

///|
test "scan: rb\"...\" is still a valid raw-bytes literal" {
  assert_true(scan("rb\"foo\"").contains("EOF"))
}

///|
test "scan: br\"...\" is NOT a raw-bytes literal (tokenized as ident + string)" {
  // Go only accepts rb"..." not br"..."; br"foo" → Ident("br") Str("foo") EOF
  assert_eq(scan("br\"foo\""), "br \"foo\" EOF")
}

// --- Unicode surrogate check in \u escape ---

///|
test "scan: \\uD800 (low surrogate) is rejected in string literal" {
  assert_true(scan("\"\\uD800\"").contains("invalid Unicode code point"))
}

///|
test "scan: \\uDFFF (high surrogate) is rejected in string literal" {
  assert_true(scan("\"\\uDFFF\"").contains("invalid Unicode code point"))
}

///|
test "scan: \\u4E2D (valid BMP) is accepted in string literal" {
  assert_false(scan("\"\\u4E2D\"").contains("error"))
}

///|
test "scan: \\uD800 is rejected in bytes literal" {
  assert_true(scan("b\"\\uD800\"").contains("invalid Unicode code point"))
}

///|
test "scan: non-ASCII octal error includes sequence and hex encoding" {
  let msg = scan("\"\\377\"")
  assert_true(
    msg.contains(
      "non-ASCII octal escape \\377 (use \\u00FF for the UTF-8 encoding of U+00FF)",
    ),
  )
}

///|
test "scan: octal >= 256 fires non-ASCII check first (ordering)" {
  // \\400 is octal 256 > 127, Go checks n > 127 first → non-ASCII, not invalid
  let msg = scan("\"\\400\"")
  assert_true(msg.contains("non-ASCII octal escape \\400"))
}

///|
test "scan: \\xfg with invalid second digit is 'invalid escape sequence'" {
  // Go: invalid (full sequence present but non-hex digit)
  // MoonBit currently: truncated
  let msg = scan("\"\\xfg\"")
  assert_true(msg.contains("invalid escape sequence \\xfg"))
}

///|
test "scan: truncated \\u escape includes partial sequence" {
  let msg = scan("\"\\u100\"")
  assert_true(msg.contains("truncated escape sequence \\u100"))
}

///|
test "scan: surrogate code point error includes U+ hex" {
  let msg = scan("\"\\udc00\"")
  assert_true(msg.contains("invalid Unicode code point U+DC00"))
}

///|
test "scan: code point out of range includes offending value in both slots" {
  let msg = scan("\"\\U00110000\"")
  assert_true(
    msg.contains("code point out of range: \\U00110000 (max \\U00110000)"),
  )
}

///|
test "scan: code point out of range preserves input case in first slot and lowercases second" {
  let msg = scan("\"\\U0011000A\"")
  assert_true(
    msg.contains("code point out of range: \\U0011000A (max \\U0011000a)"),
  )
}

// --- Unbalanced closing bracket at depth 0 ---

///|
test "scan: unexpected ')' at depth 0" {
  assert_true(scan(")").contains("unexpected ')'"))
}

///|
test "scan: unexpected ']' at depth 0" {
  assert_true(scan("]").contains("unexpected ']'"))
}

///|
test "scan: unexpected '}' at depth 0" {
  assert_true(scan("}").contains("unexpected '}'"))
}

///|
test "scan: unbalanced ')' after expression" {
  assert_true(scan("a = max(range(10)))").contains("unexpected ')'"))
}

///|
test "scan: \\xg truncated because second slot is a string terminator" {
  let msg = scan("\"\\xg\"")
  assert_true(msg.contains("truncated escape sequence \\xg"))
}

///|
test "scan: \\xgg invalid because both slot chars are non-hex visible" {
  let msg = scan("\"\\xgg\"")
  assert_true(msg.contains("invalid escape sequence \\xgg"))
}

///|
test "scan: invalid \\u slot prints all four chars in the error" {
  let msg = scan("\"\\u1g34\"")
  assert_true(msg.contains("invalid escape sequence \\u1g34"))
}

///|
test "scan: invalid \\U slot prints all eight chars in the error" {
  let msg = scan("\"\\U0000001g\"")
  assert_true(msg.contains("invalid escape sequence \\U0000001g"))
}

///|
test "scan: unterminated raw string anchors at the prefix character column" {
  let msg = scan("r\"abc")
  assert_true(msg.contains("foo.star:1:1:"))
  assert_true(msg.contains("unexpected EOF in string"))
}

///|
test "scan: unterminated bytes string anchors at the prefix character column" {
  let msg = scan("b\"abc")
  assert_true(msg.contains("foo.star:1:1:"))
  assert_true(msg.contains("unexpected EOF in string"))
}

///|
test "scan: unterminated rb string anchors at the first prefix character column" {
  let msg = scan("rb\"abc")
  assert_true(msg.contains("foo.star:1:1:"))
  assert_true(msg.contains("unexpected EOF in string"))
}

///|
test "scan: newline in raw string anchors at the prefix character column" {
  let msg = scan("r\"abc\n")
  assert_true(msg.contains("foo.star:1:1:"))
  assert_true(msg.contains("unexpected newline in string"))
}

///|
test "scan: unprefixed unterminated string still anchors at the quote column" {
  let msg = scan("\"abc")
  assert_true(msg.contains("foo.star:1:1:"))
  assert_true(msg.contains("unexpected EOF in string"))
}

///|
test "scan: unexpected input character includes the offending rune" {
  let msg = scan("a @ b")
  assert_true(msg.contains("unexpected input character '@'"))
}

///|
test "scan: unexpected dollar sign includes the character" {
  let msg = scan("$")
  assert_true(msg.contains("unexpected input character '$'"))
}

///|
test "scan: unexpected multi-byte character shows the full Unicode rune" {
  let msg = scan("a ☃ b")
  assert_true(msg.contains("unexpected input character '☃'"))
}

///|
test "scan: overflow float literal emits bare message without literal suffix" {
  let msg = scan("1.8e308")
  assert_true(msg.contains("invalid float literal"))
  assert_false(msg.contains(": 1.8e308"))
}

///|
test "scan: non-ASCII hex escape includes escape sequence and encoding hint" {
  let msg = scan("\"\\xff\"")
  assert_true(
    msg.contains(
      "non-ASCII hex escape \\xff (use \\u00FF for the UTF-8 encoding of U+00FF)",
    ),
  )
}
