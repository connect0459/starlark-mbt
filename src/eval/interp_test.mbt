// Regression tests for the bytecode VM (issue #1): every program is executed
// twice via `exec_file` and the two runs must agree on success/failure, on the
// resulting module globals, and on error messages. This is the safety net that
// guards the VM's behavior against regressions as it evolves.

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
fn assert_vm_result(src : String) -> Unit raise {
  assert_vm_result_opts(src, @eval.Options::default())
}

///|
/// Asserts the two VM runs' results agree: equal module globals (by
/// repr) on success, or an identical full error rendering (message + backtrace).
fn compare_results(
  wr : Result[@eval.Module, @errors.EvalError],
  vr : Result[@eval.Module, @errors.EvalError],
  src : String,
) -> Unit raise {
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
    // call stacks match across runs, not just the message text.
    (Err(we), Err(ve)) => assert_eq(ve.to_string(), we.to_string())
    (Ok(_), Err(ve)) =>
      fail(
        "first run succeeded but second run errored (\{ve.msg()}) for: \{src}",
      )
    (Err(we), Ok(_)) =>
      fail(
        "first run errored (\{we.msg()}) but second run succeeded for: \{src}",
      )
  }
}

///|
/// Runs `src` through both engines under `opts` and asserts they agree.
fn assert_vm_result_opts(src : String, opts : @eval.Options) -> Unit raise {
  let wr = @eval.exec_file(@eval.Thread::new("w"), "t.star", src, opts)
  let vr = @eval.exec_file(@eval.Thread::new("v"), "t.star", src, opts)
  compare_results(wr, vr, src)
}

///|
/// Runs `src` through both engines with a loader that serves `lib_src` (compiled
/// once) for the module path `"lib.star"`, and asserts they agree.
fn assert_vm_result_load(
  src : String,
  lib_src : String,
  opts? : @eval.Options = @eval.Options::default(),
) -> Unit raise {
  // Build the loaded library with the VM so its functions are bytecode-backed,
  // matching the program under test.
  fn make_loader(
    lib : @eval.Module,
  ) -> (@eval.Thread, String) -> Result[@eval.Module, @errors.EvalError] {
    fn(_t, path) {
      if path == "lib.star" {
        Ok(lib)
      } else {
        Err(@errors.EvalError::simple("no such module: \{path}"))
      }
    }
  }

  let wlib = match
    @eval.exec_file(@eval.Thread::new("wlib"), "lib.star", lib_src, opts) {
    Ok(m) => m
    Err(e) => abort("test library failed to compile (first run): \{e.msg()}")
  }
  let vlib = match
    @eval.exec_file(@eval.Thread::new("vlib"), "lib.star", lib_src, opts) {
    Ok(m) => m
    Err(e) => abort("test library failed to compile (second run): \{e.msg()}")
  }
  let wt = @eval.Thread::new("w")
  wt.set_loader(make_loader(wlib))
  let vt = @eval.Thread::new("v")
  vt.set_loader(make_loader(vlib))
  let wr = @eval.exec_file(wt, "t.star", src, opts)
  let vr = @eval.exec_file(vt, "t.star", src, opts)
  compare_results(wr, vr, src)
}

///|
/// Runs `src` through both engines under a step budget and asserts they agree on
/// the resulting cancellation error.
fn assert_vm_result_under_budget(src : String, max_steps : Int) -> Unit raise {
  let opts = @eval.Options::default()
  let wr = @eval.exec_file(
    @eval.Thread::with_step_budget("w", max_steps),
    "t.star",
    src,
    opts,
  )
  let vr = @eval.exec_file(
    @eval.Thread::with_step_budget("v", max_steps),
    "t.star",
    src,
    opts,
  )
  match (wr, vr) {
    (Err(we), Err(ve)) => assert_eq(ve.msg(), we.msg())
    (Ok(_), Err(ve)) =>
      fail(
        "first run succeeded but second run errored (\{ve.msg()}) for: \{src}",
      )
    (Err(we), Ok(_)) =>
      fail(
        "first run errored (\{we.msg()}) but second run succeeded for: \{src}",
      )
    (Ok(_), Ok(_)) =>
      fail("expected both runs to hit the step budget for: \{src}")
  }
}

///|
test "vm reports step-budget cancellation" {
  assert_vm_result_under_budget("a = 1 + 2\nb = a * 3\nc = [a, b]", 0)
}

///|
test "vm evaluates integer arithmetic" {
  assert_vm_result("x = 1 + 2 * 3 - 4")
  assert_vm_result("x = 17 // 5\ny = 17 % 5")
  assert_vm_result("x = -(3 + 4)\ny = +5")
}

///|
test "vm evaluates float arithmetic and true division" {
  assert_vm_result("x = 1.5 + 2.5\ny = 7 / 2\nz = 3.0 * 2.0")
}

///|
test "vm evaluates bitwise operators" {
  assert_vm_result(
    "a = 6 & 3\nb = 6 | 1\nc = 5 ^ 1\nd = 1 << 4\ne = 256 >> 2\nf = ~0",
  )
}

