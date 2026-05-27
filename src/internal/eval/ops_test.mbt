// Operator tests for eval: string/float/bitwise/power/in/slice/subscript.
// All tests go through eval_expr / exec_file to exercise the full pipeline.

///|
fn eval_op(src : String) -> Result[@value.Value, @errors.EvalError] {
  let t = Thread::new("test")
  let env = @value.StarlarkDict::new()
  eval_expr(t, "<test>", src, env)
}

// --- String operators ---

///|
test "eval_expr: string concatenation produces joined string" {
  match eval_op("\"hello\" + \" world\"") {
    Ok(@value.Value::StrVal(s)) => assert_eq(s.raw, "hello world")
    _ => assert_true(false)
  }
}

///|
test "eval_expr: string repeated by integer count" {
  match eval_op("\"ab\" * 3") {
    Ok(@value.Value::StrVal(s)) => assert_eq(s.raw, "ababab")
    _ => assert_true(false)
  }
}

///|
test "eval_expr: integer times string is same as string times integer" {
  match eval_op("3 * \"ab\"") {
    Ok(@value.Value::StrVal(s)) => assert_eq(s.raw, "ababab")
    _ => assert_true(false)
  }
}

///|
test "eval_expr: string repeated zero times yields empty string" {
  match eval_op("\"ab\" * 0") {
    Ok(@value.Value::StrVal(s)) => assert_eq(s.raw, "")
    _ => assert_true(false)
  }
}

///|
test "eval_expr: list concatenation merges both lists" {
  match eval_op("[1, 2] + [3, 4]") {
    Ok(@value.Value::ListVal(l)) => assert_eq(l.length(), 4)
    _ => assert_true(false)
  }
}

///|
test "eval_expr: list repeated by integer count" {
  match eval_op("[1, 2] * 3") {
    Ok(@value.Value::ListVal(l)) => assert_eq(l.length(), 6)
    _ => assert_true(false)
  }
}

///|
test "eval_expr: tuple concatenation merges both tuples" {
  match eval_op("(1, 2) + (3, 4)") {
    Ok(@value.Value::TupleVal(t)) => assert_eq(t.length(), 4)
    _ => assert_true(false)
  }
}

// --- Float arithmetic ---

///|
test "eval_expr: float addition produces correct sum" {
  assert_true(eval_op("1.5 + 2.5") is Ok(@value.Value::FloatVal(4.0)))
}

///|
test "eval_expr: float subtraction produces correct difference" {
  assert_true(eval_op("5.0 - 1.5") is Ok(@value.Value::FloatVal(3.5)))
}

///|
test "eval_expr: float multiplication produces correct product" {
  assert_true(eval_op("2.0 * 3.0") is Ok(@value.Value::FloatVal(6.0)))
}

///|
test "eval_expr: int divided by int using true division returns float" {
  assert_true(eval_op("7 / 2") is Ok(@value.Value::FloatVal(3.5)))
}

///|
test "eval_expr: mixed int-float addition promotes to float" {
  assert_true(eval_op("1 + 1.5") is Ok(@value.Value::FloatVal(2.5)))
}

///|
test "eval_expr: float floor division truncates toward negative infinity" {
  assert_true(eval_op("7.0 // 2.0") is Ok(@value.Value::FloatVal(3.0)))
}

// --- Power operator ---

///|
test "eval_expr: integer power computes correctly" {
  assert_true(eval_op("2 ** 10") is Ok(@value.Value::IntVal(1024L)))
}

///|
test "eval_expr: power of zero always returns one" {
  assert_true(eval_op("99 ** 0") is Ok(@value.Value::IntVal(1L)))
}

///|
test "eval_expr: negative integer exponent raises error" {
  assert_true(eval_op("2 ** -1") is Err(_))
}

// --- Bitwise operations ---

///|
test "eval_expr: bitwise and on integers" {
  assert_true(eval_op("0b1100 & 0b1010") is Ok(@value.Value::IntVal(0b1000L)))
}

