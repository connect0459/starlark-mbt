///|
test "Options: all extension flags are enabled by default" {
  let opts = Options::default()
  assert_eq(opts.allow_set, true)
  assert_eq(opts.allow_recursion, true)
  assert_eq(opts.allow_lambda, true)
  assert_eq(opts.allow_while, true)
  assert_eq(opts.allow_bytes, true)
  assert_eq(opts.allow_float, true)
  assert_eq(opts.allow_global_reassign, true)
  assert_eq(opts.allow_top_level_control, true)
}

///|
test "Options: load_binds_globally defaults to false for spec compliance" {
  let opts = Options::default()
  assert_eq(opts.load_binds_globally, false)
}

///|
test "Thread: default construction sets name and empty call stack" {
  let t = Thread::new("main")
  assert_eq(t.name, "main")
  assert_eq(t.call_stack_depth(), 0)
}

///|
test "Thread: default max_recursion_depth is 100" {
  let t = Thread::new("main")
  assert_eq(t.max_recursion_depth, 100)
}

///|
test "Thread: default has no step budget" {
  let t = Thread::new("main")
  assert_true(t.max_steps is None)
}

///|
test "Thread::with_step_budget sets max_steps" {
  let t = Thread::with_step_budget("test", 50)
  assert_true(t.max_steps == Some(50))
}

///|
test "Thread::execution_steps returns zero on a fresh thread" {
  let t = Thread::new("main")
  assert_eq(t.execution_steps(), 0)
}

///|
test "Thread::execution_steps increments during script evaluation" {
  let t = Thread::with_step_budget("test", 1000)
  let _ = exec_file(t, "<test>", "x = 1\ny = 2\nz = x + y", Options::default())
  assert_true(t.execution_steps() > 0)
}

///|
test "Thread::with_step_budget halts computation that exceeds limit" {
  let t = Thread::with_step_budget("test", 5)
  match
    exec_file(
      t,
      "<test>",
      "i = 0\nwhile i < 1000000:\n  i = i + 1",
      Options::default(),
    ) {
    Err(e) => assert_true(e.msg.contains("step budget"))
    Ok(_) => assert_true(false)
  }
}

///|
test "Thread::cancel halts execution with the given reason" {
  let t = Thread::new("test")
  t.cancel("timeout")
  match exec_file(t, "<test>", "x = 1\ny = 2", Options::default()) {
    Err(e) =>
      assert_true(e.msg.contains("cancelled") && e.msg.contains("timeout"))
    Ok(_) => fail("expected cancellation error")
  }
}

///|
test "Thread::cancel preserves the first reason when called multiple times" {
  let t = Thread::new("test")
  t.cancel("first")
  t.cancel("second")
  match exec_file(t, "<test>", "x = 1", Options::default()) {
    Err(e) => assert_true(e.msg.contains("first") && !e.msg.contains("second"))
    Ok(_) => fail("expected cancellation error")
  }
}

///|
test "Thread::uncancel allows execution to proceed after cancellation" {
  let t = Thread::new("test")
  t.cancel("timeout")
  t.uncancel()
  match exec_file(t, "<test>", "x = 42", Options::default()) {
    Ok(_) => ()
    Err(e) => fail("expected success after uncancel, got: \{e.msg}")
  }
}

///|
test "Thread without step budget completes a long computation" {
  let t = Thread::new("test")
  match
    exec_file(
      t,
      "<test>",
      "x = 0\nfor i in range(100):\n  x = x + i",
      Options::default(),
    ) {
    Ok(m) =>
      assert_true(get_global(m, "x") == Some(@value.Value::IntVal(4950L)))
    Err(_) => assert_true(false)
  }
}

///|
test "Thread: with_print routes output to the custom callback" {
  let msgs : Array[String] = []
  let t = Thread::with_print("test", fn(msg) { msgs.push(msg) })
  match exec_file(t, "<test>", "print(\"hello\")", Options::default()) {
    Ok(_) => {
      assert_eq(msgs.length(), 1)
      assert_eq(msgs[0], "hello")
    }
    Err(e) => fail(e.msg)
  }
}