///|
test "vm evaluates comparisons" {
  assert_vm_result(
    "a = 1 < 2\nb = 2 <= 2\nc = 3 > 4\nd = 4 >= 4\ne = 1 == 1\nf = 1 != 2",
  )
}

///|
test "vm evaluates membership" {
  assert_vm_result("a = 2 in [1, 2, 3]\nb = 5 not in [1, 2, 3]")
}

///|
test "vm evaluates string concatenation and repetition" {
  assert_vm_result("a = \"foo\" + \"bar\"\nb = \"ab\" * 3")
}

///|
test "vm evaluates list and tuple construction and indexing" {
  assert_vm_result(
    "a = [1, 2, 3]\nb = (4, 5, 6)\nc = [10, 20, 30][1]\nd = (7, 8, 9)[0]",
  )
}

///|
test "vm evaluates global reference after assignment" {
  assert_vm_result("a = 10\nb = a + 5\nc = a * b")
}

///|
test "vm evaluates forward global reference (referenced before assignment)" {
  // both engines must report the same 'referenced before assignment' error
  assert_vm_result("x = y\ny = 1")
}

///|
test "vm reports a type error in arithmetic" {
  assert_vm_result("x = 1 + \"a\"")
}

///|
test "vm reports an index out of range" {
  assert_vm_result("x = [1, 2][5]")
}

///|
test "vm evaluates nested expressions" {
  assert_vm_result(
    "a = (1 + 2) * (3 + 4)\nb = [a, a + 1, a * 2]\nc = b[2] - b[0]",
  )
}

///|
test "vm evaluates if / else at module scope" {
  assert_vm_result("x = 5\nif x > 3:\n  y = 1\nelse:\n  y = 2")
  assert_vm_result("x = 1\nif x > 3:\n  y = 1\nelse:\n  y = 2")
}

///|
test "vm evaluates and / or short-circuiting" {
  assert_vm_result(
    "a = True and 5\nb = False or 7\nc = 0 or 9\nd = 1 and 2\ne = 0 and 3",
  )
}

///|
test "vm evaluates the conditional expression" {
  assert_vm_result("x = 10\na = 1 if x > 5 else 2\nb = 1 if x < 5 else 2")
}

///|
test "vm evaluates a while loop with accumulation" {
  assert_vm_result("i = 0\ns = 0\nwhile i < 5:\n  s = s + i\n  i = i + 1")
}

///|
test "vm evaluates a for loop over a list" {
  assert_vm_result("s = 0\nfor x in [1, 2, 3, 4]:\n  s = s + x")
}

///|
test "vm evaluates for with break" {
  assert_vm_result(
    "s = 0\nfor x in [1, 2, 3, 4, 5]:\n  if x > 3:\n    break\n  s = s + x",
  )
}

///|
test "vm evaluates for with continue" {
  assert_vm_result(
    "s = 0\nfor x in [1, 2, 3, 4]:\n  if x == 2:\n    continue\n  s = s + x",
  )
}

///|
test "vm evaluates nested loops" {
  assert_vm_result(
    "total = 0\nfor i in [1, 2, 3]:\n  for j in [10, 20]:\n    total = total + i * j",
  )
}

///|
test "vm evaluates while with break and continue" {
  assert_vm_result(
    "i = 0\ns = 0\nwhile i < 10:\n  i = i + 1\n  if i == 3:\n    continue\n  if i > 6:\n    break\n  s = s + i",
  )
}

///|
test "vm evaluates a function definition and call" {
  assert_vm_result("def add(a, b):\n  return a + b\n\nx = add(2, 3)")
}

///|
test "vm evaluates function-local variables" {
  assert_vm_result(
    "def f(a):\n  b = a * 2\n  c = b + 1\n  return c\n\nx = f(10)",
  )
}

///|
test "vm evaluates a function with internal control flow" {
  assert_vm_result(
    "def classify(n):\n  if n < 0:\n    return -1\n  elif n == 0:\n    return 0\n  return 1\n\na = classify(-5)\nb = classify(0)\nc = classify(7)",
  )
}

///|
test "vm evaluates nested function calls" {
  assert_vm_result(
    "def inc(x):\n  return x + 1\n\ndef double(x):\n  return x * 2\n\ny = double(inc(5))",
  )
}

///|
test "vm evaluates a loop inside a function" {
  assert_vm_result(
    "def total(xs):\n  s = 0\n  for x in xs:\n    s = s + x\n  return s\n\nr = total([1, 2, 3, 4, 5])",
  )
}

///|
test "vm evaluates recursion (factorial)" {
  assert_vm_result_opts(
    "def fact(n):\n  if n <= 1:\n    return 1\n  return n * fact(n - 1)\n\nx = fact(5)",
    @eval.Options::default().with_allow_recursion(true),
  )
}

