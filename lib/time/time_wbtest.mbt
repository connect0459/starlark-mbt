///|
test "fmt_duration: Duration minimum value formats without double minus" {
  assert_eq(fmt_duration(-9223372036854775808L), "-2562047h47m16.854775808s")
}

///|
test "fmt_duration: Duration maximum value formats correctly" {
  assert_eq(fmt_duration(9223372036854775807L), "2562047h47m16.854775807s")
}
