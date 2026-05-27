// Coverage tests for quote() escape emission and unquote() decoding paths.

// --- quote: control-character escapes ---

///|
test "quote escapes bell, backspace, formfeed, carriage-return, vtab" {
  assert_eq(quote("\u{07}", false), "\"\\a\"")
  assert_eq(quote("\u{08}", false), "\"\\b\"")
  assert_eq(quote("\u{0C}", false), "\"\\f\"")
  assert_eq(quote("\u{0D}", false), "\"\\r\"")
  assert_eq(quote("\u{0B}", false), "\"\\v\"")
}

///|
test "quote escapes non-printable ASCII control bytes as hex" {
  assert_eq(quote("\u{01}", false), "\"\\x01\"")
}

///|
test "quote emits printable non-ASCII runes verbatim without escaping" {
  // quote returns a byte-string, so equality is checked against absence of any
  // backslash escape; the rune is copied through the UTF-8 re-encoder.
  // Two-byte rune (U+03A9), three-byte rune (U+4E2D), four-byte rune (U+1F600).
  assert_false(quote("\u{03A9}", false).contains("\\"))
  assert_false(quote("\u{4E2D}", false).contains("\\"))
  assert_false(quote("\u{1F600}", false).contains("\\"))
}

///|
test "quote escapes non-printable BMP runes as \\u" {
  // U+00AD SOFT HYPHEN is non-printable; emitted as ­.
  assert_eq(quote("\u{00AD}", false), "\"\\u00ad\"")
  // U+200B ZERO WIDTH SPACE.
  assert_eq(quote("\u{200B}", false), "\"\\u200b\"")
}

///|
test "quote prefixes bytes literals with b" {
  assert_eq(quote("\u{07}", true), "b\"\\a\"")
}

// --- unquote: raw strings ---

///|
test "unquote raw string normalizes carriage returns" {
  match unquote("r\"a\rb\"") {
    Ok((s, is_bytes)) => {
      assert_eq(s, "a\nb")
      assert_eq(is_bytes, false)
    }
    Err(e) => fail("unexpected error: \{e}")
  }
}

///|
test "unquote raw string normalizes CRLF to a single newline" {
  match unquote("r\"a\r\nb\"") {
    Ok((s, _)) => assert_eq(s, "a\nb")
    Err(e) => fail("unexpected error: \{e}")
  }
}

///|
test "unquote raw string keeps backslashes literal" {
  match unquote("r\"a\\nb\"") {
    Ok((s, _)) => assert_eq(s, "a\\nb")
    Err(e) => fail("unexpected error: \{e}")
  }
}

// --- unquote: escape decoding ---

///|
test "unquote decodes octal escapes" {
  match unquote("\"\\101\\0\"") {
    Ok((s, _)) => {
      assert_eq(s.length(), 2)
      assert_eq(s[0], 'A')
    }
    Err(e) => fail("unexpected error: \{e}")
  }
}

///|
test "unquote rejects octal escape values >= 256" {
  match unquote("\"\\400\"") {
    Ok(_) => fail("expected error")
    Err(e) => assert_eq(e, "invalid octal escape: value >= 256")
  }
}

///|
test "unquote rejects non-ASCII octal escapes in string literals" {
  match unquote("\"\\200\"") {
    Ok(_) => fail("expected error")
    Err(e) => assert_eq(e, "non-ASCII octal escape")
  }
}

///|
test "unquote permits high octal escapes inside bytes literals" {
  match unquote("b\"\\200\"") {
    Ok((s, is_bytes)) => {
      assert_eq(is_bytes, true)
      ignore(s)
    }
    Err(e) => fail("unexpected error: \{e}")
  }
}

///|
test "unquote rejects unicode escapes inside bytes literals" {
  match unquote("b\"\\u0041\"") {
    Ok(_) => fail("expected error")
    Err(e) => assert_eq(e, "\\u escape not allowed in bytes literal")
  }
  match unquote("b\"\\U00000041\"") {
    Ok(_) => fail("expected error")
    Err(e) => assert_eq(e, "\\U escape not allowed in bytes literal")
  }
}

///|
test "unquote decodes \\u and \\U escapes" {
  match unquote("\"\\u03A9\"") {
    Ok((s, _)) => assert_eq(s, "\u{03A9}")
    Err(e) => fail("unexpected error: \{e}")
  }
  match unquote("\"\\U0001F600\"") {
    Ok((s, _)) => assert_eq(s, "\u{1F600}")
    Err(e) => fail("unexpected error: \{e}")
  }
}