///|
test "eval_expr: bitwise or on integers" {
  assert_true(eval_op("0b1100 | 0b1010") is Ok(@value.Value::IntVal(0b1110L)))
}

///|
test "eval_expr: bitwise xor on integers" {
  assert_true(eval_op("0b1100 ^ 0b1010") is Ok(@value.Value::IntVal(0b0110L)))
}

///|
test "eval_expr: left shift multiplies by power of two" {
  assert_true(eval_op("1 << 4") is Ok(@value.Value::IntVal(16L)))
}

///|
test "eval_expr: right shift divides by power of two" {
  assert_true(eval_op("16 >> 2") is Ok(@value.Value::IntVal(4L)))
}

///|
test "eval_expr: bitwise not flips all bits" {
  assert_true(eval_op("~0") is Ok(@value.Value::IntVal(-1L)))
  assert_true(eval_op("~(-1)") is Ok(@value.Value::IntVal(0L)))
}

///|
test "eval_expr: unary plus leaves integer unchanged" {
  assert_true(eval_op("+5") is Ok(@value.Value::IntVal(5L)))
}

// --- Comparison operators (untested edge cases) ---

///|
test "eval_expr: less-than-or-equal holds when equal" {
  assert_true(eval_op("3 <= 3") is Ok(@value.Value::BoolVal(true)))
}

///|
test "eval_expr: greater-than-or-equal holds when equal" {
  assert_true(eval_op("3 >= 3") is Ok(@value.Value::BoolVal(true)))
}

///|
test "eval_expr: string comparison uses lexicographic byte order" {
  assert_true(eval_op("\"abc\" < \"abd\"") is Ok(@value.Value::BoolVal(true)))
  assert_true(eval_op("\"b\" > \"a\"") is Ok(@value.Value::BoolVal(true)))
}

// --- in / not in operators ---

///|
test "eval_expr: in operator finds element present in list" {
  assert_true(eval_op("2 in [1, 2, 3]") is Ok(@value.Value::BoolVal(true)))
}

///|
test "eval_expr: in operator returns false when element absent from list" {
  assert_true(eval_op("9 in [1, 2, 3]") is Ok(@value.Value::BoolVal(false)))
}

///|
test "eval_expr: not in operator returns true when element absent" {
  assert_true(eval_op("9 not in [1, 2, 3]") is Ok(@value.Value::BoolVal(true)))
}

///|
test "eval_expr: in operator on dict checks keys not values" {
  assert_true(
    eval_op("\"a\" in {\"a\": 1, \"b\": 2}") is Ok(@value.Value::BoolVal(true)),
  )
  assert_true(eval_op("1 in {\"a\": 1}") is Ok(@value.Value::BoolVal(false)))
}

///|
test "eval_expr: in operator checks substring membership in string" {
  assert_true(
    eval_op("\"ell\" in \"hello\"") is Ok(@value.Value::BoolVal(true)),
  )
  assert_true(
    eval_op("\"xyz\" in \"hello\"") is Ok(@value.Value::BoolVal(false)),
  )
}

///|
test "eval_expr: in operator checks membership in tuple" {
  assert_true(eval_op("2 in (1, 2, 3)") is Ok(@value.Value::BoolVal(true)))
}

///|
test "eval_expr: in operator checks membership in set" {
  assert_true(eval_op("1 in {1, 2}") is Ok(@value.Value::BoolVal(true)))
  assert_true(eval_op("9 in {1, 2}") is Ok(@value.Value::BoolVal(false)))
}

///|
test "eval_expr: in operator checks membership in range" {
  assert_true(
    eval_op("4 in range(0, 10, 2)") is Ok(@value.Value::BoolVal(true)),
  )
  assert_true(
    eval_op("3 in range(0, 10, 2)") is Ok(@value.Value::BoolVal(false)),
  )
}

// --- Subscript / index access ---

///|
test "eval_expr: list subscript access by positive index" {
  assert_true(eval_op("[10, 20, 30][1]") is Ok(@value.Value::IntVal(20L)))
}

///|
test "eval_expr: list subscript access by negative index counts from end" {
  assert_true(eval_op("[10, 20, 30][-1]") is Ok(@value.Value::IntVal(30L)))
}

