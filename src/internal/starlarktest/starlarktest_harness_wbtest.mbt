// Whitebox tests for the ### annotation matching harness.

///|
test "pattern_matches: backslash-escaped dot matches only literal dot" {
  assert_true(pattern_matches("a\\.b", "a.b"))
  assert_true(!pattern_matches("a\\.b", "axb"))
}

///|
test "pattern_matches: bare dot is a single-char wildcard" {
  assert_true(pattern_matches("a.b", "axb"))
  assert_true(pattern_matches("a.b", "a.b"))
}

///|
test "pattern_matches: escaped dot in the middle of a wildcard pattern" {
  assert_true(pattern_matches("foo\\.bar.*baz", "foo.bar: baz"))
  assert_true(!pattern_matches("foo\\.bar.*baz", "fooxbar: baz"))
}

///|
test "effective_pattern_length: counts text chars consumed, not raw chars" {
  // "a\\.b" is 4 raw chars but matches 3 text chars
  assert_eq(effective_pattern_length("a\\.b".to_array()), 3)
  // "abc" is 3 raw chars and matches 3 text chars
  assert_eq(effective_pattern_length("abc".to_array()), 3)
  // "\\.\\." is 4 raw chars but matches 2 text chars
  assert_eq(effective_pattern_length("\\.\\.".to_array()), 2)
}

///|
test "pattern_matches: anchor-end with escaped dot" {
  assert_true(pattern_matches("int\\.float$", "got int.float"))
  assert_true(!pattern_matches("int\\.float$", "got int_float"))
}