///|
test "unquote rejects surrogate code points" {
  match unquote("\"\\uD800\"") {
    Ok(_) => fail("expected error")
    Err(e) => assert_eq(e, "invalid Unicode surrogate")
  }
  match unquote("\"\\U0000D800\"") {
    Ok(_) => fail("expected error")
    Err(e) => assert_eq(e, "invalid Unicode surrogate")
  }
}

///|
test "unquote rejects code points beyond U+10FFFF" {
  match unquote("\"\\U00110000\"") {
    Ok(_) => fail("expected error")
    Err(e) => assert_eq(e, "code point out of range")
  }
}

///|
test "unquote rejects truncated and invalid hex escapes" {
  match unquote("\"\\xZZ\"") {
    Ok(_) => fail("expected error")
    Err(e) => assert_eq(e, "invalid hex digit in escape")
  }
}

///|
test "unquote rejects unknown escape sequences" {
  match unquote("\"\\q\"") {
    Ok(_) => fail("expected error")
    Err(e) => assert_eq(e, "invalid escape sequence \\q")
  }
}

///|
test "unquote drops backslash-newline line continuations" {
  match unquote("\"a\\\nb\"") {
    Ok((s, _)) => assert_eq(s, "ab")
    Err(e) => fail("unexpected error: \{e}")
  }
}

///|
test "unquote treats bare carriage returns as newlines" {
  match unquote("\"a\rb\"") {
    Ok((s, _)) => assert_eq(s, "a\nb")
    Err(e) => fail("unexpected error: \{e}")
  }
}

///|
test "unquote decodes single-character backslash escapes" {
  match unquote("\"\\a\\b\\f\\n\\r\\t\\v\"") {
    Ok((s, _)) => {
      assert_eq(s.length(), 7)
      assert_eq(s[0], '\u{07}')
      assert_eq(s[1], '\u{08}')
      assert_eq(s[2], '\u{0C}')
      assert_eq(s[3], '\n')
      assert_eq(s[4], '\r')
      assert_eq(s[5], '\t')
      assert_eq(s[6], '\u{0B}')
    }
    Err(e) => fail("unexpected error: \{e}")
  }
}

///|
test "unquote accepts lowercase hex digits in escapes" {
  match unquote("b\"\\xab\"") {
    Ok((_, is_bytes)) => assert_eq(is_bytes, true)
    Err(e) => fail("unexpected error: \{e}")
  }
}

///|
test "unquote decodes ASCII and three-byte runes via \\u" {
  match unquote("\"\\u0041\\u4E2D\"") {
    Ok((s, _)) => assert_eq(s, "A\u{4E2D}")
    Err(e) => fail("unexpected error: \{e}")
  }
}

///|
test "unquote rejects a truncated \\x escape at end of literal" {
  match unquote("\"\\x\"") {
    Ok(_) => fail("expected error")
    Err(e) => assert_eq(e, "truncated hex escape")
  }
}

///|
test "unquote rejects invalid hex digits inside \\u and truncated \\U" {
  match unquote("\"\\u00ZZ\"") {
    Ok(_) => fail("expected error")
    Err(e) => assert_eq(e, "invalid hex digit in escape")
  }
  match unquote("\"\\U0000\"") {
    Ok(_) => fail("expected error")
    Err(e) => assert_eq(e, "truncated hex escape")
  }
}

///|
test "unquote rejects a trailing backslash escape" {
  match unquote("\"\\\"") {
    Ok(_) => fail("expected error")
    Err(e) => assert_eq(e, "truncated escape sequence at end of literal")
  }
}

///|
test "unquote drops backslash-CRLF line continuations" {
  match unquote("\"a\\\r\nb\"") {
    Ok((s, _)) => assert_eq(s, "ab")
    Err(e) => fail("unexpected error: \{e}")
  }
}

///|
test "unquote collapses non-raw CRLF to a single newline" {
  match unquote("\"a\r\nb\"") {
    Ok((s, _)) => assert_eq(s, "a\nb")
    Err(e) => fail("unexpected error: \{e}")
  }
}

// --- unquote: structural errors ---

///|
test "unquote rejects empty input" {
  match unquote("") {
    Ok(_) => fail("expected error")
    Err(e) => assert_eq(e, "string literal too short")
  }
}

///|
test "unquote rejects input without quote characters" {
  match unquote("x") {
    Ok(_) => fail("expected error")
    Err(e) => assert_eq(e, "string literal has invalid quotes")
  }
}

///|
test "unquote rejects mismatched quotes" {
  match unquote("\"abc") {
    Ok(_) => fail("expected error")
    Err(e) => assert_eq(e, "string literal has mismatched quotes")
  }
}
