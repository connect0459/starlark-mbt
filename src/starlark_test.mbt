///|
test "new_thread creates a Thread usable with exec_file" {
  let t = @eval.Thread::new("hello")
  assert_eq(t.name(), "hello")
}

///|
test "default_options returns Options with all feature flags enabled" {
  let opts = @eval.Options::default()
  assert_eq(opts.allow_set(), true)
  assert_eq(opts.allow_recursion(), true)
  assert_eq(opts.allow_float(), true)
}

///|
test "Options::with_allow_bytes toggles the allow_bytes flag" {
  let opts = @eval.Options::default().with_allow_bytes(false)
  assert_eq(opts.allow_bytes(), false)
  assert_eq(opts.allow_float(), true)
}

///|
test "Options::with_allow_float toggles the allow_float flag" {
  let opts = @eval.Options::default().with_allow_float(false)
  assert_eq(opts.allow_float(), false)
  assert_eq(opts.allow_bytes(), true)
}

///|
test "Options::with_allow_lambda toggles the allow_lambda flag" {
  let opts = @eval.Options::default().with_allow_lambda(false)
  assert_eq(opts.allow_lambda(), false)
  assert_eq(opts.allow_while(), true)
}

///|
test "Options::with_allow_while toggles the allow_while flag" {
  let opts = @eval.Options::default().with_allow_while(false)
  assert_eq(opts.allow_while(), false)
  assert_eq(opts.allow_lambda(), true)
}

///|
test "Options::with_allow_top_level_control toggles the flag" {
  let opts = @eval.Options::default().with_allow_top_level_control(false)
  assert_eq(opts.allow_top_level_control(), false)
  assert_eq(opts.allow_while(), true)
}

///|
test "new_thread_with_loader resolves load() calls via callback" {
  let lib_src =
    #|def double(x): return x * 2
  let main_src =
    #|load("lib.star", "double")
    #|result = double(21)
  let loader = fn(
    _t : @eval.Thread,
    _path : String,
  ) -> Result[@eval.Module, @errors.EvalError] {
    let lt = @eval.Thread::new("loader")
    @starlark.exec_file(lt, "lib.star", lib_src, @eval.Options::default())
  }
  let thread = @starlark.new_thread_with_loader("main", loader)
  match
    @starlark.exec_file(thread, "main.star", main_src, @eval.Options::default()) {
    Ok(m) =>
      match m.get("result") {
        Some(v) =>
          match @starlark.number_to_int(v) {
            Some(n) => assert_eq(n, 42L)
            None => assert_true(false)
          }
        None => assert_true(false)
      }
    Err(e) => fail(e.msg())
  }
}

///|
test "error_message extracts the message from an EvalError" {
  let t = @eval.Thread::new("test")
  match
    @starlark.exec_file(t, "<test>", "x = 1 // 0", @eval.Options::default()) {
    Err(e) => assert_true(e.msg().contains("zero"))
    Ok(_) => assert_true(false)
  }
}

///|
test "Universe::set adds a binding visible to executed modules" {
  let u = @eval.Universe::standard()
  u.set("MY_CONST", @value.Value::Int(42N))
  let t = @eval.Thread::new("test")
  match
    @starlark.exec_file_with_universe(
      t,
      "<test>",
      "result = MY_CONST + 1",
      @eval.Options::default(),
      u,
    ) {
    Ok(m) => assert_true(m.get("result") == Some(@value.Value::Int(43N)))
    Err(e) => fail(e.msg())
  }
}

///|
test "eval_expr_with_opts respects allow_set option" {
  let t = @eval.Thread::new("test")
  let env = @value.StarlarkDict::new()
  // With allow_set=true, {1, 2} parses and evaluates as a Set.
  let opts_with_set = @eval.Options::default()
  match
    @starlark.eval_expr_with_opts(t, "<test>", "{1, 2}", opts_with_set, env) {
    Ok(@value.Value::Set(_)) => ()
    Ok(v) => fail("expected Set, got \{v.type_name()}")
    Err(e) => fail(e.msg())
  }
}