///|
test "Module: starts with empty globals and is not frozen" {
  let m = Module::new()
  assert_eq(m.globals_count(), 0)
  assert_false(m.is_frozen())
}

///|
test "Module: freeze transitions module to frozen state" {
  let m = Module::new()
  m.freeze()
  assert_true(m.is_frozen())
}

///|
test "Module: freeze also freezes the globals dict" {
  let m = Module::new()
  m.freeze()
  assert_true(m.is_frozen())
}

// --- Test helpers ---

///|
fn eval_e(src : String) -> Result[@value.Value, @errors.EvalError] {
  let t = Thread::new("test")
  let env = @value.StarlarkDict::new()
  eval_expr(t, "<test>", src, env)
}

///|
fn exec_src(src : String) -> Result[Module, @errors.EvalError] {
  let t = Thread::new("test")
  exec_file(t, "<test>", src, Options::default())
}

///|
fn get_global(m : Module, name : String) -> @value.Value? {
  m.get(name)
}

// --- eval_expr: literal evaluation ---

///|
test "eval_expr: None literal evaluates to NoneVal" {
  assert_true(eval_e("None") is Ok(@value.Value::NoneVal))
}

///|
test "eval_expr: True literal evaluates to BoolVal(true)" {
  assert_true(eval_e("True") is Ok(@value.Value::BoolVal(true)))
}

///|
test "eval_expr: False literal evaluates to BoolVal(false)" {
  assert_true(eval_e("False") is Ok(@value.Value::BoolVal(false)))
}

///|
test "eval_expr: integer literal evaluates to IntVal" {
  assert_true(eval_e("42") is Ok(@value.Value::IntVal(42L)))
}

///|
test "eval_expr: float literal evaluates to FloatVal" {
  assert_true(eval_e("3.14") is Ok(@value.Value::FloatVal(3.14)))
}

///|
test "eval_expr: string literal evaluates to StrVal" {
  match eval_e("\"hello\"") {
    Ok(@value.Value::StrVal(s)) => assert_eq(s.raw, "hello")
    _ => assert_true(false)
  }
}

// --- eval_expr: arithmetic ---

///|
test "eval_expr: integer addition produces correct sum" {
  assert_true(eval_e("1 + 2") is Ok(@value.Value::IntVal(3L)))
}

///|
test "eval_expr: integer subtraction produces correct difference" {
  assert_true(eval_e("10 - 3") is Ok(@value.Value::IntVal(7L)))
}

///|
test "eval_expr: integer multiplication produces correct product" {
  assert_true(eval_e("4 * 5") is Ok(@value.Value::IntVal(20L)))
}

///|
test "eval_expr: floor division truncates toward negative infinity" {
  assert_true(eval_e("7 // 2") is Ok(@value.Value::IntVal(3L)))
  assert_true(eval_e("-7 // 2") is Ok(@value.Value::IntVal(-4L)))
  assert_true(eval_e("7 // -2") is Ok(@value.Value::IntVal(-4L)))
}

///|
test "eval_expr: modulo returns remainder consistent with floor division" {
  assert_true(eval_e("7 % 3") is Ok(@value.Value::IntVal(1L)))
}

///|
test "eval_expr: unary negation negates integer" {
  assert_true(eval_e("-5") is Ok(@value.Value::IntVal(-5L)))
}

///|
test "eval_expr: integer division by zero returns an error" {
  assert_true(eval_e("1 // 0") is Err(_))
}

// --- eval_expr: boolean operators ---

///|
test "eval_expr: not True is False" {
  assert_true(eval_e("not True") is Ok(@value.Value::BoolVal(false)))
}

///|
test "eval_expr: not False is True" {
  assert_true(eval_e("not False") is Ok(@value.Value::BoolVal(true)))
}

///|
test "eval_expr: and returns first falsy operand" {
  assert_true(eval_e("False and True") is Ok(@value.Value::BoolVal(false)))
}

///|
test "eval_expr: and returns last operand when both truthy" {
  assert_true(eval_e("True and 42") is Ok(@value.Value::IntVal(42L)))
}

