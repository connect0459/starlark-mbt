// Statement tests: while, augmented assignment, tuple unpacking, loop control.

///|
fn exec_s(src : String) -> Result[Module, @errors.EvalError] {
  let t = Thread::new("test")
  exec_file(t, "<test>", src, Options::default())
}

///|
fn get_s(m : Module, name : String) -> @value.Value? {
  m.get(name)
}

// --- while loop ---

///|
test "exec_file: while loop counts down until condition is false" {
  match exec_s("x = 3\nwhile x > 0:\n  x = x - 1") {
    Ok(m) => assert_true(get_s(m, "x") == Some(@value.Value::IntVal(0L)))
    Err(_) => assert_true(false)
  }
}

///|
test "exec_file: while loop body is skipped when condition is initially false" {
  match exec_s("x = 0\nwhile False:\n  x = 1") {
    Ok(m) => assert_true(get_s(m, "x") == Some(@value.Value::IntVal(0L)))
    Err(_) => assert_true(false)
  }
}

///|
test "exec_file: while loop with break exits before condition is false" {
  match exec_s("x = 0\nwhile True:\n  x = x + 1\n  if x == 3:\n    break") {
    Ok(m) => assert_true(get_s(m, "x") == Some(@value.Value::IntVal(3L)))
    Err(_) => assert_true(false)
  }
}

///|
test "exec_file: while loop with continue skips rest of body for that iteration" {
  match
    exec_s(
      "x = 0\ny = 0\nwhile x < 5:\n  x = x + 1\n  if x == 3:\n    continue\n  y = y + 1",
    ) {
    Ok(m) => {
      assert_true(get_s(m, "x") == Some(@value.Value::IntVal(5L)))
      assert_true(get_s(m, "y") == Some(@value.Value::IntVal(4L)))
    }
    Err(_) => assert_true(false)
  }
}

// --- Augmented assignment ---

///|
test "exec_file: augmented add updates binding in place" {
  match exec_s("x = 5\nx += 3") {
    Ok(m) => assert_true(get_s(m, "x") == Some(@value.Value::IntVal(8L)))
    Err(_) => assert_true(false)
  }
}

///|
test "exec_file: augmented subtract updates binding in place" {
  match exec_s("x = 10\nx -= 4") {
    Ok(m) => assert_true(get_s(m, "x") == Some(@value.Value::IntVal(6L)))
    Err(_) => assert_true(false)
  }
}

///|
test "exec_file: augmented multiply updates binding in place" {
  match exec_s("x = 3\nx *= 4") {
    Ok(m) => assert_true(get_s(m, "x") == Some(@value.Value::IntVal(12L)))
    Err(_) => assert_true(false)
  }
}

///|
test "exec_file: augmented floor-divide updates binding in place" {
  match exec_s("x = 7\nx //= 2") {
    Ok(m) => assert_true(get_s(m, "x") == Some(@value.Value::IntVal(3L)))
    Err(_) => assert_true(false)
  }
}

///|
test "exec_file: augmented modulo updates binding in place" {
  match exec_s("x = 7\nx %= 3") {
    Ok(m) => assert_true(get_s(m, "x") == Some(@value.Value::IntVal(1L)))
    Err(_) => assert_true(false)
  }
}

///|
test "exec_file: augmented bitwise-or updates binding in place" {
  match exec_s("x = 0b1100\nx |= 0b0011") {
    Ok(m) => assert_true(get_s(m, "x") == Some(@value.Value::IntVal(0b1111L)))
    Err(_) => assert_true(false)
  }
}

///|
test "exec_file: augmented left-shift updates binding in place" {
  match exec_s("x = 1\nx <<= 4") {
    Ok(m) => assert_true(get_s(m, "x") == Some(@value.Value::IntVal(16L)))
    Err(_) => assert_true(false)
  }
}

///|
test "exec_file: augmented string concatenation extends string" {
  match exec_s("s = \"hello\"\ns += \" world\"") {
    Ok(m) =>
      match get_s(m, "s") {
        Some(@value.Value::StrVal(s)) => assert_eq(s.raw, "hello world")
        _ => assert_true(false)
      }
    Err(_) => assert_true(false)
  }
}

///|
test "exec_file: augmented list extend adds elements" {
  match exec_s("lst = [1, 2]\nlst += [3, 4]") {
    Ok(m) =>
      match get_s(m, "lst") {
        Some(@value.Value::ListVal(l)) => assert_eq(l.length(), 4)
        _ => assert_true(false)
      }
    Err(_) => assert_true(false)
  }
}

// --- Tuple unpacking assignment ---