///|
test "parse_file + file_program + Program::init pipeline" {
  let file = match @starlark.parse_file("<test>", "result = X + 1") {
    Ok(f) => f
    Err(e) => fail(e.msg())
  }
  let prog = match
    @starlark.file_program(file, @eval.Options::default(), fn(n) { n == "X" }) {
    Ok(p) => p
    Err(e) => fail(e.msg())
  }
  let pd1 = @eval.Predeclared::new()
  pd1.set("X", @value.Value::Int(10N))
  let t1 = @eval.Thread::new("test")
  match prog.init(t1, pd1) {
    Ok(m) => assert_true(m.get("result") == Some(@value.Value::Int(11N)))
    Err(e) => fail(e.msg())
  }
  let pd2 = @eval.Predeclared::new()
  pd2.set("X", @value.Value::Int(99N))
  let t2 = @eval.Thread::new("test")
  match prog.init(t2, pd2) {
    Ok(m) => assert_true(m.get("result") == Some(@value.Value::Int(100N)))
    Err(e) => fail(e.msg())
  }
}

///|
test "source_program_with_file returns both File and Program" {
  match
    @starlark.source_program_with_file(
      "hello.star",
      "x = 1",
      @eval.Options::default(),
      fn(_) { false },
    ) {
    Ok((f, prog)) => {
      assert_eq(f.path(), "hello.star")
      assert_eq(prog.filename(), "hello.star")
    }
    Err(e) => fail(e.msg())
  }
}

///|
test "Thread can be created with a name" {
  let t = @eval.Thread::new("main")
  assert_eq(t.name(), "main")
}

///|
test "Thread::with_step_budget halts computation that exceeds limit" {
  let t = @eval.Thread::with_step_budget("test", 5)
  match
    @starlark.exec_file(
      t,
      "<test>",
      "i = 0\nwhile i < 1000000:\n  i = i + 1",
      @eval.Options::default(),
    ) {
    Err(e) =>
      assert_true(
        e.msg().contains("Starlark computation cancelled: too many steps"),
      )
    Ok(_) => assert_true(false)
  }
}

///|
test "Options::default enables all feature flags" {
  let opts = @eval.Options::default()
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
  let t = @eval.Thread::new("test")
  match
    @starlark.exec_file(t, "<test>", "x = 1 + 2", @eval.Options::default()) {
    Ok(m) => assert_true(m.get("x") is Some(@value.Value::Int(3N)))
    Err(_) => assert_true(false)
  }
}

///|
test "exec_file reports a runtime error as EvalError" {
  let t = @eval.Thread::new("test")
  match
    @starlark.exec_file(t, "<test>", "x = 1 // 0", @eval.Options::default()) {
    Err(e) => assert_true(e.msg().contains("zero"))
    Ok(_) => assert_true(false)
  }
}

///|
test "exec_file reports a syntax error wrapped as EvalError" {
  let t = @eval.Thread::new("test")
  match
    @starlark.exec_file(t, "<test>", "def f(: pass", @eval.Options::default()) {
    Err(e) => assert_true(e.msg().length() > 0)
    Ok(_) => assert_true(false)
  }
}

///|
test "eval_expr evaluates an expression in an empty environment" {
  let t = @eval.Thread::new("test")
  let env = @value.StarlarkDict::new()
  match @starlark.eval_expr(t, "<test>", "1 + 2", env) {
    Ok(v) => assert_true(v is @value.Value::Int(3N))
    Err(_) => assert_true(false)
  }
}

///|
test "exec_file_with_predeclared injects host bindings" {
  let t = @eval.Thread::new("test")
  let predeclared = @eval.Predeclared::from_map({
    "ANSWER": @value.Value::Int(42N),
  })
  match
    @starlark.exec_file_with_predeclared(
      t,
      "<test>",
      "x = ANSWER + 1",
      @eval.Options::default(),
      predeclared,
    ) {
    Ok(m) => assert_true(m.get("x") is Some(@value.Value::Int(43N)))
    Err(_) => assert_true(false)
  }
}

