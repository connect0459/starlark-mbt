// Statement tests: while, augmented assignment, tuple unpacking, loop control.

///|
fn exec_s(src : String) -> Result[Module, @errors.EvalError] {
  let t = Thread::new("test")
  let opts = Options::default()
    .with_allow_while(true)
    .with_allow_top_level_control(true)
    .with_allow_global_reassign(true)
  exec_file(t, "<test>", src, opts)
}

///|
fn get_s(m : Module, name : String) -> @value.Value? {
  m.get(name)
}

// --- while loop ---

///|
test "exec_file: while loop counts down until condition is false" {
  match exec_s("x = 3\nwhile x > 0:\n  x = x - 1") {
    Ok(m) => assert_true(get_s(m, "x") == Some(@value.Value::Int(0N)))
    Err(_) => assert_true(false)
  }
}

///|
test "exec_file: while loop body is skipped when condition is initially false" {
  match exec_s("x = 0\nwhile False:\n  x = 1") {
    Ok(m) => assert_true(get_s(m, "x") == Some(@value.Value::Int(0N)))
    Err(_) => assert_true(false)
  }
}

///|
test "exec_file: while loop with break exits before condition is false" {
  match exec_s("x = 0\nwhile True:\n  x = x + 1\n  if x == 3:\n    break") {
    Ok(m) => assert_true(get_s(m, "x") == Some(@value.Value::Int(3N)))
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
      assert_true(get_s(m, "x") == Some(@value.Value::Int(5N)))
      assert_true(get_s(m, "y") == Some(@value.Value::Int(4N)))
    }
    Err(_) => assert_true(false)
  }
}

// --- Augmented assignment ---

///|
test "exec_file: augmented add updates binding in place" {
  match exec_s("x = 5\nx += 3") {
    Ok(m) => assert_true(get_s(m, "x") == Some(@value.Value::Int(8N)))
    Err(_) => assert_true(false)
  }
}

///|
test "exec_file: augmented subtract updates binding in place" {
  match exec_s("x = 10\nx -= 4") {
    Ok(m) => assert_true(get_s(m, "x") == Some(@value.Value::Int(6N)))
    Err(_) => assert_true(false)
  }
}

///|
test "exec_file: augmented multiply updates binding in place" {
  match exec_s("x = 3\nx *= 4") {
    Ok(m) => assert_true(get_s(m, "x") == Some(@value.Value::Int(12N)))
    Err(_) => assert_true(false)
  }
}

///|
test "exec_file: augmented floor-divide updates binding in place" {
  match exec_s("x = 7\nx //= 2") {
    Ok(m) => assert_true(get_s(m, "x") == Some(@value.Value::Int(3N)))
    Err(_) => assert_true(false)
  }
}

///|
test "exec_file: augmented modulo updates binding in place" {
  match exec_s("x = 7\nx %= 3") {
    Ok(m) => assert_true(get_s(m, "x") == Some(@value.Value::Int(1N)))
    Err(_) => assert_true(false)
  }
}

///|
test "exec_file: augmented bitwise-or updates binding in place" {
  match exec_s("x = 0b1100\nx |= 0b0011") {
    Ok(m) => assert_true(get_s(m, "x") == Some(@value.Value::Int(0b1111N)))
    Err(_) => assert_true(false)
  }
}

///|
test "exec_file: augmented left-shift updates binding in place" {
  match exec_s("x = 1\nx <<= 4") {
    Ok(m) => assert_true(get_s(m, "x") == Some(@value.Value::Int(16N)))
    Err(_) => assert_true(false)
  }
}

///|
test "exec_file: augmented string concatenation extends string" {
  match exec_s("s = \"hello\"\ns += \" world\"") {
    Ok(m) =>
      match get_s(m, "s") {
        Some(@value.Value::String(s)) => assert_eq(s.raw(), "hello world")
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
        Some(@value.Value::List(l)) => assert_eq(l.length(), 4)
        _ => assert_true(false)
      }
    Err(_) => assert_true(false)
  }
}

///|
test "exec_file: augmented list extend from range iterable" {
  match exec_s("lst = [1, 2]\nlst += range(3)") {
    Ok(m) =>
      match get_s(m, "lst") {
        Some(@value.Value::List(l)) => assert_eq(l.length(), 5)
        _ => assert_true(false)
      }
    Err(_) => assert_true(false)
  }
}

///|
test "exec_file: augmented list extend from tuple iterable" {
  match exec_s("lst = [10]\nlst += (20, 30)") {
    Ok(m) =>
      match get_s(m, "lst") {
        Some(@value.Value::List(l)) => assert_eq(l.length(), 3)
        _ => assert_true(false)
      }
    Err(_) => assert_true(false)
  }
}

