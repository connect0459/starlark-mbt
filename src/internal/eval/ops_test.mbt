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
    Ok(@value.Value::String(s)) => assert_eq(s.raw(), "hello world")
    _ => assert_true(false)
  }
}

///|
test "eval_expr: string repeated by integer count" {
  match eval_op("\"ab\" * 3") {
    Ok(@value.Value::String(s)) => assert_eq(s.raw(), "ababab")
    _ => assert_true(false)
  }
}

///|
test "eval_expr: integer times string is same as string times integer" {
  match eval_op("3 * \"ab\"") {
    Ok(@value.Value::String(s)) => assert_eq(s.raw(), "ababab")
    _ => assert_true(false)
  }
}

///|
test "eval_expr: string repeated zero times yields empty string" {
  match eval_op("\"ab\" * 0") {
    Ok(@value.Value::String(s)) => assert_eq(s.raw(), "")
    _ => assert_true(false)
  }
}

///|
test "eval_expr: list concatenation merges both lists" {
  match eval_op("[1, 2] + [3, 4]") {
    Ok(@value.Value::List(l)) => assert_eq(l.length(), 4)
    _ => assert_true(false)
  }
}

///|
test "eval_expr: list repeated by integer count" {
  match eval_op("[1, 2] * 3") {
    Ok(@value.Value::List(l)) => assert_eq(l.length(), 6)
    _ => assert_true(false)
  }
}

///|
test "eval_expr: tuple concatenation merges both tuples" {
  match eval_op("(1, 2) + (3, 4)") {
    Ok(@value.Value::Tuple(t)) => assert_eq(t.length(), 4)
    _ => assert_true(false)
  }
}

// --- Float arithmetic ---

///|
test "eval_expr: float addition produces correct sum" {
  assert_true(eval_op("1.5 + 2.5") is Ok(@value.Value::Float(4.0)))
}

///|
test "eval_expr: float subtraction produces correct difference" {
  assert_true(eval_op("5.0 - 1.5") is Ok(@value.Value::Float(3.5)))
}

///|
test "eval_expr: float multiplication produces correct product" {
  assert_true(eval_op("2.0 * 3.0") is Ok(@value.Value::Float(6.0)))
}

///|
test "eval_expr: int divided by int using true division returns float" {
  assert_true(eval_op("7 / 2") is Ok(@value.Value::Float(3.5)))
}

///|
test "eval_expr: mixed int-float addition promotes to float" {
  assert_true(eval_op("1 + 1.5") is Ok(@value.Value::Float(2.5)))
}

///|
test "eval_expr: float floor division truncates toward negative infinity" {
  assert_true(eval_op("7.0 // 2.0") is Ok(@value.Value::Float(3.0)))
}

// --- Power operator ---

///|
test "eval_expr: integer power computes correctly" {
  assert_true(eval_op("2 ** 10") is Ok(@value.Value::Int(1024N)))
}

///|
test "eval_expr: power of zero always returns one" {
  assert_true(eval_op("99 ** 0") is Ok(@value.Value::Int(1N)))
}

///|
test "eval_expr: negative integer exponent raises error" {
  assert_true(eval_op("2 ** -1") is Err(_))
}

///|
test "eval_expr: float power with non-integral exponent computes square root" {
  match eval_op("2.0 ** 0.5") {
    Ok(@value.Value::Float(f)) =>
      assert_true((f - 1.4142135623730951).abs() < 1.0e-12)
    _ => assert_true(false)
  }
}

// --- Bitwise operations ---

///|
test "eval_expr: bitwise and on integers" {
  assert_true(eval_op("0b1100 & 0b1010") is Ok(@value.Value::Int(0b1000N)))
}

///|
test "eval_expr: bitwise or on integers" {
  assert_true(eval_op("0b1100 | 0b1010") is Ok(@value.Value::Int(0b1110N)))
}

///|
test "eval_expr: bitwise xor on integers" {
  assert_true(eval_op("0b1100 ^ 0b1010") is Ok(@value.Value::Int(0b0110N)))
}

///|
test "eval_expr: left shift multiplies by power of two" {
  assert_true(eval_op("1 << 4") is Ok(@value.Value::Int(16N)))
}

///|
test "eval_expr: right shift divides by power of two" {
  assert_true(eval_op("16 >> 2") is Ok(@value.Value::Int(4N)))
}

///|
test "eval_expr: bitwise not flips all bits" {
  assert_true(eval_op("~0") is Ok(@value.Value::Int(-1N)))
  assert_true(eval_op("~(-1)") is Ok(@value.Value::Int(0N)))
}

///|
test "eval_expr: unary plus leaves integer unchanged" {
  assert_true(eval_op("+5") is Ok(@value.Value::Int(5N)))
}

// --- Comparison operators (untested edge cases) ---