///|
test "module globals are frozen after exec_file" {
  let t = @eval.Thread::new("test")
  match
    @starlark.exec_file(t, "<test>", "x = [1, 2, 3]", @eval.Options::default()) {
    Ok(m) => assert_true(m.is_frozen())
    Err(_) => assert_true(false)
  }
}

///|
test "Module::get returns None for undefined globals" {
  let t = @eval.Thread::new("test")
  match @starlark.exec_file(t, "<test>", "x = 1", @eval.Options::default()) {
    Ok(m) => assert_true(m.get("y") is None)
    Err(_) => assert_true(false)
  }
}

///|
test "Thread::call_stack returns empty snapshot before execution" {
  let t = @eval.Thread::new("test")
  let cs = t.call_stack()
  assert_eq(cs.length(), 0)
}

///|
test "Thread::call_stack_depth returns 0 before execution" {
  let t = @eval.Thread::new("test")
  assert_eq(t.call_stack_depth(), 0)
}

///|
test "Thread::call_stack snapshot is independent after pop" {
  let t = @eval.Thread::new("test")
  let cs = t.call_stack()
  assert_eq(cs.length(), 0)
  assert_true(cs.at(0) is None)
  assert_true(cs.pop() is None)
}

///|
test "equal returns Ok(true) for equal values" {
  let a = @value.Value::Int(42N)
  let b = @value.Value::Int(42N)
  assert_true(@starlark.equal(a, b) is Ok(true))
}

///|
test "equal returns Ok(false) for unequal values" {
  let a = @value.Value::Int(1N)
  let b = @value.Value::Int(2N)
  assert_true(@starlark.equal(a, b) is Ok(false))
}

///|
test "equal returns Ok(true) for Int equal to Float" {
  let a = @value.Value::Int(1N)
  let b = @value.Value::Float(1.0)
  assert_true(@starlark.equal(a, b) is Ok(true))
}

///|
test "number_to_int returns Some for Int" {
  let v = @value.Value::Int(7N)
  assert_true(@starlark.number_to_int(v) is Some(7L))
}

///|
test "number_to_int truncates Float to Int" {
  let v = @value.Value::Float(3.9)
  assert_true(@starlark.number_to_int(v) is Some(3L))
}

///|
test "number_to_int returns None for Int that overflows Int64" {
  let big = @value.Value::Int(BigInt::from_string("1208925819614629174706176"))
  assert_true(@starlark.number_to_int(big) is None)
}

///|
test "number_to_int returns None for Float NaN" {
  let nan = @value.Value::Float(0.0 / 0.0)
  assert_true(@starlark.number_to_int(nan) is None)
}

///|
test "number_to_int returns None for Float positive Inf" {
  let inf = @value.Value::Float(1.0 / 0.0)
  assert_true(@starlark.number_to_int(inf) is None)
}

///|
test "number_to_int returns None for Float negative Inf" {
  let inf = @value.Value::Float(-1.0 / 0.0)
  assert_true(@starlark.number_to_int(inf) is None)
}

///|
test "number_to_int returns None for non-number" {
  let v = @value.Value::String(@value.StarlarkString::new("hi"))
  assert_true(@starlark.number_to_int(v) is None)
}

///|
test "as_float extracts Double from Float" {
  let v = @value.Value::Float(2.5)
  let (f, ok) = @starlark.as_float(v)
  assert_true(ok)
  assert_true(f == 2.5)
}

///|
test "as_float converts Int to Double" {
  let v = @value.Value::Int(3N)
  let (f, ok) = @starlark.as_float(v)
  assert_true(ok)
  assert_true(f == 3.0)
}

///|
test "as_float returns (0.0, false) for non-number" {
  let v = @value.Value::None
  let (f, ok) = @starlark.as_float(v)
  assert_false(ok)
  assert_true(f == 0.0)
}

///|
test "as_string extracts raw string from String value" {
  let v = @value.Value::String(@value.StarlarkString::new("hello"))
  let (s, ok) = @starlark.as_string(v)
  assert_true(ok)
  assert_eq(s, "hello")
}