///|
test "vm evaluates recursion (fibonacci)" {
  assert_vm_result_opts(
    "def fib(n):\n  if n < 2:\n    return n\n  return fib(n - 1) + fib(n - 2)\n\nx = fib(10)",
    @eval.Options::default().with_allow_recursion(true),
  )
}

///|
test "vm evaluates a lambda" {
  assert_vm_result("f = lambda x: x * x\n\ny = f(6)")
}

///|
test "vm reports an error raised inside a called function (backtrace)" {
  // The full rendering, including the f -> <toplevel> backtrace, must match.
  assert_vm_result("def f(n):\n  return n + \"oops\"\n\ny = f(5)")
}

///|
test "vm reports a deep error backtrace through several frames" {
  assert_vm_result(
    "def a(x):\n  return b(x) + 1\n\ndef b(x):\n  return c(x) + 1\n\ndef c(x):\n  return x[0]\n\nr = a(5)",
  )
}

///|
test "vm reports maximum recursion depth" {
  assert_vm_result_opts(
    "def f(n):\n  return f(n + 1)\n\nx = f(0)",
    @eval.Options::default().with_allow_recursion(true),
  )
}

///|
test "vm reports direct recursion when recursion is disabled" {
  let opts = @eval.Options::default().with_allow_recursion(false)
  assert_vm_result_opts(
    "def fact(n):\n  if n <= 1:\n    return 1\n  return n * fact(n - 1)\n\nx = fact(5)",
    opts,
  )
}

///|
test "vm evaluates builtin calls with positional arguments" {
  assert_vm_result("n = len([1, 2, 3])\nm = len(\"hello\")")
  assert_vm_result("a = abs(-7)\nb = str(42)\nc = int(\"15\")\nd = bool(0)")
  assert_vm_result(
    "lo = min([3, 1, 2])\nhi = max([3, 1, 2])\ns = sorted([3, 1, 2])",
  )
  assert_vm_result(
    "xs = list((1, 2, 3))\nt = tuple([4, 5])\nr = reversed([1, 2, 3])",
  )
}

///|
test "vm evaluates range and range-driven for loops" {
  assert_vm_result("xs = list(range(5))")
  assert_vm_result("s = 0\nfor i in range(4):\n  s = s + i")
}

///|
test "vm evaluates builtin calls inside a function" {
  assert_vm_result(
    "def total(n):\n  s = 0\n  for i in range(n):\n    s = s + i\n  return s\n\nr = total(5)",
  )
}

///|
test "vm reports a builtin type error (backtrace)" {
  // The builtin error and backtrace must be stable across runs.
  assert_vm_result("x = len(5)")
}

///|
test "vm evaluates a builtin calling back into a user function" {
  // `sorted`/`min`/`max` accept the key function positionally, so the VM runs
  // them today and the callback must re-enter the VM, not diverge.
  assert_vm_result("def neg(x):\n  return 0 - x\n\nr = sorted([1, 3, 2], neg)")
  assert_vm_result(
    "def keyfn(x):\n  return x % 3\n\nlo = min([5, 7, 9], keyfn)\nhi = max([5, 7, 9], keyfn)",
  )
}

///|
test "vm reports a builtin callback to a recursive function when recursion is disabled" {
  // The callback re-enters the same function while it is on the stack; with
  // recursion disabled both engines must reject it identically.
  let opts = @eval.Options::default().with_allow_recursion(false)
  assert_vm_result_opts(
    "def f(x):\n  if x == 0:\n    return sorted([1, 2], f)\n  return x\n\nr = f(0)",
    opts,
  )
}

///|
test "vm reports mutual recursion when recursion is disabled" {
  let opts = @eval.Options::default().with_allow_recursion(false)
  assert_vm_result_opts(
    "def is_even(n):\n  if n == 0:\n    return True\n  return is_odd(n - 1)\n\ndef is_odd(n):\n  if n == 0:\n    return False\n  return is_even(n - 1)\n\nx = is_even(4)",
    opts,
  )
}

///|
test "vm evaluates a non-recursive call when recursion is disabled" {
  let opts = @eval.Options::default().with_allow_recursion(false)
  assert_vm_result_opts(
    "def inc(n):\n  return n + 1\n\ndef twice(n):\n  return inc(inc(n))\n\nx = twice(10)",
    opts,
  )
}

///|
test "vm leaves no call frame behind after an error on a reused thread" {
  let thread = @eval.Thread::new("v")
  let opts = @eval.Options::default()
  let r = @eval.exec_file(thread, "t.star", "x = 1 + \"oops\"", opts)
  assert_true(r is Err(_))
  assert_eq(thread.call_stack_depth(), 0)
}

///|
test "vm evaluates default parameter values" {
  assert_vm_result("def f(a, b=10):\n  return a + b\n\nx = f(1)\ny = f(1, 2)")
}

///|
test "vm evaluates keyword arguments" {
  assert_vm_result(
    "def f(a, b, c):\n  return a * 100 + b * 10 + c\n\nx = f(1, c=3, b=2)\ny = f(c=3, a=1, b=2)",
  )
}

