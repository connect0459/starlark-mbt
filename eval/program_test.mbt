// Program API tests.

///|
test "Program: source_program parses and resolves without executing" {
  let side_effects : Ref[Int] = { val: 0 }
  let pred = Predeclared::new()
  pred.set(
    "inc",
    @value.Value::new_builtin("inc", fn(_ctx, _args, _kwargs) {
      side_effects.val += 1
      Ok(@value.Value::None)
    }),
  )
  let prog = match
    source_program("check.star", "x = inc()", Options::default(), fn(name) {
      name == "inc"
    }) {
    Ok(p) => p
    Err(e) => fail("source_program failed: \{e.to_string()}")
  }
  assert_eq(side_effects.val, 0)
  let thread = Thread::new("test")
  match prog.init(thread, pred) {
    Err(e) => fail("init failed: \{e.to_string()}")
    Ok(_) => assert_eq(side_effects.val, 1)
  }
}

///|
test "Program: repeated exec with different predeclared values" {
  let prog = match
    source_program("repeat.star", "y = 2 * x", Options::default(), fn(name) {
      name == "x"
    }) {
    Ok(p) => p
    Err(e) => fail("source_program failed: \{e.to_string()}")
  }
  assert_eq(prog.filename(), "repeat.star")
  // x=42, expect y=84
  {
    let pred = Predeclared::new()
    pred.set("x", @value.Value::Int(42N))
    match prog.init(Thread::new("test"), pred) {
      Err(e) => fail("x=42: \{e.to_string()}")
      Ok(m) =>
        match m.get("y") {
          None => fail("x=42: missing y")
          Some(v) => assert_eq(v.repr(), "84")
        }
    }
  }
  // x="mur", expect y="murmur"
  let pred = Predeclared::new()
  pred.set("x", @value.Value::String(@value.StarlarkString::new("mur")))
  match prog.init(Thread::new("test"), pred) {
    Err(e) => fail("x=mur: \{e.to_string()}")
    Ok(m) =>
      match m.get("y") {
        None => fail("x=mur: missing y")
        Some(v) => assert_eq(v.repr(), "\"murmur\"")
      }
  }
}

///|
test "Program: filename for empty and non-empty files" {
  for content in ["", "empty = False"] {
    let prog = match
      source_program("hello.star", content, Options::default(), fn(_) { false }) {
      Ok(p) => p
      Err(e) => fail("source_program failed: \{e.to_string()}")
    }
    assert_eq(prog.filename(), "hello.star")
  }
}

///|
test "Program: source_program catches syntax errors before execution" {
  match
    source_program("bad.star", "def f(:", Options::default(), fn(_) { false }) {
    Ok(_) => fail("expected error")
    Err(e) => assert_true(e.to_string().contains("bad.star"))
  }
}

///|
test "Program: source_program catches resolve errors before execution" {
  match
    source_program("bad.star", "y = undefined_var", Options::default(), fn(_) {
      false
    }) {
    Ok(_) => fail("expected error")
    Err(e) => assert_true(e.to_string().contains("undefined"))
  }
}

///|
test "Program: num_loads and load" {
  let src =
    #|load("a.star", "foo")
    #|load("b.star", "bar")
  let prog = match
    source_program("test.star", src, Options::default(), fn(_) { false }) {
    Ok(p) => p
    Err(e) => fail("source_program failed: \{e.to_string()}")
  }
  assert_eq(prog.num_loads(), 2)
  let (p0, _) = prog.load(0)
  assert_eq(p0, "a.star")
  let (p1, _) = prog.load(1)
  assert_eq(p1, "b.star")
}

///|
/// A program resolved with a broad predeclared predicate stays runnable when a
/// later `init` supplies a narrower dictionary, as long as the omitted names are
/// only referenced on unreachable paths: resolution and compilation are paid
/// once at creation, so `init` never re-rejects names the broader predicate
/// accepted.
test "Program: init tolerates a narrower predeclared dict for unreachable names" {
  let src =
    #|if False:
    #|    sink = ghost
    #|y = 1
  let prog = match
    source_program(
      "broad.star",
      src,
      Options::default().with_allow_top_level_control(true),
      fn(name) { name == "ghost" },
    ) {
    Ok(p) => p
    Err(e) => fail("source_program failed: \{e.to_string()}")
  }
  // `ghost` is omitted from the init dictionary; because its only use is on the
  // dead `if False` branch, the run must still succeed.
  match prog.init(Thread::new("test"), Predeclared::new()) {
    Err(e) => fail("init failed: \{e.to_string()}")
    Ok(m) =>
      match m.get("y") {
        None => fail("missing y")
        Some(v) => assert_eq(v.repr(), "1")
      }
  }
}

///|
test "Program: init result is not frozen" {
  let prog = match
    source_program("mutable.star", "x = 1", Options::default(), fn(_) { false }) {
    Ok(p) => p
    Err(e) => fail("source_program failed: \{e.to_string()}")
  }
  let thread = Thread::new("test")
  match prog.init(thread, Predeclared::new()) {
    Err(e) => fail("init failed: \{e.to_string()}")
    Ok(m) => assert_eq(m.is_frozen(), false)
  }
}
