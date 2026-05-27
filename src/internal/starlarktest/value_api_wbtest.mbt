// Whitebox tests for value-level API semantics.
// Port of starlark-go value_test.go TestParamDefault.
// Verifies that StarlarkFunction.defaults is populated correctly for
// each of the eight canonical parameter-list shapes.

///|
fn get_func_defaults(m : @eval.Module, name : String) -> Array[@value.Value?] {
  match m.get(name) {
    Some(@value.Value::FuncVal(f)) => f.defaults()
    _ => []
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
  assert_true(d[0] is Some(@value.Value::StrVal(_)))
  assert_true(d[1] is Some(@value.Value::NoneVal))
  assert_true(d[2] is Some(@value.Value::StrVal(_)))
  match d[0] {
    Some(@value.Value::StrVal(s)) => assert_eq(s.raw, "a")
    _ => fail("expected StrVal(\"a\")")
  }
  match d[2] {
    Some(@value.Value::StrVal(s)) => assert_eq(s.raw, "")
    _ => fail("expected StrVal(\"\")")
  }
}

///|
test "param defaults: mix_required_opt has defaults only for optional params" {
  let m = exec_param_module()
  let d = get_func_defaults(m, "mix_required_opt")
  assert_eq(d.length(), 4)
  assert_true(d[0] is None)
  assert_true(d[1] is None)
  assert_true(d[2] is Some(@value.Value::StrVal(_)))
  assert_true(d[3] is Some(@value.Value::StrVal(_)))
  match d[2] {
    Some(@value.Value::StrVal(s)) => assert_eq(s.raw, "c")
    _ => fail("expected StrVal(\"c\")")
  }
  match d[3] {
    Some(@value.Value::StrVal(s)) => assert_eq(s.raw, "d")
    _ => fail("expected StrVal(\"d\")")
  }
}

///|
test "param defaults: with_varargs has None for *args" {
  let m = exec_param_module()
  let d = get_func_defaults(m, "with_varargs")
  assert_eq(d.length(), 3)
  assert_true(d[0] is None)
  assert_true(d[1] is Some(@value.Value::StrVal(_)))
  assert_true(d[2] is None)
}

///|
test "param defaults: with_varargs_kwonly has defaults at correct positions" {
  let m = exec_param_module()
  let d = get_func_defaults(m, "with_varargs_kwonly")
  assert_eq(d.length(), 5)
  assert_true(d[0] is None)
  assert_true(d[1] is Some(@value.Value::StrVal(_)))
  assert_true(d[2] is None)
  assert_true(d[3] is Some(@value.Value::StrVal(_)))
  assert_true(d[4] is None)
}

///|
test "param defaults: with_kwonly bare-star gets None in defaults" {
  let m = exec_param_module()
  let d = get_func_defaults(m, "with_kwonly")
  assert_eq(d.length(), 5)
  assert_true(d[0] is None)
  assert_true(d[1] is Some(@value.Value::StrVal(_)))
  assert_true(d[2] is None)
  assert_true(d[3] is Some(@value.Value::StrVal(_)))
  assert_true(d[4] is None)
}

///|
test "param defaults: with_kwargs has None for **kwargs" {
  let m = exec_param_module()
  let d = get_func_defaults(m, "with_kwargs")
  assert_eq(d.length(), 4)
  assert_true(d[0] is None)
  assert_true(d[1] is Some(@value.Value::StrVal(_)))
  assert_true(d[2] is Some(@value.Value::StrVal(_)))
  assert_true(d[3] is None)
}

///|
test "param defaults: with_varargs_kwonly_kwargs full shape" {
  let m = exec_param_module()
  let d = get_func_defaults(m, "with_varargs_kwonly_kwargs")
  assert_eq(d.length(), 7)
  assert_true(d[0] is None)
  assert_true(d[1] is Some(@value.Value::StrVal(_)))
  assert_true(d[2] is None)
  assert_true(d[3] is Some(@value.Value::StrVal(_)))
  assert_true(d[4] is None)
  assert_true(d[5] is Some(@value.Value::StrVal(_)))
  assert_true(d[6] is None)
}
