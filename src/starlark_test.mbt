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

///|
test "compare_limit constant equals 10" {
  assert_eq(@starlark.compare_limit, 10)
}

///|
test "equal_depth with depth 0 returns recursion error" {
  let a = @starlark.Value::List(@starlark.StarlarkList::new([]))
  let b = @starlark.Value::List(@starlark.StarlarkList::new([]))
  match @starlark.equal_depth(a, b, 0) {
    Err(e) => assert_true(e.msg().contains("maximum recursion"))
    Ok(_) => assert_true(false)
  }
}

///|
test "equal_depth with positive depth compares equal values" {
  let a = @starlark.Value::Int(42L)
  let b = @starlark.Value::Int(42L)
  match @starlark.equal_depth(a, b, 10) {
    Ok(true) => ()
    _ => assert_true(false)
  }
}

///|
test "compare_depth with depth 0 returns recursion error" {
  let a = @starlark.Value::List(@starlark.StarlarkList::new([]))
  let b = @starlark.Value::List(@starlark.StarlarkList::new([]))
  match @starlark.compare_depth("==", a, b, 0) {
    Err(e) => assert_true(e.msg().contains("maximum recursion"))
    Ok(_) => assert_true(false)
  }
}

///|
test "compare_depth with positive depth handles ordered comparison" {
  let a = @starlark.Value::Int(1L)
  let b = @starlark.Value::Int(2L)
  match @starlark.compare_depth("<", a, b, 10) {
    Ok(true) => ()
    _ => assert_true(false)
  }
}

///|
test "StarlarkFunction::num_params counts positional parameters" {
  let t = @starlark.Thread::new("test")
  match
    @starlark.exec_file(
      t,
      "<test>",
      "def f(a, b, c): pass",
      @starlark.Options::default(),
    ) {
    Ok(m) =>
      match @starlark.module_get(m, "f") {
        Some(@starlark.Value::Function(f)) => assert_eq(f.num_params(), 3)
        _ => assert_true(false)
      }
    Err(_) => assert_true(false)
  }
}

///|
test "StarlarkFunction::has_varargs detects star-args parameter" {
  let t = @starlark.Thread::new("test")
  match
    @starlark.exec_file(
      t,
      "<test>",
      "def f(a, *args): pass",
      @starlark.Options::default(),
    ) {
    Ok(m) =>
      match @starlark.module_get(m, "f") {
        Some(@starlark.Value::Function(f)) => {
          assert_true(f.has_varargs())
          assert_false(f.has_kwargs())
        }
        _ => assert_true(false)
      }
    Err(_) => assert_true(false)
  }
}

///|
test "StarlarkFunction::has_kwargs detects double-star parameter" {
  let t = @starlark.Thread::new("test")
  match
    @starlark.exec_file(
      t,
      "<test>",
      "def f(a, **kwargs): pass",
      @starlark.Options::default(),
    ) {
    Ok(m) =>
      match @starlark.module_get(m, "f") {
        Some(@starlark.Value::Function(f)) => {
          assert_false(f.has_varargs())
          assert_true(f.has_kwargs())
        }
        _ => assert_true(false)
      }
    Err(_) => assert_true(false)
  }
}

///|
test "StarlarkFunction::num_kwonly_params counts keyword-only params" {
  let t = @starlark.Thread::new("test")
  match
    @starlark.exec_file(
      t,
      "<test>",
      "def f(a, *, b, c): pass",
      @starlark.Options::default(),
    ) {
    Ok(m) =>
      match @starlark.module_get(m, "f") {
        Some(@starlark.Value::Function(f)) =>
          assert_eq(f.num_kwonly_params(), 2)
        _ => assert_true(false)
      }
    Err(_) => assert_true(false)
  }
}

///|
test "StarlarkFunction::param returns name and position by index" {
  let t = @starlark.Thread::new("test")
  match
    @starlark.exec_file(
      t,
      "<test>",
      "def f(x, y): pass",
      @starlark.Options::default(),
    ) {
    Ok(m) =>
      match @starlark.module_get(m, "f") {
        Some(@starlark.Value::Function(f)) => {
          let (name0, _pos0) = f.param(0)
          let (name1, _pos1) = f.param(1)
          assert_eq(name0, "x")
          assert_eq(name1, "y")
        }
        _ => assert_true(false)
      }
    Err(_) => assert_true(false)
  }
}

///|
test "StarlarkFunction::doc returns first string literal as docstring" {
  let t = @starlark.Thread::new("test")
  match
    @starlark.exec_file(
      t,
      "<test>",
      "def f():\n  \"the doc\"\n  pass",
      @starlark.Options::default(),
    ) {
    Ok(m) =>
      match @starlark.module_get(m, "f") {
        Some(@starlark.Value::Function(f)) => assert_eq(f.doc(), "the doc")
        _ => assert_true(false)
      }
    Err(_) => assert_true(false)
  }
}

