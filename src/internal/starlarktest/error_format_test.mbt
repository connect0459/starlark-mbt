///|
test "error format: syntax error includes filename line col and message" {
  let thread = @eval.Thread::new("test")
  let result = @eval.exec_file(
    thread,
    "test.star",
    "x = (",
    @eval.Options::default(),
  )
  match result {
    Err(e) =>
      inspect(
        e.msg(),
        content=(
          #|test.star:1:6: unexpected token end of file
        ),
      )
    Ok(_) => abort("expected error")
  }
}

///|
test "error format: resolve error for undefined variable includes position" {
  let thread = @eval.Thread::new("test")
  let result = @eval.exec_file(
    thread,
    "test.star",
    "x = undefined_var",
    @eval.Options::default(),
  )
  match result {
    Err(e) =>
      inspect(
        e.msg(),
        content=(
          #|test.star:1:5: undefined: undefined_var
        ),
      )
    Ok(_) => abort("expected error")
  }
}

///|
test "error format: type error in binary op" {
  let thread = @eval.Thread::new("test")
  let result = @eval.exec_file(
    thread,
    "test.star",
    "x = 1 + \"hello\"",
    @eval.Options::default(),
  )
  match result {
    Err(e) =>
      inspect(
        e.msg(),
        content=(
          #|unknown binary op: int + string
        ),
      )
    Ok(_) => abort("expected error")
  }
}

///|
test "error format: integer division by zero" {
  let thread = @eval.Thread::new("test")
  let result = @eval.exec_file(
    thread,
    "test.star",
    "x = 1 // 0",
    @eval.Options::default(),
  )
  match result {
    Err(e) =>
      inspect(
        e.msg(),
        content=(
          #|integer division by zero
        ),
      )
    Ok(_) => abort("expected error")
  }
}

///|
test "error format: list index out of range" {
  let thread = @eval.Thread::new("test")
  let result = @eval.exec_file(
    thread,
    "test.star",
    "x = [1, 2, 3][10]",
    @eval.Options::default(),
  )
  match result {
    Err(e) =>
      inspect(
        e.msg(),
        content=(
          #|index 10 out of range for sequence of length 3
        ),
      )
    Ok(_) => abort("expected error")
  }
}

///|
test "error format: EvalError backtrace includes traceback with call frames" {
  let thread = @eval.Thread::new("test")
  let src =
    #|def g():
    #|  return 1 + "oops"
    #|def f():
    #|  g()
    #|f()
  let result = @eval.exec_file(
    thread,
    "test.star",
    src,
    @eval.Options::default(),
  )
  match result {
    Err(e) =>
      inspect(
        e.backtrace(),
        content=(
          #|Traceback (most recent call last):
          #|  test.star:5:2: in <toplevel>
          #|  test.star:5:2: in f
          #|  test.star:4:4: in g
          #|Error: unknown binary op: int + string
        ),
      )
    Ok(_) => abort("expected error")
  }
}

///|
test "error format: EvalError backtrace with no frames shows only Error line" {
  let thread = @eval.Thread::new("test")
  let result = @eval.exec_file(
    thread,
    "test.star",
    "x = 1 + \"oops\"",
    @eval.Options::default(),
  )
  match result {
    Err(e) =>
      inspect(
        e.backtrace(),
        content=(
          #|Traceback (most recent call last):
          #|  test.star:1:1: in <toplevel>
          #|Error: unknown binary op: int + string
        ),
      )
    Ok(_) => abort("expected error")
  }
}

///|
test "error format: wrong number of args to function" {
  let thread = @eval.Thread::new("test")
  let src =
    #|def f(a, b):
    #|  return a + b
    #|f(1)
  let result = @eval.exec_file(
    thread,
    "test.star",
    src,
    @eval.Options::default(),
  )
  match result {
    Err(e) =>
      inspect(
        e.msg(),
        content=(
          #|function f missing 1 argument (b)
        ),
      )
    Ok(_) => abort("expected error")
  }
}

///|
test "error format: recursion depth exceeded" {
  let thread = @eval.Thread::with_print("test", fn(_, _) {  })
  let src =
    #|def f():
    #|  return f()
    #|f()
  let result = @eval.exec_file(
    thread,
    "test.star",
    src,
    @eval.Options::default(),
  )
  match result {
    Err(e) =>
      inspect(
        e.msg(),
        content=(
          #|maximum recursion depth exceeded
        ),
      )
    Ok(_) => abort("expected error")
  }
}

///|
test "Thread.cancel: pre-cancel prevents execution and returns cancellation error" {
  let thread = @eval.Thread::new("test")
  thread.cancel("nope")
  let result = @eval.exec_file(
    thread,
    "test.star",
    "x = 1",
    @eval.Options::default(),
  )
  match result {
    Err(e) =>
      assert_true(e.msg().contains("Starlark computation cancelled: nope"))
    Ok(_) => abort("expected cancellation error")
  }
}

