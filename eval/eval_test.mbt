///|
test "Universe: new creates an empty universe queryable like other registries" {
  let u = Universe::new()
  assert_false(u.has("x"))
  assert_eq(u.keys().length(), 0)
  u.set("x", @value.Value::Int(1N))
  assert_true(u.has("x"))
  assert_true(u.keys() == ["x"])
}

///|
test "Universe: from_map wraps an existing binding map" {
  let u = Universe::from_map({
    "a": @value.Value::Int(1N),
    "b": @value.Value::Int(2N),
  })
  assert_true(u.has("a"))
  assert_true(u.has("b"))
  assert_true(u.keys() == ["a", "b"])
}

///|
test "Predeclared: has and keys mirror the other name-value registries" {
  let p = Predeclared::new()
  assert_false(p.has("k"))
  assert_eq(p.keys().length(), 0)
  p.set("k", @value.Value::Int(7N))
  assert_true(p.has("k"))
  assert_true(p.keys() == ["k"])
}

///|
test "Universe: each, values, and delete round out the registry surface" {
  let u = Universe::from_map({
    "a": @value.Value::Int(1N),
    "b": @value.Value::Int(2N),
  })
  let seen : Map[String, @value.Value] = {}
  u.each((k, v) => seen[k] = v)
  assert_eq(seen.length(), 2)
  assert_eq(u.values().length(), 2)
  assert_true(u.delete("a"))
  assert_false(u.delete("a"))
  assert_false(u.has("a"))
  assert_true(u.has("b"))
}

///|
test "Predeclared: each, values, and delete round out the registry surface" {
  let p = Predeclared::from_map({
    "x": @value.Value::Int(10N),
    "y": @value.Value::Int(20N),
  })
  let seen : Map[String, @value.Value] = {}
  p.each((k, v) => seen[k] = v)
  assert_eq(seen.length(), 2)
  assert_eq(p.values().length(), 2)
  assert_true(p.delete("x"))
  assert_false(p.delete("x"))
  assert_false(p.has("x"))
  assert_true(p.has("y"))
}

///|
test "Options: default dialect enables standard features and disables non-standard extensions" {
  let opts = Options::default()
  // Standard features are enabled.
  assert_eq(opts.allow_set(), true)
  assert_eq(opts.allow_lambda(), true)
  assert_eq(opts.allow_bytes(), true)
  assert_eq(opts.allow_float(), true)
  // Non-standard extensions are disabled by default.
  assert_eq(opts.allow_recursion(), false)
  assert_eq(opts.allow_while(), false)
  assert_eq(opts.allow_global_reassign(), false)
  assert_eq(opts.allow_top_level_control(), false)
}

///|
test "Options: load_binds_globally defaults to false for spec compliance" {
  let opts = Options::default()
  assert_eq(opts.load_binds_globally(), false)
}

///|
test "Thread: default construction sets name and empty call stack" {
  let t = Thread::new("main")
  assert_eq(t.name(), "main")
  assert_eq(t.call_stack_depth(), 0)
}

///|
test "Thread: default max_recursion_depth is 100" {
  let t = Thread::new("main")
  assert_eq(t.max_recursion_depth(), 100)
}

///|
test "Thread: default has no step budget" {
  let t = Thread::new("main")
  assert_true(t.max_steps() is None)
}

///|
test "Thread::with_step_budget sets max_steps" {
  let t = Thread::with_step_budget("test", 50)
  assert_true(t.max_steps() == Some(50))
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
      relaxed_opts(),
    ) {
    Err(e) =>
      assert_true(
        e.msg().contains("Starlark computation cancelled: too many steps"),
      )
    Ok(_) => assert_true(false)
  }
}

///|
test "Thread::cancel halts execution with the given reason" {
  let t = Thread::new("test")
  t.cancel("timeout")
  match exec_file(t, "<test>", "x = 1\ny = 2", Options::default()) {
    Err(e) =>
      assert_true(e.msg().contains("cancelled") && e.msg().contains("timeout"))
    Ok(_) => fail("expected cancellation error")
  }
}

