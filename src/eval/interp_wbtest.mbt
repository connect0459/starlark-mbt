///|
test "accumulator alloc guard does not raise when current length is below allocation cap" {
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
test "accumulator alloc guard raises excessive-sequence error when current length reaches allocation cap" {
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
test "accumulator alloc guard error message includes caller name and projected element count" {
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
test "presence check preserves Ok(true) as present" {
  assert_true(swallowed_contains(Ok(true)))
}

///|
test "presence check preserves Ok(false) as absent" {
  assert_false(swallowed_contains(Ok(false)))
}

///|
test "presence check collapses Err to false so alloc guard can fire before hashability error" {
  assert_false(swallowed_contains(Err("unhashable type: list")))
}

///|
test "accumulator alloc guard does not fire when container has room and element is new" {
  let ctx = EvalContext::new(Thread::new("t"), Options::default())
  let raised = try {
    guard_accum_alloc_if_new(ctx, "set", max_alloc_elems - 1, false)
    false
  } catch {
    EvalErr(_) => true
  }
  assert_false(raised)
}

///|
test "accumulator alloc guard raises excessive-sequence error at cap when element is new" {
  let ctx = EvalContext::new(Thread::new("t"), Options::default())
  let caught = try {
    guard_accum_alloc_if_new(ctx, "set", max_alloc_elems, false)
    false
  } catch {
    EvalErr(e) => e.msg().contains("excessive sequence")
  }
  assert_true(caught)
}

///|
test "accumulator alloc guard is bypassed at cap when element is already present" {
  let ctx = EvalContext::new(Thread::new("t"), Options::default())
  let raised = try {
    guard_accum_alloc_if_new(ctx, "set", max_alloc_elems, true)
    false
  } catch {
    EvalErr(_) => true
  }
  assert_false(raised)
}

///|
/// Composed path: swallowed_contains + guard_accum_alloc_if_new with a real
/// StarlarkSet. Verifies that the two helpers are wired correctly and that
/// an existing element (is_present=true from a real contains call) prevents
/// the alloc guard from firing at cap.
test "set alloc guard bypassed at cap when element already present — composed path" {
  let ctx = EvalContext::new(Thread::new("t"), Options::default())
  let s = @value.StarlarkSet::new()
  let elem = @value.Value::Int(1N)
  s.add(elem) |> ignore
  let is_present = swallowed_contains(s.contains(elem))
  assert_true(is_present)
  let raised = try {
    guard_accum_alloc_if_new(ctx, "set", max_alloc_elems, is_present)
    false
  } catch {
    EvalErr(_) => true
  }
  assert_false(raised)
}

///|
/// Composed path: swallowed_contains + guard_accum_alloc_if_new with a real
/// StarlarkDict. Verifies that an existing key (is_present=true from a real
/// contains call) prevents the alloc guard from firing at cap.
test "dict alloc guard bypassed at cap when key already present — composed path" {
  let ctx = EvalContext::new(Thread::new("t"), Options::default())
  let d = @value.StarlarkDict::new()
  let key = @value.Value::Int(1N)
  d.set(key, @value.Value::None) |> ignore
  let is_present = swallowed_contains(d.contains(key))
  assert_true(is_present)
  let raised = try {
    guard_accum_alloc_if_new(ctx, "dict", max_alloc_elems, is_present)
    false
  } catch {
    EvalErr(_) => true
  }
  assert_false(raised)
}

///|
/// Unhashable set element at cap: presence check collapses Err to false,
/// so alloc guard fires before hashability error propagates.
test "unhashable absent set element at allocation cap triggers alloc guard first" {
  let ctx = EvalContext::new(Thread::new("t"), Options::default())
  let s = @value.StarlarkSet::new()
  let unhashable = @value.Value::List(@value.StarlarkList::new([]))
  let is_present = swallowed_contains(s.contains(unhashable))
  assert_false(is_present)
  let caught = try {
    guard_accum_alloc_if_new(ctx, "set", max_alloc_elems, is_present)
    false
  } catch {
    EvalErr(e) => e.msg().contains("excessive sequence")
  }
  assert_true(caught)
}

///|
/// Full error message check: alloc guard error for an unhashable set element
/// at cap names the caller as "set", reports the projected element count, and
/// does not contain "unhashable" — confirming that the allocation limit takes
/// priority over the hashability error.
test "alloc guard error for unhashable set element at cap names caller and count without unhashable" {
  let ctx = EvalContext::new(Thread::new("t"), Options::default())
  let s = @value.StarlarkSet::new()
  let unhashable = @value.Value::List(@value.StarlarkList::new([]))
  let is_present = swallowed_contains(s.contains(unhashable))
  assert_false(is_present)
  let msg = try {
    guard_accum_alloc_if_new(ctx, "set", max_alloc_elems, is_present)
    ""
  } catch {
    EvalErr(e) => e.msg()
  }
  assert_true(msg.contains("set"))
  assert_true(msg.contains("excessive sequence"))
  assert_false(msg.contains("unhashable"))
  assert_true(msg.contains("\{max_alloc_elems + 1}"))
}

///|
/// Unhashable dict key at cap: presence check collapses Err to false,
/// so alloc guard fires before hashability error propagates.
test "unhashable absent dict key at allocation cap triggers alloc guard first" {
  let ctx = EvalContext::new(Thread::new("t"), Options::default())
  let d = @value.StarlarkDict::new()
  let unhashable = @value.Value::List(@value.StarlarkList::new([]))
  let is_present = swallowed_contains(d.contains(unhashable))
  assert_false(is_present)
  let caught = try {
    guard_accum_alloc_if_new(ctx, "dict", max_alloc_elems, is_present)
    false
  } catch {
    EvalErr(e) => e.msg().contains("excessive sequence")
  }
  assert_true(caught)
}

///|
/// Full error message check: alloc guard error for an unhashable dict key at
/// cap names the caller as "dict", reports the projected element count, and
/// does not contain "unhashable" — confirming that the allocation limit takes
/// priority over the hashability error.
test "alloc guard error for unhashable dict key at cap names caller and count without unhashable" {
  let ctx = EvalContext::new(Thread::new("t"), Options::default())
  let d = @value.StarlarkDict::new()
  let unhashable = @value.Value::List(@value.StarlarkList::new([]))
  let is_present = swallowed_contains(d.contains(unhashable))
  assert_false(is_present)
  let msg = try {
    guard_accum_alloc_if_new(ctx, "dict", max_alloc_elems, is_present)
    ""
  } catch {
    EvalErr(e) => e.msg()
  }
  assert_true(msg.contains("dict"))
  assert_true(msg.contains("excessive sequence"))
  assert_false(msg.contains("unhashable"))
  assert_true(msg.contains("\{max_alloc_elems + 1}"))
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
