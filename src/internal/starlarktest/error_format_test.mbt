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
        e.msg,
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
        e.msg,
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
        e.msg,
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
        e.msg,
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
        e.msg,
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
        e.msg,
        content=(
          #|function f missing 1 argument (b)
        ),
      )
    Ok(_) => abort("expected error")
  }
}

///|
test "error format: recursion depth exceeded" {
  let thread = @eval.Thread::with_print("test", fn(_) {  })
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
        e.msg,
        content=(
          #|maximum recursion depth exceeded
        ),
      )
    Ok(_) => abort("expected error")
  }
}
