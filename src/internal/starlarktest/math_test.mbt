// Integration tests derived from math.star.

///|
let math_ceil_src : String =
  #|load("assert.star", "assert")
  #|load("math.star", "math")
  #|inf = float("inf")
  #|nan = float("nan")
  #|assert.eq(math.ceil(0.0), 0.0)
  #|assert.eq(math.ceil(0.4), 1.0)
  #|assert.eq(math.ceil(0.5), 1.0)
  #|assert.eq(math.ceil(1.0), 1.0)
  #|assert.eq(math.ceil(10.0), 10.0)
  #|assert.eq(math.ceil(0), 0.0)
  #|assert.eq(math.ceil(1), 1.0)
  #|assert.eq(math.ceil(10), 10.0)
  #|assert.eq(math.ceil(-0.0), 0.0)
  #|assert.eq(math.ceil(-0.4), 0.0)
  #|assert.eq(math.ceil(-0.5), 0.0)
  #|assert.eq(math.ceil(-1.0), -1.0)
  #|assert.eq(math.ceil(-10.0), -10.0)
  #|assert.eq(math.ceil(-1), -1.0)
  #|assert.eq(math.ceil(-10), -10.0)
  #|assert.eq(type(math.ceil(0)), "int")
  #|assert.eq(type(math.ceil(0.4)), "int")
  #|assert.eq(type(math.ceil(10)), "int")
  #|assert.eq(type(math.ceil(-10.0)), "int")
  #|assert.eq(type(math.ceil(-0.5)), "int")
  #|assert.fails(lambda: math.ceil(inf), "cannot convert float infinity to integer")
  #|assert.fails(lambda: math.ceil(-inf), "cannot convert float infinity to integer")
  #|assert.fails(lambda: math.ceil(nan), "cannot convert float NaN to integer")
  #|assert.fails(lambda: math.ceil("0"), "got string, want float or int")

