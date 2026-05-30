// Integration tests derived from int.star (bazelbuild/starlark test suite).

///|
let int_star_src : String =
  #|load("assert.star", "assert")
  #|
  #|assert.eq(0 - 1, -1)
  #|assert.eq(0 + 1, +1)
  #|assert.eq(1 + 1, 2)
  #|assert.eq(5 + 7, 12)
  #|assert.eq(5 * 7, 35)
  #|assert.eq(5 - 7, -2)
  #|
  #|maxint64 = (1 << 63) - 1
  #|minint64 = -1 << 63
  #|maxint32 = (1 << 31) - 1
  #|minint32 = -1 << 31
  #|assert.eq(maxint64, 9223372036854775807)
  #|assert.eq(minint64, -9223372036854775808)
  #|assert.eq(maxint32, 2147483647)
  #|assert.eq(minint32, -2147483648)
  #|
  #|def truth():
  #|    assert.true(not 0)
  #|    for m in [1, maxint32]:
  #|        assert.true(123 * m)
  #|        assert.true(-1 * m)
  #|
  #|truth()
  #|
  #|def division():
  #|    for m in [1, maxint32]:
  #|        assert.eq((100 * m) // (7 * m), 14)
  #|        assert.eq((100 * m) // (-7 * m), -15)
  #|        assert.eq((-100 * m) // (7 * m), -15)
  #|        assert.eq((-100 * m) // (-7 * m), 14)
  #|        assert.eq((98 * m) // (7 * m), 14)
  #|        assert.eq((98 * m) // (-7 * m), -14)
  #|        assert.eq((-98 * m) // (7 * m), -14)
  #|        assert.eq((-98 * m) // (-7 * m), 14)
  #|
  #|division()
  #|
  #|def remainder():
  #|    for m in [1, maxint32]:
  #|        assert.eq((100 * m) % (7 * m), 2 * m)
  #|        assert.eq((100 * m) % (-7 * m), -5 * m)
  #|        assert.eq((-100 * m) % (7 * m), 5 * m)
  #|        assert.eq((-100 * m) % (-7 * m), -2 * m)
  #|        assert.eq((98 * m) % (7 * m), 0)
  #|        assert.eq((98 * m) % (-7 * m), 0)
  #|        assert.eq((-98 * m) % (7 * m), 0)
  #|        assert.eq((-98 * m) % (-7 * m), 0)
  #|
  #|remainder()
  #|
  #|def compound():
  #|    x = 1
  #|    x += 1
  #|    assert.eq(x, 2)
  #|    x -= 3
  #|    assert.eq(x, -1)
  #|    x *= 39
  #|    assert.eq(x, -39)
  #|    x //= 4
  #|    assert.eq(x, -10)
  #|    x /= -2
  #|    assert.eq(x, 5)
  #|    x %= 3
  #|    assert.eq(x, 2)
  #|    x = 2
  #|    x &= 1
  #|    assert.eq(x, 0)
  #|    x |= 2
  #|    assert.eq(x, 2)
  #|    x ^= 3
  #|    assert.eq(x, 1)
  #|    x <<= 2
  #|    assert.eq(x, 4)
  #|    x >>= 2
  #|    assert.eq(x, 1)
  #|
  #|compound()
  #|
  #|assert.fails(int, "missing argument")
  #|assert.eq(int(False), 0)
  #|assert.eq(int(True), 1)
  #|assert.eq(int(3), 3)
  #|assert.eq(int(3.1), 3)
  #|assert.fails(lambda: int(3, base = 10), "non-string with explicit base")
  #|assert.fails(lambda: int(True, 10), "non-string with explicit base")
  #|assert.eq(int("123"), 123)
  #|assert.eq(int("-123"), -123)
  #|assert.eq(int("0123"), 123)
  #|assert.eq(int("-0123"), -123)
  #|assert.fails(lambda: int("0x12"), "invalid literal with base 10")
  #|assert.fails(lambda: int("-0x12"), "invalid literal with base 10")
  #|
  #|assert.eq(int("0"), 0)
  #|assert.eq(int("00"), 0)
  #|assert.eq(int("0", base = 10), 0)
  #|assert.eq(int("00", base = 10), 0)
  #|assert.eq(int("0", base = 8), 0)
  #|assert.eq(int("00", base = 8), 0)
  #|assert.eq(int("-0"), 0)
  #|assert.eq(int("-00"), 0)
  #|assert.eq(int("-0", base = 10), 0)
  #|assert.eq(int("-00", base = 10), 0)
  #|assert.eq(int("-0", base = 8), 0)
  #|assert.eq(int("-00", base = 8), 0)
  #|assert.eq(int("+0"), 0)
  #|assert.eq(int("+00"), 0)
  #|assert.eq(int("+0", base = 10), 0)
  #|assert.eq(int("+00", base = 10), 0)
  #|assert.eq(int("+0", base = 8), 0)
  #|assert.eq(int("+00", base = 8), 0)
  #|assert.eq(int("11", base = 9), 10)
  #|assert.eq(int("-11", base = 9), -10)
  #|assert.eq(int("10011", base = 2), 19)
  #|assert.eq(int("-10011", base = 2), -19)
  #|assert.eq(int("123", 8), 83)
  #|assert.eq(int("-123", 8), -83)
  #|assert.eq(int("0123", 8), 83)
  #|assert.eq(int("-0123", 8), -83)
  #|assert.eq(int("00123", 8), 83)
  #|assert.eq(int("-00123", 8), -83)
  #|assert.eq(int("0o123", 8), 83)
  #|assert.eq(int("-0o123", 8), -83)
  #|assert.eq(int("123", 7), 66)
  #|assert.eq(int("-123", 7), -66)
  #|assert.eq(int("12", 16), 18)
  #|assert.eq(int("-12", 16), -18)
  #|assert.eq(int("0x12", 16), 18)
  #|assert.eq(int("-0x12", 16), -18)
  #|assert.eq(int("1010", 2), 10)
  #|assert.eq(int("111111101", 2), 509)
  #|assert.eq(int("0b0101", 0), 5)
  #|assert.eq(int("0b0101", 2), 5)
  #|assert.eq(int("0b00000", 0), 0)
  #|assert.fails(lambda: int("0Oxa", 8), "invalid literal with base 8: 0Oxa")
  #|assert.fails(lambda: int("--4"), "invalid literal with base 10: --4")
  #|assert.fails(lambda: int("0x-4", 16), "invalid literal with base 16: 0x-4")
  #|
  #|assert.fails(lambda: int("0b0"), "invalid literal with base 10")
  #|assert.eq(int("0b0", 0), 0)
  #|assert.eq(int("0b0", 2), 0)
  #|assert.eq(int("0b0", 16), 0xb0)
  #|assert.eq(int("0x0b0", 16), 0xb0)
  #|assert.eq(int("0x0b0", 0), 0xb0)
  #|assert.eq(int("0x0b0101", 16), 0x0b0101)
  #|
  #|assert.eq(int("123", 0), 123)
  #|assert.eq(int("+123", 0), 123)
  #|assert.eq(int("-123", 0), -123)
  #|assert.eq(int("0x12", 0), 18)
  #|assert.eq(int("+0x12", 0), 18)
  #|assert.eq(int("-0x12", 0), -18)
  #|assert.eq(int("0o123", 0), 83)
  #|assert.eq(int("+0o123", 0), 83)
  #|assert.eq(int("-0o123", 0), -83)
  #|
  #|assert.eq(1 | 2, 3)
  #|assert.eq(3 | 6, 7)
  #|assert.eq((1 | 2) & (2 | 4), 2)
  #|assert.eq(1 ^ 2, 3)
  #|assert.eq(2 ^ 2, 0)
  #|assert.eq(1 | 0 ^ 1, 1)
  #|assert.eq(~1, -2)
  #|assert.eq(~(-2), 1)
  #|assert.eq(~0, -1)
  #|assert.eq(1 << 2, 4)
  #|assert.eq(2 >> 1, 1)
  #|assert.fails(lambda: 2 << -1, "negative shift count")
  #|assert.fails(lambda: 1 << 512, "shift count too large")
  #|
  #|def comparisons():
  #|    for m in [1, maxint32 / 2, maxint32]:
  #|        assert.lt(-2 * m, -1 * m)
  #|        assert.lt(-1 * m, 0 * m)
  #|        assert.lt(0 * m, 1 * m)
  #|        assert.lt(1 * m, 2 * m)
  #|        assert.true(2 * m >= 2 * m)
  #|        assert.true(2 * m > 1 * m)
  #|        assert.true(1 * m >= 1 * m)
  #|        assert.true(1 * m > 0 * m)
  #|        assert.true(0 * m >= 0 * m)
  #|        assert.true(0 * m > -1 * m)
  #|        assert.true(-1 * m >= -1 * m)
  #|        assert.true(-1 * m > -2 * m)
  #|
  #|comparisons()
  #|
  #|assert.eq(str(maxint64), "9223372036854775807")
  #|assert.eq(str(minint64), "-9223372036854775808")
  #|assert.eq(str(maxint32 + 1), "2147483648")
  #|assert.eq(str(minint32 - 1), "-2147483649")
  #|assert.eq(str(minint32 * minint32), "4611686018427387904")
  #|assert.eq(str(minint32 | maxint32), "-1")
  #|assert.eq(str(minint32 & minint32), "-2147483648")
  #|assert.eq(str(minint32 ^ maxint32), "-1")
  #|assert.eq(str(minint32 // -1), "2147483648")
  #|
  #|assert.eq("%o %x %d" % (0o755, 0xDEADBEEF, 42), "755 deadbeef 42")
  #|nums = [-95, -1, 0, +1, +95]
  #|assert.eq(" ".join(["%o" % x for x in nums]), "-137 -1 0 1 137")
  #|assert.eq(" ".join(["%d" % x for x in nums]), "-95 -1 0 1 95")
  #|assert.eq(" ".join(["%i" % x for x in nums]), "-95 -1 0 1 95")
  #|assert.eq(" ".join(["%x" % x for x in nums]), "-5f -1 0 1 5f")
  #|assert.eq(" ".join(["%X" % x for x in nums]), "-5F -1 0 1 5F")
  #|assert.eq("%o %x %d" % (123, 123, 123), "173 7b 123")
  #|assert.eq("%o %x %d" % (123.1, 123.1, 123.1), "173 7b 123")
  #|assert.fails(lambda: "%d" % True, "cannot convert bool to int")

