// Whitebox tests for value-level API semantics.
// Verifies that StarlarkFunction.defaults is populated correctly for
// each of the eight canonical parameter-list shapes, and that
// StarlarkFunction.param_default(i) provides correct indexed access.

///|
fn get_func_defaults(m : @eval.Module, name : String) -> Array[@value.Value?] {
  match m.get(name) {
    Some(@value.Value::Function(f)) => f.defaults()
    _ => []
  }
}

///|
fn get_func(m : @eval.Module, name : String) -> @value.StarlarkFunction? {
  match m.get(name) {
    Some(@value.Value::Function(f)) => Some(f)
    _ => None
  }
}

///|
let function_param_src : String =
  #|def all_required(a, b, c): pass
  #|def all_opt(a="a", b=None, c=""): pass
  #|def mix_required_opt(a, b, c="c", d="d"): pass
  #|def with_varargs(a, b="b", *args): pass
  #|def with_varargs_kwonly(a, b="b", *args, c="c", d): pass
  #|def with_kwonly(a, b="b", *, c="c", d): pass
  #|def with_kwargs(a, b="b", c="c", **kwargs): pass
  #|def with_varargs_kwonly_kwargs(a, b="b", *args, c="c", d, e="e", **kwargs): pass

///|
fn exec_param_module() -> @eval.Module raise {
  let thread = @eval.Thread::new("param-test")
  match
    @eval.exec_file(
      thread,
      "<test>",
      function_param_src,
      @eval.Options::default(),
    ) {
    Ok(m) => m
    Err(e) => fail("exec_file failed: \{e.msg()}")
  }
}

///|
test "param defaults: all_required has no defaults" {
  let m = exec_param_module()
  let d = get_func_defaults(m, "all_required")
  assert_eq(d.length(), 3)
  assert_true(d[0] is None)
  assert_true(d[1] is None)
  assert_true(d[2] is None)
}

///|
test "param defaults: all_opt has a default for every param" {
  let m = exec_param_module()
  let d = get_func_defaults(m, "all_opt")
  assert_eq(d.length(), 3)
  assert_true(d[0] is Some(@value.Value::String(_)))
  assert_true(d[1] is Some(@value.Value::None))
  assert_true(d[2] is Some(@value.Value::String(_)))
  match d[0] {
    Some(@value.Value::String(s)) => assert_eq(s.raw(), "a")
    _ => fail("expected String(\"a\")")
  }
  match d[2] {
    Some(@value.Value::String(s)) => assert_eq(s.raw(), "")
    _ => fail("expected String(\"\")")
  }
}

///|
test "param defaults: mix_required_opt has defaults only for optional params" {
  let m = exec_param_module()
  let d = get_func_defaults(m, "mix_required_opt")
  assert_eq(d.length(), 4)
  assert_true(d[0] is None)
  assert_true(d[1] is None)
  assert_true(d[2] is Some(@value.Value::String(_)))
  assert_true(d[3] is Some(@value.Value::String(_)))
  match d[2] {
    Some(@value.Value::String(s)) => assert_eq(s.raw(), "c")
    _ => fail("expected String(\"c\")")
  }
  match d[3] {
    Some(@value.Value::String(s)) => assert_eq(s.raw(), "d")
    _ => fail("expected String(\"d\")")
  }
}

///|
test "param defaults: with_varargs has None for *args" {
  let m = exec_param_module()
  let d = get_func_defaults(m, "with_varargs")
  assert_eq(d.length(), 3)
  assert_true(d[0] is None)
  assert_true(d[1] is Some(@value.Value::String(_)))
  assert_true(d[2] is None)
}

///|
test "param defaults: with_varargs_kwonly has defaults at correct positions" {
  let m = exec_param_module()
  let d = get_func_defaults(m, "with_varargs_kwonly")
  assert_eq(d.length(), 5)
  assert_true(d[0] is None)
  assert_true(d[1] is Some(@value.Value::String(_)))
  assert_true(d[2] is None)
  assert_true(d[3] is Some(@value.Value::String(_)))
  assert_true(d[4] is None)
}

///|
test "param defaults: with_kwonly bare-star gets None in defaults" {
  let m = exec_param_module()
  let d = get_func_defaults(m, "with_kwonly")
  assert_eq(d.length(), 5)
  assert_true(d[0] is None)
  assert_true(d[1] is Some(@value.Value::String(_)))
  assert_true(d[2] is None)
  assert_true(d[3] is Some(@value.Value::String(_)))
  assert_true(d[4] is None)
}

