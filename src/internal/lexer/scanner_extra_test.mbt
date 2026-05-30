// Additional scanner coverage: string-escape decoding, number-literal error
// paths, indentation errors, and operator edge cases. Reuses the `scan` helper
// defined in scanner_test.mbt.

///|
fn rep(c : String, n : Int) -> String {
  let b = StringBuilder::new()
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
  assert_true(scan("'\\777'").contains("invalid octal escape sequence"))
}

///|
test "scan: rejects non-ASCII octal escape in a string" {
  assert_true(scan("'\\200'").contains("non-ASCII octal escape"))
}

///|
test "scan: rejects a truncated hex escape (first digit)" {
  assert_true(scan("'\\xG'").contains("truncated escape sequence"))
}

///|
test "scan: rejects a truncated hex escape (second digit)" {
  assert_true(scan("'\\x4G'").contains("truncated escape sequence"))
}

///|
test "scan: rejects a non-ASCII hex escape in a string" {
  assert_true(scan("'\\x80'").contains("non-ASCII hex escape"))
}

///|
test "scan: \\u inside bytes literal produces UTF-8 bytes (MISSING-61)" {
  // starlark-go accepts \uNNNN in b"..." and encodes the codepoint as UTF-8.
  // b"A" = b"A" (U+0041 → 0x41)
  assert_eq(scan("b'\\u0041'"), "b\"A\" EOF")
}

///|
test "scan: \\U inside bytes literal produces UTF-8 bytes (MISSING-61)" {
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
test "scan: rejects surrogate code points" {
  assert_true(scan("'\\U0000D800'").contains("invalid Unicode surrogate"))
}

///|
test "scan: rejects unknown escape sequences" {
  assert_true(scan("'\\q'").contains("invalid escape sequence"))
}

///|
test "scan: rejects a truncated unicode escape" {
  assert_true(scan("'\\u00G0'").contains("truncated Unicode escape sequence"))
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

// --- Byte-string prefix rules (MISSING-63) ---

///|
test "scan: rb\"...\" is still a valid raw-bytes literal" {
  assert_true(scan("rb\"foo\"").contains("EOF"))
}

///|
test "scan: br\"...\" is NOT a raw-bytes literal (tokenized as ident + string)" {
  // Go only accepts rb"..." not br"..."; br"foo" → Ident("br") Str("foo") EOF
  assert_eq(scan("br\"foo\""), "br \"foo\" EOF")
}