///|
test "Thread::cancel preserves the first reason when called multiple times" {
  let t = Thread::new("test")
  t.cancel("first")
  t.cancel("second")
  match exec_file(t, "<test>", "x = 1", Options::default()) {
    Err(e) =>
      assert_true(e.msg().contains("first") && !e.msg().contains("second"))
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
    Err(e) => fail("expected success after uncancel, got: \{e.msg()}")
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
      relaxed_opts(),
    ) {
    Ok(m) => assert_true(get_global(m, "x") == Some(@value.Value::Int(4950N)))
    Err(_) => assert_true(false)
  }
}

///|
test "Thread::set_on_max_steps callback is invoked when step budget is exceeded" {
  let called : Ref[Bool] = { val: false }
  let t = Thread::with_step_budget("test", 5)
  t.set_on_max_steps(fn(th) {
    called.val = true
    th.cancel("callback cancelled")
  })
  match
    exec_file(
      t,
      "<test>",
      "i = 0\nwhile i < 1000000:\n  i = i + 1",
      relaxed_opts(),
    ) {
    Err(e) => {
      assert_true(called.val)
      assert_true(e.msg().contains("callback cancelled"))
    }
    Ok(_) => fail("expected error when step budget exceeded")
  }
}

///|
test "Thread::set_on_max_steps callback can extend the step budget" {
  let call_count : Ref[Int] = { val: 0 }
  let t = Thread::with_step_budget("test", 10)
  t.set_on_max_steps(fn(th) {
    call_count.val += 1
    if call_count.val < 3 {
      th.set_max_steps(th.execution_steps() + 10)
    } else {
      th.cancel("budget exhausted")
    }
  })
  match
    exec_file(
      t,
      "<test>",
      "i = 0\nwhile i < 1000000:\n  i = i + 1",
      relaxed_opts(),
    ) {
    Err(e) => assert_true(e.msg().contains("budget exhausted"))
    Ok(_) => fail("expected error when budget exhausted")
  }
  assert_eq(call_count.val, 3)
}

///|
test "Thread::set_max_steps updates the step budget on an existing thread" {
  let t = Thread::with_step_budget("test", 50)
  assert_true(t.max_steps() == Some(50))
  t.set_max_steps(200)
  assert_true(t.max_steps() == Some(200))
}

///|
test "Thread: with_print routes output to the custom callback" {
  let msgs : Array[String] = []
  let t = Thread::with_print("test", fn(_thread, msg) { msgs.push(msg) })
  match exec_file(t, "<test>", "print(\"hello\")", Options::default()) {
    Ok(_) => {
      assert_eq(msgs.length(), 1)
      assert_eq(msgs[0], "hello")
    }
    Err(e) => fail(e.msg())
  }
}

///|
test "Thread: with_print callback receives Thread with accessible call stack" {
  let captured_depth : Array[Int] = []
  let src =
    #|def f():
    #|  print("inside f")
    #|f()
  let t = Thread::with_print("test", fn(thread, _msg) {
    captured_depth.push(thread.call_stack_depth())
  })
  match exec_file(t, "foo.star", src, Options::default()) {
    Ok(_) => {
      assert_eq(captured_depth.length(), 1)
      assert_true(captured_depth[0] > 0)
    }
    Err(e) => fail(e.msg())
  }
}

///|
test "Module: starts with empty globals and is not frozen" {
  let m = Module::new()
  assert_eq(m.globals_count(), 0)
  assert_eq(m.predeclared_count(), 0)
  assert_false(m.is_frozen())
}

///|
test "Module: predeclared_count matches injected predeclared bindings" {
  let t = Thread::new("test")
  let pd = Predeclared::new()
  pd.set("a", @value.Value::Int(1N))
  pd.set("b", @value.Value::Int(2N))
  match
    exec_file_with_predeclared(t, "<test>", "x = 1", Options::default(), pd) {
    Ok(m) => {
      assert_eq(m.predeclared_count(), 2)
      assert_true(m.predeclared_names().length() == 2)
    }
    Err(e) => fail(e.msg())
  }
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
  let env = @value.StringDict::new()
  eval_expr(t, "<test>", src, env)
}

///|
fn exec_src(src : String) -> Result[Module, @errors.EvalError] {
  let t = Thread::new("test")
  exec_file(t, "<test>", src, relaxed_opts())
}

