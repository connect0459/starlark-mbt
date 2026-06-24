///|
test "decode_utf8_lossy keeps valid UTF-8 unchanged" {
  // "hello, 世界"
  let valid = b"hello, \xE4\xB8\x96\xE7\x95\x8C"
  assert_eq(decode_utf8_lossy(valid), "hello, 世界")
}

///|
test "decode_utf8_lossy replaces a truncated sequence byte by byte" {
  // "hello, 世界" with the final byte removed leaves "世" followed by the first
  // two bytes (0xE7 0x95) of "界". Go decodes each as a separate error byte,
  // yielding two U+FFFD, unlike the WHATWG maximal-subpart rule (one U+FFFD).
  let truncated = b"hello, \xE4\xB8\x96\xE7\x95"
  assert_eq(decode_utf8_lossy(truncated), "hello, 世\u{FFFD}\u{FFFD}")
}

///|
test "decode_utf8_lossy replaces an unpaired surrogate encoding" {
  let b = b"\xED\xB0\x80"
  assert_eq(decode_utf8_lossy(b), "\u{FFFD}\u{FFFD}\u{FFFD}")
}

///|
test "is_valid_utf8 accepts valid UTF-8" {
  // "hello, 世界"
  let valid = b"hello, \xE4\xB8\x96\xE7\x95\x8C"
  assert_true(is_valid_utf8(valid))
}

///|
test "is_valid_utf8 rejects a truncated sequence" {
  // "世界" with the final byte removed.
  let truncated = b"\xE4\xB8\x96\xE7\x95"
  assert_false(is_valid_utf8(truncated))
}

///|
test "is_valid_utf8 rejects an unpaired surrogate encoding" {
  let b = b"\xED\xB0\x80"
  assert_false(is_valid_utf8(b))
}

///|
test "utf16_decode_cp: BMP character returns code unit as codepoint and step 1" {
  let s = "\u{FFFF}"
  assert_true(utf16_decode_cp(s, 0, s.length()) == (0xFFFF, 1))
}

///|
test "utf16_decode_cp: supplementary character returns combined codepoint and step 2" {
  assert_true(utf16_decode_cp("\u{10000}", 0, 2) == (0x10000, 2))
  assert_true(utf16_decode_cp("\u{10001}", 0, 2) == (0x10001, 2))
  assert_true(utf16_decode_cp("\u{10FFFF}", 0, 2) == (0x10FFFF, 2))
}

///|
test "utf16_decode_cp: lone high surrogate at end of string returns raw code unit and step 1" {
  let s = "\u{10000}"
  assert_true(utf16_decode_cp(s, 0, 1) == (0xD800, 1))
}

///|
test "utf16_decode_cp: len larger than string length does not read past the end" {
  let s = "\u{FFFF}"
  assert_true(utf16_decode_cp(s, 0, s.length() + 10) == (0xFFFF, 1))
}

///|
test "printability: ASCII control characters are not printable" {
  // C0 controls below U+0020 and DEL (U+007F) are non-printable.
  assert_false(is_unicode_printable(0x00))
  assert_false(is_unicode_printable(0x1F))
  assert_false(is_unicode_printable(0x7F))
}

///|
test "printability: visible ASCII characters are printable" {
  // Space and the rest of printable ASCII (U+0020..U+007E) are printable.
  assert_true(is_unicode_printable(0x20))
  assert_true(is_unicode_printable('A'.to_int()))
  assert_true(is_unicode_printable(0x7E))
}

///|
test "printability: C1 controls and no-break space are not printable" {
  assert_false(is_unicode_printable(0x80))
  assert_false(is_unicode_printable(0x9F))
  assert_false(is_unicode_printable(0xA0))
}

///|
test "printability: soft hyphen is not printable" {
  assert_false(is_unicode_printable(0xAD))
}

///|
test "printability: line and paragraph separators are not printable" {
  assert_false(is_unicode_printable(0x2028))
  assert_false(is_unicode_printable(0x2029))
}

///|
test "printability: bidirectional and zero-width format characters are not printable" {
  // Zero-width and directional marks (U+200B..U+200F).
  assert_false(is_unicode_printable(0x200B))
  assert_false(is_unicode_printable(0x200F))
  // Explicit bidi embedding/override controls (U+202A..U+202E).
  assert_false(is_unicode_printable(0x202A))
  assert_false(is_unicode_printable(0x202E))
  // Word joiner and invisible math operators (U+2060..U+2064).
  assert_false(is_unicode_printable(0x2060))
  assert_false(is_unicode_printable(0x2064))
  // Bidi isolate controls and deprecated format chars (U+2066..U+206F).
  assert_false(is_unicode_printable(0x2066))
  assert_false(is_unicode_printable(0x206F))
}

///|
test "printability: byte-order mark and interlinear annotation marks are not printable" {
  assert_false(is_unicode_printable(0xFEFF))
  assert_false(is_unicode_printable(0xFFF9))
  assert_false(is_unicode_printable(0xFFFB))
}

///|
test "printability: noncharacters are not printable" {
  // BMP sentinel noncharacters.
  assert_false(is_unicode_printable(0xFFFE))
  assert_false(is_unicode_printable(0xFFFF))
  // The contiguous noncharacter block U+FDD0..U+FDEF.
  assert_false(is_unicode_printable(0xFDD0))
  assert_false(is_unicode_printable(0xFDEF))
}

///|
test "printability: private-use areas are not printable" {
  // BMP private-use area.
  assert_false(is_unicode_printable(0xE000))
  assert_false(is_unicode_printable(0xF8FF))
  // Supplementary private-use planes.
  assert_false(is_unicode_printable(0xF0000))
}

///|
test "printability: ordinary letters and symbols above ASCII are printable" {
  assert_true(is_unicode_printable(0xE9)) // é
  assert_true(is_unicode_printable(0x4E16)) // 世
  assert_true(is_unicode_printable(0x1F600)) // 😀
}

///|
test "is_decimal_digit: ASCII digits 0-9 are decimal digits" {
  assert_true(is_decimal_digit(0x0030)) // 0
  assert_true(is_decimal_digit(0x0039)) // 9
}

///|
test "is_decimal_digit: ASCII letters and non-digits are not decimal digits" {
  assert_false(is_decimal_digit(0x0041)) // A
  assert_false(is_decimal_digit(0x0061)) // a
  assert_false(is_decimal_digit(0x00B2)) // superscript 2 (No, not Nd)
}

///|
test "is_decimal_digit: Arabic-Indic digits (U+0660-U+0669) are decimal digits" {
  assert_true(is_decimal_digit(0x0660)) // ARABIC-INDIC DIGIT ZERO
  assert_true(is_decimal_digit(0x0661)) // ARABIC-INDIC DIGIT ONE
  assert_true(is_decimal_digit(0x0669)) // ARABIC-INDIC DIGIT NINE
}

///|
test "is_decimal_digit: Kirat Rai digits start at U+16D70, not U+16D60" {
  assert_true(is_decimal_digit(0x16D70)) // KIRAT RAI DIGIT ZERO
  assert_true(is_decimal_digit(0x16D79)) // KIRAT RAI DIGIT NINE
  assert_false(is_decimal_digit(0x16D60)) // KIRAT RAI LETTER KA (Lo, not Nd)
  assert_false(is_decimal_digit(0x16D69)) // KIRAT RAI VOWEL SIGN AA (Mc, not Nd)
}
