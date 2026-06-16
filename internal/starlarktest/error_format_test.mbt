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
          #|test.star:1:6: got end of file, want primary expression
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
test "error format: sequence-assignment of a non-iterable has no position prefix" {
  let thread = @eval.Thread::new("test")
  let result = @eval.exec_file(
    thread,
    "test.star",
    "a, b = 5",
    @eval.Options::default(),
  )
  match result {
    Err(e) =>
      inspect(
        e.msg(),
        content=(
          #|got int in sequence assignment
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
          #|floored division by zero
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
          #|list index 10 out of range [-3:2]
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
          #|  test.star:4:4: in f
          #|  test.star:2:12: in g
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
          #|  test.star:1:7: in <toplevel>
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
  let thread = @eval.Thread::with_print("test", fn(_, _bytes) {  })
  let src =
    #|def f():
    #|  return f()
    #|f()
  let result = @eval.exec_file(
    thread,
    "test.star",
    src,
    @eval.Options::default().with_allow_recursion(true),
  )
  match result {
    Err(e) =>
      inspect(
        e.msg(),
        content=(
          #|Starlark stack overflow
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
    @eval.Options::default()
    .with_allow_top_level_control(true)
    .with_allow_global_reassign(true),
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
test "error format: load failure backtrace shows toplevel frame" {
  let thread = @eval.Thread::with_loader("test", fn(_thread, _path) {
    Err(@errors.EvalError::simple("floored division by zero"))
  })
  let src =
    #|
    #|load('crash.star', 'x')
  let result = @eval.exec_file(
    thread,
    "root.star",
    src,
    @eval.Options::default(),
  )
  match result {
    Err(e) =>
      inspect(
        e.backtrace(),
        content=(
          #|Traceback (most recent call last):
          #|  root.star:2:1: in <toplevel>
          #|Error: cannot load crash.star: floored division by zero
        ),
      )
    Ok(_) => abort("expected error")
  }
}

///|
test "error format: load failure cause preserves inner backtrace" {
  let loaded_src =
    #|def f(x):
    #|  return 1 // x
    #|
    #|f(0)
  let thread = @eval.Thread::with_loader("test", fn(_thread, path) {
    let inner_thread = @eval.Thread::new("inner")
    @eval.exec_file(inner_thread, path, loaded_src, @eval.Options::default())
  })
  let src =
    #|
    #|load('crash.star', 'x')
  let result = @eval.exec_file(
    thread,
    "root.star",
    src,
    @eval.Options::default(),
  )
  match result {
    Err(e) => {
      inspect(
        e.backtrace(),
        content=(
          #|Traceback (most recent call last):
          #|  root.star:2:1: in <toplevel>
          #|Error: cannot load crash.star: floored division by zero
        ),
      )
      match e.cause() {
        Some(inner) =>
          inspect(
            inner.backtrace(),
            content=(
              #|Traceback (most recent call last):
              #|  crash.star:4:2: in <toplevel>
              #|  crash.star:2:12: in f
              #|Error: floored division by zero
            ),
          )
        None => abort("expected inner cause error")
      }
    }
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
          #|  test.star:2:10: in f
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
      assert_true(bt.contains("floored division by zero"))
    }
    Ok(_) => abort("expected error")
  }
}

///|
test "error format: module-level error backtrace includes <toplevel> frame" {
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
test "error format: function call from toplevel shows <toplevel> frame" {
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

///|
test "error format: intermediate frame shows call-site within function" {
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
          #|  test.star:4:4: in f
          #|  test.star:2:12: in g
          #|Error: unknown binary op: int + string
        ),
      )
    Ok(_) => abort("expected error")
  }
}

///|
test "error format: deep call chain frames show call positions" {
  let thread = @eval.Thread::new("test")
  let src =
    #|def f(x): return 1//x
    #|def g(x): return f(x)
    #|def h(): return min([1, 2, 0], key=g)
    #|def i(): return h()
    #|i()
  let result = @eval.exec_file(
    thread,
    "crash.star",
    src,
    @eval.Options::default(),
  )
  match result {
    Err(e) =>
      inspect(
        e.backtrace(),
        content=(
          #|Traceback (most recent call last):
          #|  crash.star:5:2: in <toplevel>
          #|  crash.star:4:18: in i
          #|  crash.star:3:20: in h
          #|  <builtin>: in min
          #|  crash.star:2:19: in g
          #|  crash.star:1:19: in f
          #|Error: floored division by zero
        ),
      )
    Ok(_) => abort("expected error")
  }
}

///|
test "error format: traceback frame anchors at the binary operator, not the left operand" {
  let cases : Array[(String, String)] = [
    ("\"aaaaaaaaaa\" + 1", "t.star:1:14: in <toplevel>"),
    ("1 < \"a\"", "t.star:1:3: in <toplevel>"),
    ("1 | \"x\"", "t.star:1:3: in <toplevel>"),
  ]
  for item in cases {
    let (src, want_frame) = item
    let thread = @eval.Thread::new("test")
    let result = @eval.exec_file(
      thread,
      "t.star",
      src,
      @eval.Options::default(),
    )
    match result {
      Err(e) => assert_true(e.backtrace().contains(want_frame))
      Ok(_) => abort("expected error for: \{src}")
    }
  }
}

///|
test "error format: traceback frame anchors at the = sign for tuple unpack" {
  let thread = @eval.Thread::new("test")
  let result = @eval.exec_file(
    thread,
    "t.star",
    "a, b = 1, 2, 3",
    @eval.Options::default(),
  )
  match result {
    Err(e) => assert_true(e.backtrace().contains("t.star:1:6: in <toplevel>"))
    Ok(_) => abort("expected error")
  }
}

///|
test "error format: load with no loader gives 'not implemented' message" {
  let thread = @eval.Thread::new("test")
  let src =
    #|load('foo.star', 'x')
  let result = @eval.exec_file(
    thread,
    "root.star",
    src,
    @eval.Options::default(),
  )
  match result {
    Err(e) =>
      assert_true(e.msg().contains("load not implemented by this application"))
    Ok(_) => abort("expected error")
  }
}

///|
test "error format: load name-not-found error has no position prefix in message" {
  let thread = @eval.Thread::with_loader("test", fn(_thread, _path) {
    Ok(@eval.Module::new())
  })
  let src =
    #|load('m.star', 'missing_name')
  let result = @eval.exec_file(
    thread,
    "root.star",
    src,
    @eval.Options::default(),
  )
  match result {
    Err(e) => {
      let msg = e.msg()
      assert_true(msg.contains("load: name missing_name not found in module"))
      assert_true(!msg.has_prefix("root.star:"))
    }
    Ok(_) => abort("expected error")
  }
}

///|
test "Thread.with_print: callback receives caller position and name via call_frame(1)" {
  let buf : Array[String] = []
  let src =
    #|
    #|print("hello")
    #|def f(): print("hello", "world", sep=", ")
    #|f()
  let thread = @eval.Thread::with_print("test", fn(thread, bytes) {
    let msg = @utf8.decode_lossy(bytes[:])
    match thread.call_frame(1) {
      Some(frame) =>
        buf.push("\{frame.pos().to_string()}: \{frame.name()}: \{msg}\n")
      None => ()
    }
  })
  let result = @eval.exec_file(
    thread,
    "foo.star",
    src,
    @eval.Options::default(),
  )
  assert_true(result is Ok(_))
  let got = buf.join("")
  let want = "foo.star:2:6: <toplevel>: hello\nfoo.star:3:15: f: hello, world\n"
  assert_eq(got, want)
}