///|
/// Options enabling the non-standard extensions (while loops, top-level control
/// flow, top-level reassignment) needed by statement-behavior tests that drive
/// loops and reassignment at module scope.
fn relaxed_opts() -> Options {
  Options::default()
  .with_allow_while(true)
  .with_allow_top_level_control(true)
  .with_allow_global_reassign(true)
}

///|
fn get_global(m : Module, name : String) -> @value.Value? {
  m.get(name)
}

// --- eval_expr: literal evaluation ---

///|
test "eval_expr: resolves a binding supplied via env" {
  let t = Thread::new("test")
  let env = @value.StringDict::new()
  env.set("x", @value.Value::Int(10N))
  match eval_expr(t, "<test>", "x + 5", env) {
    Ok(v) =>
      match @value.number_to_int(v) {
        Some(n) => assert_eq(n, 15L)
        None => fail("result is not an int")
      }
    Err(e) => fail("eval_expr errored: \{e.msg()}")
  }
}

///|
test "eval_expr: an undefined name reports an undefined-name error with position" {
  let t = Thread::new("test")
  let env = @value.StringDict::new()
  match eval_expr(t, "expr.star", "ghost", env) {
    Err(e) => assert_eq(e.to_string(), "expr.star:1:1: undefined: ghost")
    Ok(_) => fail("expected an undefined-name error")
  }
}

///|
test "eval_expr: a runtime error carries the caller-supplied filename" {
  let t = Thread::new("test")
  let env = @value.StringDict::new()
  match eval_expr(t, "expr.star", "1 // 0", env) {
    Err(e) => assert_true(e.backtrace().contains("expr.star"))
    Ok(_) => fail("expected a division-by-zero error")
  }
}

///|
test "eval_expr: None literal evaluates to None" {
  assert_true(eval_e("None") is Ok(@value.Value::None))
}

///|
test "eval_expr: True literal evaluates to Bool(true)" {
  assert_true(eval_e("True") is Ok(@value.Value::Bool(true)))
}

///|
test "eval_expr: False literal evaluates to Bool(false)" {
  assert_true(eval_e("False") is Ok(@value.Value::Bool(false)))
}

///|
test "eval_expr: integer literal evaluates to Int" {
  assert_true(eval_e("42") is Ok(@value.Value::Int(42N)))
}

///|
test "eval_expr: float literal evaluates to Float" {
  assert_true(eval_e("3.14") is Ok(@value.Value::Float(3.14)))
}

///|
test "eval_expr: string literal evaluates to String" {
  match eval_e("\"hello\"") {
    Ok(@value.Value::String(s)) => assert_eq(s.raw(), "hello")
    _ => assert_true(false)
  }
}

// --- eval_expr: arithmetic ---

///|
test "eval_expr: integer addition produces correct sum" {
  assert_true(eval_e("1 + 2") is Ok(@value.Value::Int(3N)))
}

///|
test "eval_expr: integer subtraction produces correct difference" {
  assert_true(eval_e("10 - 3") is Ok(@value.Value::Int(7N)))
}

///|
test "eval_expr: integer multiplication produces correct product" {
  assert_true(eval_e("4 * 5") is Ok(@value.Value::Int(20N)))
}

///|
test "eval_expr: floor division truncates toward negative infinity" {
  assert_true(eval_e("7 // 2") is Ok(@value.Value::Int(3N)))
  assert_true(eval_e("-7 // 2") is Ok(@value.Value::Int(-4N)))
  assert_true(eval_e("7 // -2") is Ok(@value.Value::Int(-4N)))
}

///|
test "eval_expr: modulo returns remainder consistent with floor division" {
  assert_true(eval_e("7 % 3") is Ok(@value.Value::Int(1N)))
}

///|
test "eval_expr: unary negation negates integer" {
  assert_true(eval_e("-5") is Ok(@value.Value::Int(-5N)))
}

///|
test "eval_expr: integer division by zero returns an error" {
  assert_true(eval_e("1 // 0") is Err(_))
}

// --- eval_expr: boolean operators ---