///|
test "math.star: ceil" {
  let errs = run_star_string(math_ceil_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let math_fabs_src : String =
  #|load("assert.star", "assert")
  #|load("math.star", "math")
  #|inf = float("inf")
  #|nan = float("nan")
  #|assert.eq(math.fabs(2.0), 2.0)
  #|assert.eq(math.fabs(0.0), 0.0)
  #|assert.eq(math.fabs(-2.0), 2.0)
  #|assert.eq(math.fabs(2), 2)
  #|assert.eq(math.fabs(0), 0)
  #|assert.eq(math.fabs(-2), 2)
  #|assert.eq(math.fabs(inf), inf)
  #|assert.eq(math.fabs(-inf), inf)
  #|assert.eq(math.fabs(nan), nan)
  #|assert.fails(lambda: math.fabs("0"), "got string, want float or int")

///|
test "math.star: fabs" {
  let errs = run_star_string(math_fabs_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let math_floor_src : String =
  #|load("assert.star", "assert")
  #|load("math.star", "math")
  #|inf = float("inf")
  #|nan = float("nan")
  #|assert.eq(math.floor(0.0), 0.0)
  #|assert.eq(math.floor(0.4), 0.0)
  #|assert.eq(math.floor(0.5), 0.0)
  #|assert.eq(math.floor(1.0), 1.0)
  #|assert.eq(math.floor(10.0), 10.0)
  #|assert.eq(math.floor(-0.0), 0.0)
  #|assert.eq(math.floor(-0.4), -1.0)
  #|assert.eq(math.floor(-0.5), -1.0)
  #|assert.eq(math.floor(-1.0), -1.0)
  #|assert.eq(math.floor(-10.0), -10.0)
  #|assert.eq(type(math.floor(0)), "int")
  #|assert.eq(type(math.floor(0.4)), "int")
  #|assert.eq(type(math.floor(10)), "int")
  #|assert.eq(type(math.floor(-10.0)), "int")
  #|assert.eq(type(math.floor(-0.5)), "int")
  #|assert.fails(lambda: math.floor(inf), "cannot convert float infinity to integer")
  #|assert.fails(lambda: math.floor(-inf), "cannot convert float infinity to integer")
  #|assert.fails(lambda: math.floor(nan), "cannot convert float NaN to integer")
  #|assert.fails(lambda: math.floor("0"), "got string, want float or int")

///|
test "math.star: floor" {
  let errs = run_star_string(math_floor_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let math_mod_src : String =
  #|load("assert.star", "assert")
  #|load("math.star", "math")
  #|inf = float("inf")
  #|nan = float("nan")
  #|assert.eq(math.mod(5, 3), 2)
  #|assert.eq(math.mod(inf, 1), nan)
  #|assert.eq(math.mod(-inf, 1.0), nan)
  #|assert.eq(math.mod(nan, 1.0), nan)
  #|assert.eq(math.mod(1.0, 0.0), nan)
  #|assert.eq(math.mod(1.0, inf), 1)
  #|assert.eq(math.mod(1.0, -inf), 1)
  #|assert.eq(math.mod(1.0, nan), nan)
  #|assert.fails(lambda: math.mod("0", 1.0), "got string, want float or int")
  #|assert.fails(lambda: math.mod(1.0, "0"), "got string, want float or int")

///|
test "math.star: mod" {
  let errs = run_star_string(math_mod_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let math_pow_src : String =
  #|load("assert.star", "assert")
  #|load("math.star", "math")
  #|inf = float("inf")
  #|nan = float("nan")
  #|assert.eq(math.pow(5, 3), 125)
  #|assert.eq(math.pow(5, 0), 1)
  #|assert.eq(math.pow(5, 1), 5)
  #|assert.eq(math.pow(1, 5), 1)
  #|assert.eq(math.pow(inf, 1), inf)
  #|assert.eq(math.pow(-inf, 1.0), -inf)
  #|assert.eq(math.pow(nan, 1.0), nan)
  #|assert.eq(math.pow(1.1, inf), inf)
  #|assert.eq(math.pow(1.1, -inf), 0)
  #|assert.eq(math.pow(2.0, nan), nan)
  #|# IEEE-754 special case: pow(-1, +-Inf) == 1
  #|assert.eq(math.pow(-1.0, inf), 1.0)
  #|assert.eq(math.pow(-1.0, -inf), 1.0)
  #|assert.fails(lambda: math.pow("0", 1.0), "got string, want float or int")
  #|assert.fails(lambda: math.pow(1.0, "0"), "got string, want float or int")

///|
test "math.star: pow" {
  let errs = run_star_string(math_pow_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let math_copysign_src : String =
  #|load("assert.star", "assert")
  #|load("math.star", "math")
  #|inf = float("inf")
  #|nan = float("nan")
  #|assert.eq(math.copysign(3.2, -1), -3.2)
  #|assert.eq(math.copysign(inf, -1.0), -inf)
  #|assert.eq(math.copysign(-inf, -1), -inf)
  #|assert.eq(math.copysign(nan, -1), nan)
  #|assert.eq(math.copysign(-1, nan), 1)
  #|assert.fails(lambda: math.copysign("0", 1.0), "got string, want float or int")
  #|assert.fails(lambda: math.copysign(1.0, "0"), "got string, want float or int")

///|
test "math.star: copysign" {
  let errs = run_star_string(math_copysign_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let math_remainder_src : String =
  #|load("assert.star", "assert")
  #|load("math.star", "math")
  #|inf = float("inf")
  #|nan = float("nan")
  #|assert.eq(math.remainder(3, 5), -2)
  #|assert.eq(math.remainder(1, 0), nan)
  #|assert.eq(math.remainder(2, inf), 2)
  #|assert.eq(math.remainder(2, -inf), 2)
  #|assert.eq(math.remainder(inf, -1.0), nan)
  #|assert.eq(math.remainder(-inf, -1), nan)
  #|assert.eq(math.remainder(nan, -1), nan)
  #|assert.eq(math.remainder(-1, nan), nan)
  #|assert.fails(lambda: math.remainder("0", 1.0), "got string, want float or int")
  #|assert.fails(lambda: math.remainder(1.0, "0"), "got string, want float or int")

///|
test "math.star: remainder" {
  let errs = run_star_string(math_remainder_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let math_round_src : String =
  #|load("assert.star", "assert")
  #|load("math.star", "math")
  #|inf = float("inf")
  #|nan = float("nan")
  #|assert.eq(math.round(0.0), 0.0)
  #|assert.eq(math.round(0.4), 0.0)
  #|assert.eq(math.round(0.5), 1.0)
  #|assert.eq(math.round(0.6), 1.0)
  #|assert.eq(math.round(1.0), 1.0)
  #|assert.eq(math.round(10.0), 10.0)
  #|assert.eq(math.round(inf), inf)
  #|assert.eq(math.round(nan), nan)
  #|assert.eq(math.round(-0.4), 0.0)
  #|assert.eq(math.round(-0.5), -1.0)
  #|assert.eq(math.round(-0.6), -1.0)
  #|assert.eq(math.round(-1.0), -1.0)
  #|assert.eq(math.round(-10.0), -10.0)
  #|assert.eq(math.round(-inf), -inf)
  #|# precision near the halfway point: floor(x+0.5) would round these up wrongly
  #|assert.eq(math.round(0.49999999999999994), 0.0)
  #|assert.eq(math.round(-0.49999999999999994), -0.0)
  #|# large integral mantissa stays unchanged (no fractional part)
  #|assert.eq(math.round(4503599627370497.0), 4503599627370497.0)
  #|assert.fails(lambda: math.round("0"), "got string, want float or int")

///|
test "math.star: round" {
  let errs = run_star_string(math_round_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let math_exp_src : String =
  #|load("assert.star", "assert")
  #|load("math.star", "math")
  #|inf = float("inf")
  #|nan = float("nan")
  #|def near(got, want, threshold):
  #|  return math.fabs(got - want) < threshold
  #|assert.eq(math.exp(0.0), 1)
  #|assert.eq(math.exp(1.0), math.e)
  #|assert.true(near(math.exp(2.0), math.e * math.e, 0.00000000000001))
  #|assert.eq(math.exp(-1.0), 1 / math.e)
  #|assert.eq(math.exp(0), 1)
  #|assert.eq(math.exp(1), math.e)
  #|assert.true(near(math.exp(2), math.e * math.e, 0.00000000000001))
  #|assert.eq(math.exp(-1), 1 / math.e)
  #|assert.eq(math.exp(inf), inf)
  #|assert.eq(math.exp(-inf), 0)
  #|assert.eq(math.exp(nan), nan)
  #|assert.fails(lambda: math.exp("0"), "got string, want float or int")

///|
test "math.star: exp" {
  let errs = run_star_string(math_exp_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let math_sqrt_src : String =
  #|load("assert.star", "assert")
  #|load("math.star", "math")
  #|inf = float("inf")
  #|nan = float("nan")
  #|assert.eq(math.sqrt(0.0), 0.0)
  #|assert.eq(math.sqrt(4.0), 2.0)
  #|assert.eq(math.sqrt(-4.0), nan)
  #|assert.eq(math.sqrt(0), 0)
  #|assert.eq(math.sqrt(4), 2)
  #|assert.eq(math.sqrt(-4), nan)
  #|assert.eq(math.sqrt(nan), nan)
  #|assert.eq(math.sqrt(inf), inf)
  #|assert.eq(math.sqrt(-inf), nan)
  #|assert.fails(lambda: math.sqrt("0"), "got string, want float or int")

///|
test "math.star: sqrt" {
  let errs = run_star_string(math_sqrt_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let math_acos_src : String =
  #|load("assert.star", "assert")
  #|load("math.star", "math")
  #|inf = float("inf")
  #|nan = float("nan")
  #|assert.eq(math.acos(1.0), 0)
  #|assert.eq(math.acos(1), 0)
  #|assert.eq(math.acos(0.0), math.pi / 2)
  #|assert.eq(math.acos(0), math.pi / 2)
  #|assert.eq(math.acos(-1.0), math.pi)
  #|assert.eq(math.acos(-1), math.pi)
  #|assert.eq(math.acos(1.01), nan)
  #|assert.eq(math.acos(-1.01), nan)
  #|assert.eq(math.acos(inf), nan)
  #|assert.eq(math.acos(-inf), nan)
  #|assert.eq(math.acos(nan), nan)
  #|assert.fails(lambda: math.acos("0"), "got string, want float or int")

///|
test "math.star: acos" {
  let errs = run_star_string(math_acos_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let math_asin_src : String =
  #|load("assert.star", "assert")
  #|load("math.star", "math")
  #|inf = float("inf")
  #|nan = float("nan")
  #|assert.eq(math.asin(0.0), 0)
  #|assert.eq(math.asin(1.0), math.pi / 2)
  #|assert.eq(math.asin(-1.0), -math.pi / 2)
  #|assert.eq(math.asin(0), 0)
  #|assert.eq(math.asin(1), math.pi / 2)
  #|assert.eq(math.asin(-1), -math.pi / 2)
  #|assert.eq(math.asin(1.01), nan)
  #|assert.eq(math.asin(-1.01), nan)
  #|assert.eq(math.asin(inf), nan)
  #|assert.eq(math.asin(-inf), nan)
  #|assert.eq(math.asin(nan), nan)
  #|assert.fails(lambda: math.asin("0"), "got string, want float or int")

///|
test "math.star: asin" {
  let errs = run_star_string(math_asin_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let math_atan_src : String =
  #|load("assert.star", "assert")
  #|load("math.star", "math")
  #|inf = float("inf")
  #|nan = float("nan")
  #|assert.eq(math.atan(0.0), 0)
  #|assert.eq(math.atan(1.0), math.pi / 4)
  #|assert.eq(math.atan(-1.0), -math.pi / 4)
  #|assert.eq(math.atan(1), math.pi / 4)
  #|assert.eq(math.atan(-1), -math.pi / 4)
  #|assert.eq(math.atan(inf), math.pi / 2)
  #|assert.eq(math.atan(-inf), -math.pi / 2)
  #|assert.eq(math.atan(nan), nan)
  #|assert.fails(lambda: math.atan("0"), "got string, want float or int")

///|
test "math.star: atan" {
  let errs = run_star_string(math_atan_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let math_atan2_src : String =
  #|load("assert.star", "assert")
  #|load("math.star", "math")
  #|inf = float("inf")
  #|nan = float("nan")
  #|assert.eq(math.atan2(1.0, 1.0), math.pi / 4)
  #|assert.eq(math.atan2(-1.0, 1.0), -math.pi / 4)
  #|assert.eq(math.atan2(0.0, 10.0), 0)
  #|assert.eq(math.atan2(0.0, -10.0), math.pi)
  #|assert.eq(math.atan2(-0.0, -10.0), -math.pi)
  #|assert.eq(math.atan2(10.0, 0.0), math.pi / 2)
  #|assert.eq(math.atan2(-10.0, 0.0), -math.pi / 2)
  #|assert.eq(math.atan2(1, 1), math.pi / 4)
  #|assert.eq(math.atan2(-1, 1), -math.pi / 4)
  #|assert.eq(math.atan2(0, 10.0), 0)
  #|assert.eq(math.atan2(0.0, -10), math.pi)
  #|assert.eq(math.atan2(-0.0, -10), -math.pi)
  #|assert.eq(math.atan2(10.0, 0), math.pi / 2)
  #|assert.eq(math.atan2(-10.0, 0), -math.pi / 2)
  #|assert.eq(math.atan2(1.0, nan), nan)
  #|assert.eq(math.atan2(nan, 1.0), nan)
  #|assert.eq(math.atan2(10.0, inf), 0)
  #|assert.eq(math.atan2(-10.0, inf), 0)
  #|assert.eq(math.atan2(10.0, -inf), math.pi)
  #|assert.eq(math.atan2(-10.0, -inf), -math.pi)
  #|assert.eq(math.atan2(inf, 10.0), math.pi / 2)
  #|assert.eq(math.atan2(inf, -10.0), math.pi / 2)
  #|assert.eq(math.atan2(-inf, 10.0), -math.pi / 2)
  #|assert.eq(math.atan2(-inf, -10.0), -math.pi / 2)
  #|assert.eq(math.atan2(inf, inf), math.pi / 4)
  #|assert.eq(math.atan2(-inf, inf), -math.pi / 4)
  #|assert.eq(math.atan2(inf, -inf), 3 * math.pi / 4)
  #|assert.eq(math.atan2(-inf, -inf), -3 * math.pi / 4)
  #|assert.fails(lambda: math.atan2("0", 1.0), "got string, want float or int")
  #|assert.fails(lambda: math.atan2(1.0, "0"), "got string, want float or int")

///|
test "math.star: atan2" {
  let errs = run_star_string(math_atan2_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let math_cos_src : String =
  #|load("assert.star", "assert")
  #|load("math.star", "math")
  #|inf = float("inf")
  #|nan = float("nan")
  #|def near(got, want, threshold):
  #|  return math.fabs(got - want) < threshold
  #|assert.eq(math.cos(0.0), 1)
  #|assert.true(near(math.cos(math.pi / 2), 0, 0.00000000000001))
  #|assert.eq(math.cos(math.pi), -1)
  #|assert.true(near(math.cos(-math.pi / 2), 0, 0.00000000000001))
  #|assert.eq(math.cos(-math.pi), -1)
  #|assert.eq(math.cos(inf), nan)
  #|assert.eq(math.cos(-inf), nan)
  #|assert.eq(math.cos(nan), nan)
  #|assert.fails(lambda: math.cos("0"), "got string, want float or int")

///|
test "math.star: cos" {
  let errs = run_star_string(math_cos_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let math_hypot_src : String =
  #|load("assert.star", "assert")
  #|load("math.star", "math")
  #|inf = float("inf")
  #|nan = float("nan")
  #|assert.eq(math.hypot(4.0, 3.0), 5.0)
  #|assert.eq(math.hypot(4, 3), 5.0)
  #|assert.eq(math.hypot(inf, 3.0), inf)
  #|assert.eq(math.hypot(-inf, 3.0), inf)
  #|assert.eq(math.hypot(3.0, inf), inf)
  #|assert.eq(math.hypot(3.0, -inf), inf)
  #|assert.eq(math.hypot(nan, 3.0), nan)
  #|assert.eq(math.hypot(3.0, nan), nan)
  #|assert.fails(lambda: math.hypot("0", 1.0), "got string, want float or int")
  #|assert.fails(lambda: math.hypot(1.0, "0"), "got string, want float or int")

///|
test "math.star: hypot" {
  let errs = run_star_string(math_hypot_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let math_sin_src : String =
  #|load("assert.star", "assert")
  #|load("math.star", "math")
  #|inf = float("inf")
  #|nan = float("nan")
  #|assert.eq(math.sin(0.0), 0)
  #|assert.eq(math.sin(0), 0)
  #|assert.eq(math.sin(math.pi / 2), 1)
  #|assert.eq(math.sin(-math.pi / 2), -1)
  #|assert.eq(math.sin(inf), nan)
  #|assert.eq(math.sin(-inf), nan)
  #|assert.eq(math.sin(nan), nan)
  #|assert.fails(lambda: math.sin("0"), "got string, want float or int")

///|
test "math.star: sin" {
  let errs = run_star_string(math_sin_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let math_tan_src : String =
  #|load("assert.star", "assert")
  #|load("math.star", "math")
  #|inf = float("inf")
  #|nan = float("nan")
  #|def near(got, want, threshold):
  #|  return math.fabs(got - want) < threshold
  #|assert.eq(math.tan(0.0), 0)
  #|assert.eq(math.tan(0), 0)
  #|assert.true(near(math.tan(math.pi / 4), 1, 0.00000000000001))
  #|assert.true(near(math.tan(-math.pi / 4), -1, 0.00000000000001))
  #|assert.eq(math.tan(inf), nan)
  #|assert.eq(math.tan(-inf), nan)
  #|assert.eq(math.tan(nan), nan)
  #|assert.fails(lambda: math.tan("0"), "got string, want float or int")

///|
test "math.star: tan" {
  let errs = run_star_string(math_tan_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let math_degrees_src : String =
  #|load("assert.star", "assert")
  #|load("math.star", "math")
  #|inf = float("inf")
  #|nan = float("nan")
  #|oneDeg = 57.29577951308232
  #|assert.eq(math.degrees(1.0), oneDeg)
  #|assert.eq(math.degrees(1), oneDeg)
  #|assert.eq(math.degrees(-1.0), -oneDeg)
  #|assert.eq(math.degrees(-1), -oneDeg)
  #|assert.eq(math.degrees(inf), inf)
  #|assert.eq(math.degrees(-inf), -inf)
  #|assert.eq(math.degrees(nan), nan)
  #|assert.fails(lambda: math.degrees("0"), "got string, want float or int")

///|
test "math.star: degrees" {
  let errs = run_star_string(math_degrees_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let math_radians_src : String =
  #|load("assert.star", "assert")
  #|load("math.star", "math")
  #|inf = float("inf")
  #|nan = float("nan")
  #|oneRad = 0.017453292519943295
  #|assert.eq(math.radians(1.0), oneRad)
  #|assert.eq(math.radians(-1.0), -oneRad)
  #|assert.eq(math.radians(1), oneRad)
  #|assert.eq(math.radians(-1), -oneRad)
  #|assert.eq(math.radians(inf), inf)
  #|assert.eq(math.radians(-inf), -inf)
  #|assert.eq(math.radians(nan), nan)
  #|assert.fails(lambda: math.radians("0"), "got string, want float or int")

///|
test "math.star: radians" {
  let errs = run_star_string(math_radians_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let math_acosh_src : String =
  #|load("assert.star", "assert")
  #|load("math.star", "math")
  #|inf = float("inf")
  #|nan = float("nan")
  #|assert.eq(math.acosh(1.0), 0)
  #|assert.eq(math.acosh(1), 0)
  #|assert.eq(math.acosh(0.99), nan)
  #|assert.eq(math.acosh(0), nan)
  #|assert.eq(math.acosh(-0.99), nan)
  #|assert.eq(math.acosh(-inf), nan)
  #|assert.eq(math.acosh(inf), inf)
  #|assert.eq(math.acosh(nan), nan)
  #|assert.fails(lambda: math.acosh("0"), "got string, want float or int")

///|
test "math.star: acosh" {
  let errs = run_star_string(math_acosh_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let math_asinh_src : String =
  #|load("assert.star", "assert")
  #|load("math.star", "math")
  #|inf = float("inf")
  #|nan = float("nan")
  #|def near(got, want, threshold):
  #|  return math.fabs(got - want) < threshold
  #|asinhOne = 0.8813735870195432
  #|assert.eq(math.asinh(0.0), 0)
  #|assert.eq(math.asinh(0), 0)
  #|assert.true(near(math.asinh(1.0), asinhOne, 0.00000001))
  #|assert.true(near(math.asinh(1), asinhOne, 0.00000001))
  #|assert.true(near(math.asinh(-1.0), -asinhOne, 0.00000001))
  #|assert.true(near(math.asinh(-1), -asinhOne, 0.00000001))
  #|assert.eq(math.asinh(inf), inf)
  #|assert.eq(math.asinh(-inf), -inf)
  #|assert.eq(math.asinh(nan), nan)
  #|assert.fails(lambda: math.asinh("0"), "got string, want float or int")

///|
test "math.star: asinh" {
  let errs = run_star_string(math_asinh_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let math_atanh_src : String =
  #|load("assert.star", "assert")
  #|load("math.star", "math")
  #|inf = float("inf")
  #|nan = float("nan")
  #|atanhHalf = 0.5493061443340548
  #|assert.eq(math.atanh(0.0), 0)
  #|assert.eq(math.atanh(0), 0)
  #|assert.eq(math.atanh(0.5), atanhHalf)
  #|assert.eq(math.atanh(-0.5), -atanhHalf)
  #|assert.eq(math.atanh(1), inf)
  #|assert.eq(math.atanh(-1), -inf)
  #|assert.eq(math.atanh(1.1), nan)
  #|assert.eq(math.atanh(-1.1), nan)
  #|assert.eq(math.atanh(inf), nan)
  #|assert.eq(math.atanh(-inf), nan)
  #|assert.eq(math.atanh(nan), nan)
  #|assert.fails(lambda: math.atanh("0"), "got string, want float or int")

///|
test "math.star: atanh" {
  let errs = run_star_string(math_atanh_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let math_cosh_src : String =
  #|load("assert.star", "assert")
  #|load("math.star", "math")
  #|inf = float("inf")
  #|nan = float("nan")
  #|coshOne = 1.5430806348152437
  #|assert.eq(math.cosh(1.0), coshOne)
  #|assert.eq(math.cosh(1), coshOne)
  #|assert.eq(math.cosh(0.0), 1)
  #|assert.eq(math.cosh(0), 1)
  #|assert.eq(math.cosh(-inf), inf)
  #|assert.eq(math.cosh(inf), inf)
  #|assert.eq(math.cosh(nan), nan)
  #|assert.fails(lambda: math.cosh("0"), "got string, want float or int")

///|
test "math.star: cosh" {
  let errs = run_star_string(math_cosh_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let math_sinh_src : String =
  #|load("assert.star", "assert")
  #|load("math.star", "math")
  #|inf = float("inf")
  #|nan = float("nan")
  #|sinhOne = 1.1752011936438014
  #|assert.eq(math.sinh(0.0), 0)
  #|assert.eq(math.sinh(0), 0)
  #|assert.eq(math.sinh(1.0), sinhOne)
  #|assert.eq(math.sinh(1), sinhOne)
  #|assert.eq(math.sinh(-1.0), -sinhOne)
  #|assert.eq(math.sinh(-1), -sinhOne)
  #|assert.eq(math.sinh(-inf), -inf)
  #|assert.eq(math.sinh(inf), inf)
  #|assert.eq(math.sinh(nan), nan)
  #|assert.fails(lambda: math.sinh("0"), "got string, want float or int")

///|
test "math.star: sinh" {
  let errs = run_star_string(math_sinh_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let math_tanh_src : String =
  #|load("assert.star", "assert")
  #|load("math.star", "math")
  #|inf = float("inf")
  #|nan = float("nan")
  #|tanhOne = 0.7615941559557649
  #|assert.eq(math.tanh(0.0), 0)
  #|assert.eq(math.tanh(0), 0)
  #|assert.eq(math.tanh(1.0), tanhOne)
  #|assert.eq(math.tanh(1), tanhOne)
  #|assert.eq(math.tanh(-1.0), -tanhOne)
  #|assert.eq(math.tanh(-1), -tanhOne)
  #|assert.eq(math.tanh(-inf), -1)
  #|assert.eq(math.tanh(inf), 1)
  #|assert.eq(math.tanh(nan), nan)
  #|assert.fails(lambda: math.tanh("0"), "got string, want float or int")

///|
test "math.star: tanh" {
  let errs = run_star_string(math_tanh_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let math_log_src : String =
  #|load("assert.star", "assert")
  #|load("math.star", "math")
  #|nan = float("nan")
  #|assert.eq(math.log(math.e), 1)
  #|assert.eq(math.log(10, 10), 1)
  #|assert.eq(math.log(10.0, 10.0), 1)
  #|assert.eq(math.log(2, 2.0), 1)
  #|assert.fails(lambda: math.log(2, 1), "division by zero")
  #|assert.fails(lambda: math.log(0.99, 1.0), "division by zero")
  #|assert.eq(math.log(0.0), float("-inf"))
  #|assert.eq(math.log(0), float("-inf"))
  #|assert.eq(math.log(-1.0), nan)
  #|assert.eq(math.log(-1), nan)
  #|assert.eq(math.log(nan), nan)
  #|assert.fails(lambda: math.log("0"), "got string, want float or int")
  #|assert.fails(lambda: math.log(10, "10"), "got string, want float or int")

///|
test "math.star: log" {
  let errs = run_star_string(math_log_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let math_gamma_src : String =
  #|load("assert.star", "assert")
  #|load("math.star", "math")
  #|inf = float("inf")
  #|nan = float("nan")
  #|assert.eq(math.gamma(1.0), 1)
  #|assert.eq(math.gamma(1), 1)
  #|assert.eq(math.gamma(-1), nan)
  #|assert.eq(math.gamma(0), inf)
  #|assert.eq(math.gamma(-inf), nan)
  #|assert.eq(math.gamma(inf), inf)
  #|assert.eq(math.gamma(nan), nan)
  #|assert.fails(lambda: math.gamma("0"), "got string, want float or int")

///|
test "math.star: gamma" {
  let errs = run_star_string(math_gamma_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let math_constants_src : String =
  #|load("assert.star", "assert")
  #|load("math.star", "math")
  #|assert.eq(math.e, 2.7182818284590452)
  #|assert.eq(math.pi, 3.1415926535897932)

///|
test "math.star: constants" {
  let errs = run_star_string(math_constants_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let math_bigint_boundary_src : String =
  #|load("assert.star", "assert")
  #|load("math.star", "math")
  #|
  #|# BigInt boundary: ceil and floor of float just above 2^63
  #|# float((1<<63) + 1) rounds to 2^63 due to precision loss
  #|assert.eq(math.ceil((1<<63) + 0.5), int(float((1<<63) + 1)))
  #|assert.eq(math.floor((1<<63) + 0.5), int(float(1<<63)))

///|
test "math.star: ceil and floor produce BigInt beyond Int64 range" {
  let errs = run_star_string(math_bigint_boundary_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}