///|
test "eval_expr: less-than-or-equal holds when equal" {
  assert_true(eval_op("3 <= 3") is Ok(@value.Value::Bool(true)))
}

///|
test "eval_expr: greater-than-or-equal holds when equal" {
  assert_true(eval_op("3 >= 3") is Ok(@value.Value::Bool(true)))
}

///|
test "eval_expr: string comparison uses lexicographic byte order" {
  assert_true(eval_op("\"abc\" < \"abd\"") is Ok(@value.Value::Bool(true)))
  assert_true(eval_op("\"b\" > \"a\"") is Ok(@value.Value::Bool(true)))
}

// --- in / not in operators ---

///|
test "eval_expr: in operator finds element present in list" {
  assert_true(eval_op("2 in [1, 2, 3]") is Ok(@value.Value::Bool(true)))
}

///|
test "eval_expr: in operator returns false when element absent from list" {
  assert_true(eval_op("9 in [1, 2, 3]") is Ok(@value.Value::Bool(false)))
}

///|
test "eval_expr: not in operator returns true when element absent" {
  assert_true(eval_op("9 not in [1, 2, 3]") is Ok(@value.Value::Bool(true)))
}

///|
test "eval_expr: in operator on dict checks keys not values" {
  assert_true(
    eval_op("\"a\" in {\"a\": 1, \"b\": 2}") is Ok(@value.Value::Bool(true)),
  )
  assert_true(eval_op("1 in {\"a\": 1}") is Ok(@value.Value::Bool(false)))
}

///|
test "eval_expr: in operator checks substring membership in string" {
  assert_true(eval_op("\"ell\" in \"hello\"") is Ok(@value.Value::Bool(true)))
  assert_true(eval_op("\"xyz\" in \"hello\"") is Ok(@value.Value::Bool(false)))
}

///|
test "eval_expr: in operator checks membership in tuple" {
  assert_true(eval_op("2 in (1, 2, 3)") is Ok(@value.Value::Bool(true)))
}

///|
test "eval_expr: in operator checks membership in set" {
  assert_true(eval_op("1 in {1, 2}") is Ok(@value.Value::Bool(true)))
  assert_true(eval_op("9 in {1, 2}") is Ok(@value.Value::Bool(false)))
}

///|
test "eval_expr: in operator checks membership in range" {
  assert_true(eval_op("4 in range(0, 10, 2)") is Ok(@value.Value::Bool(true)))
  assert_true(eval_op("3 in range(0, 10, 2)") is Ok(@value.Value::Bool(false)))
}

// --- Subscript / index access ---

///|
test "eval_expr: list subscript access by positive index" {
  assert_true(eval_op("[10, 20, 30][1]") is Ok(@value.Value::Int(20N)))
}

///|
test "eval_expr: list subscript access by negative index counts from end" {
  assert_true(eval_op("[10, 20, 30][-1]") is Ok(@value.Value::Int(30N)))
}

///|
test "eval_expr: string subscript returns single-byte string" {
  match eval_op("\"abc\"[0]") {
    Ok(@value.Value::String(s)) => {
      assert_eq(s.byte_len(), 1)
      assert_eq(s.byte_at(0), b'a')
    }
    _ => assert_true(false)
  }
}

///|
test "eval_expr: dict subscript access retrieves associated value" {
  assert_true(eval_op("{\"x\": 42}[\"x\"]") is Ok(@value.Value::Int(42N)))
}

///|
test "eval_expr: dict subscript with missing key raises error" {
  assert_true(eval_op("{\"x\": 1}[\"y\"]") is Err(_))
}

///|
test "eval_expr: range subscript accesses element by index" {
  assert_true(eval_op("range(0, 10, 2)[3]") is Ok(@value.Value::Int(6N)))
}

///|
test "eval_expr: list subscript out of range raises error" {
  assert_true(eval_op("[1, 2, 3][9]") is Err(_))
}

// --- Slice ---

///|
test "eval_expr: list slice with positive bounds" {
  match eval_op("[1, 2, 3, 4, 5][1:4]") {
    Ok(@value.Value::List(l)) => {
      assert_eq(l.length(), 3)
      assert_true(l.get(0) == @value.Value::Int(2N))
      assert_true(l.get(2) == @value.Value::Int(4N))
    }
    _ => assert_true(false)
  }
}

///|
test "eval_expr: list slice with omitted bounds returns full copy" {
  match eval_op("[1, 2, 3][:]") {
    Ok(@value.Value::List(l)) => assert_eq(l.length(), 3)
    _ => assert_true(false)
  }
}

///|
test "eval_expr: list slice with negative step reverses list" {
  match eval_op("[1, 2, 3, 4, 5][::-1]") {
    Ok(@value.Value::List(l)) => {
      assert_eq(l.length(), 5)
      assert_true(l.get(0) == @value.Value::Int(5N))
      assert_true(l.get(4) == @value.Value::Int(1N))
    }
    _ => assert_true(false)
  }
}