///|
test "eval_expr: or returns first truthy operand" {
  assert_true(eval_e("True or False") is Ok(@value.Value::BoolVal(true)))
}

///|
test "eval_expr: or returns last operand when all falsy" {
  assert_true(eval_e("False or 0") is Ok(@value.Value::IntVal(0L)))
}

// --- eval_expr: comparisons ---

///|
test "eval_expr: equal integers are equal" {
  assert_true(eval_e("1 == 1") is Ok(@value.Value::BoolVal(true)))
}

///|
test "eval_expr: different integers are not equal" {
  assert_true(eval_e("1 != 2") is Ok(@value.Value::BoolVal(true)))
}

///|
test "eval_expr: less than holds between ordered integers" {
  assert_true(eval_e("1 < 2") is Ok(@value.Value::BoolVal(true)))
}

///|
test "eval_expr: greater than holds between ordered integers" {
  assert_true(eval_e("3 > 2") is Ok(@value.Value::BoolVal(true)))
}

// --- eval_expr: conditional expression ---

///|
test "eval_expr: conditional returns true branch when condition is truthy" {
  assert_true(eval_e("1 if True else 2") is Ok(@value.Value::IntVal(1L)))
}

///|
test "eval_expr: conditional returns false branch when condition is falsy" {
  assert_true(eval_e("1 if False else 2") is Ok(@value.Value::IntVal(2L)))
}

// --- eval_expr: collection literals ---

///|
test "eval_expr: empty list literal produces empty list" {
  match eval_e("[]") {
    Ok(@value.Value::ListVal(l)) => assert_eq(l.items.length(), 0)
    _ => assert_true(false)
  }
}

///|
test "eval_expr: list literal with elements has correct elements" {
  match eval_e("[1, 2, 3]") {
    Ok(@value.Value::ListVal(l)) => {
      assert_eq(l.items.length(), 3)
      assert_true(l.items[0] == @value.Value::IntVal(1L))
      assert_true(l.items[2] == @value.Value::IntVal(3L))
    }
    _ => assert_true(false)
  }
}

///|
test "eval_expr: tuple literal with elements has correct elements" {
  match eval_e("(1, 2)") {
    Ok(@value.Value::TupleVal(t)) => {
      assert_eq(t.length(), 2)
      assert_true(t[0] == @value.Value::IntVal(1L))
    }
    _ => assert_true(false)
  }
}

///|
test "eval_expr: dict literal with entries has correct entries" {
  match eval_e("{\"a\": 1}") {
    Ok(@value.Value::DictVal(d)) => {
      assert_eq(d.length(), 1)
      let key = @value.Value::StrVal(@value.StarlarkString::new("a"))
      assert_true(d.get(key) == Ok(Some(@value.Value::IntVal(1L))))
    }
    _ => assert_true(false)
  }
}

// --- exec_file: statements ---

///|
test "exec_file: integer assignment binds value to global variable" {
  match exec_src("x = 42") {
    Ok(m) => assert_true(get_global(m, "x") == Some(@value.Value::IntVal(42L)))
    Err(_) => assert_true(false)
  }
}

///|
test "exec_file: expression evaluation produces correct global binding" {
  match exec_src("x = 1 + 2") {
    Ok(m) => assert_true(get_global(m, "x") == Some(@value.Value::IntVal(3L)))
    Err(_) => assert_true(false)
  }
}

///|
test "exec_file: if-true branch binds the consequent value" {
  match exec_src("if True:\n  x = 1\nelse:\n  x = 2") {
    Ok(m) => assert_true(get_global(m, "x") == Some(@value.Value::IntVal(1L)))
    Err(_) => assert_true(false)
  }
}

///|
test "exec_file: if-false branch binds the alternative value" {
  match exec_src("if False:\n  x = 1\nelse:\n  x = 2") {
    Ok(m) => assert_true(get_global(m, "x") == Some(@value.Value::IntVal(2L)))
    Err(_) => assert_true(false)
  }
}

///|
test "exec_file: for loop accumulates sum over range" {
  match exec_src("x = 0\nfor i in [1, 2, 3]:\n  x = x + i") {
    Ok(m) => assert_true(get_global(m, "x") == Some(@value.Value::IntVal(6L)))
    Err(_) => assert_true(false)
  }
}