///|
test "int.star: all assertions pass" {
  let errs = run_star_string(int_star_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let bigint_star_src : String =
  #|load("assert.star", "assert")
  #|
  #|maxint64 = (1 << 63) - 1
  #|minint64 = -1 << 63
  #|maxint32 = (1 << 31) - 1
  #|minint32 = -1 << 31
  #|
  #|# overflow past Int64 range
  #|assert.eq(str(maxint64 + 1), "9223372036854775808")
  #|assert.eq(str(minint64 - 1), "-9223372036854775809")
  #|assert.eq(str(minint64 * minint64), "85070591730234615865843651857942052864")
  #|
  #|# large literals
  #|assert.eq(9223372036854775808, maxint64 + 1)
  #|
  #|# minint64 literal
  #|assert.eq(str(-9223372036854775808), "-9223372036854775808")
  #|
  #|# large multiplications (require BigInt)
  #|assert.eq(0x1000000000000001 * 0x1000000000000001, 0x1000000000000002000000000000001)
  #|assert.eq(1111111111111111 * 1111111111111111, 1234567901234567654320987654321)

///|
test "int.star: bigint precision cases" {
  let errs = run_star_string(bigint_star_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let int_base_mismatch_src : String =
  #|load("assert.star", "assert")
  #|
  #|# int() rejects prefix/base mismatches
  #|assert.fails(lambda: int("0x123", 8), "invalid literal.*base 8")
  #|assert.fails(lambda: int("-0x123", 8), "invalid literal.*base 8")
  #|assert.fails(lambda: int("0o123", 16), "invalid literal.*base 16")
  #|assert.fails(lambda: int("-0o123", 16), "invalid literal.*base 16")
  #|assert.fails(lambda: int("0x110", 2), "invalid literal.*base 2")
  #|
  #|# old-style octal is rejected when base=0
  #|assert.fails(lambda: int("0123", 0), "invalid literal.*base 0")
  #|assert.fails(lambda: int("-0123", 0), "invalid literal.*base 0")
  #|
  #|# double-sign is rejected
  #|assert.fails(lambda: int("++4"), "invalid literal with base 10: ++4")
  #|assert.fails(lambda: int("+-4"), "invalid literal with base 10: +-4")

///|
test "int.star: int() base-mismatch and invalid prefix errors" {
  let errs = run_star_string(int_base_mismatch_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let int_octal_base10_src : String =
  #|load("assert.star", "assert")
  #|# int("0o123") with implicit base=10 is rejected (int.star lines 112-113)
  #|assert.fails(lambda: int("0o123"), "invalid literal.*base 10")
  #|assert.fails(lambda: int("-0o123"), "invalid literal.*base 10")

///|
test "int.star: int(octal-prefixed string) with base=10 raises" {
  let errs = run_star_string(int_octal_base10_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let int_large_string_src : String =
  #|load("assert.star", "assert")
  #|# int() from very large decimal strings (int.star lines 104-105)
  #|assert.eq(int("100000000000000000000"),  10000000000 * 10000000000)
  #|assert.eq(int("-100000000000000000000"), -10000000000 * 10000000000)

///|
test "int.star: int() parses 20-digit decimal strings as BigInt" {
  let errs = run_star_string(int_large_string_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let int_boundary_src : String =
  #|load("assert.star", "assert")
  #|
  #|maxint32 = (1 << 31) - 1
  #|minint32 = -1 << 31
  #|maxuint32 = (1 << 32) - 1
  #|
  #|# Add: crossing int32 boundary
  #|assert.eq(maxint32 + 1, 0x80000000)
  #|assert.eq(minint32 - 1, -0x80000001)
  #|
  #|# Mul: large products requiring BigInt
  #|assert.eq(maxint32 * maxint32, 0x3fffffff00000001)
  #|assert.eq(minint32 * minint32, 0x4000000000000000)
  #|assert.eq(maxuint32 * maxuint32, 0xfffffffe00000001)
  #|assert.eq(minint32 * -1, 0x80000000)
  #|
  #|# Floor div at int32 boundary
  #|assert.eq(minint32 // -1, 0x80000000)
  #|assert.eq((1 << 31) // 2, 0x40000000)
  #|
  #|# Bitwise AND
  #|assert.eq(maxint32 & maxint32, 0x7fffffff)
  #|assert.eq(minint32 & minint32, -0x80000000)
  #|assert.eq((1 << 33) & (1 << 32), 0)
  #|
  #|# Modulo
  #|assert.eq((1 << 32) % 2, 0)
  #|
  #|# Bitwise OR
  #|assert.eq((1 << 32) | 0, 0x100000000)
  #|assert.eq(maxint32 | 0, 0x7fffffff)
  #|assert.eq(maxuint32 | 0, 0xffffffff)
  #|assert.eq(minint32 | minint32, -0x80000000)
  #|
  #|# Bitwise XOR
  #|assert.eq(minint32 ^ -1, 0x7fffffff)
  #|
  #|# Bitwise NOT
  #|assert.eq(~minint32, 0x7fffffff)
  #|assert.eq(~maxint32, -0x80000000)
  #|
  #|# Shift: producing values outside int32/int64 range
  #|assert.eq(1 << 31, 0x80000000)
  #|assert.eq(1 << 32, 0x100000000)
  #|assert.eq((maxint32 + 1) >> 1, 0x40000000)
  #|assert.eq((minint32 * 2) >> 1, -0x80000000)

///|
test "int.star: BigInt arithmetic boundary tests" {
  let errs = run_star_string(int_boundary_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let int_unsupported_type_src : String =
  #|load("assert.star", "assert")
  #|assert.fails(lambda: int([]), "int: cannot convert list to int")
  #|assert.fails(lambda: int(None), "int: cannot convert NoneType to int")
  #|assert.fails(lambda: int({}), "int: cannot convert dict to int")
  #|assert.fails(lambda: int((1, 2)), "int: cannot convert tuple to int")

///|
test "int.star: int() reports a descriptive error for unsupported argument types" {
  let errs = run_star_string(int_unsupported_type_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let int_shift_rshift_src : String =
  #|load("assert.star", "assert")
  #|assert.eq(1 >> 1000, 0)
  #|assert.eq((-1) >> 1000, -1)

///|
test "int.star: right shift with large count returns 0/-1 instead of error" {
  let errs = run_star_string(int_shift_rshift_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let int_base_range_src : String =
  #|load("assert.star", "assert")
  #|assert.fails(lambda: int("a", 1), "int: base must be an integer >= 2 && <= 36")
  #|assert.fails(lambda: int("a", 37), "int: base must be an integer >= 2 && <= 36")
  #|assert.fails(lambda: int("a", -1), "int: base must be an integer >= 2 && <= 36")
  #|# base 0 is valid (auto-detect)
  #|assert.eq(int("0xff", 0), 255)
  #|# edge cases: base 2 and 36 are valid
  #|assert.eq(int("z", 36), 35)
  #|assert.eq(int("1", 2), 1)

///|
test "int.star: int() rejects out-of-range base" {
  let errs = run_star_string(int_base_range_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let div_zero_messages_src : String =
  #|load("assert.star", "assert")
  #|assert.fails(lambda: 1 / 0, "floating-point division by zero")
  #|assert.fails(lambda: 1 / 0.0, "floating-point division by zero")
  #|assert.fails(lambda: 1 // 0, "floored division by zero")
  #|assert.fails(lambda: 1 % 0, "integer modulo by zero")
  #|assert.fails(lambda: 1 % 0.0, "floating-point modulo by zero")
  #|assert.fails(lambda: "abc"[::0], "zero is not a valid slice step")

///|
test "division/modulo/slice-step report descriptive error messages" {
  let errs = run_star_string(div_zero_messages_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let binary_op_messages_src : String =
  #|load("assert.star", "assert")
  #|assert.fails(lambda: 1.0 * "x", "unknown binary op: float * string")
  #|assert.fails(lambda: 1 / "x", "unknown binary op: int / string")
  #|assert.fails(lambda: 1 // "x", "unknown binary op: int // string")
  #|assert.fails(lambda: 1 % [1], "unknown binary op: int % list")
  #|assert.fails(lambda: 1 << 1.0, "unknown binary op: int << float")
  #|assert.fails(lambda: 1 << -3, "negative shift count: -3")
  #|assert.fails(lambda: 1 << 600, "shift count too large: 600")

///|
test "binary-op and shift report descriptive error messages" {
  let errs = run_star_string(binary_op_messages_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}
