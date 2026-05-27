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
fn fv(x : Double) -> @value.Value {
  @value.Value::Float(x)
}

///|
fn iv(x : Int64) -> @value.Value {
  @value.Value::Int(x)
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
    Ok(v) => fail("expected Float, got \{@value.type_name(v)}")
    Err(e) => fail("expected Ok, got Err(\{e})")
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
test "math_module: ceil and floor" {
  let m = math_module()
  expect_float(call1(m, "ceil", fv(1.2)), 2.0)
  expect_float(call1(m, "ceil", fv(-1.2)), -1.0)
  expect_float(call1(m, "floor", fv(1.9)), 1.0)
  expect_float(call1(m, "floor", fv(-1.9)), -2.0)
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
