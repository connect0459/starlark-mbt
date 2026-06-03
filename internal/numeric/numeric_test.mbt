///|
test "floor_div with positive operands divides toward the quotient" {
  assert_true(@numeric.floor_div(7N, 2N) == Ok(3N))
  assert_true(@numeric.floor_div(6N, 2N) == Ok(3N))
}

///|
test "floor_div truncates toward negative infinity" {
  // -7 // 2 = -4 (not -3)
  assert_true(@numeric.floor_div(-7N, 2N) == Ok(-4N))
  // 7 // -2 = -4 (not -3)
  assert_true(@numeric.floor_div(7N, -2N) == Ok(-4N))
  // -7 // -2 = 3
  assert_true(@numeric.floor_div(-7N, -2N) == Ok(3N))
}

///|
test "floor_div by zero is an error" {
  assert_true(@numeric.floor_div(7N, 0N) is Err(_))
}

///|
test "starlark_mod result has the same sign as the divisor" {
  // positive % positive
  assert_true(@numeric.starlark_mod(7N, 2N) == Ok(1N))
  // negative dividend, positive divisor: result is positive
  assert_true(@numeric.starlark_mod(-7N, 2N) == Ok(1N))
  // positive dividend, negative divisor: result is negative
  assert_true(@numeric.starlark_mod(7N, -2N) == Ok(-1N))
  // negative % negative
  assert_true(@numeric.starlark_mod(-7N, -2N) == Ok(-1N))
}

///|
test "starlark_mod by zero is an error" {
  assert_true(@numeric.starlark_mod(7N, 0N) is Err(_))
}

///|
test "format_float switches to scientific notation at magnitude 1e6" {
  // Go's strconv FormatFloat 'g' uses %e once the decimal exponent reaches 6.
  assert_eq(@numeric.format_float(9999999.9), "9.9999999e+06")
  assert_eq(@numeric.format_float(1234567.8), "1.2345678e+06")
  assert_eq(@numeric.format_float(1200000.5), "1.2000005e+06")
  assert_eq(@numeric.format_float(-9999999.9), "-9.9999999e+06")
}

///|
test "format_float keeps decimal form below magnitude 1e6" {
  assert_eq(@numeric.format_float(123456.7), "123456.7")
  assert_eq(@numeric.format_float(100000.0), "100000.0")
}
