// Coverage for Token::to_string arms not reached by scanner error messages.

///|
test "Token::to_string renders the remaining token variants" {
  assert_eq(Illegal.to_string(), "illegal token")
  assert_eq(Newline.to_string(), "newline")
  assert_eq(Bytes(b"").to_string(), "bytes literal")
  assert_eq(Minus.to_string(), "-")
  assert_eq(Percent.to_string(), "%")
  assert_eq(Amp.to_string(), "&")
  assert_eq(Tilde.to_string(), "~")
  assert_eq(Comma.to_string(), ",")
  assert_eq(LBrack.to_string(), "[")
  assert_eq(NotIn.to_string(), "not in")
}

///|
test "count_indent expands tabs by source column" {
  let sc = Scanner::new("test.star", "\t \tx")
  assert_eq(sc.count_indent(), 15)
}

///|
test "count_indent of eight spaces then a tab is 16" {
  let sc = Scanner::new("test.star", "        \tx")
  assert_eq(sc.count_indent(), 16)
}