///|
test "param defaults: with_kwargs has None for **kwargs" {
  let m = exec_param_module()
  let d = get_func_defaults(m, "with_kwargs")
  assert_eq(d.length(), 4)
  assert_true(d[0] is None)
  assert_true(d[1] is Some(@value.Value::String(_)))
  assert_true(d[2] is Some(@value.Value::String(_)))
  assert_true(d[3] is None)
}

///|
test "param defaults: with_varargs_kwonly_kwargs full shape" {
  let m = exec_param_module()
  let d = get_func_defaults(m, "with_varargs_kwonly_kwargs")
  assert_eq(d.length(), 7)
  assert_true(d[0] is None)
  assert_true(d[1] is Some(@value.Value::String(_)))
  assert_true(d[2] is None)
  assert_true(d[3] is Some(@value.Value::String(_)))
  assert_true(d[4] is None)
  assert_true(d[5] is Some(@value.Value::String(_)))
  assert_true(d[6] is None)
}

///|
test "param_default: out-of-bounds indices return None" {
  let m = exec_param_module()
  let f = get_func(m, "all_required").unwrap()
  assert_true(f.param_default(-1) is None)
  assert_true(f.param_default(3) is None)
  assert_true(f.param_default(100) is None)
}

///|
test "param_default: all_required returns None for each index" {
  let m = exec_param_module()
  let f = get_func(m, "all_required").unwrap()
  assert_true(f.param_default(0) is None)
  assert_true(f.param_default(1) is None)
  assert_true(f.param_default(2) is None)
}

///|
test "param_default: all_opt returns Some for each valid index" {
  let m = exec_param_module()
  let f = get_func(m, "all_opt").unwrap()
  match f.param_default(0) {
    Some(@value.Value::String(s)) => assert_eq(s.raw(), "a")
    _ => fail("expected Some(String(\"a\")) at index 0")
  }
  assert_true(f.param_default(1) is Some(@value.Value::None))
  match f.param_default(2) {
    Some(@value.Value::String(s)) => assert_eq(s.raw(), "")
    _ => fail("expected Some(String(\"\")) at index 2")
  }
}

///|
test "param_default: with_varargs has None for *args slot" {
  let m = exec_param_module()
  let f = get_func(m, "with_varargs").unwrap()
  assert_true(f.param_default(0) is None)
  assert_true(f.param_default(1) is Some(@value.Value::String(_)))
  assert_true(f.param_default(2) is None)
}

///|
test "param_default: with_kwargs has None for **kwargs slot" {
  let m = exec_param_module()
  let f = get_func(m, "with_kwargs").unwrap()
  assert_true(f.param_default(0) is None)
  assert_true(f.param_default(1) is Some(@value.Value::String(_)))
  assert_true(f.param_default(2) is Some(@value.Value::String(_)))
  assert_true(f.param_default(3) is None)
}

///|
test "param_default: mix_required_opt has None then Some at correct positions" {
  let m = exec_param_module()
  let f = get_func(m, "mix_required_opt").unwrap()
  assert_true(f.param_default(0) is None)
  assert_true(f.param_default(1) is None)
  match f.param_default(2) {
    Some(@value.Value::String(s)) => assert_eq(s.raw(), "c")
    _ => fail("expected Some(String(\"c\")) at index 2")
  }
  match f.param_default(3) {
    Some(@value.Value::String(s)) => assert_eq(s.raw(), "d")
    _ => fail("expected Some(String(\"d\")) at index 3")
  }
}

///|
test "param_default: with_varargs_kwonly_kwargs full shape via indexed access" {
  let m = exec_param_module()
  let f = get_func(m, "with_varargs_kwonly_kwargs").unwrap()
  assert_true(f.param_default(0) is None)
  assert_true(f.param_default(1) is Some(@value.Value::String(_)))
  assert_true(f.param_default(2) is None)
  assert_true(f.param_default(3) is Some(@value.Value::String(_)))
  assert_true(f.param_default(4) is None)
  assert_true(f.param_default(5) is Some(@value.Value::String(_)))
  assert_true(f.param_default(6) is None)
}
