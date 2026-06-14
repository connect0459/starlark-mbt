///|
let pi : Double = 3.141592653589793

///|
fn call1(
  m : @value.Value,
  attr : String,
  arg : @value.Value,
) -> Result[@value.Value, String] raise Error {
  match m {
    @value.Value::Module(mod) =>
      match mod.get(attr) {
        Some(@value.Value::Builtin(f)) =>
          match
            f.call_body(
              @value.BuiltinCallCtx::new(fn(_, _, _) { Ok(@value.Value::None) }),
              [arg],
              [],
            ) {
            Some(r) => r
            None => fail("no body")
          }
        _ => fail("attr not found: \{attr}")
      }
    _ => fail("not a module")
  }
}

///|
fn call2(
  m : @value.Value,
  attr : String,
  a : @value.Value,
  b : @value.Value,
) -> Result[@value.Value, String] raise Error {
  match m {
    @value.Value::Module(mod) =>
      match mod.get(attr) {
        Some(@value.Value::Builtin(f)) =>
          match
            f.call_body(
              @value.BuiltinCallCtx::new(fn(_, _, _) { Ok(@value.Value::None) }),
              [a, b],
              [],
            ) {
            Some(r) => r
            None => fail("no body")
          }
        _ => fail("attr not found: \{attr}")
      }
    _ => fail("not a module")
  }
}

///|
fn call_raw(
  m : @value.Value,
  attr : String,
  pos_args : Array[@value.Value],
  kw_args : Array[(String, @value.Value)],
) -> Result[@value.Value, String] raise Error {
  match m {
    @value.Value::Module(mod) =>
      match mod.get(attr) {
        Some(@value.Value::Builtin(f)) =>
          match
            f.call_body(
              @value.BuiltinCallCtx::new(fn(_, _, _) { Ok(@value.Value::None) }),
              pos_args,
              kw_args,
            ) {
            Some(r) => r
            None => fail("no body")
          }
        _ => fail("attr not found: \{attr}")
      }
    _ => fail("not a module")
  }
}

///|
fn fv(x : Double) -> @value.Value {
  @value.Value::Float(x)
}

///|
fn iv(x : Int64) -> @value.Value {
  @value.Value::Int(BigInt::from_int64(x))
}

///|
fn approx(a : Double, b : Double) -> Bool {
  let diff = a - b
  let abs_diff = if diff < 0.0 { -diff } else { diff }
  abs_diff < 1.0e-10
}

///|
fn expect_float(
  r : Result[@value.Value, String],
  expected : Double,
) -> Unit raise Error {
  match r {
    Ok(@value.Value::Float(f)) =>
      if !approx(f, expected) {
        fail("expected \{expected}, got \{f}")
      }
    Ok(v) => fail("expected Float, got \{v.type_name()}")
    Err(e) => fail("expected Ok, got Err(\{e})")
  }
}

///|
fn expect_int(
  r : Result[@value.Value, String],
  expected : Int64,
) -> Unit raise Error {
  match r {
    Ok(@value.Value::Int(i)) =>
      if i != BigInt::from_int64(expected) {
        fail("expected \{expected}, got \{i}")
      }
    Ok(v) => fail("expected Int, got \{v.type_name()}")
    Err(e) => fail("expected Ok, got Err(\{e})")
  }
}

///|
fn expect_err(
  r : Result[@value.Value, String],
  substring : String,
) -> Unit raise Error {
  match r {
    Err(msg) =>
      if !msg.contains(substring) {
        fail("expected error containing '\{substring}', got '\{msg}'")
      }
    Ok(v) => fail("expected Err, got Ok(\{v.repr()})")
  }
}

///|
test "math_module: constants e and pi" {
  let m = math_module()
  match m {
    @value.Value::Module(mod) => {
      match mod.get("e") {
        Some(@value.Value::Float(f)) =>
          assert_true(approx(f, 2.718281828459045))
        _ => fail("e not found or wrong type")
      }
      match mod.get("pi") {
        Some(@value.Value::Float(f)) => assert_true(approx(f, pi))
        _ => fail("pi not found or wrong type")
      }
    }
    _ => fail("expected Module")
  }
}