///|
test "vm evaluates defaults combined with keyword arguments" {
  assert_vm_result(
    "def f(a, b=2, c=3):\n  return [a, b, c]\n\nx = f(1)\ny = f(1, c=9)\nz = f(1, 8, 9)",
  )
}

///|
test "vm evaluates *args" {
  assert_vm_result(
    "def f(a, *rest):\n  return [a, rest]\n\nx = f(1)\ny = f(1, 2, 3)",
  )
}

///|
test "vm evaluates **kwargs" {
  assert_vm_result("def f(a, **kw):\n  return [a, kw]\n\nx = f(1, b=2, c=3)")
}

///|
test "vm evaluates keyword-only parameters" {
  assert_vm_result(
    "def f(a, *, b, c=5):\n  return a + b + c\n\nx = f(1, b=2)\ny = f(1, b=2, c=3)",
  )
}

///|
test "vm evaluates the full parameter form" {
  assert_vm_result(
    "def f(a, b=2, *args, c, **kw):\n  return [a, b, args, c, kw]\n\nx = f(1, 9, 8, 7, c=3, d=4)",
  )
}

///|
test "vm reports a too-many-positional-arguments error" {
  assert_vm_result("def f(a, b):\n  return a\n\nx = f(1, 2, 3)")
}

///|
test "vm reports a missing required argument error" {
  assert_vm_result("def f(a, b, c):\n  return a\n\nx = f(1)")
}

///|
test "vm reports an unexpected keyword argument error" {
  assert_vm_result("def f(a, b):\n  return a\n\nx = f(1, zz=2)")
}

///|
test "vm reports multiple values for a parameter error" {
  assert_vm_result("def f(a, b):\n  return a\n\nx = f(1, a=2)")
}

///|
test "vm reports a nullary function called with arguments" {
  assert_vm_result("def f():\n  return 1\n\nx = f(2)")
}

///|
test "vm evaluates keyword args passed to a builtin" {
  assert_vm_result("xs = sorted([3, 1, 2], reverse=True)")
}

///|
test "vm evaluates a single-level closure" {
  assert_vm_result(
    "def make_adder(n):\n  def add(x):\n    return x + n\n  return add\n\nf = make_adder(10)\na = f(5)\nb = f(100)",
  )
}

///|
test "vm evaluates independent closures from the same factory" {
  assert_vm_result(
    "def make_adder(n):\n  def add(x):\n    return x + n\n  return add\n\nf = make_adder(10)\ng = make_adder(20)\na = f(1)\nb = g(1)",
  )
}

///|
test "vm evaluates a closure capturing multiple variables" {
  assert_vm_result(
    "def f(a, b):\n  def g(c):\n    return a + b + c\n  return g(100)\n\nx = f(1, 2)",
  )
}

///|
test "vm evaluates multi-level nested closures" {
  assert_vm_result(
    "def a(x):\n  def b(y):\n    def c(z):\n      return x + y + z\n    return c\n  return b\n\nr = a(1)(2)(3)",
  )
}

///|
test "vm evaluates a lambda closure" {
  assert_vm_result(
    "def make(n):\n  return lambda x: x + n\n\nf = make(10)\ny = f(5)",
  )
}

///|
test "vm evaluates a closure over a locally-mutated variable" {
  assert_vm_result(
    "def f():\n  total = 0\n  for i in [1, 2, 3]:\n    total = total + i\n  def get():\n    return total\n  return get()\n\nx = f()",
  )
}

///|
test "vm evaluates a closure capturing a module global is not a closure" {
  // `n` here is a module global, not a captured local: must use the global path.
  assert_vm_result("n = 10\n\ndef add(x):\n  return x + n\n\ny = add(5)")
}

///|
test "vm evaluates a simple list comprehension" {
  assert_vm_result("xs = [x * 2 for x in [1, 2, 3, 4]]")
}

///|
test "vm evaluates a list comprehension with an if guard" {
  assert_vm_result("xs = [x for x in [1, 2, 3, 4, 5, 6] if x % 2 == 0]")
}

///|
test "vm evaluates a nested (multi-for) list comprehension" {
  assert_vm_result("xs = [x * 10 + y for x in [1, 2] for y in [3, 4]]")
}

///|
test "vm evaluates a comprehension with multiple if guards" {
  assert_vm_result(
    "xs = [x for x in [1, 2, 3, 4, 5, 6, 7, 8, 9, 10] if x % 2 == 0 if x > 4]",
  )
}

///|
test "vm evaluates a comprehension over range" {
  assert_vm_result("xs = [i * i for i in range(6)]")
}

///|
test "vm evaluates a dict comprehension" {
  assert_vm_result("d = {k: k * k for k in [1, 2, 3]}")
}

///|
test "vm evaluates a dict comprehension with a guard" {
  assert_vm_result("d = {x: x + 1 for x in [1, 2, 3, 4] if x != 2}")
}

///|
test "vm evaluates a comprehension inside a function" {
  assert_vm_result(
    "def squares(n):\n  return [i * i for i in range(n)]\n\nxs = squares(5)",
  )
}

