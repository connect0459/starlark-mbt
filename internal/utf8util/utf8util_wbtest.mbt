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