///|
test "math_module: ceil on float returns int" {
  let m = math_module()
  expect_int(call1(m, "ceil", fv(1.2)), 2L)
  expect_int(call1(m, "ceil", fv(-1.2)), -1L)
  expect_int(call1(m, "ceil", fv(0.0)), 0L)
}

///|
test "math_module: ceil on int returns int passthrough" {
  let m = math_module()
  expect_int(call1(m, "ceil", iv(5L)), 5L)
  expect_int(call1(m, "ceil", iv(-3L)), -3L)
}

///|
test "math_module: ceil on infinity raises error" {
  let m = math_module()
  expect_err(
    call1(m, "ceil", fv(1.0 / 0.0)),
    "cannot convert float infinity to integer",
  )
  expect_err(
    call1(m, "ceil", fv(-1.0 / 0.0)),
    "cannot convert float infinity to integer",
  )
}

///|
test "math_module: ceil on NaN raises error" {
  let m = math_module()
  expect_err(
    call1(m, "ceil", fv(0.0 / 0.0)),
    "cannot convert float NaN to integer",
  )
}

///|
fn expect_exact_err(
  r : Result[@value.Value, String],
  message : String,
) -> Unit raise Error {
  match r {
    Err(msg) => assert_eq(msg, message)
    Ok(v) => fail("expected Err, got Ok(\{v.repr()})")
  }
}

///|
test "math_module: ceil/floor errors carry no name or parameter prefix" {
  let m = math_module()
  let s = @value.Value::String(@value.StarlarkString::new("0"))
  expect_exact_err(call1(m, "ceil", s), "got string, want float or int")
  expect_exact_err(call1(m, "floor", s), "got string, want float or int")
  expect_exact_err(
    call1(m, "ceil", fv(0.0 / 0.0)),
    "cannot convert float NaN to integer",
  )
  expect_exact_err(
    call1(m, "floor", fv(1.0 / 0.0)),
    "cannot convert float infinity to integer",
  )
}

///|
test "math_module: floor on float returns int" {
  let m = math_module()
  expect_int(call1(m, "floor", fv(1.9)), 1L)
  expect_int(call1(m, "floor", fv(-1.9)), -2L)
  expect_int(call1(m, "floor", fv(0.0)), 0L)
}

///|
test "math_module: floor on int returns int passthrough" {
  let m = math_module()
  expect_int(call1(m, "floor", iv(7L)), 7L)
  expect_int(call1(m, "floor", iv(-2L)), -2L)
}

///|
test "math_module: floor on infinity raises error" {
  let m = math_module()
  expect_err(
    call1(m, "floor", fv(1.0 / 0.0)),
    "cannot convert float infinity to integer",
  )
  expect_err(
    call1(m, "floor", fv(-1.0 / 0.0)),
    "cannot convert float infinity to integer",
  )
}

///|
test "math_module: floor on NaN raises error" {
  let m = math_module()
  expect_err(
    call1(m, "floor", fv(0.0 / 0.0)),
    "cannot convert float NaN to integer",
  )
}

///|
test "math_module: round" {
  let m = math_module()
  expect_float(call1(m, "round", fv(1.5)), 2.0)
  expect_float(call1(m, "round", fv(1.4)), 1.0)
}

///|
test "math_module: fabs" {
  let m = math_module()
  expect_float(call1(m, "fabs", fv(-3.5)), 3.5)
  expect_float(call1(m, "fabs", fv(3.5)), 3.5)
  expect_float(call1(m, "fabs", iv(-4L)), 4.0)
}

///|
test "math_module: sqrt" {
  let m = math_module()
  expect_float(call1(m, "sqrt", fv(4.0)), 2.0)
  expect_float(call1(m, "sqrt", fv(9.0)), 3.0)
}

///|
test "math_module: pow" {
  let m = math_module()
  expect_float(call2(m, "pow", fv(2.0), fv(10.0)), 1024.0)
  expect_float(call2(m, "pow", fv(2.0), fv(0.0)), 1.0)
}

///|
test "math_module: pow(-1, ±inf) equals 1 per IEEE 754 Annex F" {
  let m = math_module()
  let inf = @double.infinity
  expect_float(call2(m, "pow", fv(-1.0), fv(inf)), 1.0)
  expect_float(call2(m, "pow", fv(-1.0), fv(-inf)), 1.0)
}

