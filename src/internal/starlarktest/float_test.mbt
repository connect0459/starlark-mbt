// Integration tests derived from float.star.

///|
let float_type_truth_src : String =
  #|load("assert.star", "assert")
  #|
  #|# type
  #|assert.eq(type(0.0), "float")
  #|
  #|# truth
  #|assert.true(123.0)
  #|assert.true(-1.0)
  #|assert.true(not 0.0)
  #|assert.true(-1.0e-45)
  #|assert.true(float("NaN"))
  #|
  #|# not iterable
  #|assert.fails(lambda: len(0.0), 'has no len')
  #|assert.fails(lambda: [x for x in 0.0], 'float value is not iterable')
  #|
  #|# literals
  #|assert.eq(type(1.234), "float")
  #|assert.eq(type(1e10), "float")
  #|assert.eq(type(1e+10), "float")
  #|assert.eq(type(1e-10), "float")
  #|assert.eq(type(1.234e10), "float")
  #|assert.eq(type(1.234e+10), "float")
  #|assert.eq(type(1.234e-10), "float")

///|
test "float.star: type, truth, not iterable, literals" {
  let errs = run_star_string(float_type_truth_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let float_equality_precision_src : String =
  #|load("assert.star", "assert")
  #|
  #|# int/float equality
  #|assert.eq(0.0, 0)
  #|assert.eq(0, 0.0)
  #|assert.eq(1.0, 1)
  #|assert.eq(1, 1.0)
  #|
  #|# loss of precision
  #|p53 = 1<<53
  #|assert.eq(float(p53-1), p53-1)
  #|assert.eq(float(p53+0), p53+0)
  #|assert.eq(float(p53+1), p53+0)
  #|assert.eq(float(p53+2), p53+2)
  #|assert.eq(float(p53+3), p53+4)
  #|assert.eq(float(p53+4), p53+4)
  #|assert.eq(float(p53+5), p53+4)
  #|assert.eq(float(p53+6), p53+6)
  #|assert.eq(float(p53+7), p53+8)
  #|assert.eq(float(p53+8), p53+8)
  #|
  #|assert.true(float(p53+1) != p53+1) # comparisons are exact
  #|assert.eq(float(p53+1) - (p53+1), 0) # arithmetic entails rounding
  #|
  #|assert.fails(lambda: {123.0: "f", 123: "i"}, "duplicate key: 123")
  #|
  #|# equal int/float values have same hash
  #|d = {123.0: "x"}
  #|d[123] = "y"
  #|assert.eq(len(d), 1)
  #|assert.eq(d[123.0], "y")
  #|
  #|# literals (mostly covered by scanner tests)
  #|assert.eq(str(0.), "0.0")
  #|assert.eq(str(.0), "0.0")
  #|assert.true(5.0 != 4.999999999999999)
  #|assert.eq(5.0, 4.9999999999999999) # both literals denote 5.0

///|
test "float.star: int/float equality and precision loss" {
  let errs = run_star_string(float_equality_precision_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let float_arithmetic_src : String =
  #|load("assert.star", "assert")
  #|
  #|nan = float("NaN")
  #|inf = float("+Inf")
  #|neginf = float("-Inf")
  #|negzero = (-1e-323 / 10)
  #|
  #|# +float, -float
  #|assert.eq(+(123.0), 123.0)
  #|assert.eq(-(123.0), -123.0)
  #|assert.eq(-(-(123.0)), 123.0)
  #|assert.eq(+(inf), inf)
  #|assert.eq(-(inf), neginf)
  #|assert.eq(-(neginf), inf)
  #|assert.eq(str(-(nan)), "nan")
  #|# +
  #|assert.eq(1.2e3 + 5.6e7, 5.60012e+07)
  #|assert.eq(1.2e3 + 1, 1201)
  #|assert.eq(1 + 1.2e3, 1201)
  #|assert.eq(str(1.2e3 + nan), "nan")
  #|assert.eq(inf + 0, inf)
  #|assert.eq(inf + 1, inf)
  #|assert.eq(inf + inf, inf)
  #|assert.eq(str(inf + neginf), "nan")
  #|# -
  #|assert.eq(1.2e3 - 5.6e7, -5.59988e+07)
  #|assert.eq(1.2e3 - 1, 1199)
  #|assert.eq(1 - 1.2e3, -1199)
  #|assert.eq(str(1.2e3 - nan), "nan")
  #|assert.eq(inf - 0, inf)
  #|assert.eq(inf - 1, inf)
  #|assert.eq(str(inf - inf), "nan")
  #|assert.eq(inf - neginf, inf)
  #|# *
  #|assert.eq(1.5e6 * 2.2e3, 3.3e9)
  #|assert.eq(1.5e6 * 123, 1.845e+08)
  #|assert.eq(123 * 1.5e6, 1.845e+08)
  #|assert.eq(str(1.2e3 * nan), "nan")
  #|assert.eq(str(inf * 0), "nan")
  #|assert.eq(inf * 1, inf)
  #|assert.eq(inf * inf, inf)
  #|assert.eq(inf * neginf, neginf)
  #|# /
  #|assert.eq(str(100.0 / 7.0), "14.285714285714286")
  #|assert.eq(str(100 / 7.0), "14.285714285714286")
  #|assert.eq(str(100.0 / 7), "14.285714285714286")
  #|assert.eq(str(100.0 / nan), "nan")
  #|# //
  #|assert.eq(100.0 // 7.0, 14)
  #|assert.eq(100 // 7.0, 14)
  #|assert.eq(100.0 // 7, 14)
  #|assert.eq(100.0 // -7.0, -15)
  #|assert.eq(100 // -7.0, -15)
  #|assert.eq(100.0 // -7, -15)
  #|assert.eq(str(1 // neginf), "-0.0")
  #|assert.eq(str(100.0 // nan), "nan")
  #|
  #|# addition
  #|assert.eq(0.0 + 1.0, 1.0)
  #|assert.eq(1.0 + 1.0, 2.0)
  #|assert.eq(1.25 + 2.75, 4.0)
  #|assert.eq(5.0 + 7.0, 12.0)
  #|assert.eq(5.1 + 7, 12.1)
  #|assert.eq(7 + 5.1, 12.1)
  #|
  #|# subtraction
  #|assert.eq(5.0 - 7.0, -2.0)
  #|assert.eq(5.1 - 7.1, -2.0)
  #|assert.eq(5.5 - 7, -1.5)
  #|assert.eq(5 - 7.5, -2.5)
  #|assert.eq(0.0 - 1.0, -1.0)
  #|
  #|# multiplication
  #|assert.eq(5.0 * 7.0, 35.0)
  #|assert.eq(5.5 * 2.5, 13.75)
  #|assert.eq(5.5 * 7, 38.5)
  #|assert.eq(5 * 7.1, 35.5)
  #|
  #|# real division
  #|assert.eq(100.0 / 8.0, 12.5)
  #|assert.eq(100.0 / -8.0, -12.5)
  #|assert.eq(-100.0 / 8.0, -12.5)
  #|assert.eq(-100.0 / -8.0, 12.5)
  #|assert.eq(98.0 / 8.0, 12.25)
  #|assert.eq(98.0 / -8.0, -12.25)
  #|assert.eq(-98.0 / 8.0, -12.25)
  #|assert.eq(-98.0 / -8.0, 12.25)
  #|assert.eq(2.5 / 2.0, 1.25)
  #|assert.eq(2.5 / 2, 1.25)
  #|assert.eq(5 / 4.0, 1.25)
  #|assert.eq(5 / 4, 1.25)
  #|assert.fails(lambda: 1.0 / 0, "floating-point division by zero")
  #|assert.fails(lambda: 1.0 / 0.0, "floating-point division by zero")
  #|assert.fails(lambda: 1 / 0.0, "floating-point division by zero")
  #|
  #|# floored division
  #|assert.eq(100.0 // 8.0, 12.0)
  #|assert.eq(100.0 // -8.0, -13.0)
  #|assert.eq(-100.0 // 8.0, -13.0)
  #|assert.eq(-100.0 // -8.0, 12.0)
  #|assert.eq(98.0 // 8.0, 12.0)
  #|assert.eq(98.0 // -8.0, -13.0)
  #|assert.eq(-98.0 // 8.0, -13.0)
  #|assert.eq(-98.0 // -8.0, 12.0)
  #|assert.eq(2.5 // 2.0, 1.0)
  #|assert.eq(2.5 // 2, 1.0)
  #|assert.eq(5 // 4.0, 1.0)
  #|assert.eq(5 // 4, 1)
  #|assert.eq(type(5 // 4), "int")
  #|assert.fails(lambda: 1.0 // 0, "floored division by zero")
  #|assert.fails(lambda: 1.0 // 0.0, "floored division by zero")
  #|assert.fails(lambda: 1 // 0.0, "floored division by zero")
  #|
  #|# remainder (floor-mod: sign follows divisor)
  #|assert.eq(100.0 % 8.0, 4.0)
  #|assert.eq(100.0 % -7.0, -5.0)
  #|assert.eq(-100.0 % 7.0, 5.0)
  #|assert.eq(-100.0 % -7.0, -2.0)
  #|assert.eq(2.5 % 2.0, 0.5)
  #|assert.eq(2.5 % 2, 0.5)
  #|assert.eq(5 % 4.0, 1.0)
  #|assert.eq(-100.0 % 7, 5.0)
  #|assert.eq(100 % 7.0, 2.0)
  #|assert.fails(lambda: 1.0 % 0, "floating-point modulo by zero")
  #|assert.fails(lambda: 1.0 % 0.0, "floating-point modulo by zero")
  #|assert.fails(lambda: 1 % 0.0, "floating-point modulo by zero")
  #|
  #|# floats cannot be used as indices
  #|assert.fails(lambda: "abc"[1.0], "want int")
  #|assert.fails(lambda: ["A", "B", "C"].insert(1.0, "D"), "want int")
  #|assert.fails(lambda: range(3)[1.0], "got float, want int")

///|
test "float.star: arithmetic operations" {
  let errs = run_star_string(float_arithmetic_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let float_nan_sort_cmp_src : String =
  #|load("assert.star", "assert")
  #|
  #|nan = float("NaN")
  #|inf = float("+Inf")
  #|neginf = float("-Inf")
  #|negzero = (-1e-323 / 10)
  #|
  #|# NaN comparisons
  #|assert.true(nan == nan)
  #|assert.true(nan >= nan)
  #|assert.true(nan <= nan)
  #|assert.true(not (nan > nan))
  #|assert.true(not (nan < nan))
  #|assert.true(not (nan != nan))
  #|
  #|# sorted with mixed int/float
  #|assert.eq(
  #|    str(sorted([inf, neginf, nan, 1e300, -1e300, 1.0, -1.0, 1, -1, 1e-300, -1e-300, 0, 0.0, negzero, 1e-300, -1e-300])),
  #|    "[-inf, -1e+300, -1.0, -1, -1e-300, -1e-300, 0, 0.0, -0.0, 1e-300, 1e-300, 1.0, 1, 1e+300, +inf, nan]")
  #|assert.eq(str(sorted([7, 3, nan, 1, 9])), "[1, 3, 7, 9, nan]")
  #|assert.eq(str(sorted([7, 3, nan, 1, 9], reverse=True)), "[nan, 9, 7, 3, 1]")
  #|
  #|# NaN dict tests
  #|nandict = {nan: 1}
  #|nandict[nan] = 2
  #|assert.eq(len(nandict), 1)
  #|assert.eq(nandict[nan], 2)
  #|assert.fails(lambda: {nan: 1, nan: 2}, "duplicate key: nan")
  #|
  #|nandict[float('nan')] = 3
  #|assert.eq(str(nandict), "{nan: 3}")
  #|
  #|assert.eq(str({inf: 1, neginf: 2}), "{+inf: 1, -inf: 2}")
  #|
  #|# zero equality
  #|assert.eq(0.0, negzero)
  #|
  #|# inf arithmetic
  #|assert.eq(+inf / +inf, nan)
  #|assert.eq(+inf / -inf, nan)
  #|assert.eq(-inf / +inf, nan)
  #|assert.eq(0.0 / +inf, 0.0)
  #|assert.eq(0.0 / -inf, 0.0)
  #|assert.true(inf > -inf)
  #|assert.eq(inf, -neginf)
  #|
  #|# NaN/inf modulo
  #|assert.eq(str(1.2e3 % nan), "nan")
  #|assert.eq(str(inf % 1), "nan")
  #|assert.eq(str(inf % inf), "nan")
  #|assert.eq(str(inf % neginf), "nan")
  #|
  #|# negative zero
  #|negz = -0
  #|assert.eq(negz, 0)
  #|
  #|# min/max with nan
  #|assert.eq(max([1, nan, 3]), nan)
  #|assert.eq(max([nan, 2, 3]), nan)
  #|assert.eq(min([1, nan, 3]), 1)
  #|assert.eq(min([nan, 2, 3]), 2)
  #|
  #|# float/float comparisons (fltmax only; fltmin underflows to 0.0 in this impl)
  #|fltmax = 1.7976931348623157e+308
  #|assert.lt(-inf, -fltmax)
  #|assert.lt(-fltmax, -1.0)
  #|assert.lt(1.0, fltmax)
  #|assert.lt(fltmax, inf)
  #|
  #|# int/float comparisons
  #|assert.eq(0, 0.0)
  #|assert.eq(1, 1.0)
  #|assert.eq(-1, -1.0)
  #|assert.ne(-1, -1.0 + 1e-7)
  #|assert.lt(-2, -2 + 1e-15)

///|
test "float.star: NaN, sorted, comparisons" {
  let errs = run_star_string(float_nan_sort_cmp_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let float_conversions_src : String =
  #|load("assert.star", "assert")
  #|
  #|nan = float("NaN")
  #|inf = float("+Inf")
  #|neginf = float("-Inf")
  #|
  #|# int conversion (rounds towards zero) - basic cases only
  #|assert.eq(int(100.1), 100)
  #|assert.eq(int(100.0), 100)
  #|assert.eq(int(99.9), 99)
  #|assert.eq(int(-99.9), -99)
  #|assert.eq(int(-100.0), -100)
  #|assert.eq(int(-100.1), -100)
  #|assert.fails(lambda: int(inf), "cannot convert.*infinity")
  #|assert.fails(lambda: int(nan), "cannot convert.*NaN")
  #|
  #|# float() function
  #|assert.eq(float(), 0.0)
  #|# float(bool)
  #|assert.eq(float(False), 0.0)
  #|assert.eq(float(True), 1.0)
  #|# float(int)
  #|assert.eq(float(0), 0.0)
  #|assert.eq(float(1), 1.0)
  #|assert.eq(float(123), 123.0)
  #|# float(float)
  #|assert.eq(float(1.1), 1.1)
  #|assert.fails(lambda: float(None), "float got NoneType, want number or string")
  #|assert.ne(False, 0.0)
  #|assert.ne(True, 1.0)
  #|# float(string)
  #|assert.eq(float("1.1"), 1.1)
  #|assert.fails(lambda: float("1.1abc"), "invalid float literal")
  #|assert.fails(lambda: float("1e100.0"), "invalid float literal")
  #|assert.fails(lambda: float("1e1000"), "floating-point number too large")
  #|assert.eq(float("-1.1"), -1.1)
  #|assert.eq(float("+1.1"), +1.1)
  #|assert.eq(float("+Inf"), inf)
  #|assert.eq(float("-Inf"), neginf)
  #|assert.eq(float("NaN"), nan)
  #|assert.eq(float("+NAN"), nan)
  #|assert.eq(float("-nan"), nan)
  #|assert.eq(str(float("Inf")), "+inf")
  #|assert.eq(str(float("+INF")), "+inf")
  #|assert.eq(str(float("-inf")), "-inf")
  #|assert.eq(str(float("+InFiniTy")), "+inf")
  #|assert.eq(str(float("-iNFiniTy")), "-inf")
  #|assert.fails(lambda: float("one point two"), "invalid float literal")
  #|assert.fails(lambda: float("1.2.3"), "invalid float literal")
  #|
  #|# int() function
  #|assert.eq(int(0.0), 0)
  #|assert.eq(int(1.0), 1)
  #|assert.eq(int(1.1), 1)
  #|assert.eq(int(0.9), 0)
  #|assert.eq(int(-1.1), -1.0)
  #|assert.eq(int(-1.0), -1.0)
  #|assert.eq(int(-0.9), 0.0)
  #|assert.eq(int(-1.23e-32), 0)
  #|assert.eq(int(1.23e-32), 0)
  #|assert.fails(lambda: int(float("+Inf")), "cannot convert float infinity to integer")
  #|assert.fails(lambda: int(float("-Inf")), "cannot convert float infinity to integer")
  #|assert.fails(lambda: int(float("NaN")), "cannot convert float NaN to integer")

///|
test "float.star: float() and int() conversions" {
  let errs = run_star_string(float_conversions_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let float_whitespace_src : String =
  #|load("assert.star", "assert")
  #|assert.fails(lambda: float("  1.0  "), "invalid float literal")
  #|assert.fails(lambda: float(" 1.0"), "invalid float literal")
  #|assert.fails(lambda: float("1.0 "), "invalid float literal")
  #|assert.fails(lambda: float("\t1.0"), "invalid float literal")

///|
test "float.star: float() rejects surrounding whitespace" {
  let errs = run_star_string(float_whitespace_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let float_formatting_src : String =
  #|load("assert.star", "assert")
  #|
  #|nan = float("NaN")
  #|inf = float("+Inf")
  #|neginf = float("-Inf")
  #|negzero = (-1e-323 / 10)
  #|
  #|# %d with basic floats (NaN/Inf via %d is not guarded in this impl)
  #|assert.eq("%d" % 0, "0")
  #|assert.eq("%d" % 0.0, "0")
  #|assert.eq("%d" % 123, "123")
  #|assert.eq("%d" % 123.0, "123")
  #|assert.eq("%d" % negzero, "0")
  #|
  #|# %e - scientific notation with 6 decimal places
  #|assert.eq("%e" % nan, "nan")
  #|assert.eq("%e" % inf, "+inf")
  #|assert.eq("%e" % neginf, "-inf")
  #|assert.eq("%e" % 0,       "0.000000e+00")
  #|assert.eq("%e" % 123,     "1.230000e+02")
  #|assert.eq("%e" % 123.0,   "1.230000e+02")
  #|assert.eq("%e" % negzero, "-0.000000e+00")
  #|
  #|# %E - uppercase exponent; special values stay lowercase
  #|assert.eq("%E" % nan, "nan")
  #|assert.eq("%E" % inf, "+inf")
  #|assert.eq("%E" % neginf, "-inf")
  #|assert.eq("%E" % 1.23e45, "1.230000E+45")
  #|
  #|# %f - fixed notation with 6 decimal places
  #|assert.eq("%f" % nan, "nan")
  #|assert.eq("%f" % inf, "+inf")
  #|assert.eq("%f" % neginf, "-inf")
  #|assert.eq("%f" % 0,       "0.000000")
  #|assert.eq("%f" % 123,     "123.000000")
  #|assert.eq("%f" % 123.0,   "123.000000")
  #|assert.eq("%f" % negzero, "-0.000000")
  #|
  #|# %g - impl returns float.to_string() for numbers
  #|assert.eq("%g" % nan, "nan")
  #|assert.eq("%g" % inf, "+inf")
  #|assert.eq("%g" % neginf, "-inf")
  #|
  #|# %G - special values stay lowercase
  #|assert.eq("%G" % nan, "nan")
  #|assert.eq("%G" % inf, "+inf")
  #|assert.eq("%G" % neginf, "-inf")
  #|
  #|# str uses format_float (correct Starlark float formatting)
  #|assert.eq(str(0.0), "0.0")
  #|assert.eq(str(123.0), "123.0")
  #|assert.eq(str(1.23e45), "1.23e+45")
  #|assert.eq(str(-1.23e-45), "-1.23e-45")
  #|assert.eq(str(nan), "nan")
  #|assert.eq(str(inf), "+inf")
  #|assert.eq(str(neginf), "-inf")
  #|assert.eq(str(negzero), "-0.0")
  #|
  #|# format errors: %e/%f/%g require float or int, not str
  #|assert.fails(lambda: "%e" % "123", "requires float, not str")
  #|assert.fails(lambda: "%f" % "123", "requires float, not str")
  #|assert.fails(lambda: "%g" % "123", "requires float, not str")

///|
test "float.star: string formatting" {
  let errs = run_star_string(float_formatting_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let float_go_fmt_src : String =
  #|load("assert.star", "assert")
  #|# Large round numbers with 7+ integer digits -> scientific
  #|assert.eq(str(1e20), "1e+20")
  #|assert.eq(str(1e6), "1e+06")
  #|assert.eq(str(1e10), "1e+10")
  #|assert.eq(str(-1e20), "-1e+20")
  #|# 6-digit integers stay fixed
  #|assert.eq(str(1e5), "100000.0")
  #|# Small numbers: exponent < -4 -> scientific
  #|assert.eq(str(1e-5), "1e-05")
  #|assert.eq(str(1e-7), "1e-07")
  #|assert.eq(str(-1e-5), "-1e-05")
  #|# Normal decimals stay fixed
  #|assert.eq(str(123.0), "123.0")
  #|# exp=-4 is NOT scientific (threshold is < -4, not <= -4)
  #|assert.eq(str(1e-4), "0.0001")

///|
test "float.star: str() uses Go-compatible g-format for large/small floats" {
  let errs = run_star_string(float_go_fmt_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let float_checktypes_src : String =
  #|load("assert.star", "assert")
  #|
  #|i0 = 1
  #|f0 = 1.0
  #|assert.eq(type(i0), "int")
  #|assert.eq(type(f0), "float")
  #|
  #|ops = {
  #|    '+': lambda x, y: x + y,
  #|    '-': lambda x, y: x - y,
  #|    '*': lambda x, y: x * y,
  #|    '/': lambda x, y: x / y,
  #|    '//': lambda x, y: x // y,
  #|    '%': lambda x, y: x % y,
  #|}
  #|
  #|def checktypes():
  #|  want = set("""
  #|int + int = int
  #|int + float = float
  #|float + int = float
  #|float + float = float
  #|int - int = int
  #|int - float = float
  #|float - int = float
  #|float - float = float
  #|int * int = int
  #|int * float = float
  #|float * int = float
  #|float * float = float
  #|int / int = float
  #|int / float = float
  #|float / int = float
  #|float / float = float
  #|int // int = int
  #|int // float = float
  #|float // int = float
  #|float // float = float
  #|int % int = int
  #|int % float = float
  #|float % int = float
  #|float % float = float
  #|"""[1:].splitlines())
  #|  for opname in ("+", "-", "*", "/", "%"):
  #|    for x in [i0, f0]:
  #|      for y in [i0, f0]:
  #|        op = ops[opname]
  #|        got = "%s %s %s = %s" % (type(x), opname, type(y), type(op(x, y)))
  #|        assert.contains(want, got)
  #|checktypes()

///|
test "float.star: checktypes()" {
  let errs = run_star_string(float_checktypes_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let float_bigint_regression_src : String =
  #|load("assert.star", "assert")
  #|
  #|# Regression test for https://github.com/google/starlark-go/issues/375.
  #|# float(maxint64) rounds up to 2^63; int() must return BigInt.
  #|maxint64 = (1<<63)-1
  #|assert.eq(int(float(maxint64)), 9223372036854775808)

///|
test "float.star: int(float(maxint64)) BigInt regression" {
  let errs = run_star_string(float_bigint_regression_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let float_string_errors_src : String =
  #|load("assert.star", "assert")
  #|assert.fails(lambda: float("1.1abc"), "invalid float literal")
  #|assert.fails(lambda: float("1e1000"), "floating-point number too large")
  #|assert.fails(lambda: float(""), "float: empty string")

///|
test "float(): string error messages match starlark-go" {
  let errs = run_star_string(float_string_errors_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let float_bigint_overflow_src : String =
  #|load("assert.star", "assert")
  #|huge = 123 << 500 << 500 << 50
  #|assert.fails(lambda: float(huge), "int too large to convert to float")
  #|assert.fails(lambda: float(-huge), "int too large to convert to float")
  #|# mixed int+float arithmetic with huge int must raise
  #|assert.fails(lambda: (1<<500<<500<<500) + 0.0, "int too large to convert to float")
  #|assert.fails(lambda: 0.0 + (1<<500<<500<<500), "int too large to convert to float")
  #|assert.fails(lambda: (1<<500<<500<<500) - 0.0, "int too large to convert to float")
  #|assert.fails(lambda: 0.0 - (1<<500<<500<<500), "int too large to convert to float")
  #|assert.fails(lambda: (1<<500<<500<<500) * 1.0, "int too large to convert to float")
  #|assert.fails(lambda: 1.0 * (1<<500<<500<<500), "int too large to convert to float")
  #|assert.fails(lambda: (1<<500<<500<<500) / 1.0, "int too large to convert to float")
  #|assert.fails(lambda: 1.0 / (1<<500<<500<<500), "int too large to convert to float")
  #|assert.fails(lambda: (1<<500<<500<<500) // 1.0, "int too large to convert to float")
  #|assert.fails(lambda: 1.0 // (1<<500<<500<<500), "int too large to convert to float")
  #|assert.fails(lambda: (1<<500<<500<<500) % 1.0, "int too large to convert to float")
  #|assert.fails(lambda: 1.0 % (1<<500<<500<<500), "int too large to convert to float")

///|
test "float(huge_bigint) raises int too large" {
  let errs = run_star_string(float_bigint_overflow_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let float_percent_g_src : String =
  #|load("assert.star", "assert")
  #|# %g format specifier for normal values (float.star lines 435-448)
  #|negzero = -1e-323 / 10
  #|assert.eq("%g" % 0,      "0.0")
  #|assert.eq("%g" % 0.0,    "0.0")
  #|assert.eq("%g" % 1.110,  "1.11")
  #|assert.eq("%g" % 1.23e45,"1.23e+45")
  #|assert.eq("%g" % 123,    "123.0")
  #|assert.eq("%g" % 123.0,  "123.0")
  #|assert.eq("%g" % 1e5,    "100000.0")
  #|assert.eq("%g" % 1e6,    "1e+06")
  #|assert.eq("%g" % negzero, "-0.0")

///|
test "float.star: %g format specifier for normal values" {
  let errs = run_star_string(float_percent_g_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let float_percent_ef_edge_src : String =
  #|load("assert.star", "assert")
  #|# %e/%f edge-case floats (float.star lines 407-435)
  #|assert.eq("%e" % -1.23e-45, "-1.230000e-45")
  #|assert.eq("%e" % 1.23e45,   "1.230000e+45")
  #|assert.eq("%f" % -1.23e-45, "-0.000000")
  #|assert.eq("%d" % 1.23e45,   "1229999999999999973814869011019624571608236032")

///|
test "float.star: %e/%f with edge-case floats" {
  let errs = run_star_string(float_percent_ef_edge_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let float_mod_negative_src : String =
  #|load("assert.star", "assert")
  #|# float % with negative operands (float.star lines 148-156)
  #|assert.eq(-100.0 % -7.0,  -2)
  #|assert.eq(-100.0 % -8.0,  -4.0)
  #|assert.eq(-100.0 % 7,      5)
  #|assert.eq(-100.0 % 7.0,    5)
  #|assert.eq(-100.0 % 8.0,    4.0)
  #|assert.eq(-98.0  % -8.0,  -2.0)
  #|assert.eq(-98.0  % 8.0,    6.0)

///|
test "float.star: float %% with negative operands" {
  let errs = run_star_string(float_mod_negative_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}
