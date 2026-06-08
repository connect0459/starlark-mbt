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

///|
test "format_float: numbers well below 1e-4 switch to scientific notation" {
  assert_eq(@numeric.format_float(1.0e-5), "1e-05")
  assert_eq(@numeric.format_float(1.5e-5), "1.5e-05")
  assert_eq(@numeric.format_float(-1.0e-5), "-1e-05")
}

///|
test "format_float pads single-digit exponents to two digits" {
  // Go's 'g' format always emits at least two exponent digits.
  assert_eq(@numeric.format_float(1.0e-7), "1e-07")
  assert_eq(@numeric.format_float(1.0e-6), "1e-06")
}

///|
test "format_float keeps two-or-more digit exponents intact" {
  assert_eq(@numeric.format_float(1.0e-10), "1e-10")
  assert_eq(@numeric.format_float(1.0e20), "1e+20")
  assert_eq(@numeric.format_float(1.5e22), "1.5e+22")
}

///|
test "format_float renders large values with a fractional part in scientific notation" {
  assert_eq(@numeric.format_float(1234567.5), "1.2345675e+06")
  assert_eq(@numeric.format_float(123456789012.0), "1.23456789012e+11")
}