///|
test "math_module: sin and cos" {
  let m = math_module()
  expect_float(call1(m, "sin", fv(pi)), 0.0)
  expect_float(call1(m, "cos", fv(0.0)), 1.0)
}

///|
test "math_module: log natural" {
  let m = math_module()
  expect_float(call1(m, "log", fv(2.718281828459045)), 1.0)
}

///|
test "math_module: log base=1 raises division by zero" {
  let m = math_module()
  expect_err(call2(m, "log", fv(2.0), fv(1.0)), "division by zero")
}

///|
test "math_module: log base=1 error is exactly 'division by zero' without function prefix" {
  let m = math_module()
  expect_exact_err(call2(m, "log", fv(2.0), fv(1.0)), "division by zero")
}

///|
test "math_module: log base=0 computes without error" {
  let m = math_module()
  // ln(x)/ln(0) = ln(x)/(-inf) = 0.0
  match call2(m, "log", fv(2.0), fv(0.0)) {
    Ok(@value.Value::Float(_)) => ()
    Ok(v) => fail("expected Float, got \{v.type_name()}")
    Err(e) => fail("expected Ok, got Err(\{e})")
  }
}

///|
test "math_module: degrees and radians" {
  let m = math_module()
  expect_float(call1(m, "degrees", fv(pi)), 180.0)
  expect_float(call1(m, "radians", fv(180.0)), pi)
}

///|
test "math_module: gamma(1)==1, gamma(5)==24" {
  let m = math_module()
  expect_float(call1(m, "gamma", fv(1.0)), 1.0)
  expect_float(call1(m, "gamma", fv(5.0)), 24.0)
}

///|
test "math_module: type error for non-numeric arg" {
  let m = math_module()
  match
    call1(m, "sqrt", @value.Value::String(@value.StarlarkString::new("x"))) {
    Err(msg) => assert_true(msg.contains("want float or int"))
    Ok(_) => fail("expected error")
  }
}

///|
test "math_module: unary function rejects wrong argument counts and keyword args" {
  let m = math_module()
  expect_err(call_raw(m, "sin", [], []), "got 0 arguments, want 1")
  expect_err(
    call_raw(m, "sin", [fv(1.0), fv(2.0)], []),
    "got 2 arguments, want 1",
  )
  expect_err(
    call_raw(m, "sin", [fv(1.0)], [("x", fv(1.0))]),
    "unexpected keyword arguments",
  )
}

///|
test "math_module: binary function rejects wrong argument counts and keyword args" {
  let m = math_module()
  expect_err(call_raw(m, "pow", [fv(2.0)], []), "got 1 arguments, want 2")
  expect_err(
    call_raw(m, "pow", [fv(2.0), fv(3.0), fv(4.0)], []),
    "got 3 arguments, want 2",
  )
  expect_err(
    call_raw(m, "pow", [fv(2.0), fv(3.0)], [("x", fv(1.0))]),
    "unexpected keyword arguments",
  )
}

///|
test "math_module: log rejects wrong argument counts and keyword args" {
  let m = math_module()
  expect_err(call_raw(m, "log", [], []), "got 0 arguments, want at least 1")
  expect_err(
    call_raw(m, "log", [fv(2.0), fv(10.0), fv(1.0)], []),
    "got 3 arguments, want at most 2",
  )
  expect_err(
    call_raw(m, "log", [fv(2.0)], [("base", fv(10.0))]),
    "unexpected keyword arguments",
  )
}

///|
test "math_module: remainder uses round-half-to-even for non-tie cases" {
  let m = math_module()
  expect_float(call2(m, "remainder", fv(3.0), fv(5.0)), -2.0)
  expect_float(call2(m, "remainder", fv(3.5), fv(2.0)), -0.5)
}

///|
test "math_module: remainder applies IEEE 754 round-half-to-even on tie" {
  let m = math_module()
  expect_float(call2(m, "remainder", fv(5.0), fv(2.0)), 1.0)
  expect_float(call2(m, "remainder", fv(7.0), fv(2.0)), -1.0)
  expect_float(call2(m, "remainder", fv(-5.0), fv(2.0)), -1.0)
  expect_float(call2(m, "remainder", fv(-7.0), fv(2.0)), 1.0)
}

