// Differential tests for the bytecode VM (issue #1): every program is executed
// by both the AST walker (`exec_file`) and the VM (`exec_file_vm`); the two must
// agree on success/failure, on the resulting module globals, and on error
// messages. This is the safety net that lets the VM be brought up feature by
// feature while the walker remains the default engine.

///|
/// Extracts a module's globals as a name -> value map.
fn globals_map(m : @eval.Module) -> Map[String, @value.Value] {
  let out : Map[String, @value.Value] = {}
  for name in m.global_names() {
    match m.get(name) {
      Some(v) => out[name] = v
      None => ()
    }
  }
  out
}

///|
/// Runs `src` through both engines and asserts they agree.
fn assert_vm_matches_walker(src : String) -> Unit raise {
  let opts = @eval.Options::default()
  let wr = @eval.exec_file(@eval.Thread::new("w"), "t.star", src, opts)
  let vr = @eval.exec_file_vm(@eval.Thread::new("v"), "t.star", src, opts)
  match (wr, vr) {
    (Ok(wm), Ok(vm)) => {
      let wg = globals_map(wm)
      let vg = globals_map(vm)
      assert_eq(vg.length(), wg.length())
      for name, wval in wg {
        match vg.get(name) {
          Some(vval) => assert_true(wval.starlark_equals(vval))
          None => fail("VM is missing global '\{name}' for: \{src}")
        }
      }
    }
    (Err(we), Err(ve)) => assert_eq(ve.msg(), we.msg())
    (Ok(_), Err(ve)) =>
      fail("walker succeeded but VM errored (\{ve.msg()}) for: \{src}")
    (Err(we), Ok(_)) =>
      fail("walker errored (\{we.msg()}) but VM succeeded for: \{src}")
  }
}

///|
/// Runs `src` through both engines under a step budget and asserts they agree on
/// the resulting cancellation error.
fn assert_vm_matches_walker_under_budget(
  src : String,
  max_steps : Int,
) -> Unit raise {
  let opts = @eval.Options::default()
  let wr = @eval.exec_file(
    @eval.Thread::with_step_budget("w", max_steps),
    "t.star",
    src,
    opts,
  )
  let vr = @eval.exec_file_vm(
    @eval.Thread::with_step_budget("v", max_steps),
    "t.star",
    src,
    opts,
  )
  match (wr, vr) {
    (Err(we), Err(ve)) => assert_eq(ve.msg(), we.msg())
    (Ok(_), Err(ve)) =>
      fail("walker succeeded but VM errored (\{ve.msg()}) for: \{src}")
    (Err(we), Ok(_)) =>
      fail("walker errored (\{we.msg()}) but VM succeeded for: \{src}")
    (Ok(_), Ok(_)) =>
      fail("expected both engines to hit the step budget for: \{src}")
  }
}

///|
test "vm matches walker on step-budget cancellation" {
  assert_vm_matches_walker_under_budget("a = 1 + 2\nb = a * 3\nc = [a, b]", 0)
}

///|
test "vm matches walker on integer arithmetic" {
  assert_vm_matches_walker("x = 1 + 2 * 3 - 4")
  assert_vm_matches_walker("x = 17 // 5\ny = 17 % 5")
  assert_vm_matches_walker("x = -(3 + 4)\ny = +5")
}

///|
test "vm matches walker on float arithmetic and true division" {
  assert_vm_matches_walker("x = 1.5 + 2.5\ny = 7 / 2\nz = 3.0 * 2.0")
}

///|
test "vm matches walker on bitwise operators" {
  assert_vm_matches_walker(
    "a = 6 & 3\nb = 6 | 1\nc = 5 ^ 1\nd = 1 << 4\ne = 256 >> 2\nf = ~0",
  )
}

///|
test "vm matches walker on comparisons" {
  assert_vm_matches_walker(
    "a = 1 < 2\nb = 2 <= 2\nc = 3 > 4\nd = 4 >= 4\ne = 1 == 1\nf = 1 != 2",
  )
}

///|
test "vm matches walker on membership" {
  assert_vm_matches_walker("a = 2 in [1, 2, 3]\nb = 5 not in [1, 2, 3]")
}

///|
test "vm matches walker on string concatenation and repetition" {
  assert_vm_matches_walker("a = \"foo\" + \"bar\"\nb = \"ab\" * 3")
}

///|
test "vm matches walker on list and tuple construction and indexing" {
  assert_vm_matches_walker(
    "a = [1, 2, 3]\nb = (4, 5, 6)\nc = [10, 20, 30][1]\nd = (7, 8, 9)[0]",
  )
}

///|
test "vm matches walker on global reference after assignment" {
  assert_vm_matches_walker("a = 10\nb = a + 5\nc = a * b")
}

///|
test "vm matches walker on forward global reference (referenced before assignment)" {
  // both engines must report the same 'referenced before assignment' error
  assert_vm_matches_walker("x = y\ny = 1")
}

///|
test "vm matches walker on a type error in arithmetic" {
  assert_vm_matches_walker("x = 1 + \"a\"")
}

///|
test "vm matches walker on index out of range" {
  assert_vm_matches_walker("x = [1, 2][5]")
}

///|
test "vm matches walker on nested expressions" {
  assert_vm_matches_walker(
    "a = (1 + 2) * (3 + 4)\nb = [a, a + 1, a * 2]\nc = b[2] - b[0]",
  )
}

///|
test "vm matches walker on if / else at module scope" {
  assert_vm_matches_walker("x = 5\nif x > 3:\n  y = 1\nelse:\n  y = 2")
  assert_vm_matches_walker("x = 1\nif x > 3:\n  y = 1\nelse:\n  y = 2")
}

///|
test "vm matches walker on and / or short-circuiting" {
  assert_vm_matches_walker(
    "a = True and 5\nb = False or 7\nc = 0 or 9\nd = 1 and 2\ne = 0 and 3",
  )
}

///|
test "vm matches walker on the conditional expression" {
  assert_vm_matches_walker(
    "x = 10\na = 1 if x > 5 else 2\nb = 1 if x < 5 else 2",
  )
}

///|
test "vm matches walker on a while loop with accumulation" {
  assert_vm_matches_walker(
    "i = 0\ns = 0\nwhile i < 5:\n  s = s + i\n  i = i + 1",
  )
}

///|
test "vm matches walker on a for loop over a list" {
  assert_vm_matches_walker("s = 0\nfor x in [1, 2, 3, 4]:\n  s = s + x")
}

///|
test "vm matches walker on for with break" {
  assert_vm_matches_walker(
    "s = 0\nfor x in [1, 2, 3, 4, 5]:\n  if x > 3:\n    break\n  s = s + x",
  )
}

///|
test "vm matches walker on for with continue" {
  assert_vm_matches_walker(
    "s = 0\nfor x in [1, 2, 3, 4]:\n  if x == 2:\n    continue\n  s = s + x",
  )
}

///|
test "vm matches walker on nested loops" {
  assert_vm_matches_walker(
    "total = 0\nfor i in [1, 2, 3]:\n  for j in [10, 20]:\n    total = total + i * j",
  )
}

///|
test "vm matches walker on while with break and continue" {
  assert_vm_matches_walker(
    "i = 0\ns = 0\nwhile i < 10:\n  i = i + 1\n  if i == 3:\n    continue\n  if i > 6:\n    break\n  s = s + i",
  )
}