// Note: referencing a comprehension variable after the comprehension (e.g.
// `xs = [x for x in [1,2,3]]; y = x`) is a resolver-permitted but
// runtime-undefined name; the VM compiler reports it at compile time.

///|
test "vm evaluates a comprehension whose later iterable references the target" {
  // `[a for _ in [1] for a in a]`: the second iterable `a` references the
  // comp-local `a` before assignment -> referenced-before-assignment error.
  assert_vm_result("xs = [a for _ in [1] for a in a]")
}

///|
test "vm evaluates a name repeating across comprehension for clauses" {
  // The same target appears in two `for` clauses, so it is a single
  // comp-local that must be fully unbound when the comprehension ends; a
  // later reference to the same name must see the enclosing global, not a
  // leftover comp-local slot.
  assert_vm_result("i = 5\nxs = [i for i in [1] for i in [2]]\ny = i")
}

///|
test "vm evaluates a basic load statement" {
  assert_vm_result_load(
    "load(\"lib.star\", \"foo\", \"bar\")\nx = foo + 1\ny = bar", "foo = 42\nbar = [1, 2, 3]",
  )
}

///|
test "vm evaluates load with aliasing" {
  assert_vm_result_load(
    "load(\"lib.star\", a=\"foo\", b=\"bar\")\nx = a\ny = b", "foo = 7\nbar = \"hi\"",
  )
}

///|
test "vm evaluates load of a function then calling it" {
  assert_vm_result_load(
    "load(\"lib.star\", \"add\")\nz = add(2, 3)", "def add(a, b):\n  return a + b",
  )
}

///|
test "vm evaluates a loaded function that uses its own constants" {
  // The loaded function's constant (100) and the caller's constant (3) occupy
  // the same pool index in their respective programs; the callee must read its
  // own program's constants, not the caller's.
  assert_vm_result_load(
    "load(\"lib.star\", \"scale\")\nr = scale(3)", "def scale(x):\n  return x * 100",
  )
}

///|
/// Runs `main_src` on the VM with a loader serving a VM-compiled `lib.star`.
fn vm_load_run(
  main_src : String,
  lib_src : String,
) -> Result[@eval.Module, @errors.EvalError] {
  let lib = match
    @eval.exec_file(
      @eval.Thread::new("lib"),
      "lib.star",
      lib_src,
      @eval.Options::default(),
    ) {
    Ok(m) => m
    Err(e) => abort("test library failed to compile: \{e.msg()}")
  }
  let t = @eval.Thread::new("main")
  t.set_loader(fn(_t, path) {
    if path == "lib.star" {
      Ok(lib)
    } else {
      Err(@errors.EvalError::simple("no such module: \{path}"))
    }
  })
  @eval.exec_file(t, "main.star", main_src, @eval.Options::default())
}

// These two cases assert the VM's behavior directly rather than through the
// dual-run harness: they pin down that the VM resolves a loaded function's own
// module globals and sibling functions against the function's own module —
// the correct behavior, matching starlark-go and starlark-rust.

///|
test "host call runs a bytecode-compiled function" {
  let m = match
    @eval.exec_file(
      @eval.Thread::new("t"),
      "t.star",
      "def add(a, b):\n  return a + b",
      @eval.Options::default(),
    ) {
    Ok(m) => m
    Err(e) => {
      fail("compile failed: \{e.msg()}")
      return
    }
  }
  let f = match m.get("add") {
    Some(v) => v
    None => {
      fail("missing add")
      return
    }
  }
  match
    @eval.call(
      @eval.Thread::new("t2"),
      f,
      [@value.Value::Int(3N), @value.Value::Int(4N)],
      [],
    ) {
    Ok(v) =>
      match @value.number_to_int(v) {
        Some(n) => assert_eq(n, 7L)
        None => fail("result is not an int")
      }
    Err(e) => fail("host call errored: \{e.msg()}")
  }
}

///|
test "reflection works on a bytecode-compiled function" {
  let m = match
    @eval.exec_file(
      @eval.Thread::new("t"),
      "refl.star",
      "G = 1\ndef f(x, y):\n  \"the doc\"\n  return x + y",
      @eval.Options::default(),
    ) {
    Ok(m) => m
    Err(e) => {
      fail("compile failed: \{e.msg()}")
      return
    }
  }
  match m.get("f") {
    Some(@value.Value::Function(f)) => {
      assert_eq(f.num_params(), 2)
      assert_eq(f.param(0).0, "x")
      assert_eq(f.param(1).0, "y")
      assert_eq(f.doc(), "the doc")
      assert_true(f.globals().contains("G"))
      match f.defining_module() {
        Some(mod_ref) => assert_eq(mod_ref.name(), "refl.star")
        None => fail("expected a defining module")
      }
    }
    _ => fail("missing function f")
  }
}