///|
test "math_module: remainder preserves precision when x >> y (large ratio)" {
  let m = math_module()
  // 1e17 mod 3 = 1 exactly; naive x - rint(x/y)*y rounds to 0
  expect_float(call2(m, "remainder", fv(1.0e17), fv(3.0)), 1.0)
  expect_float(call2(m, "remainder", fv(-1.0e17), fv(3.0)), -1.0)
  expect_float(call2(m, "remainder", fv(1.0e17), fv(-3.0)), 1.0)
  // 1e308 mod 1e-308 must be finite, not ±Inf (naive formula overflows)
  match call2(m, "remainder", fv(1.0e308), fv(1.0e-308)) {
    Ok(@value.Value::Float(f)) =>
      if f.is_inf() || f.is_nan() {
        fail("expected finite result, got \{f}")
      }
    Ok(v) => fail("expected Float, got \{v.type_name()}")
    Err(e) => fail("expected Ok Float, got Err: \{e}")
  }
}

///|
test "math_module: remainder applies round-half-to-even on tie when y = 2^52" {
  let m = math_module()
  expect_float(
    call2(m, "remainder", fv(6755399441055744.0), fv(4503599627370496.0)),
    -2251799813685248.0,
  )
}

///|
test "math_module: pow(1, nan) and pow(1, ±inf) return 1.0 per IEEE 754" {
  let m = math_module()
  let nan = 0.0 / 0.0
  let inf = @double.infinity
  expect_float(call2(m, "pow", fv(1.0), fv(nan)), 1.0)
  expect_float(call2(m, "pow", fv(1.0), fv(inf)), 1.0)
  expect_float(call2(m, "pow", fv(1.0), fv(-inf)), 1.0)
}

///|
test "math_module: hypot(±inf, nan) returns +inf" {
  let m = math_module()
  let nan = 0.0 / 0.0
  let inf = @double.infinity
  match call2(m, "hypot", fv(inf), fv(nan)) {
    Ok(@value.Value::Float(f)) => assert_true(f.is_inf() && f > 0.0)
    Ok(v) => fail("expected Float, got \{v.type_name()}")
    Err(e) => fail("expected Ok, got Err(\{e})")
  }
  match call2(m, "hypot", fv(-inf), fv(nan)) {
    Ok(@value.Value::Float(f)) => assert_true(f.is_inf() && f > 0.0)
    Ok(v) => fail("expected Float, got \{v.type_name()}")
    Err(e) => fail("expected Ok, got Err(\{e})")
  }
  match call2(m, "hypot", fv(nan), fv(inf)) {
    Ok(@value.Value::Float(f)) => assert_true(f.is_inf() && f > 0.0)
    Ok(v) => fail("expected Float, got \{v.type_name()}")
    Err(e) => fail("expected Ok, got Err(\{e})")
  }
}

///|
test "math_module: gamma(171) returns finite value" {
  let m = math_module()
  match call1(m, "gamma", fv(171.0)) {
    Ok(@value.Value::Float(f)) => {
      assert_true(!f.is_inf())
      assert_true(!f.is_nan())
      // go: 7.2574156153080003e+306; bounds stay loose here; exact check is in
      // the "gamma precision" test below
      assert_true(f > 7.2e+306 && f < 7.3e+306)
    }
    Ok(v) => fail("expected Float, got \{v.type_name()}")
    Err(e) => fail("expected Ok, got Err(\{e})")
  }
}

///|
fn within_1_ulp(a : Double, b : Double) -> Bool {
  if a == b {
    true
  } else if a.is_nan() || b.is_nan() {
    false
  } else {
    let ai = a.reinterpret_as_int64()
    let bi = b.reinterpret_as_int64()
    ai == bi + 1L || bi == ai + 1L
  }
}

///|
fn expect_float_within_1_ulp(
  label : String,
  r : Result[@value.Value, String],
  expected : Double,
) -> Unit raise Error {
  match r {
    Ok(@value.Value::Float(f)) =>
      if !within_1_ulp(f, expected) {
        fail("\{label}: expected \{expected} (±1 ULP), got \{f}")
      }
    Ok(v) => fail("\{label}: expected Float, got \{v.type_name()}")
    Err(e) => fail("\{label}: expected Ok, got Err(\{e})")
  }
}

