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
  assert_eq(t.call_stack.length(), 0)
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
test "Thread: with_print accepts a custom print callback" {
  let msgs : Array[String] = []
  let t = Thread::with_print("test", fn(msg) { msgs.push(msg) })
  (t.print_fn)("hello")
  assert_eq(msgs.length(), 1)
  assert_eq(msgs[0], "hello")
}

///|
test "Module: starts with empty globals and is not frozen" {
  let m = Module::new()
  assert_eq(m.globals.length(), 0)
  assert_false(m.frozen)
}

///|
test "Module: freeze transitions module to frozen state" {
  let m = Module::new()
  m.freeze()
  assert_true(m.frozen)
}

///|
test "Module: freeze also freezes the globals dict" {
  let m = Module::new()
  m.freeze()
  assert_true(m.globals.is_frozen())
}

///|
test "exec_file: returns error before evaluator is implemented" {
  let t = Thread::new("test")
  let opts = Options::default()
  let result = exec_file(t, "test.star", "x = 1", opts)
  assert_true(result is Err(_))
}

///|
test "eval_expr: returns error before evaluator is implemented" {
  let t = Thread::new("test")
  let env = @value.StarlarkDict::new()
  let result = eval_expr(t, "test.star", "1 + 2", env)
  assert_true(result is Err(_))
}