///|
test "reflection reports free variables of a bytecode-compiled closure" {
  let m = match
    @eval.exec_file(
      @eval.Thread::new("t"),
      "t.star",
      "def outer():\n  c = 99\n  def inner():\n    return c\n  return inner\n\nf = outer()",
      @eval.Options::default(),
    ) {
    Ok(m) => m
    Err(e) => {
      fail("compile failed: \{e.msg()}")
      return
    }
  }
  match m.get("f") {
    Some(@value.Value::Function(f)) => {
      assert_true(f.num_free_vars() >= 1)
      match f.free_var(0) {
        Some((name, _)) => assert_true(name.length() > 0)
        None => fail("expected a free variable")
      }
    }
    _ => fail("missing function f")
  }
}

///|
test "vm resolves a loaded function's module global against its own module" {
  match
    vm_load_run(
      "load(\"lib.star\", \"scaled\")\nr = scaled(5)", "factor = 10\ndef scaled(x):\n  return x * factor",
    ) {
    Ok(m) =>
      match m.get("r") {
        Some(v) =>
          match @value.number_to_int(v) {
            Some(n) => assert_eq(n, 50L)
            None => fail("r is not an int")
          }
        None => fail("missing global r")
      }
    Err(e) => fail("vm errored: \{e.msg()}")
  }
}

///|
test "vm resolves a sibling call inside a loaded module against its own module" {
  match
    vm_load_run(
      "load(\"lib.star\", \"outer\")\nr = outer(7)", "def helper(n):\n  return n + 1000\n\ndef outer(x):\n  return helper(x) * 2",
    ) {
    Ok(m) =>
      match m.get("r") {
        Some(v) =>
          match @value.number_to_int(v) {
            Some(n) => assert_eq(n, 2014L)
            None => fail("r is not an int")
          }
        None => fail("missing global r")
      }
    Err(e) => fail("vm errored: \{e.msg()}")
  }
}

///|
test "vm evaluates load_binds_globally exporting loaded names" {
  assert_vm_result_load(
    "load(\"lib.star\", \"foo\")\nx = foo",
    "foo = 99",
    opts=@eval.Options::default().with_load_binds_globally(true),
  )
}

///|
test "vm reports load of a missing name" {
  assert_vm_result_load("load(\"lib.star\", \"nope\")\nx = nope", "foo = 1")
}

///|
test "vm reports load with no loader configured" {
  // No loader is set, so both engines report 'load not implemented'.
  assert_vm_result("load(\"lib.star\", \"foo\")\nx = foo")
}

///|
test "vm evaluates index assignment" {
  assert_vm_result("xs = [1, 2, 3]\nxs[1] = 99\ny = xs")
}

// (Dict-key index assignment and dict `|=` are exercised in the data-literals
// PR, once dict literals compile.)

///|
test "vm evaluates tuple unpacking assignment" {
  assert_vm_result("a, b = (1, 2)\nx = a\ny = b")
  assert_vm_result("a, b, c = [10, 20, 30]\ns = a + b + c")
}

///|
test "vm evaluates nested tuple unpacking" {
  assert_vm_result("(a, b), c = ((1, 2), 3)\ns = a + b + c")
}

///|
test "vm reports unpacking length mismatch errors" {
  assert_vm_result("a, b = (1, 2, 3)")
  assert_vm_result("a, b, c = (1, 2)")
}

///|
test "vm reports unpacking a non-iterable" {
  assert_vm_result("a, b = 5")
}

///|
test "vm evaluates swap via tuple assignment" {
  assert_vm_result("a = 1\nb = 2\na, b = b, a\nx = a\ny = b")
}

///|
test "vm evaluates augmented assignment to a name" {
  assert_vm_result("x = 10\nx += 5\nx *= 2\nx -= 1\nx //= 3\ny = x")
}

///|
test "vm evaluates in-place list extend via +=" {
  // `xs += [..]` must mutate in place so the alias sees the change
  assert_vm_result("xs = [1, 2]\nys = xs\nxs += [3, 4]\na = xs\nb = ys")
}

///|
test "vm evaluates augmented assignment inside a function" {
  assert_vm_result(
    "def f(n):\n  total = 0\n  for i in range(n):\n    total += i\n  return total\n\nr = f(5)",
  )
}

///|
test "vm reports assigning to an index out of range" {
  assert_vm_result("xs = [1, 2]\nxs[5] = 9")
}

///|
test "vm evaluates attribute access and method calls" {
  assert_vm_result("s = \"Hello\".upper()\nt = \"a,b,c\".split(\",\")")
  assert_vm_result("d = {\"k\": 1}\nv = d.get(\"k\")\nw = d.get(\"x\", 9)")
}

///|
test "vm evaluates a mutating method call on a list" {
  assert_vm_result("xs = [3, 1, 2]\nxs.append(4)\nxs.sort()\ny = xs")
}

///|
test "vm evaluates a method call inside a function" {
  assert_vm_result("def f(xs):\n  xs.append(99)\n  return xs\n\nr = f([1, 2])")
}

///|
test "vm reports accessing a missing attribute" {
  assert_vm_result("xs = [1, 2]\ny = xs.no_such_attr")
}