///|
test "math_module: gamma precision matches go Cephes implementation" {
  let m = math_module()
  // Large argument: Stirling path (x > 33). Former Lanczos gave
  // 4.2690680090040405e+304; go gives 4.2690680090047066e+304.
  expect_float_within_1_ulp(
    "gamma(170)",
    call1(m, "gamma", fv(170.0)),
    4.2690680090047066e+304,
  )
  expect_float_within_1_ulp(
    "gamma(171)",
    call1(m, "gamma", fv(171.0)),
    7.2574156153080003e+306,
  )
  // Argument in (0, 33]: rational approximation path after reduction to [2,3].
  expect_float_within_1_ulp(
    "gamma(0.5)",
    call1(m, "gamma", fv(0.5)),
    1.7724538509055159,
  )
  expect_float_within_1_ulp(
    "gamma(1.5)",
    call1(m, "gamma", fv(1.5)),
    0.88622692545275794,
  )
  expect_float_within_1_ulp(
    "gamma(2.5)",
    call1(m, "gamma", fv(2.5)),
    1.329340388179137,
  )
  expect_float_within_1_ulp(
    "gamma(0.1)",
    call1(m, "gamma", fv(0.1)),
    9.5135076986687324,
  )
  // Negative non-integer: reflection formula.
  expect_float_within_1_ulp(
    "gamma(-0.5)",
    call1(m, "gamma", fv(-0.5)),
    -3.5449077018110318,
  )
  // Zero: +0 → +Inf, -0 → -Inf.
  match call1(m, "gamma", fv(0.0)) {
    Ok(@value.Value::Float(f)) =>
      if !(f.is_inf() && f > 0.0) {
        fail("gamma(+0): expected +Inf, got \{f}")
      }
    Ok(v) => fail("gamma(+0): expected Float, got \{v.type_name()}")
    Err(e) => fail("gamma(+0): expected Ok, got Err(\{e})")
  }
  match call1(m, "gamma", fv(-0.0)) {
    Ok(@value.Value::Float(f)) =>
      if !(f.is_inf() && f < 0.0) {
        fail("gamma(-0): expected -Inf, got \{f}")
      }
    Ok(v) => fail("gamma(-0): expected Float, got \{v.type_name()}")
    Err(e) => fail("gamma(-0): expected Ok, got Err(\{e})")
  }
}

///|
test "math_module: fabs(-0.0) returns positive zero" {
  let m = math_module()
  let neg_zero = -0.0
  match call1(m, "fabs", fv(neg_zero)) {
    Ok(@value.Value::Float(f)) => {
      assert_eq(f, 0.0)
      // Verify the result is +0.0, not -0.0
      assert_true(1.0 / f > 0.0)
    }
    Ok(v) => fail("expected Float, got \{v.type_name()}")
    Err(e) => fail("expected Ok, got Err(\{e})")
  }
}

///|
test "math_module: sqrt(-0.0) returns negative zero" {
  let m = math_module()
  let neg_zero = -0.0
  match call1(m, "sqrt", fv(neg_zero)) {
    Ok(@value.Value::Float(f)) => {
      assert_eq(f, 0.0)
      // Verify the result is -0.0, not +0.0
      assert_true(1.0 / f < 0.0)
    }
    Ok(v) => fail("expected Float, got \{v.type_name()}")
    Err(e) => fail("expected Ok, got Err(\{e})")
  }
}

///|
test "math_module: rounding functions reject wrong argument counts and keyword args" {
  let m = math_module()
  expect_err(call_raw(m, "ceil", [], []), "got 0 arguments, want 1")
  expect_err(
    call_raw(m, "ceil", [fv(1.0), fv(2.0)], []),
    "got 2 arguments, want 1",
  )
  expect_err(
    call_raw(m, "ceil", [fv(1.0)], [("x", fv(1.0))]),
    "unexpected keyword arguments",
  )
  expect_err(call_raw(m, "floor", [], []), "got 0 arguments, want 1")
  expect_err(
    call_raw(m, "floor", [fv(1.0)], [("x", fv(1.0))]),
    "unexpected keyword arguments",
  )
}
