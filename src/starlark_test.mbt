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
        @starlark.module_get(m, "x") is Some(@starlark.Value::Int(3L)),
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
    Ok(v) => assert_true(v is @starlark.Value::Int(3L))
    Err(_) => assert_true(false)
  }
}

///|
test "exec_file_with_predeclared injects host bindings" {
  let t = @starlark.Thread::new("test")
  let predeclared = @starlark.Predeclared::from_map({
    "ANSWER": @starlark.Value::Int(42L),
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
        @starlark.module_get(m, "x") is Some(@starlark.Value::Int(43L)),
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

///|
test "Thread::call_stack returns empty snapshot before execution" {
  let t = @starlark.Thread::new("test")
  let cs = t.call_stack()
  assert_eq(cs.length(), 0)
}

///|
test "Thread::call_stack_depth returns 0 before execution" {
  let t = @starlark.Thread::new("test")
  assert_eq(t.call_stack_depth(), 0)
}

///|
test "Thread::call_stack snapshot is independent after pop" {
  let t = @starlark.Thread::new("test")
  let cs = t.call_stack()
  assert_eq(cs.length(), 0)
  assert_true(cs.at(0) is None)
  assert_true(cs.pop() is None)
}

///|
test "equal returns Ok(true) for equal values" {
  let a = @starlark.Value::Int(42L)
  let b = @starlark.Value::Int(42L)
  assert_true(@starlark.equal(a, b) is Ok(true))
}

///|
test "equal returns Ok(false) for unequal values" {
  let a = @starlark.Value::Int(1L)
  let b = @starlark.Value::Int(2L)
  assert_true(@starlark.equal(a, b) is Ok(false))
}

///|
test "equal returns Ok(true) for Int equal to Float" {
  let a = @starlark.Value::Int(1L)
  let b = @starlark.Value::Float(1.0)
  assert_true(@starlark.equal(a, b) is Ok(true))
}

///|
test "number_to_int returns Some for Int" {
  let v = @starlark.Value::Int(7L)
  assert_true(@starlark.number_to_int(v) is Some(7L))
}

///|
test "number_to_int truncates Float to Int" {
  let v = @starlark.Value::Float(3.9)
  assert_true(@starlark.number_to_int(v) is Some(3L))
}

///|
test "number_to_int returns None for non-number" {
  let v = @starlark.Value::String(@starlark.StarlarkString::new("hi"))
  assert_true(@starlark.number_to_int(v) is None)
}

///|
test "as_float extracts Double from Float" {
  let v = @starlark.Value::Float(2.5)
  let (f, ok) = @starlark.as_float(v)
  assert_true(ok)
  assert_true(f == 2.5)
}

///|
test "as_float converts Int to Double" {
  let v = @starlark.Value::Int(3L)
  let (f, ok) = @starlark.as_float(v)
  assert_true(ok)
  assert_true(f == 3.0)
}

///|
test "as_float returns (0.0, false) for non-number" {
  let v = @starlark.Value::None
  let (f, ok) = @starlark.as_float(v)
  assert_false(ok)
  assert_true(f == 0.0)
}

///|
test "as_string extracts raw string from String value" {
  let v = @starlark.Value::String(@starlark.StarlarkString::new("hello"))
  let (s, ok) = @starlark.as_string(v)
  assert_true(ok)
  assert_eq(s, "hello")
}

///|
test "as_string returns empty string and false for non-string" {
  let v = @starlark.Value::Int(1L)
  let (s, ok) = @starlark.as_string(v)
  assert_false(ok)
  assert_eq(s, "")
}

///|
test "len_of returns sequence length for List" {
  let v = @starlark.Value::List(
    @starlark.StarlarkList::new([
      @starlark.Value::Int(1L),
      @starlark.Value::Int(2L),
    ]),
  )
  assert_eq(@starlark.len_of(v), 2)
}

///|
test "len_of returns -1 for non-sequence" {
  let v = @starlark.Value::Int(5L)
  assert_eq(@starlark.len_of(v), -1)
}

///|
test "iterate returns an iterator for a list" {
  let lst = @starlark.Value::List(
    @starlark.StarlarkList::new([@starlark.Value::Int(10L)]),
  )
  match @starlark.iterate(lst) {
    Ok(it) => {
      assert_true(it.next() is Some(@starlark.Value::Int(10L)))
      it.done()
    }
    Err(_) => assert_true(false)
  }
}

///|
test "iterate returns Err for non-iterable" {
  let v = @starlark.Value::Int(1L)
  assert_true(@starlark.iterate(v) is Err(_))
}

///|
test "call invokes a Starlark function from the host" {
  let t = @starlark.Thread::new("test")
  match
    @starlark.exec_file(
      t,
      "<test>",
      "def add(a, b): return a + b",
      @starlark.Options::default(),
    ) {
    Ok(m) =>
      match @starlark.module_get(m, "add") {
        Some(fn_val) =>
          match
            @starlark.call(
              t,
              fn_val,
              [@starlark.Value::Int(3L), @starlark.Value::Int(4L)],
              [],
            ) {
            Ok(v) => assert_true(v is @starlark.Value::Int(7L))
            Err(_) => assert_true(false)
          }
        None => assert_true(false)
      }
    Err(_) => assert_true(false)
  }
}

///|
test "StringDict: basic construction and access" {
  let d = @starlark.StringDict::new()
  d.set("x", @starlark.Value::Int(1L))
  d.set("y", @starlark.Value::Bool(true))
  assert_true(d.has("x"))
  assert_true(d.has("y"))
  assert_false(d.has("z"))
  assert_true(d.get("x") == Some(@starlark.Value::Int(1L)))
  assert_true(d.get("missing") == None)
}

///|
test "StringDict::keys returns sorted keys" {
  let d = @starlark.StringDict::new()
  d.set("beta", @starlark.Value::None)
  d.set("alpha", @starlark.Value::None)
  d.set("gamma", @starlark.Value::None)
  let keys = d.keys()
  assert_true(keys == ["alpha", "beta", "gamma"])
}

///|
test "StringDict::freeze freezes contained values" {
  let d = @starlark.StringDict::new()
  let lst = @starlark.StarlarkList::new([@starlark.Value::Int(1L)])
  d.set("lst", @starlark.Value::List(lst))
  d.freeze()
  assert_true(lst.is_frozen())
}

///|
test "binary: integer arithmetic via public API" {
  let two = @starlark.Value::Int(2L)
  let three = @starlark.Value::Int(3L)
  match @starlark.binary("+", two, three) {
    Ok(v) => assert_true(v == @starlark.Value::Int(5L))
    Err(_) => assert_true(false)
  }
  match @starlark.binary("*", two, three) {
    Ok(v) => assert_true(v == @starlark.Value::Int(6L))
    Err(_) => assert_true(false)
  }
}

///|
test "unary: not operator via public API" {
  match @starlark.unary("not", @starlark.Value::Bool(false)) {
    Ok(v) => assert_true(v == @starlark.Value::Bool(true))
    Err(_) => assert_true(false)
  }
}

///|
test "compare: integer comparison via public API" {
  let two = @starlark.Value::Int(2L)
  let three = @starlark.Value::Int(3L)
  match @starlark.compare("<", two, three) {
    Ok(b) => assert_true(b)
    Err(_) => assert_true(false)
  }
  match @starlark.compare("==", two, two) {
    Ok(b) => assert_true(b)
    Err(_) => assert_true(false)
  }
}
