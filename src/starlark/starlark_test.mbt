///|
test "Thread can be created with a name" {
  let t = @starlark.Thread::new("main")
  assert_eq(t.name(), "main")
}

///|
test "Thread::with_step_budget halts computation that exceeds limit" {
  let t = @starlark.Thread::with_step_budget("test", 5)
  match
    @starlark.exec_file(
      t,
      "<test>",
      "i = 0\nwhile i < 1000000:\n  i = i + 1",
      @starlark.Options::default(),
    ) {
    Err(e) => assert_true(e.msg().contains("step budget"))
    Ok(_) => assert_true(false)
  }
}

///|
test "Options::default enables all feature flags" {
  let opts = @starlark.Options::default()
  assert_eq(opts.allow_set(), true)
  assert_eq(opts.allow_recursion(), true)
  assert_eq(opts.allow_lambda(), true)
  assert_eq(opts.allow_while(), true)
  assert_eq(opts.allow_bytes(), true)
  assert_eq(opts.allow_float(), true)
  assert_eq(opts.allow_global_reassign(), true)
  assert_eq(opts.allow_top_level_control(), true)
}

///|
test "exec_file runs a simple script and exposes globals" {
  let t = @starlark.Thread::new("test")
  match
    @starlark.exec_file(t, "<test>", "x = 1 + 2", @starlark.Options::default()) {
    Ok(m) =>
      assert_true(
        @starlark.module_get(m, "x") is Some(@starlark.Value::IntVal(3L)),
      )
    Err(_) => assert_true(false)
  }
}

///|
test "exec_file reports a runtime error as EvalError" {
  let t = @starlark.Thread::new("test")
  match
    @starlark.exec_file(t, "<test>", "x = 1 // 0", @starlark.Options::default()) {
    Err(e) => assert_true(e.msg().contains("zero"))
    Ok(_) => assert_true(false)
  }
}

///|
test "exec_file reports a syntax error wrapped as EvalError" {
  let t = @starlark.Thread::new("test")
  match
    @starlark.exec_file(
      t,
      "<test>",
      "def f(: pass",
      @starlark.Options::default(),
    ) {
    Err(e) => assert_true(e.msg().length() > 0)
    Ok(_) => assert_true(false)
  }
}

///|
test "eval_expr evaluates an expression in an empty environment" {
  let t = @starlark.Thread::new("test")
  let env = @starlark.StarlarkDict::new()
  match @starlark.eval_expr(t, "<test>", "1 + 2", env) {
    Ok(v) => assert_true(v is @starlark.Value::IntVal(3L))
    Err(_) => assert_true(false)
  }
}

///|
test "exec_file_with_predeclared injects host bindings" {
  let t = @starlark.Thread::new("test")
  let predeclared = @starlark.Predeclared::from_map({
    "ANSWER": @starlark.Value::IntVal(42L),
  })
  match
    @starlark.exec_file_with_predeclared(
      t,
      "<test>",
      "x = ANSWER + 1",
      @starlark.Options::default(),
      predeclared,
    ) {
    Ok(m) =>
      assert_true(
        @starlark.module_get(m, "x") is Some(@starlark.Value::IntVal(43L)),
      )
    Err(_) => assert_true(false)
  }
}

///|
test "module globals are frozen after exec_file" {
  let t = @starlark.Thread::new("test")
  match
    @starlark.exec_file(
      t,
      "<test>",
      "x = [1, 2, 3]",
      @starlark.Options::default(),
    ) {
    Ok(m) => assert_true(m.is_frozen())
    Err(_) => assert_true(false)
  }
}

///|
test "module_get returns None for undefined globals" {
  let t = @starlark.Thread::new("test")
  match
    @starlark.exec_file(t, "<test>", "x = 1", @starlark.Options::default()) {
    Ok(m) => assert_true(@starlark.module_get(m, "y") is None)
    Err(_) => assert_true(false)
  }
}