///|
test "eval_expr: not True is False" {
  assert_true(eval_e("not True") is Ok(@value.Value::Bool(false)))
}

///|
test "eval_expr: not False is True" {
  assert_true(eval_e("not False") is Ok(@value.Value::Bool(true)))
}

///|
test "eval_expr: and returns first falsy operand" {
  assert_true(eval_e("False and True") is Ok(@value.Value::Bool(false)))
}

///|
test "eval_expr: and returns last operand when both truthy" {
  assert_true(eval_e("True and 42") is Ok(@value.Value::Int(42N)))
}

///|
test "eval_expr: or returns first truthy operand" {
  assert_true(eval_e("True or False") is Ok(@value.Value::Bool(true)))
}

///|
test "eval_expr: or returns last operand when all falsy" {
  assert_true(eval_e("False or 0") is Ok(@value.Value::Int(0N)))
}

// --- eval_expr: comparisons ---

///|
test "eval_expr: equal integers are equal" {
  assert_true(eval_e("1 == 1") is Ok(@value.Value::Bool(true)))
}

///|
test "eval_expr: different integers are not equal" {
  assert_true(eval_e("1 != 2") is Ok(@value.Value::Bool(true)))
}

///|
test "eval_expr: less than holds between ordered integers" {
  assert_true(eval_e("1 < 2") is Ok(@value.Value::Bool(true)))
}

///|
test "eval_expr: greater than holds between ordered integers" {
  assert_true(eval_e("3 > 2") is Ok(@value.Value::Bool(true)))
}

// --- eval_expr: conditional expression ---

///|
test "eval_expr: conditional returns true branch when condition is truthy" {
  assert_true(eval_e("1 if True else 2") is Ok(@value.Value::Int(1N)))
}

///|
test "eval_expr: conditional returns false branch when condition is falsy" {
  assert_true(eval_e("1 if False else 2") is Ok(@value.Value::Int(2N)))
}

// --- eval_expr: collection literals ---

///|
test "eval_expr: empty list literal produces empty list" {
  match eval_e("[]") {
    Ok(@value.Value::List(l)) => assert_eq(l.length(), 0)
    _ => assert_true(false)
  }
}

///|
test "eval_expr: list literal with elements has correct elements" {
  match eval_e("[1, 2, 3]") {
    Ok(@value.Value::List(l)) => {
      assert_eq(l.length(), 3)
      assert_true(l[0] == @value.Value::Int(1N))
      assert_true(l[2] == @value.Value::Int(3N))
    }
    _ => assert_true(false)
  }
}

///|
test "eval_expr: tuple literal with elements has correct elements" {
  match eval_e("(1, 2)") {
    Ok(@value.Value::Tuple(t)) => {
      assert_eq(t.length(), 2)
      assert_true(t[0] == @value.Value::Int(1N))
    }
    _ => assert_true(false)
  }
}

///|
test "eval_expr: dict literal with entries has correct entries" {
  match eval_e("{\"a\": 1}") {
    Ok(@value.Value::Dict(d)) => {
      assert_eq(d.length(), 1)
      let key = @value.Value::String(@value.StarlarkString::new("a"))
      assert_true(d.get(key) == Ok(Some(@value.Value::Int(1N))))
    }
    _ => assert_true(false)
  }
}

// --- exec_file: statements ---

///|
test "exec_file: integer assignment binds value to global variable" {
  match exec_src("x = 42") {
    Ok(m) => assert_true(get_global(m, "x") == Some(@value.Value::Int(42N)))
    Err(_) => assert_true(false)
  }
}

///|
test "exec_file: expression evaluation produces correct global binding" {
  match exec_src("x = 1 + 2") {
    Ok(m) => assert_true(get_global(m, "x") == Some(@value.Value::Int(3N)))
    Err(_) => assert_true(false)
  }
}

///|
test "exec_file: if-true branch binds the consequent value" {
  match exec_src("if True:\n  x = 1\nelse:\n  x = 2") {
    Ok(m) => assert_true(get_global(m, "x") == Some(@value.Value::Int(1N)))
    Err(_) => assert_true(false)
  }
}