///|
test "eval_expr: string slice extracts byte subsequence" {
  match eval_op("\"hello\"[1:4]") {
    Ok(@value.Value::String(s)) => assert_eq(s.raw(), "ell")
    _ => assert_true(false)
  }
}

///|
test "eval_expr: string slice with step skips bytes" {
  match eval_op("\"abcde\"[::2]") {
    Ok(@value.Value::String(s)) => assert_eq(s.raw(), "ace")
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
  assert_true(eval_op("-7 // 2") is Ok(@value.Value::Int(-4N)))
  assert_true(eval_op("7 // -2") is Ok(@value.Value::Int(-4N)))
}

///|
test "eval_expr: modulo sign follows divisor not dividend" {
  assert_true(eval_op("-7 % 2") is Ok(@value.Value::Int(1N)))
  assert_true(eval_op("7 % -2") is Ok(@value.Value::Int(-1N)))
}

// --- ExtVal protocol dispatch ---

///|
fn make_ext_seq(items : Array[@value.Value]) -> @value.Value {
  @value.Value::ExtVal(
    @value.CustomValue::new(fn() { "myseq" }, fn() { true }, fn() {
      let parts = items.map(fn(v) { @value.repr(v) }).join(", ")
      "myseq([\{parts}])"
    })
    .with_length(fn() { items.length() })
    .with_get_index(fn(i) { Ok(items[i]) })
    .with_set_index(fn(i, v) {
      items[i] = v
      Ok(())
    })
    .with_slice(fn(start, stop, step) {
      let result : Array[@value.Value] = []
      if step > 0 {
        let mut i = start
        while i < stop {
          result.push(items[i])
          i += step
        }
      } else {
        let mut i = start
        while i > stop {
          result.push(items[i])
          i += step
        }
      }
      Ok(@value.Value::Tuple(result))
    }),
  )
}

///|
fn eval_with_env(
  src : String,
  bindings : Array[(String, @value.Value)],
) -> Result[@value.Value, @errors.EvalError] {
  let t = Thread::new("test")
  let env = @value.StarlarkDict::new()
  for pair in bindings {
    let (name, v) = pair
    let key = @value.Value::String(@value.StarlarkString::new(name))
    env.set(key, v) |> ignore
  }
  eval_expr(t, "<test>", src, env)
}

///|
fn exec_with_predeclared(
  src : String,
  bindings : Array[(String, @value.Value)],
) -> Result[Module, @errors.EvalError] {
  let t = Thread::new("test")
  let pd = Predeclared::new()
  for pair in bindings {
    let (name, v) = pair
    pd.set(name, v)
  }
  exec_file_with_predeclared(t, "<test>", src, Options::default(), pd)
}

///|
test "eval_expr: ExtVal with get_index supports subscript read" {
  let seq = make_ext_seq([
    @value.Value::Int(10N),
    @value.Value::Int(20N),
    @value.Value::Int(30N),
  ])
  assert_true(eval_with_env("s[0]", [("s", seq)]) is Ok(@value.Value::Int(10N)))
  assert_true(eval_with_env("s[2]", [("s", seq)]) is Ok(@value.Value::Int(30N)))
}

///|
test "eval_expr: ExtVal with get_index supports negative index" {
  let seq = make_ext_seq([
    @value.Value::Int(10N),
    @value.Value::Int(20N),
    @value.Value::Int(30N),
  ])
  assert_true(
    eval_with_env("s[-1]", [("s", seq)]) is Ok(@value.Value::Int(30N)),
  )
  assert_true(
    eval_with_env("s[-3]", [("s", seq)]) is Ok(@value.Value::Int(10N)),
  )
}

///|
test "eval_expr: ExtVal without get_index raises error on subscript" {
  let cv = @value.CustomValue::new(fn() { "noseq" }, fn() { true }, fn() { "" })
  let v = @value.Value::ExtVal(cv)
  assert_true(eval_with_env("x[0]", [("x", v)]) is Err(_))
}

///|
test "exec_file: ExtVal with set_index supports subscript assignment" {
  let seq = make_ext_seq([
    @value.Value::Int(1N),
    @value.Value::Int(2N),
    @value.Value::Int(3N),
  ])
  match exec_with_predeclared("s[1] = 99\nresult = s[1]", [("s", seq)]) {
    Ok(m) => assert_true(m.get("result") == Some(@value.Value::Int(99N)))
    Err(e) => fail("unexpected error: \{e.msg()}")
  }
}

///|
test "eval_expr: ExtVal with slice supports slice notation" {
  let seq = make_ext_seq([
    @value.Value::Int(0N),
    @value.Value::Int(1N),
    @value.Value::Int(2N),
    @value.Value::Int(3N),
  ])
  match eval_with_env("s[1:3]", [("s", seq)]) {
    Ok(@value.Value::Tuple(t)) => assert_eq(t.length(), 2)
    Ok(other) => fail("expected Tuple, got \{@value.repr(other)}")
    Err(e) => fail("unexpected error: \{e.msg()}")
  }
}

// --- Error message format ---

///|
fn op_err(src : String) -> String {
  match eval_op(src) {
    Err(e) => e.msg()
    Ok(_) => ""
  }
}

///|
fn op_ok_str(src : String) -> String {
  match eval_op(src) {
    Ok(@value.Value::String(s)) => s.raw()
    Ok(other) => "non-string: \{@value.repr(other)}"
    Err(e) => "error: \{e.msg()}"
  }
}

///|
test "eval_expr: %f rounds half-to-even on the exact value" {
  // 5e-07 stored as a double is just below 0.0000005, so it rounds DOWN to
  // 0.000000 — the half-up-on-inexact-intermediate algorithm wrongly produced
  // 0.000001.
  assert_eq(op_ok_str("\"%f\" % 5e-07"), "0.000000")
  assert_eq(op_ok_str("\"%f\" % 1.5e-06"), "0.000002")
  assert_eq(op_ok_str("\"%f\" % 2.5e-06"), "0.000003")
  assert_eq(op_ok_str("\"%f\" % 123.456789"), "123.456789")
  // carry that ripples through the integer part
  assert_eq(op_ok_str("\"%f\" % 9.9999996"), "10.000000")
  assert_eq(op_ok_str("\"%f\" % -0.0"), "-0.000000")
  assert_eq(op_ok_str("\"%f\" % 1e20"), "100000000000000000000.000000")
}

///|
test "eval_expr: %e rounds half-to-even and propagates exponent carry" {
  assert_eq(op_ok_str("\"%e\" % 5e-07"), "5.000000e-07")
  assert_eq(op_ok_str("\"%e\" % 123.456789"), "1.234568e+02")
  // mantissa rounds up to 10.0000000 → renormalised to 1.000000e+01
  assert_eq(op_ok_str("\"%e\" % 9.9999996"), "1.000000e+01")
  assert_eq(op_ok_str("\"%e\" % 999999.96"), "1.000000e+06")
  assert_eq(op_ok_str("\"%E\" % 1e20"), "1.000000E+20")
  assert_eq(op_ok_str("\"%e\" % 0.0"), "0.000000e+00")
}

///|
test "eval_expr: %d on non-number wraps the NumberToInt cause" {
  assert_eq(
    op_err("\"%d\" % \"x\""),
    "%d format requires integer: cannot convert string to int",
  )
  assert_eq(
    op_err("\"%x\" % True"),
    "%x format requires integer: cannot convert bool to int",
  )
}

///|
test "eval_expr: %c out-of-range reports the offending value" {
  assert_eq(
    op_err("\"%c\" % 1114112"),
    "%c format requires a valid Unicode code point, got 1114112",
  )
}

///|
test "eval_expr: %c on non-int non-string reports int-or-string requirement" {
  assert_eq(
    op_err("\"%c\" % True"),
    "%c format requires int or single-character string, not bool",
  )
}

///|
test "eval_expr: unknown conversion verb reports a descriptive error" {
  assert_eq(op_err("\"%z\" % 1"), "unknown conversion %z")
}

///|
test "eval_expr: trailing percent reports incomplete or missing argument" {
  assert_eq(op_err("\"%\" % 5"), "incomplete format")
  assert_eq(op_err("\"%\" % ()"), "not enough arguments for format string")
}

///|
test "eval_expr: unary minus on string reports unknown-unary-op" {
  assert_eq(op_err("-\"x\""), "unknown unary op: - string")
}

///|
test "eval_expr: enumerate on non-iterable carries name prefix" {
  assert_eq(op_err("enumerate(5)"), "enumerate: got int, want iterable")
}

///|
test "exec_file: item assignment on tuple reports a descriptive error" {
  match exec_b("t = (1, 2)\nt[0] = 9") {
    Ok(_) => assert_true(false)
    Err(e) => assert_eq(e.msg(), "tuple value does not support item assignment")
  }
}

///|
test "exec_file: tuple unpack mismatch uses got/want order" {
  match exec_b("a, b = 1, 2, 3") {
    Ok(_) => assert_true(false)
    Err(e) => assert_eq(e.msg(), "too many values to unpack (got 3, want 2)")
  }
}

///|
test "eval_expr: ExtVal without slice raises error on slice" {
  let cv = @value.CustomValue::new(fn() { "noslice" }, fn() { true }, fn() {
    ""
  })
  let v = @value.Value::ExtVal(cv)
  assert_true(eval_with_env("x[0:1]", [("x", v)]) is Err(_))
}
