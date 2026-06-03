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
  assert_vm_matches_walker_opts(src, @eval.Options::default())
}

///|
/// Runs `src` through both engines under `opts` and asserts they agree.
fn assert_vm_matches_walker_opts(
  src : String,
  opts : @eval.Options,
) -> Unit raise {
  let wr = @eval.exec_file(@eval.Thread::new("w"), "t.star", src, opts)
  let vr = @eval.exec_file_vm(@eval.Thread::new("v"), "t.star", src, opts)
  match (wr, vr) {
    (Ok(wm), Ok(vm)) => {
      let wg = globals_map(wm)
      let vg = globals_map(vm)
      assert_eq(vg.length(), wg.length())
      for name, wval in wg {
        match vg.get(name) {
          // Compare by repr: it is canonical for data values and yields
          // "<function name>" for functions (which compare by identity, so
          // the two engines' distinct function objects are never `==`).
          Some(vval) => assert_eq(vval.repr(), wval.repr())
          None => fail("VM is missing global '\{name}' for: \{src}")
        }
      }
    }
    // Compare the full rendering (message + backtrace) so error positions and
    // call stacks match the walker, not just the message text.
    (Err(we), Err(ve)) => assert_eq(ve.to_string(), we.to_string())
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

///|
test "vm matches walker on a function definition and call" {
  assert_vm_matches_walker("def add(a, b):\n  return a + b\n\nx = add(2, 3)")
}

///|
test "vm matches walker on function-local variables" {
  assert_vm_matches_walker(
    "def f(a):\n  b = a * 2\n  c = b + 1\n  return c\n\nx = f(10)",
  )
}

///|
test "vm matches walker on a function with internal control flow" {
  assert_vm_matches_walker(
    "def classify(n):\n  if n < 0:\n    return -1\n  elif n == 0:\n    return 0\n  return 1\n\na = classify(-5)\nb = classify(0)\nc = classify(7)",
  )
}

///|
test "vm matches walker on nested function calls" {
  assert_vm_matches_walker(
    "def inc(x):\n  return x + 1\n\ndef double(x):\n  return x * 2\n\ny = double(inc(5))",
  )
}

///|
test "vm matches walker on a loop inside a function" {
  assert_vm_matches_walker(
    "def total(xs):\n  s = 0\n  for x in xs:\n    s = s + x\n  return s\n\nr = total([1, 2, 3, 4, 5])",
  )
}

///|
test "vm matches walker on recursion (factorial)" {
  assert_vm_matches_walker(
    "def fact(n):\n  if n <= 1:\n    return 1\n  return n * fact(n - 1)\n\nx = fact(5)",
  )
}

///|
test "vm matches walker on recursion (fibonacci)" {
  assert_vm_matches_walker(
    "def fib(n):\n  if n < 2:\n    return n\n  return fib(n - 1) + fib(n - 2)\n\nx = fib(10)",
  )
}

///|
test "vm matches walker on a lambda" {
  assert_vm_matches_walker("f = lambda x: x * x\n\ny = f(6)")
}

///|
test "vm matches walker on an error raised inside a called function (backtrace)" {
  // The full rendering, including the f -> <toplevel> backtrace, must match.
  assert_vm_matches_walker("def f(n):\n  return n + \"oops\"\n\ny = f(5)")
}

///|
test "vm matches walker on a deep error backtrace through several frames" {
  assert_vm_matches_walker(
    "def a(x):\n  return b(x) + 1\n\ndef b(x):\n  return c(x) + 1\n\ndef c(x):\n  return x[0]\n\nr = a(5)",
  )
}

///|
test "vm matches walker on maximum recursion depth" {
  assert_vm_matches_walker("def f(n):\n  return f(n + 1)\n\nx = f(0)")
}

///|
test "vm matches walker on direct recursion when recursion is disabled" {
  let opts = @eval.Options::default().with_allow_recursion(false)
  assert_vm_matches_walker_opts(
    "def fact(n):\n  if n <= 1:\n    return 1\n  return n * fact(n - 1)\n\nx = fact(5)",
    opts,
  )
}

///|
test "vm matches walker on builtin calls with positional arguments" {
  assert_vm_matches_walker("n = len([1, 2, 3])\nm = len(\"hello\")")
  assert_vm_matches_walker(
    "a = abs(-7)\nb = str(42)\nc = int(\"15\")\nd = bool(0)",
  )
  assert_vm_matches_walker(
    "lo = min([3, 1, 2])\nhi = max([3, 1, 2])\ns = sorted([3, 1, 2])",
  )
  assert_vm_matches_walker(
    "xs = list((1, 2, 3))\nt = tuple([4, 5])\nr = reversed([1, 2, 3])",
  )
}

///|
test "vm matches walker on range and range-driven for loops" {
  assert_vm_matches_walker("xs = list(range(5))")
  assert_vm_matches_walker("s = 0\nfor i in range(4):\n  s = s + i")
}

///|
test "vm matches walker on builtin calls inside a function" {
  assert_vm_matches_walker(
    "def total(n):\n  s = 0\n  for i in range(n):\n    s = s + i\n  return s\n\nr = total(5)",
  )
}

///|
test "vm matches walker on a builtin type error (backtrace)" {
  // The builtin error and backtrace must match the walker exactly.
  assert_vm_matches_walker("x = len(5)")
}

///|
test "vm matches walker when a builtin calls back into a user function" {
  // `sorted`/`min`/`max` accept the key function positionally, so the VM runs
  // them today and the callback must re-enter the VM, not diverge.
  assert_vm_matches_walker(
    "def neg(x):\n  return 0 - x\n\nr = sorted([1, 3, 2], neg)",
  )
  assert_vm_matches_walker(
    "def keyfn(x):\n  return x % 3\n\nlo = min([5, 7, 9], keyfn)\nhi = max([5, 7, 9], keyfn)",
  )
}

///|
test "vm matches walker on a builtin callback to a recursive function when recursion is disabled" {
  // The callback re-enters the same function while it is on the stack; with
  // recursion disabled both engines must reject it identically.
  let opts = @eval.Options::default().with_allow_recursion(false)
  assert_vm_matches_walker_opts(
    "def f(x):\n  if x == 0:\n    return sorted([1, 2], f)\n  return x\n\nr = f(0)",
    opts,
  )
}

///|
test "vm matches walker on mutual recursion when recursion is disabled" {
  let opts = @eval.Options::default().with_allow_recursion(false)
  assert_vm_matches_walker_opts(
    "def is_even(n):\n  if n == 0:\n    return True\n  return is_odd(n - 1)\n\ndef is_odd(n):\n  if n == 0:\n    return False\n  return is_even(n - 1)\n\nx = is_even(4)",
    opts,
  )
}

///|
test "vm matches walker on a non-recursive call when recursion is disabled" {
  let opts = @eval.Options::default().with_allow_recursion(false)
  assert_vm_matches_walker_opts(
    "def inc(n):\n  return n + 1\n\ndef twice(n):\n  return inc(inc(n))\n\nx = twice(10)",
    opts,
  )
}

///|
test "vm leaves no call frame behind after an error on a reused thread" {
  let thread = @eval.Thread::new("v")
  let opts = @eval.Options::default()
  let r = @eval.exec_file_vm(thread, "t.star", "x = 1 + \"oops\"", opts)
  assert_true(r is Err(_))
  assert_eq(thread.call_stack_depth(), 0)
}