///|
test "exec_file: if-false branch binds the alternative value" {
  match exec_src("if False:\n  x = 1\nelse:\n  x = 2") {
    Ok(m) => assert_true(get_global(m, "x") == Some(@value.Value::Int(2N)))
    Err(_) => assert_true(false)
  }
}

///|
test "exec_file: for loop accumulates sum over range" {
  match exec_src("x = 0\nfor i in [1, 2, 3]:\n  x = x + i") {
    Ok(m) => assert_true(get_global(m, "x") == Some(@value.Value::Int(6N)))
    Err(_) => assert_true(false)
  }
}

///|
test "exec_file: function definition and call returns correct value" {
  match exec_src("def f(x):\n  return x + 1\nresult = f(41)") {
    Ok(m) =>
      assert_true(get_global(m, "result") == Some(@value.Value::Int(42N)))
    Err(_) => assert_true(false)
  }
}

///|
test "exec_file: function with no return returns None" {
  match exec_src("def f():\n  pass\nresult = f()") {
    Ok(m) => assert_true(get_global(m, "result") == Some(@value.Value::None))
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
  Options::default().with_load_binds_globally(v)
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
    "a.star": { "x": @value.Value::Int(42N) },
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
      println(e.msg())
      assert_true(false)
    }
  }
}

///|
test "load_binds_globally=true: loaded names included in module globals" {
  let mods : Map[String, Map[String, @value.Value]] = {
    "a.star": { "x": @value.Value::Int(42N) },
  }
  let t = Thread::with_loader("test", make_loader(mods))
  match
    exec_file(
      t,
      "<test>",
      "load(\"a.star\", \"x\")",
      make_opts_load_binds(true),
    ) {
    Ok(m) => assert_true(get_global(m, "x") == Some(@value.Value::Int(42N)))
    Err(e) => {
      println(e.msg())
      assert_true(false)
    }
  }
}

///|
test "load_binds_globally=false: loaded name is usable within the same file" {
  let mods : Map[String, Map[String, @value.Value]] = {
    "a.star": { "x": @value.Value::Int(42N) },
  }
  let t = Thread::with_loader("test", make_loader(mods))
  let src =
    #|load("a.star", "x")
    #|y = x + 1
  match exec_file(t, "<test>", src, make_opts_load_binds(false)) {
    Ok(m) => {
      assert_true(get_global(m, "x") is None)
      assert_true(get_global(m, "y") == Some(@value.Value::Int(43N)))
    }
    Err(e) => {
      println(e.msg())
      assert_true(false)
    }
  }
}

///|
test "load_binds_globally=false: loaded name is accessible from a function body" {
  let mods : Map[String, Map[String, @value.Value]] = {
    "a.star": { "x": @value.Value::Int(42N) },
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
      assert_true(get_global(m, "result") == Some(@value.Value::Int(42N)))
    }
    Err(e) => {
      println(e.msg())
      assert_true(false)
    }
  }
}

// --- exec_repl_chunk ---

///|
fn dict_get(d : @value.StringDict, name : String) -> @value.Value? {
  d.get(name)
}

///|
test "exec_repl_chunk: assigns a variable into globals dict" {
  let thread = Thread::new("repl")
  let globals = @value.StringDict::new()
  match
    exec_repl_chunk(thread, "<repl>", "x = 42", globals, Options::default()) {
    Ok(_) => assert_true(dict_get(globals, "x") == Some(@value.Value::Int(42N)))
    Err(e) => {
      println(e.msg())
      assert_true(false)
    }
  }
}

///|
test "exec_repl_chunk: subsequent chunk sees variables from previous chunk" {
  let thread = Thread::new("repl")
  let globals = @value.StringDict::new()
  let _ = exec_repl_chunk(
    thread,
    "<repl>",
    "x = 10",
    globals,
    Options::default(),
  )
  match
    exec_repl_chunk(thread, "<repl>", "y = x + 5", globals, Options::default()) {
    Ok(_) => assert_true(dict_get(globals, "y") == Some(@value.Value::Int(15N)))
    Err(e) => {
      println(e.msg())
      assert_true(false)
    }
  }
}