///|
test "Thread.cancel: cancellation is sticky across multiple execs" {
  let thread = @eval.Thread::new("test")
  thread.cancel("stop")
  let _ = @eval.exec_file(thread, "a.star", "x = 1", @eval.Options::default())
  let result = @eval.exec_file(
    thread,
    "b.star",
    "y = 2",
    @eval.Options::default(),
  )
  match result {
    Err(e) =>
      assert_true(e.msg().contains("Starlark computation cancelled: stop"))
    Ok(_) => abort("expected sticky cancellation on second exec")
  }
}

///|
test "Thread.uncancel: allows execution after cancellation is cleared" {
  let thread = @eval.Thread::new("test")
  thread.cancel("stop")
  thread.uncancel()
  let result = @eval.exec_file(
    thread,
    "test.star",
    "x = 1",
    @eval.Options::default(),
  )
  assert_true(result is Ok(_))
}

///|
test "Thread.execution_steps: returns nonzero after evaluating expressions" {
  let thread = @eval.Thread::new("test")
  let _ = @eval.exec_file(
    thread,
    "test.star",
    "x = 1 + 2 + 3",
    @eval.Options::default(),
  )
  assert_true(thread.execution_steps() > 0)
}

///|
test "Thread.execution_steps: scales linearly with computation size" {
  let count_steps : (Int) -> Int = fn(n) {
    let thread = @eval.Thread::new("test")
    let steps0 = thread.execution_steps()
    let _ = @eval.exec_file_with_predeclared(
      thread,
      "steps.star",
      "squares = [x*x for x in range(n)]",
      @eval.Options::default(),
      @eval.Predeclared::from_map({
        "n": @value.Value::Int(BigInt::from_int(n)),
      }),
    )
    thread.execution_steps() - steps0
  }
  let steps_small = count_steps(1000)
  let steps_large = count_steps(100000)
  let ratio = steps_large.to_double() / steps_small.to_double()
  assert_true(ratio >= 99.0 && ratio <= 101.0)
}

///|
test "Thread.with_step_budget: halts when budget is exceeded" {
  let thread = @eval.Thread::with_step_budget("test", 10)
  let result = @eval.exec_file(
    thread,
    "test.star",
    "x = 0\nfor i in range(1000):\n  x = i",
    @eval.Options::default(),
  )
  match result {
    Err(e) =>
      assert_true(
        e.msg().contains("Starlark computation cancelled: too many steps"),
      )
    Ok(_) => abort("expected step budget error")
  }
}

///|
test "error format: load failure uses cannot-load prefix" {
  let thread = @eval.Thread::with_loader("test", fn(_thread, _path) {
    Err(@errors.EvalError::simple("floored division by zero"))
  })
  let result = @eval.exec_file(
    thread,
    "root.star",
    "load('crash.star', 'x')",
    @eval.Options::default(),
  )
  match result {
    Err(e) =>
      inspect(
        e.msg(),
        content=(
          #|cannot load crash.star: floored division by zero
        ),
      )
    Ok(_) => abort("expected error")
  }
}

///|
test "error format: builtin method error shows Error-in prefix" {
  let thread = @eval.Thread::new("test")
  let src =
    #|def f():
    #|  ''.join([1])
    #|f()
  let result = @eval.exec_file(
    thread,
    "test.star",
    src,
    @eval.Options::default(),
  )
  match result {
    Err(e) =>
      inspect(
        e.backtrace(),
        content=(
          #|Traceback (most recent call last):
          #|  test.star:3:2: in <toplevel>
          #|  test.star:3:2: in f
          #|Error in join: join: in list, want string, got int
        ),
      )
    Ok(_) => abort("expected error")
  }
}

///|
test "error format: builtin with callback shows builtin frame in traceback" {
  let thread = @eval.Thread::new("test")
  let src =
    #|def bad(x): return 1 // 0
    #|def f():
    #|  min([1], key=bad)
    #|f()
  let result = @eval.exec_file(
    thread,
    "test.star",
    src,
    @eval.Options::default(),
  )
  match result {
    Err(e) => {
      let bt = e.backtrace()
      assert_true(bt.contains("<builtin>: in min"))
      assert_true(bt.contains("integer division by zero"))
    }
    Ok(_) => abort("expected error")
  }
}

///|
test "error format: module-level error backtrace includes <toplevel> frame (BUG-3)" {
  let thread = @eval.Thread::new("test")
  let result = @eval.exec_file(
    thread,
    "test.star",
    "x = 1 + \"oops\"",
    @eval.Options::default(),
  )
  match result {
    Err(e) => {
      let bt = e.backtrace()
      assert_true(bt.contains("in <toplevel>"))
    }
    Ok(_) => abort("expected error")
  }
}

///|
test "error format: function call from toplevel shows <toplevel> frame (BUG-3)" {
  let thread = @eval.Thread::new("test")
  let src =
    #|def g():
    #|  return 1 + "oops"
    #|def f():
    #|  g()
    #|f()
  let result = @eval.exec_file(
    thread,
    "test.star",
    src,
    @eval.Options::default(),
  )
  match result {
    Err(e) => {
      let bt = e.backtrace()
      assert_true(bt.contains("in <toplevel>"))
      assert_true(bt.contains("in f"))
      assert_true(bt.contains("in g"))
    }
    Ok(_) => abort("expected error")
  }
}