///|
test "StarlarkFunction::position returns def site position" {
  let t = @starlark.Thread::new("test")
  match
    @starlark.exec_file(
      t,
      "<test>",
      "def f(): pass",
      @starlark.Options::default(),
    ) {
    Ok(m) =>
      match @starlark.module_get(m, "f") {
        Some(@starlark.Value::Function(f)) => {
          let pos = f.position()
          assert_eq(pos.filename(), "<test>")
          assert_eq(pos.line(), 1)
        }
        _ => assert_true(false)
      }
    Err(_) => assert_true(false)
  }
}

///|
test "Module::globals_map returns all module-level globals" {
  let t = @starlark.Thread::new("test")
  match
    @starlark.exec_file(
      t,
      "<test>",
      "x = 1\ny = 2",
      @starlark.Options::default(),
    ) {
    Ok(m) => {
      let gmap = m.globals_map()
      assert_true(gmap.contains("x"))
      assert_true(gmap.contains("y"))
      assert_eq(gmap.length(), 2)
    }
    Err(_) => assert_true(false)
  }
}

///|
test "Module::predeclared_map returns predeclared bindings" {
  let t = @starlark.Thread::new("test")
  let pre = @starlark.Predeclared::new()
  pre.set("answer", @starlark.Value::Int(42L))
  match
    @starlark.exec_file_with_predeclared(
      t,
      "<test>",
      "x = answer",
      @starlark.Options::default(),
      pre,
    ) {
    Ok(m) => {
      let pmap = m.predeclared_map()
      assert_true(pmap.contains("answer"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "Thread::set_local and local store and retrieve host values" {
  let t = @starlark.Thread::new("test")
  t.set_local(
    "request_id",
    @starlark.Value::String(@starlark.StarlarkString::new("abc-123")),
  )
  match t.get_local("request_id") {
    Some(@starlark.Value::String(s)) => assert_eq(s.raw(), "abc-123")
    _ => assert_true(false)
  }
}

///|
test "Thread::local returns None for missing key" {
  let t = @starlark.Thread::new("test")
  assert_true(t.get_local("missing") is None)
}

///|
test "StarlarkBuiltinFunc::receiver returns None for unbound builtin" {
  let b = @starlark.StarlarkBuiltinFunc::dispatch("my_func")
  assert_true(b.receiver() is None)
}

///|
test "StarlarkBuiltinFunc::bind_receiver creates a bound builtin" {
  let b = @starlark.StarlarkBuiltinFunc::dispatch("my_method")
  let recv = @starlark.Value::Int(42L)
  let bound = b.bind_receiver(recv)
  match bound.receiver() {
    Some(@starlark.Value::Int(42L)) => ()
    _ => assert_true(false)
  }
}

///|
test "StarlarkFunction::free_var returns name from captured scope" {
  let t = @starlark.Thread::new("test")
  match
    @starlark.exec_file(
      t,
      "<test>",
      "def outer():\n  y = 20\n  def inner(): return y\n  return inner\nf = outer()",
      @starlark.Options::default(),
    ) {
    Ok(m) =>
      match @starlark.module_get(m, "f") {
        Some(@starlark.Value::Function(f)) =>
          assert_true(f.num_free_vars() >= 1)
        _ => assert_true(false)
      }
    Err(_) => assert_true(false)
  }
}

///|
test "StarlarkFunction::free_var returns binding from captured scope" {
  let t = @starlark.Thread::new("test")
  match
    @starlark.exec_file(
      t,
      "<test>",
      "def outer():\n  captured = 99\n  def inner(): return captured\n  return inner\nf = outer()",
      @starlark.Options::default(),
    ) {
    Ok(m) =>
      match @starlark.module_get(m, "f") {
        Some(@starlark.Value::Function(f)) => {
          let n = f.num_free_vars()
          assert_true(n >= 1)
          // The first free var should be the captured binding
          match f.free_var(0) {
            Some((name, _val)) => assert_true(name.length() > 0)
            None => assert_true(false)
          }
        }
        _ => assert_true(false)
      }
    Err(_) => assert_true(false)
  }
}

///|
test "StarlarkFunction::globals returns module global variables" {
  let t = @starlark.Thread::new("test")
  match
    @starlark.exec_file(
      t,
      "<test>",
      "X = 10\ndef f(): return X",
      @starlark.Options::default(),
    ) {
    Ok(m) =>
      match @starlark.module_get(m, "f") {
        Some(@starlark.Value::Function(f)) => {
          let g = f.globals()
          assert_true(g.contains("X"))
        }
        _ => assert_true(false)
      }
    Err(_) => assert_true(false)
  }
}

///|
test "StarlarkFunction::module returns the defining module" {
  let t = @starlark.Thread::new("test")
  match
    @starlark.exec_file(
      t,
      "mymod.star",
      "CONST = 42\ndef f(): return CONST",
      @starlark.Options::default(),
    ) {
    Ok(m) =>
      match @starlark.module_get(m, "f") {
        Some(@starlark.Value::Function(f)) =>
          match f.defining_module() {
            Some(mod_ref) => {
              assert_eq(mod_ref.name(), "mymod.star")
              assert_true(mod_ref.get("CONST") is Some(_))
            }
            None => assert_true(false)
          }
        _ => assert_true(false)
      }
    Err(_) => assert_true(false)
  }
}
