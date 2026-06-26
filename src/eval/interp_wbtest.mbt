///|
test "guard_accum_alloc does not raise when current length is below allocation cap" {
  let ctx = EvalContext::new(Thread::new("t"), Options::default())
  let raised = try {
    guard_accum_alloc(ctx, "list", max_alloc_elems - 1)
    false
  } catch {
    EvalErr(_) => true
  }
  assert_false(raised)
}

///|
test "guard_accum_alloc raises excessive-sequence error when current length reaches allocation cap" {
  let ctx = EvalContext::new(Thread::new("t"), Options::default())
  let caught = try {
    guard_accum_alloc(ctx, "list", max_alloc_elems)
    false
  } catch {
    EvalErr(e) => e.msg().contains("excessive sequence")
  }
  assert_true(caught)
}

///|
test "guard_accum_alloc error message includes caller name and projected element count" {
  let ctx = EvalContext::new(Thread::new("t"), Options::default())
  let msg = try {
    guard_accum_alloc(ctx, "dict", max_alloc_elems)
    ""
  } catch {
    EvalErr(e) => e.msg()
  }
  assert_true(msg.contains("dict"))
  assert_true(msg.contains("\{max_alloc_elems + 1}"))
}

///|
test "SetAdd alloc guard condition evaluates false when element already exists in set" {
  let ctx = EvalContext::new(Thread::new("t"), Options::default())
  let s = @value.StarlarkSet::new()
  let elem = @value.Value::Int(1N)
  s.add(elem) |> ignore
  assert_false(!check(ctx, s.contains(elem)))
}

///|
test "SetAdd alloc guard condition evaluates true when element is absent from set" {
  let ctx = EvalContext::new(Thread::new("t"), Options::default())
  let s = @value.StarlarkSet::new()
  assert_true(!check(ctx, s.contains(@value.Value::Int(1N))))
}

///|
/// A name the VM resolves as predeclared but that has no binding in the base
/// environment must raise an undefined-name error with its source position,
/// rather than silently resolving to a fabricated (body-less) builtin.
test "vm reports an undefined predeclared name instead of fabricating a builtin" {
  let file = match @parser.parse_file("t.star", "x = ghost") {
    Ok(f) => f
    Err(e) => fail("parse failed: \{e.to_string()}")
  }
  let prog = @compile.compile(
    file,
    fn(name) { name == "ghost" },
    fn(name) { name == "None" || name == "True" || name == "False" },
    true,
  ) catch {
    @compile.CompileErr(msg) => fail("compile failed: \{msg}")
  }
  let ctx = EvalContext::new(Thread::new("t"), Options::default())
  match run_program_vm(ctx, prog, "t.star") {
    Err(e) => assert_eq(e.to_string(), "t.star:1:5: undefined: ghost")
    Ok(_) =>
      fail("expected an undefined-name error for the unbound predeclared name")
  }
}