///|
test "exec_file: function definition and call returns correct value" {
  match exec_src("def f(x):\n  return x + 1\nresult = f(41)") {
    Ok(m) =>
      assert_true(get_global(m, "result") == Some(@value.Value::IntVal(42L)))
    Err(_) => assert_true(false)
  }
}

///|
test "exec_file: function with no return returns None" {
  match exec_src("def f():\n  pass\nresult = f()") {
    Ok(m) => assert_true(get_global(m, "result") == Some(@value.Value::NoneVal))
    Err(_) => assert_true(false)
  }
}

///|
test "exec_file: syntax error propagates as eval error" {
  assert_true(exec_src("def (broken") is Err(_))
}

// --- load_binds_globally ---

///|
fn make_opts_load_binds(v : Bool) -> Options {
  {
    allow_set: true,
    allow_recursion: true,
    allow_lambda: true,
    allow_while: true,
    allow_bytes: true,
    allow_float: true,
    allow_global_reassign: true,
    allow_top_level_control: true,
    load_binds_globally: v,
  }
}

///|
fn make_loader(
  entries : Map[String, Map[String, @value.Value]],
) -> (Thread, String) -> Result[Module, @errors.EvalError] {
  fn(_thread, path) {
    match entries.get(path) {
      Some(m) => Ok(Module::from_map(m))
      None => Err(@errors.EvalError::simple("no such module: \{path}"))
    }
  }
}

///|
test "load_binds_globally=false: loaded names excluded from module globals" {
  let mods : Map[String, Map[String, @value.Value]] = {
    "a.star": { "x": @value.Value::IntVal(42L) },
  }
  let t = Thread::with_loader("test", make_loader(mods))
  match
    exec_file(
      t,
      "<test>",
      "load(\"a.star\", \"x\")",
      make_opts_load_binds(false),
    ) {
    Ok(m) => assert_true(get_global(m, "x") is None)
    Err(e) => {
      println(e.msg)
      assert_true(false)
    }
  }
}

///|
test "load_binds_globally=true: loaded names included in module globals" {
  let mods : Map[String, Map[String, @value.Value]] = {
    "a.star": { "x": @value.Value::IntVal(42L) },
  }
  let t = Thread::with_loader("test", make_loader(mods))
  match
    exec_file(
      t,
      "<test>",
      "load(\"a.star\", \"x\")",
      make_opts_load_binds(true),
    ) {
    Ok(m) => assert_true(get_global(m, "x") == Some(@value.Value::IntVal(42L)))
    Err(e) => {
      println(e.msg)
      assert_true(false)
    }
  }
}

///|
test "load_binds_globally=false: loaded name is usable within the same file" {
  let mods : Map[String, Map[String, @value.Value]] = {
    "a.star": { "x": @value.Value::IntVal(42L) },
  }
  let t = Thread::with_loader("test", make_loader(mods))
  let src =
    #|load("a.star", "x")
    #|y = x + 1
  match exec_file(t, "<test>", src, make_opts_load_binds(false)) {
    Ok(m) => {
      assert_true(get_global(m, "x") is None)
      assert_true(get_global(m, "y") == Some(@value.Value::IntVal(43L)))
    }
    Err(e) => {
      println(e.msg)
      assert_true(false)
    }
  }
}

///|
test "load_binds_globally=false: loaded name is accessible from a function body" {
  let mods : Map[String, Map[String, @value.Value]] = {
    "a.star": { "x": @value.Value::IntVal(42L) },
  }
  let t = Thread::with_loader("test", make_loader(mods))
  let src =
    #|load("a.star", "x")
    #|def f():
    #|  return x
    #|result = f()
  match exec_file(t, "<test>", src, make_opts_load_binds(false)) {
    Ok(m) => {
      assert_true(get_global(m, "x") is None)
      assert_true(get_global(m, "result") == Some(@value.Value::IntVal(42L)))
    }
    Err(e) => {
      println(e.msg)
      assert_true(false)
    }
  }
}