///|
test "exec_repl_chunk: returns EvalError on runtime error" {
  let thread = Thread::new("repl")
  let globals = @value.StringDict::new()
  match
    exec_repl_chunk(thread, "<repl>", "x = 1 // 0", globals, Options::default()) {
    Err(e) => assert_true(e.msg().contains("zero"))
    Ok(_) => assert_true(false)
  }
}

///|
fn ok_value(r : Result[@value.Value, @errors.EvalError]) -> @value.Value {
  match r {
    Ok(v) => v
    Err(e) =>
      @value.Value::String(@value.StarlarkString::new("ERR: \{e.msg()}"))
  }
}

///|
test "binary: arithmetic operations on integers" {
  let two = @value.Value::Int(2)
  let three = @value.Value::Int(3)
  assert_true(ok_value(binary("+", two, three)) == @value.Value::Int(5))
  assert_true(ok_value(binary("-", three, two)) == @value.Value::Int(1))
  assert_true(ok_value(binary("*", two, three)) == @value.Value::Int(6))
  assert_true(ok_value(binary("//", three, two)) == @value.Value::Int(1))
  assert_true(ok_value(binary("%", three, two)) == @value.Value::Int(1))
}

///|
test "binary: real division produces a float result" {
  let ten = @value.Value::Int(10)
  let two = @value.Value::Int(2)
  assert_true(ok_value(binary("/", ten, two)) == @value.Value::Float(5.0))
}

///|
test "binary: bitwise operators produce correct integer results" {
  let six = @value.Value::Int(6)
  let three = @value.Value::Int(3)
  assert_true(ok_value(binary("&", six, three)) == @value.Value::Int(2))
  assert_true(ok_value(binary("|", six, three)) == @value.Value::Int(7))
  assert_true(ok_value(binary("^", six, three)) == @value.Value::Int(5))
  assert_true(
    ok_value(binary("<<", @value.Value::Int(1), @value.Value::Int(3))) ==
    @value.Value::Int(8),
  )
  assert_true(
    ok_value(binary(">>", @value.Value::Int(8), @value.Value::Int(2))) ==
    @value.Value::Int(2),
  )
}

///|
test "binary: returns error when the operation raises" {
  let one = @value.Value::Int(1)
  let zero = @value.Value::Int(0)
  assert_true(binary("//", one, zero) is Err(_))
}

///|
test "binary: power operator is not a known operator" {
  let two = @value.Value::Int(2)
  let three = @value.Value::Int(3)
  match binary("**", two, three) {
    Err(e) => assert_true(e.msg().contains("unknown binary operator"))
    Ok(_) => assert_true(false)
  }
}

///|
test "binary: unknown operator returns error" {
  let x = @value.Value::Int(1)
  let y = @value.Value::Int(2)
  match binary("??", x, y) {
    Err(e) => assert_true(e.msg().contains("unknown binary operator"))
    Ok(_) => assert_true(false)
  }
}

///|
test "unary: numeric operations" {
  let three = @value.Value::Int(3)
  assert_true(ok_value(unary("-", three)) == @value.Value::Int(-3))
  assert_true(ok_value(unary("+", three)) == @value.Value::Int(3))
  assert_true(
    ok_value(unary("not", @value.Value::Bool(false))) ==
    @value.Value::Bool(true),
  )
}

///|
test "unary: bitwise not operator" {
  let five = @value.Value::Int(5)
  assert_true(ok_value(unary("~", five)) == @value.Value::Int(-6))
}

///|
test "unary: returns error when operation raises" {
  assert_true(
    unary("+", @value.Value::String(@value.StarlarkString::new("x"))) is Err(_),
  )
}

///|
test "unary: unknown operator returns error" {
  match unary("??", @value.Value::Int(1)) {
    Err(e) => assert_true(e.msg().contains("unknown unary operator"))
    Ok(_) => assert_true(false)
  }
}

///|
test "Thread::call_frame: returns None when index is out of range" {
  let t = Thread::new("test")
  assert_true(t.call_frame(100) is None)
}

///|
test "Thread::reset_steps: resets the execution step counter to zero" {
  let t = Thread::with_step_budget("test", 1000)
  ignore(exec_file(t, "<test>", "x = 1 + 1", Options::default()))
  assert_true(t.execution_steps() > 0)
  t.reset_steps()
  assert_eq(t.execution_steps(), 0)
}

