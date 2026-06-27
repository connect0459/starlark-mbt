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
test "SetDict alloc guard condition evaluates false when key already exists in dict" {
  let d = @value.StarlarkDict::new()
  let key = @value.Value::Int(1N)
  d.set(key, @value.Value::None) |> ignore
  let is_duplicate = match d.contains(key) {
    Ok(b) => b
    Err(_) => false
  }
  assert_false(!is_duplicate)
}

///|
test "SetDict alloc guard condition evaluates true when key is absent from dict" {
  let d = @value.StarlarkDict::new()
  let is_duplicate = match d.contains(@value.Value::Int(1N)) {
    Ok(b) => b
    Err(_) => false
  }
  assert_true(!is_duplicate)
}

///|
test "SetDict alloc guard condition treats unhashable key as absent so guard fires first" {
  let d = @value.StarlarkDict::new()
  let unhashable = @value.Value::List(@value.StarlarkList::new([]))
  let is_duplicate = match d.contains(unhashable) {
    Ok(b) => b
    Err(_) => false
  }
  assert_false(is_duplicate)
}

///|
test "SetDict unhashable key at allocation cap triggers alloc guard before hashability error" {
  let ctx = EvalContext::new(Thread::new("t"), Options::default())
  let d = @value.StarlarkDict::new()
  let unhashable = @value.Value::List(@value.StarlarkList::new([]))
  let is_duplicate = match d.contains(unhashable) {
    Ok(b) => b
    Err(_) => false
  }
  assert_false(is_duplicate)
  let caught = try {
    guard_accum_alloc(ctx, "dict", max_alloc_elems)
    false
  } catch {
    EvalErr(e) => e.msg().contains("excessive sequence")
  }
  assert_true(caught)
}

///|
test "SetAdd alloc guard condition evaluates false when element already exists in set" {
  let s = @value.StarlarkSet::new()
  let elem = @value.Value::Int(1N)
  s.add(elem) |> ignore
  let is_duplicate = match s.contains(elem) {
    Ok(b) => b
    Err(_) => false
  }
  assert_false(!is_duplicate)
}

///|
test "SetAdd alloc guard condition evaluates true when element is absent from set" {
  let s = @value.StarlarkSet::new()
  let is_duplicate = match s.contains(@value.Value::Int(1N)) {
    Ok(b) => b
    Err(_) => false
  }
  assert_true(!is_duplicate)
}

///|
test "SetAdd alloc guard condition treats unhashable element as absent so guard fires first" {
  let s = @value.StarlarkSet::new()
  let unhashable = @value.Value::List(@value.StarlarkList::new([]))
  let is_duplicate = match s.contains(unhashable) {
    Ok(b) => b
    Err(_) => false
  }
  assert_false(is_duplicate)
}

///|
test "SetAdd unhashable element at allocation cap triggers alloc guard before hashability error" {
  let ctx = EvalContext::new(Thread::new("t"), Options::default())
  let s = @value.StarlarkSet::new()
  let unhashable = @value.Value::List(@value.StarlarkList::new([]))
  let is_duplicate = match s.contains(unhashable) {
    Ok(b) => b
    Err(_) => false
  }
  assert_false(is_duplicate)
  let caught = try {
    guard_accum_alloc(ctx, "set", max_alloc_elems)
    false
  } catch {
    EvalErr(e) => e.msg().contains("excessive sequence")
  }
  assert_true(caught)
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