///|
test "exec_file: augmented extend from range on frozen list raises error" {
  let items : Array[@value.Value] = [
    @value.Value::Int(1N),
    @value.Value::Int(2N),
  ]
  let frozen = @value.Value::new_list(items)
  if frozen is @value.Value::List(l) {
    l.freeze()
  }
  let pre : Map[String, @value.Value] = {}
  pre["frozen_lst"] = frozen
  let t = Thread::new("test")
  let result = exec_file_with_predeclared(
    t,
    "<test>",
    "def f(x):\n  x += range(3)\nf(frozen_lst)",
    Options::default(),
    Predeclared::from_map(pre),
  )
  assert_true(result is Err(_))
}

// --- Tuple unpacking assignment ---

///|
test "exec_file: simple tuple unpacking assigns each element" {
  match exec_s("a, b = 1, 2") {
    Ok(m) => {
      assert_true(get_s(m, "a") == Some(@value.Value::Int(1N)))
      assert_true(get_s(m, "b") == Some(@value.Value::Int(2N)))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "exec_file: tuple unpacking from list value" {
  match exec_s("a, b, c = [10, 20, 30]") {
    Ok(m) => {
      assert_true(get_s(m, "a") == Some(@value.Value::Int(10N)))
      assert_true(get_s(m, "b") == Some(@value.Value::Int(20N)))
      assert_true(get_s(m, "c") == Some(@value.Value::Int(30N)))
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
    Ok(m) => assert_true(get_s(m, "s") == Some(@value.Value::Int(10N)))
    Err(_) => assert_true(false)
  }
}

///|
test "exec_file: for loop with bare-tuple iterable iterates over all elements" {
  match exec_s("s = 0\nfor x in 1, 2, 3:\n  s = s + x") {
    Ok(m) => assert_true(get_s(m, "s") == Some(@value.Value::Int(6N)))
    Err(e) => fail("unexpected error: \{e.msg()}")
  }
}

///|
test "exec_file: for loop with tuple unpacking over bare-tuple iterable" {
  match exec_s("s = 0\nfor a, b in (1, 2), (3, 4):\n  s = s + a + b") {
    Ok(m) => assert_true(get_s(m, "s") == Some(@value.Value::Int(10N)))
    Err(e) => fail("unexpected error: \{e.msg()}")
  }
}

// --- for loop control flow ---

///|
test "exec_file: for loop break stops iteration early" {
  match
    exec_s("x = 0\nfor i in [1, 2, 3, 4, 5]:\n  if i == 3:\n    break\n  x = i") {
    Ok(m) => assert_true(get_s(m, "x") == Some(@value.Value::Int(2N)))
    Err(_) => assert_true(false)
  }
}

///|
test "exec_file: for loop continue skips rest of body for matching iterations" {
  match
    exec_s(
      "s = 0\nfor i in [1, 2, 3, 4, 5]:\n  if i == 3:\n    continue\n  s = s + i",
    ) {
    Ok(m) => assert_true(get_s(m, "s") == Some(@value.Value::Int(12N)))
    Err(_) => assert_true(false)
  }
}

// --- iterator drain on early frame exit ---

///|
test "exec_file: return from inside for loop does not permanently lock the iterated list" {
  let src =
    #|def first(L):
    #|    for x in L:
    #|        return x
    #|
    #|L = [1, 2, 3]
    #|first(L)
    #|L.append(4)
  match exec_s(src) {
    Ok(m) =>
      match get_s(m, "L") {
        Some(@value.Value::List(l)) => assert_eq(l.length(), 4)
        _ => fail("expected L to be a list")
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: return from nested for loops drains all active iterators" {
  let src =
    #|def first_pair(L, M):
    #|    for x in L:
    #|        for y in M:
    #|            return (x, y)
    #|
    #|L = [1, 2]
    #|M = [3, 4]
    #|first_pair(L, M)
    #|L.append(5)
    #|M.append(6)
  match exec_s(src) {
    Ok(m) => {
      match get_s(m, "L") {
        Some(@value.Value::List(l)) => assert_eq(l.length(), 3)
        _ => fail("expected L to be a list")
      }
      match get_s(m, "M") {
        Some(@value.Value::List(ml)) => assert_eq(ml.length(), 3)
        _ => fail("expected M to be a list")
      }
    }
    Err(e) => fail(e.to_string())
  }
}

// --- dict subscript assignment ---

///|
test "exec_file: dict subscript assignment sets key-value pair" {
  match exec_s("d = {}\nd[\"x\"] = 42") {
    Ok(m) =>
      match get_s(m, "d") {
        Some(@value.Value::Dict(d)) => {
          let key = @value.Value::String(@value.StarlarkString::new("x"))
          assert_true(d.get(key) == Ok(Some(@value.Value::Int(42N))))
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
        Some(@value.Value::List(l)) =>
          assert_true(l[1] == @value.Value::Int(99N))
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
  exported["answer"] = @value.Value::Int(42N)
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
    Ok(m) => assert_true(m.get("x") == Some(@value.Value::Int(43N)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: load statement supports aliased bindings" {
  let exported : Map[String, @value.Value] = {}
  exported["foo"] = @value.Value::Int(1N)
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
    Ok(m) => assert_true(m.get("y") == Some(@value.Value::Int(2N)))
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