///|
test "as_string returns empty string and false for non-string" {
  let v = @value.Value::Int(1N)
  let (s, ok) = @starlark.as_string(v)
  assert_false(ok)
  assert_eq(s, "")
}

///|
test "len_of returns sequence length for List" {
  let v = @value.Value::List(
    @value.StarlarkList::new([@value.Value::Int(1N), @value.Value::Int(2N)]),
  )
  assert_eq(@starlark.len_of(v), 2)
}

///|
test "len_of returns -1 for non-sequence" {
  let v = @value.Value::Int(5N)
  assert_eq(@starlark.len_of(v), -1)
}

///|
test "iterate returns an iterator for a list" {
  let lst = @value.Value::List(
    @value.StarlarkList::new([@value.Value::Int(10N)]),
  )
  match @starlark.iterate(lst) {
    Ok(it) => {
      assert_true(it.next() is Some(@value.Value::Int(10N)))
      it.done()
    }
    Err(_) => assert_true(false)
  }
}

///|
test "iterate returns Err for non-iterable" {
  let v = @value.Value::Int(1N)
  assert_true(@starlark.iterate(v) is Err(_))
}

///|
test "call invokes a Starlark function from the host" {
  let t = @eval.Thread::new("test")
  match
    @starlark.exec_file(
      t,
      "<test>",
      "def add(a, b): return a + b",
      @eval.Options::default(),
    ) {
    Ok(m) =>
      match m.get("add") {
        Some(fn_val) =>
          match
            @starlark.call(
              t,
              fn_val,
              [@value.Value::Int(3N), @value.Value::Int(4N)],
              [],
            ) {
            Ok(v) => assert_true(v is @value.Value::Int(7N))
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
  d.set("x", @value.Value::Int(1N))
  d.set("y", @value.Value::Bool(true))
  assert_true(d.has("x"))
  assert_true(d.has("y"))
  assert_false(d.has("z"))
  assert_true(d.get("x") == Some(@value.Value::Int(1N)))
  assert_true(d.get("missing") == None)
}

///|
test "StringDict::keys returns sorted keys" {
  let d = @starlark.StringDict::new()
  d.set("beta", @value.Value::None)
  d.set("alpha", @value.Value::None)
  d.set("gamma", @value.Value::None)
  let keys = d.keys()
  assert_true(keys == ["alpha", "beta", "gamma"])
}

///|
test "StringDict::freeze freezes contained values" {
  let d = @starlark.StringDict::new()
  let lst = @value.StarlarkList::new([@value.Value::Int(1N)])
  d.set("lst", @value.Value::List(lst))
  d.freeze()
  assert_true(lst.is_frozen())
}

///|
test "binary: integer arithmetic via public API" {
  let two = @value.Value::Int(2N)
  let three = @value.Value::Int(3N)
  match @starlark.binary("+", two, three) {
    Ok(v) => assert_true(v == @value.Value::Int(5N))
    Err(_) => assert_true(false)
  }
  match @starlark.binary("*", two, three) {
    Ok(v) => assert_true(v == @value.Value::Int(6N))
    Err(_) => assert_true(false)
  }
}

///|
test "unary: not operator via public API" {
  match @starlark.unary("not", @value.Value::Bool(false)) {
    Ok(v) => assert_true(v == @value.Value::Bool(true))
    Err(_) => assert_true(false)
  }
}

///|
test "compare: integer comparison via public API" {
  let two = @value.Value::Int(2N)
  let three = @value.Value::Int(3N)
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
test "equal returns Err when nesting exceeds compare_limit" {
  let mut inner = @value.Value::Int(0N)
  for _ in 0..<(@starlark.compare_limit + 2) {
    inner = @value.Value::List(@value.StarlarkList::new([inner]))
  }
  match @starlark.equal(inner, inner) {
    Err(_) => ()
    Ok(_) => fail("expected depth limit error")
  }
}

///|
test "equal_depth with depth 0 returns recursion error" {
  let a = @value.Value::List(@value.StarlarkList::new([]))
  let b = @value.Value::List(@value.StarlarkList::new([]))
  match @starlark.equal_depth(a, b, 0) {
    Err(e) => assert_true(e.msg().contains("maximum recursion"))
    Ok(_) => assert_true(false)
  }
}

///|
test "equal_depth with positive depth compares equal values" {
  let a = @value.Value::Int(42N)
  let b = @value.Value::Int(42N)
  match @starlark.equal_depth(a, b, 10) {
    Ok(true) => ()
    _ => assert_true(false)
  }
}

///|
test "compare_depth with depth 0 returns recursion error" {
  let a = @value.Value::List(@value.StarlarkList::new([]))
  let b = @value.Value::List(@value.StarlarkList::new([]))
  match @starlark.compare_depth("==", a, b, 0) {
    Err(e) => assert_true(e.msg().contains("maximum recursion"))
    Ok(_) => assert_true(false)
  }
}

///|
test "compare_depth with positive depth handles ordered comparison" {
  let a = @value.Value::Int(1N)
  let b = @value.Value::Int(2N)
  match @starlark.compare_depth("<", a, b, 10) {
    Ok(true) => ()
    _ => assert_true(false)
  }
}

///|
test "StarlarkFunction::num_params counts positional parameters" {
  let t = @eval.Thread::new("test")
  match
    @starlark.exec_file(
      t,
      "<test>",
      "def f(a, b, c): pass",
      @eval.Options::default(),
    ) {
    Ok(m) =>
      match m.get("f") {
        Some(@value.Value::Function(f)) => assert_eq(f.num_params(), 3)
        _ => assert_true(false)
      }
    Err(_) => assert_true(false)
  }
}

///|
test "StarlarkFunction::has_varargs detects star-args parameter" {
  let t = @eval.Thread::new("test")
  match
    @starlark.exec_file(
      t,
      "<test>",
      "def f(a, *args): pass",
      @eval.Options::default(),
    ) {
    Ok(m) =>
      match m.get("f") {
        Some(@value.Value::Function(f)) => {
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
  let t = @eval.Thread::new("test")
  match
    @starlark.exec_file(
      t,
      "<test>",
      "def f(a, **kwargs): pass",
      @eval.Options::default(),
    ) {
    Ok(m) =>
      match m.get("f") {
        Some(@value.Value::Function(f)) => {
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
  let t = @eval.Thread::new("test")
  match
    @starlark.exec_file(
      t,
      "<test>",
      "def f(a, *, b, c): pass",
      @eval.Options::default(),
    ) {
    Ok(m) =>
      match m.get("f") {
        Some(@value.Value::Function(f)) => assert_eq(f.num_kwonly_params(), 2)
        _ => assert_true(false)
      }
    Err(_) => assert_true(false)
  }
}

///|
test "StarlarkFunction::param returns name and position by index" {
  let t = @eval.Thread::new("test")
  match
    @starlark.exec_file(
      t,
      "<test>",
      "def f(x, y): pass",
      @eval.Options::default(),
    ) {
    Ok(m) =>
      match m.get("f") {
        Some(@value.Value::Function(f)) => {
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
  let t = @eval.Thread::new("test")
  match
    @starlark.exec_file(
      t,
      "<test>",
      "def f():\n  \"the doc\"\n  pass",
      @eval.Options::default(),
    ) {
    Ok(m) =>
      match m.get("f") {
        Some(@value.Value::Function(f)) => assert_eq(f.doc(), "the doc")
        _ => assert_true(false)
      }
    Err(_) => assert_true(false)
  }
}

///|
test "StarlarkFunction::position returns def site position" {
  let t = @eval.Thread::new("test")
  match
    @starlark.exec_file(t, "<test>", "def f(): pass", @eval.Options::default()) {
    Ok(m) =>
      match m.get("f") {
        Some(@value.Value::Function(f)) => {
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
  let t = @eval.Thread::new("test")
  match
    @starlark.exec_file(t, "<test>", "x = 1\ny = 2", @eval.Options::default()) {
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
  let t = @eval.Thread::new("test")
  let pre = @eval.Predeclared::new()
  pre.set("answer", @value.Value::Int(42N))
  match
    @starlark.exec_file_with_predeclared(
      t,
      "<test>",
      "x = answer",
      @eval.Options::default(),
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
  let t = @eval.Thread::new("test")
  t.set_local(
    "request_id",
    @value.Value::String(@value.StarlarkString::new("abc-123")),
  )
  match t.get_local("request_id") {
    Some(@value.Value::String(s)) => assert_eq(s.raw(), "abc-123")
    _ => assert_true(false)
  }
}

///|
test "Thread::local returns None for missing key" {
  let t = @eval.Thread::new("test")
  assert_true(t.get_local("missing") is None)
}

///|
test "StarlarkBuiltinFunc::receiver returns None for unbound builtin" {
  let b = @value.StarlarkBuiltinFunc::dispatch("my_func")
  assert_true(b.receiver() is None)
}

///|
test "StarlarkBuiltinFunc::bind_receiver creates a bound builtin" {
  let b = @value.StarlarkBuiltinFunc::dispatch("my_method")
  let recv = @value.Value::Int(42N)
  let bound = b.bind_receiver(recv)
  match bound.receiver() {
    Some(@value.Value::Int(42N)) => ()
    _ => assert_true(false)
  }
}

///|
test "StarlarkFunction::free_var returns name from captured scope" {
  let t = @eval.Thread::new("test")
  match
    @starlark.exec_file(
      t,
      "<test>",
      "def outer():\n  y = 20\n  def inner(): return y\n  return inner\nf = outer()",
      @eval.Options::default(),
    ) {
    Ok(m) =>
      match m.get("f") {
        Some(@value.Value::Function(f)) => assert_true(f.num_free_vars() >= 1)
        _ => assert_true(false)
      }
    Err(_) => assert_true(false)
  }
}

///|
test "StarlarkFunction::free_var returns binding from captured scope" {
  let t = @eval.Thread::new("test")
  match
    @starlark.exec_file(
      t,
      "<test>",
      "def outer():\n  captured = 99\n  def inner(): return captured\n  return inner\nf = outer()",
      @eval.Options::default(),
    ) {
    Ok(m) =>
      match m.get("f") {
        Some(@value.Value::Function(f)) => {
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
  let t = @eval.Thread::new("test")
  match
    @starlark.exec_file(
      t,
      "<test>",
      "X = 10\ndef f(): return X",
      @eval.Options::default(),
    ) {
    Ok(m) =>
      match m.get("f") {
        Some(@value.Value::Function(f)) => {
          let g = f.globals()
          assert_true(g.contains("X"))
        }
        _ => assert_true(false)
      }
    Err(_) => assert_true(false)
  }
}

///|
test "parse_expr returns a parsed expression" {
  match @starlark.parse_expr("test.star", "1 + 2") {
    Ok(_) => ()
    Err(_) => assert_true(false)
  }
  assert_true(@starlark.parse_expr("test.star", "1 +") is Err(_))
}

///|
test "eval_parsed_expr evaluates a pre-parsed expression" {
  let thread = @eval.Thread::new("test")
  let expr = match @starlark.parse_expr("test.star", "10 * 3 + 1") {
    Ok(e) => e
    Err(_) => {
      assert_true(false)
      return
    }
  }
  let env = @value.StarlarkDict::new()
  match
    @starlark.eval_parsed_expr(thread, expr, @eval.Options::default(), env) {
    Ok(v) => assert_true(v is @value.Value::Int(31N))
    Err(_) => assert_true(false)
  }
}

///|
test "StarlarkFunction::module returns the defining module" {
  let t = @eval.Thread::new("test")
  match
    @starlark.exec_file(
      t,
      "mymod.star",
      "CONST = 42\ndef f(): return CONST",
      @eval.Options::default(),
    ) {
    Ok(m) =>
      match m.get("f") {
        Some(@value.Value::Function(f)) =>
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