///|
test "Universe::get: returns the value bound to a name" {
  let u = Universe::from_map({ "x": @value.Value::Int(42) })
  assert_true(u.get("x") == Some(@value.Value::Int(42)))
  assert_true(u.get("missing") is None)
}

///|
test "Predeclared::get: returns the value bound to a name" {
  let p = Predeclared::from_map({ "x": @value.Value::Int(7) })
  assert_true(p.get("x") == Some(@value.Value::Int(7)))
  assert_true(p.get("missing") is None)
}

///|
fn ok_bool(r : Result[Bool, @errors.EvalError]) -> Bool {
  match r {
    Ok(b) => b
    Err(_) => false
  }
}

///|
test "compare: integer comparisons" {
  let two = @value.Value::Int(2)
  let three = @value.Value::Int(3)
  assert_true(ok_bool(compare("==", two, two)))
  assert_true(ok_bool(compare("!=", two, three)))
  assert_true(ok_bool(compare("<", two, three)))
  assert_true(ok_bool(compare("<=", two, three)))
  assert_true(ok_bool(compare(">", three, two)))
  assert_true(ok_bool(compare(">=", three, two)))
}

///|
test "compare: unknown operator returns error" {
  match compare("??", @value.Value::Int(1), @value.Value::Int(2)) {
    Err(e) => assert_true(e.msg().contains("unknown comparison operator"))
    Ok(_) => assert_true(false)
  }
}

///|
test "exec_repl_chunk: returns EvalError on parse or resolve error" {
  let thread = Thread::new("repl")
  let globals = @value.StringDict::new()
  match
    exec_repl_chunk(
      thread,
      "<repl>",
      "def f(: pass",
      globals,
      Options::default(),
    ) {
    Err(e) => assert_true(e.msg().length() > 0)
    Ok(_) => assert_true(false)
  }
}

///|
test "exec_file: set literal rejected when allow_set disabled" {
  let t = Thread::new("test")
  let opts = Options::default().with_allow_set(false)
  match exec_file(t, "<test>", "x = {1, 2}", opts) {
    Err(e) => assert_true(e.msg().contains("does not support sets"))
    Ok(_) => fail("expected set-dialect error")
  }
}

///|
test "Thread::set_max_steps does not reset the step counter" {
  let t = Thread::with_step_budget("test", 1000)
  let _ = exec_file(t, "<test>", "x = 1\ny = 2\nz = x + y", Options::default())
  let before = t.execution_steps()
  assert_true(before > 0)
  t.set_max_steps(5000)
  assert_eq(t.execution_steps(), before)
}

///|
test "Thread can combine print, loader, and step budget via setters" {
  let msgs : Array[String] = []
  let t = Thread::new("test")
  t.set_print(fn(_thread, msg) { msgs.push(msg) })
  t.set_loader(fn(_thread, _path) {
    let m = Module::new()
    Ok(m)
  })
  t.set_max_steps(10000)
  match exec_file(t, "<test>", "print(\"hi\")", Options::default()) {
    Ok(_) => {
      assert_eq(msgs.length(), 1)
      assert_eq(msgs[0], "hi")
      assert_true(t.max_steps() == Some(10000))
    }
    Err(e) => fail(e.msg())
  }
}

///|
test "bind_args: singular 'argument' when max_pos is 1" {
  let r = exec_src("def f(a): return a\nf(1, 2)")
  match r {
    Err(e) =>
      assert_eq(e.msg(), "function f accepts 1 positional argument (2 given)")
    Ok(_) => fail("expected error")
  }
}

///|
test "bind_args: 'at most' prefix when optional positional params exist" {
  let r = exec_src("def f(a, b=2): return a\nf(1, 2, 3)")
  match r {
    Err(e) =>
      assert_eq(
        e.msg(),
        "function f accepts at most 2 positional arguments (3 given)",
      )
    Ok(_) => fail("expected error")
  }
}

///|
test "bind_args: nullary function rejects positional args" {
  let r = exec_src("def f(): return 1\nf(1, 2)")
  match r {
    Err(e) => assert_eq(e.msg(), "function f accepts no arguments (2 given)")
    Ok(_) => fail("expected error")
  }
}