///|
test "vm reports augmented assignment to an unassignable attribute" {
  // Built-in values reject attribute assignment; both engines must report the
  // same error for `obj.attr += v`.
  assert_vm_result("xs = [1, 2]\nxs.foo += 1")
}

///|
test "vm evaluates augmented assignment to a list index" {
  assert_vm_result("xs = [1, 2, 3]\nxs[1] += 10\nxs[0] *= 5\ny = xs")
}

///|
test "vm evaluates augmented assignment to a dict key" {
  assert_vm_result(
    "d = {\"a\": 1, \"b\": 2}\nd[\"a\"] += 100\nd[\"b\"] //= 2\nx = d",
  )
}

///|
test "vm evaluates augmented in-place list extend at an index" {
  // `xs[i] += [..]` must mutate the nested list in place
  assert_vm_result("xs = [[1], [2]]\nys = xs[0]\nxs[0] += [9]\na = xs\nb = ys")
}

///|
test "vm evaluates the index of an augmented target once" {
  // The container and index are evaluated once; appending to a log proves it.
  assert_vm_result(
    "log = []\n" +
    "def idx():\n  log.append(\"i\")\n  return 0\n\n" +
    "xs = [10]\nxs[idx()] += 5\nx = xs\nn = log",
  )
}

///|
test "vm reports augmented assignment to an out-of-range index" {
  assert_vm_result("xs = [1]\nxs[5] += 1")
}

///|
test "vm reports an undefined name at module scope" {
  assert_vm_result("x = undefined_name")
}

///|
test "vm reports an undefined name inside a function" {
  assert_vm_result("def f():\n  return missing\n\ny = f()")
}

///|
test "vm reports an undefined name used in an expression" {
  assert_vm_result("a = 1\nb = a + nope")
}

///|
test "vm evaluates a call with a *args splat" {
  assert_vm_result(
    "def f(a, b, c):\n  return a + b + c\n\nxs = [1, 2, 3]\nr = f(*xs)",
  )
}

///|
test "vm evaluates a call with fixed positionals and a *args splat" {
  assert_vm_result(
    "def f(a, b, c, d):\n  return a * 1000 + b * 100 + c * 10 + d\n\nr = f(1, *[2, 3], 4)",
  )
}

///|
test "vm evaluates a call with a **kwargs splat" {
  assert_vm_result(
    "def f(a, b):\n  return a - b\n\nkw = {\"a\": 10, \"b\": 3}\nr = f(**kw)",
  )
}

///|
test "vm evaluates a call with keywords and a **kwargs splat" {
  assert_vm_result(
    "def f(a, b, c):\n  return (a, b, c)\n\nr = f(a=1, **{\"b\": 2, \"c\": 3})",
  )
}

///|
test "vm evaluates a call with both *args and **kwargs" {
  assert_vm_result(
    "def f(a, b, c, d):\n  return a + b + c + d\n\nr = f(*[1, 2], **{\"c\": 3, \"d\": 4})",
  )
}

///|
test "vm evaluates a *args splat into a builtin" {
  assert_vm_result("r = max(*[3, 1, 2])")
}

///|
test "vm reports a *args splat that is not iterable" {
  assert_vm_result("def f(a):\n  return a\n\nr = f(*5)")
}

///|
test "vm reports a **kwargs splat that is not a mapping" {
  assert_vm_result("def f(a):\n  return a\n\nr = f(**5)")
}

///|
test "vm reports a **kwargs splat with a non-string key" {
  assert_vm_result("def f(a):\n  return a\n\nr = f(**{1: 2})")
}

///|
test "vm reports a *args splat with an unexpected keyword" {
  assert_vm_result("def f(a):\n  return a\n\nr = f(*[1], **{\"z\": 9})")
}

///|
test "vm evaluates a dict literal" {
  assert_vm_result("d = {\"a\": 1, \"b\": 2, \"c\": 3}")
  assert_vm_result("d = {}")
  assert_vm_result("d = {1: \"x\", 2: \"y\"}\nv = d[2]")
}

///|
test "vm reports a dict literal with a duplicate key" {
  assert_vm_result("d = {\"a\": 1, \"a\": 2}")
}

///|
test "vm evaluates a nested dict and list literal" {
  assert_vm_result("d = {\"xs\": [1, 2], \"nested\": {\"k\": 3}}")
}

///|
test "vm evaluates dict-key index assignment" {
  assert_vm_result("d = {\"a\": 1}\nd[\"b\"] = 2\nx = d")
}

///|
test "vm evaluates a set literal" {
  assert_vm_result("s = set([1, 2, 3])\nt = {1, 2, 2, 3}\nn = len(t)")
}

///|
test "vm evaluates a for loop with a tuple target" {
  assert_vm_result(
    "total = 0\nfor a, b in [(1, 2), (3, 4)]:\n  total += a * b\nx = total",
  )
}