///|
test "exec_file: simple tuple unpacking assigns each element" {
  match exec_s("a, b = 1, 2") {
    Ok(m) => {
      assert_true(get_s(m, "a") == Some(@value.Value::IntVal(1L)))
      assert_true(get_s(m, "b") == Some(@value.Value::IntVal(2L)))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "exec_file: tuple unpacking from list value" {
  match exec_s("a, b, c = [10, 20, 30]") {
    Ok(m) => {
      assert_true(get_s(m, "a") == Some(@value.Value::IntVal(10L)))
      assert_true(get_s(m, "b") == Some(@value.Value::IntVal(20L)))
      assert_true(get_s(m, "c") == Some(@value.Value::IntVal(30L)))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "exec_file: tuple unpacking with wrong count raises error" {
  assert_true(exec_s("a, b = 1, 2, 3") is Err(_))
}

///|
test "exec_file: tuple unpacking in for loop" {
  match exec_s("s = 0\nfor a, b in [(1, 2), (3, 4)]:\n  s = s + a + b") {
    Ok(m) => assert_true(get_s(m, "s") == Some(@value.Value::IntVal(10L)))
    Err(_) => assert_true(false)
  }
}

// --- for loop control flow ---

///|
test "exec_file: for loop break stops iteration early" {
  match
    exec_s("x = 0\nfor i in [1, 2, 3, 4, 5]:\n  if i == 3:\n    break\n  x = i") {
    Ok(m) => assert_true(get_s(m, "x") == Some(@value.Value::IntVal(2L)))
    Err(_) => assert_true(false)
  }
}

///|
test "exec_file: for loop continue skips rest of body for matching iterations" {
  match
    exec_s(
      "s = 0\nfor i in [1, 2, 3, 4, 5]:\n  if i == 3:\n    continue\n  s = s + i",
    ) {
    Ok(m) => assert_true(get_s(m, "s") == Some(@value.Value::IntVal(12L)))
    Err(_) => assert_true(false)
  }
}

// --- dict subscript assignment ---

///|
test "exec_file: dict subscript assignment sets key-value pair" {
  match exec_s("d = {}\nd[\"x\"] = 42") {
    Ok(m) =>
      match get_s(m, "d") {
        Some(@value.Value::DictVal(d)) => {
          let key = @value.Value::StrVal(@value.StarlarkString::new("x"))
          assert_true(d.get(key) == Ok(Some(@value.Value::IntVal(42L))))
        }
        _ => assert_true(false)
      }
    Err(_) => assert_true(false)
  }
}

///|
test "exec_file: list subscript assignment updates element in place" {
  match exec_s("lst = [1, 2, 3]\nlst[1] = 99") {
    Ok(m) =>
      match get_s(m, "lst") {
        Some(@value.Value::ListVal(l)) =>
          assert_true(l.get(1) == @value.Value::IntVal(99L))
        _ => assert_true(false)
      }
    Err(_) => assert_true(false)
  }
}

// --- load statement ---

///|
test "exec_file: load statement raises error when no loader is set" {
  assert_true(exec_s("load(\"module\", \"sym\")") is Err(_))
}

///|
test "exec_file: load statement makes symbol usable within the file" {
  let exported : Map[String, @value.Value] = {}
  exported["answer"] = @value.Value::IntVal(42L)
  let loader : (Thread, String) -> Result[Module, @errors.EvalError] = fn(
    _thread,
    _path,
  ) {
    Ok(Module::from_map(exported))
  }
  let t = Thread::with_loader("test", loader)
  let result = exec_file(
    t,
    "<test>",
    "load(\"mylib\", \"answer\")\nx = answer + 1",
    Options::default(),
  )
  match result {
    Ok(m) => assert_true(m.get("x") == Some(@value.Value::IntVal(43L)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: load statement supports aliased bindings" {
  let exported : Map[String, @value.Value] = {}
  exported["foo"] = @value.Value::IntVal(1L)
  let loader : (Thread, String) -> Result[Module, @errors.EvalError] = fn(
    _thread,
    _path,
  ) {
    Ok(Module::from_map(exported))
  }
  let t = Thread::with_loader("test", loader)
  let result = exec_file(
    t,
    "<test>",
    "load(\"mylib\", bar=\"foo\")\ny = bar + 1",
    Options::default(),
  )
  match result {
    Ok(m) => assert_true(m.get("y") == Some(@value.Value::IntVal(2L)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: load statement raises error when symbol not found in module" {
  let loader : (Thread, String) -> Result[Module, @errors.EvalError] = fn(
    _thread,
    _path,
  ) {
    Ok(Module::from_map({}))
  }
  let t = Thread::with_loader("test", loader)
  let result = exec_file(
    t,
    "<test>",
    "load(\"mylib\", \"missing\")",
    Options::default(),
  )
  assert_true(result is Err(_))
}