///|
test "eval_expr: string subscript returns single-byte string" {
  match eval_op("\"abc\"[0]") {
    Ok(@value.Value::StrVal(s)) => {
      assert_eq(s.byte_len(), 1)
      assert_eq(s.byte_at(0), b'a')
    }
    _ => assert_true(false)
  }
}

///|
test "eval_expr: dict subscript access retrieves associated value" {
  assert_true(eval_op("{\"x\": 42}[\"x\"]") is Ok(@value.Value::IntVal(42L)))
}

///|
test "eval_expr: dict subscript with missing key raises error" {
  assert_true(eval_op("{\"x\": 1}[\"y\"]") is Err(_))
}

///|
test "eval_expr: range subscript accesses element by index" {
  assert_true(eval_op("range(0, 10, 2)[3]") is Ok(@value.Value::IntVal(6L)))
}

///|
test "eval_expr: list subscript out of range raises error" {
  assert_true(eval_op("[1, 2, 3][9]") is Err(_))
}

// --- Slice ---

///|
test "eval_expr: list slice with positive bounds" {
  match eval_op("[1, 2, 3, 4, 5][1:4]") {
    Ok(@value.Value::ListVal(l)) => {
      assert_eq(l.length(), 3)
      assert_true(l.get(0) == @value.Value::IntVal(2L))
      assert_true(l.get(2) == @value.Value::IntVal(4L))
    }
    _ => assert_true(false)
  }
}

///|
test "eval_expr: list slice with omitted bounds returns full copy" {
  match eval_op("[1, 2, 3][:]") {
    Ok(@value.Value::ListVal(l)) => assert_eq(l.length(), 3)
    _ => assert_true(false)
  }
}

///|
test "eval_expr: list slice with negative step reverses list" {
  match eval_op("[1, 2, 3, 4, 5][::-1]") {
    Ok(@value.Value::ListVal(l)) => {
      assert_eq(l.length(), 5)
      assert_true(l.get(0) == @value.Value::IntVal(5L))
      assert_true(l.get(4) == @value.Value::IntVal(1L))
    }
    _ => assert_true(false)
  }
}

///|
test "eval_expr: string slice extracts byte subsequence" {
  match eval_op("\"hello\"[1:4]") {
    Ok(@value.Value::StrVal(s)) => assert_eq(s.raw, "ell")
    _ => assert_true(false)
  }
}

///|
test "eval_expr: string slice with step skips bytes" {
  match eval_op("\"abcde\"[::2]") {
    Ok(@value.Value::StrVal(s)) => assert_eq(s.raw, "ace")
    _ => assert_true(false)
  }
}

///|
test "eval_expr: slice step of zero raises error" {
  assert_true(eval_op("[1, 2, 3][::0]") is Err(_))
}

// --- Type error cases ---

///|
test "eval_expr: Bool does not participate in integer arithmetic" {
  assert_true(eval_op("True + True") is Err(_))
  assert_true(eval_op("True + 1") is Err(_))
  assert_true(eval_op("False - 1") is Err(_))
}

///|
test "eval_expr: adding incompatible types raises error" {
  assert_true(eval_op("\"hello\" + 1") is Err(_))
  assert_true(eval_op("1 + [1, 2]") is Err(_))
}

///|
test "eval_expr: modulo by zero raises error" {
  assert_true(eval_op("7 % 0") is Err(_))
}

// --- Negative operand semantics ---

///|
test "eval_expr: floor division of negative dividend rounds toward negative infinity" {
  assert_true(eval_op("-7 // 2") is Ok(@value.Value::IntVal(-4L)))
  assert_true(eval_op("7 // -2") is Ok(@value.Value::IntVal(-4L)))
}

///|
test "eval_expr: modulo sign follows divisor not dividend" {
  assert_true(eval_op("-7 % 2") is Ok(@value.Value::IntVal(1L)))
  assert_true(eval_op("7 % -2") is Ok(@value.Value::IntVal(-1L)))
}