///|
test "vm evaluates a for loop with a nested tuple target" {
  assert_vm_result(
    "s = 0\nfor (a, b), c in [((1, 2), 3), ((4, 5), 6)]:\n  s += a + b + c\nx = s",
  )
}

///|
test "vm reports a for-loop tuple target unpack mismatch" {
  assert_vm_result("for a, b in [(1, 2, 3)]:\n  pass")
}

///|
test "vm evaluates a list comprehension with a tuple target" {
  assert_vm_result("xs = [a + b for a, b in [(1, 2), (3, 4)]]")
}

///|
test "vm evaluates a set comprehension" {
  assert_vm_result("s = {x % 3 for x in range(10)}\nn = len(s)")
}

///|
test "vm evaluates a guarded set comprehension" {
  assert_vm_result("s = {x for x in range(10) if x % 2 == 0}\nn = len(s)")
}

///|
test "vm evaluates a dict comprehension with a tuple target" {
  assert_vm_result("d = {k: v for k, v in [(\"a\", 1), (\"b\", 2)]}")
}

///|
test "vm evaluates top-level list comprehension with lambda capturing loop variable" {
  let src =
    #|fs = [lambda: i for i in [1, 2, 3]]
    #|vals = [f() for f in fs]
  assert_vm_result(src)
  match
    @eval.exec_file(
      @eval.Thread::new("t"),
      "t.star",
      src,
      @eval.Options::default(),
    ) {
    Err(e) => fail(e.to_string())
    Ok(m) =>
      match m.get("vals") {
        None => fail("global 'vals' missing")
        Some(v) => assert_eq(v.repr(), "[3, 3, 3]")
      }
  }
}

///|
test "vm top-level lambda capture produces late-binding values like function scope" {
  let src =
    #|fs = [lambda: i for i in range(3)]
    #|result = [f() for f in fs]
  assert_vm_result(src)
  match
    @eval.exec_file(
      @eval.Thread::new("t"),
      "t.star",
      src,
      @eval.Options::default(),
    ) {
    Err(e) => fail(e.to_string())
    Ok(m) =>
      match m.get("result") {
        None => fail("global 'result' missing")
        // All lambdas close over the same cell for `i`; after the loop i==2,
        // so every lambda returns 2.
        Some(v) => assert_eq(v.repr(), "[2, 2, 2]")
      }
  }
}

///|
test "vm top-level lambda capture nested comprehension with free variable" {
  let src =
    #|n = 10
    #|fns = [lambda: n + i for i in range(3)]
    #|vals = [f() for f in fns]
  assert_vm_result(src)
  match
    @eval.exec_file(
      @eval.Thread::new("t"),
      "t.star",
      src,
      @eval.Options::default(),
    ) {
    Err(e) => fail(e.to_string())
    Ok(m) =>
      match m.get("vals") {
        None => fail("global 'vals' missing")
        // `i` ends on 2 (last value from range(3)), `n` is 10, so every
        // lambda returns 12.
        Some(v) => assert_eq(v.repr(), "[12, 12, 12]")
      }
  }
}

///|
test "vm: unhashable dict key error anchors at the colon position" {
  // d={([1],2):3} — key ([1],2) starts at col 4, colon ':' is at col 11.
  // go anchors at the colon (entry.Colon); mbt anchored at key start.
  let r = @eval.exec_file(
    @eval.Thread::new("v"),
    "t.star",
    "d={([1],2):3}",
    @eval.Options::default(),
  )
  match r {
    Err(e) => {
      assert_true(e.msg().contains("unhashable"))
      assert_eq(e.call_stack().at(0).unwrap().pos().col(), 11)
    }
    Ok(_) => fail("expected unhashable-key error")
  }
}

///|
test "vm: unhashable dict comprehension key error anchors at the colon position" {
  // {([1],2):x for x in [0]} — key ([1],2) starts at col 2, colon ':' is at col 9.
  // go anchors at the colon; the comprehension SetDict path must mirror the
  // dict-literal SetDictUniq path.
  let r = @eval.exec_file(
    @eval.Thread::new("v"),
    "t.star",
    "{([1],2):x for x in [0]}",
    @eval.Options::default(),
  )
  match r {
    Err(e) => {
      assert_true(e.msg().contains("unhashable"))
      assert_eq(e.call_stack().at(0).unwrap().pos().col(), 9)
    }
    Ok(_) => fail("expected unhashable-key error")
  }
}

///|
test "vm: duplicate dict key error anchors at the colon position" {
  // {"a":1,"a":2} — second "a" at col 8, its colon at col 11.
  // set_pos(colon) before SetDictUniq covers duplicate-key errors too.
  let r = @eval.exec_file(
    @eval.Thread::new("v"),
    "t.star",
    "{\"a\":1,\"a\":2}",
    @eval.Options::default(),
  )
  match r {
    Err(e) => {
      assert_true(e.msg().contains("duplicate key"))
      assert_eq(e.call_stack().at(0).unwrap().pos().col(), 11)
    }
    Ok(_) => fail("expected duplicate-key error")
  }
}