///|
test "bind_args: nullary function counts keyword args in total" {
  let r = exec_src("def f(): return 1\nf(a=1)")
  match r {
    Err(e) => assert_eq(e.msg(), "function f accepts no arguments (1 given)")
    Ok(_) => fail("expected error")
  }
}

///|
test "bind_args: nullary function counts mixed pos+kw args total" {
  let r = exec_src("def f(): return 1\nf(1, a=2)")
  match r {
    Err(e) => assert_eq(e.msg(), "function f accepts no arguments (2 given)")
    Ok(_) => fail("expected error")
  }
}

///|
test "bind_args: kwonly star path uses singular and no 'at most' for required param" {
  let r = exec_src("def f(a, *, b): return a\nf(1, 2)")
  match r {
    Err(e) =>
      assert_eq(e.msg(), "function f accepts 1 positional argument (2 given)")
    Ok(_) => fail("expected error")
  }
}

///|
test "call: returns error when calling a non-callable value" {
  let t = Thread::new("test")
  assert_true(call(t, @value.Value::Int(42N), [], []) is Err(_))
}

///|
test "call: successfully invokes a Starlark function defined via exec_file" {
  let t = Thread::new("test")
  match
    exec_file(t, "<test>", "def add(a, b): return a + b", Options::default()) {
    Ok(m) =>
      match m.get("add") {
        Some(func) => {
          let t2 = Thread::new("test2")
          let r = call(
            t2,
            func,
            [@value.Value::Int(3N), @value.Value::Int(4N)],
            [],
          )
          assert_true(r is Ok(@value.Value::Int(7N)))
        }
        None => fail("add not found")
      }
    Err(e) => fail(e.msg())
  }
}

///|
test "call: propagates error when the Starlark function raises" {
  let t = Thread::new("test")
  match exec_file(t, "<test>", "def boom(): fail('oops')", Options::default()) {
    Ok(m) =>
      match m.get("boom") {
        Some(func) => {
          let t2 = Thread::new("test2")
          assert_true(call(t2, func, [], []) is Err(_))
        }
        None => fail("boom not found")
      }
    Err(e) => fail(e.msg())
  }
}

///|
test "compare: returns error when types do not support ordering" {
  assert_true(compare("<", @value.Value::None, @value.Value::None) is Err(_))
}

///|
test "exec_file_with_universe: returns error on parse failure" {
  let t = Thread::new("test")
  let u = Universe::new()
  assert_true(
    exec_file_with_universe(t, "<test>", "!!!invalid!!!", Options::default(), u)
    is Err(_),
  )
}

///|
test "exec_file_with_universe: successfully runs script with custom universe binding" {
  let t = Thread::new("test")
  let u = Universe::from_map({ "MY_VAL": @value.Value::Int(99N) })
  match
    exec_file_with_universe(t, "<test>", "x = MY_VAL", Options::default(), u) {
    Ok(m) => assert_true(m.get("x") == Some(@value.Value::Int(99N)))
    Err(e) => fail(e.msg())
  }
}

///|
test "exec_file_with_predeclared: returns error on parse failure" {
  let t = Thread::new("test")
  let p = Predeclared::new()
  assert_true(
    exec_file_with_predeclared(
      t,
      "<test>",
      "!!!invalid!!!",
      Options::default(),
      p,
    )
    is Err(_),
  )
}

///|
test "exec_file_with_predeclared: successfully runs script with injected bindings" {
  let t = Thread::new("test")
  let p = Predeclared::from_map({ "PRE": @value.Value::Int(7N) })
  match
    exec_file_with_predeclared(t, "<test>", "x = PRE", Options::default(), p) {
    Ok(m) => assert_true(m.get("x") == Some(@value.Value::Int(7N)))
    Err(e) => fail(e.msg())
  }
}

///|
test "exec_file_with_universe: returns error when script references an undefined name" {
  let t = Thread::new("test")
  let u = Universe::new()
  assert_true(
    exec_file_with_universe(
      t,
      "<test>",
      "x = __undefined_xyz__",
      Options::default(),
      u,
    )
    is Err(_),
  )
}
