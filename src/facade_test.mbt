///|
test "exec runs source with default thread and options" {
  match exec("x = 1 + 2") {
    Ok(m) => assert_true(m.get("x") is Some(@value.Value::Int(3N)))
    Err(e) => fail(e.msg())
  }
}

///|
test "exec exposes all module globals" {
  match exec("a = 1\nb = a + 1") {
    Ok(m) => {
      assert_true(m.get("a") is Some(@value.Value::Int(1N)))
      assert_true(m.get("b") is Some(@value.Value::Int(2N)))
    }
    Err(e) => fail(e.msg())
  }
}

///|
test "exec accepts a custom filename" {
  match exec("y = 5", filename="custom.star") {
    Ok(m) => assert_true(m.get("y") is Some(@value.Value::Int(5N)))
    Err(e) => fail(e.msg())
  }
}

///|
test "exec surfaces evaluation errors" {
  match exec("x = 1 // 0") {
    Err(e) => assert_true(e.msg().contains("zero"))
    Ok(_) => fail("expected a division-by-zero error")
  }
}

///|
test "eval evaluates an expression with defaults" {
  match eval("1 + 2") {
    Ok(v) => assert_true(v is @value.Value::Int(3N))
    Err(e) => fail(e.msg())
  }
}

///|
test "eval evaluates a string expression" {
  match eval("'ab' + 'cd'") {
    Ok(v) => {
      let (s, ok) = @value.as_string(v)
      assert_true(ok)
      assert_eq(s, "abcd")
    }
    Err(e) => fail(e.msg())
  }
}

///|
test "eval surfaces expression errors" {
  match eval("1 +") {
    Err(_) => ()
    Ok(_) => fail("expected a syntax error")
  }
}

///|
test "Value alias names the public value type" {
  let v : Value = @value.Value::Int(7N)
  assert_true(v is @value.Value::Int(7N))
}

///|
test "Module alias names the public module type" {
  match exec("z = 9") {
    Ok(m) => {
      let module_ : Module = m
      assert_true(module_.get("z") is Some(@value.Value::Int(9N)))
    }
    Err(e) => fail(e.msg())
  }
}

///|
test "EvalError alias names the public error type" {
  match exec("boom()") {
    Err(e) => {
      let err : EvalError = e
      assert_true(err.msg().length() > 0)
    }
    Ok(_) => fail("expected an error")
  }
}
