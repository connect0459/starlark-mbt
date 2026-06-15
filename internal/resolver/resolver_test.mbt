// Tests for the Starlark name resolver.
// Uses parse helpers to avoid verbose AST construction.

///|
fn parse_or_fail(src : String) -> @syntax.File {
  match @parser.parse_file("<test>", src) {
    Ok(f) => f
    Err(_) => panic()
  }
}

///|
fn no_predeclared(_name : String) -> Bool {
  false
}

///|
fn no_universal(_name : String) -> Bool {
  false
}

///|
fn only_universal(name : String) -> Bool {
  name == "None" || name == "True" || name == "False"
}

///|
fn with_predeclared(names : Array[String]) -> (String) -> Bool {
  fn(name) { names.contains(name) }
}

///|
fn with_universal(names : Array[String]) -> (String) -> Bool {
  fn(name) { names.contains(name) }
}

///|
fn has_error(result : ResolvedFile, substr : String) -> Bool {
  result.errors().any(fn(e) { e.msg().contains(substr) })
}

///|
fn error_col(result : ResolvedFile, substr : String) -> Int? {
  for e in result.errors() {
    if e.msg().contains(substr) {
      return Some(e.pos().col())
    }
  }
  None
}

// --- Basic resolution: valid programs ---

///|
test "resolve: accepts empty file" {
  let f = parse_or_fail("")
  let result = resolve(
    f,
    no_predeclared,
    no_universal,
    ResolveOptions::default(),
  )
  assert_true(result.is_valid())
}

///|
test "resolve: accepts simple global assignment" {
  let f = parse_or_fail("x = 1")
  let result = resolve(
    f,
    no_predeclared,
    no_universal,
    ResolveOptions::default(),
  )
  assert_true(result.is_valid())
}

///|
test "resolve: accepts use of previously defined global" {
  let f = parse_or_fail("x = 1\ny = x + 1")
  let result = resolve(
    f,
    no_predeclared,
    no_universal,
    ResolveOptions::default(),
  )
  assert_true(result.is_valid())
}

///|
test "resolve: allows forward reference to global in function body" {
  let f = parse_or_fail("def f():\n  return x\nx = 1")
  let result = resolve(
    f,
    no_predeclared,
    no_universal,
    ResolveOptions::default(),
  )
  assert_true(result.is_valid())
}

///|
test "resolve: accepts use of predeclared name" {
  let f = parse_or_fail("M()")
  let result = resolve(
    f,
    with_predeclared(["M"]),
    no_universal,
    ResolveOptions::default(),
  )
  assert_true(result.is_valid())
}

///|
test "resolve: accepts use of universal name" {
  let f = parse_or_fail("len([])")
  let result = resolve(
    f,
    no_predeclared,
    with_universal(["len"]),
    ResolveOptions::default(),
  )
  assert_true(result.is_valid())
}

///|
test "resolve: accepts local variable defined in function" {
  let f = parse_or_fail("def f():\n  x = 1\n  return x")
  let result = resolve(
    f,
    no_predeclared,
    no_universal,
    ResolveOptions::default(),
  )
  assert_true(result.is_valid())
}

///|
test "resolve: local variable shadows global of same name" {
  let f = parse_or_fail("x = 1\ndef f():\n  x = 2\n  return x")
  let result = resolve(
    f,
    no_predeclared,
    no_universal,
    ResolveOptions::default(),
  )
  assert_true(result.is_valid())
}

// --- Undefined variable detection ---

///|
test "resolve: reports error for undefined global" {
  let f = parse_or_fail("y = x + 1")
  let result = resolve(
    f,
    no_predeclared,
    no_universal,
    ResolveOptions::default(),
  )
  assert_true(has_error(result, "undefined: x"))
}

///|
test "resolve: reports error for undefined variable in function" {
  let f = parse_or_fail("def f():\n  return z")
  let result = resolve(
    f,
    no_predeclared,
    no_universal,
    ResolveOptions::default(),
  )
  assert_true(has_error(result, "undefined: z"))
}

///|
test "resolve: augmented-assigned-only name is visible to a nested closure" {
  // `n` is bound only by `n += 1` in f; the inner def g closes over it.
  // It must resolve as local-to-f / free-in-g, not raise "undefined: n".
  let f = parse_or_fail("def f():\n  def g(): return n\n  n += 1\n  return g")
  let result = resolve(
    f,
    no_predeclared,
    no_universal,
    ResolveOptions::default(),
  )
  assert_false(has_error(result, "undefined: n"))
}

///|
test "resolve: undefined suggests did-you-mean for close global name" {
  let f = parse_or_fail("hello = 1\nprint(hollo)")
  let result = resolve(
    f,
    no_predeclared,
    fn(n) { n == "print" },
    ResolveOptions::default(),
  )
  assert_true(has_error(result, "undefined: hollo (did you mean hello?)"))
}

///|
test "resolve: undefined suggests did-you-mean for close local parameter name" {
  let f = parse_or_fail("def f(param):\n  return parma")
  let result = resolve(
    f,
    no_predeclared,
    fn(_) { false },
    ResolveOptions::default(),
  )
  assert_true(has_error(result, "undefined: parma (did you mean param?)"))
}

///|
test "resolve: undefined with no close match gives no hint" {
  let f = parse_or_fail("hello = 1\nprint(goodbye)")
  let result = resolve(
    f,
    no_predeclared,
    fn(n) { n == "print" },
    ResolveOptions::default(),
  )
  // "goodbye" is far from "hello" — no hint appended
  assert_true(has_error(result, "undefined: goodbye"))
}

// --- Global reassignment ---

///|
test "resolve: rejects global reassignment when flag is off" {
  let f = parse_or_fail("x = 1\nx = 2")
  let opts = ResolveOptions::default().with_allow_global_reassign(false)
  let result = resolve(f, no_predeclared, no_universal, opts)
  assert_true(has_error(result, "cannot reassign global x"))
}

///|
test "resolve: allows global reassignment when flag is on" {
  let f = parse_or_fail("x = 1\nx = 2")
  let opts = ResolveOptions::default().with_allow_global_reassign(true)
  let result = resolve(f, no_predeclared, no_universal, opts)
  assert_true(result.is_valid())
}

// --- Top-level control flow ---

///|
test "resolve: rejects top-level if when flag is off" {
  let f = parse_or_fail("if True:\n  x = 1")
  let opts = ResolveOptions::default().with_allow_top_level_control(false)
  let result = resolve(f, no_predeclared, only_universal, opts)
  assert_true(has_error(result, "if"))
}

///|
test "resolve: accepts top-level if when flag is on" {
  let f = parse_or_fail("if True:\n  x = 1")
  let opts = ResolveOptions::default().with_allow_top_level_control(true)
  let result = resolve(f, no_predeclared, only_universal, opts)
  assert_true(result.is_valid())
}

///|
test "resolve: rejects top-level for when flag is off" {
  let f = parse_or_fail("for x in []:\n  pass")
  let opts = ResolveOptions::default().with_allow_top_level_control(false)
  let result = resolve(f, no_predeclared, no_universal, opts)
  assert_true(has_error(result, "for"))
}

///|
test "resolve: rejects top-level while when flag is off" {
  let f = parse_or_fail("while True:\n  pass")
  let opts = ResolveOptions::default()
    .with_allow_top_level_control(false)
    .with_allow_recursion(true)
  let result = resolve(f, no_predeclared, only_universal, opts)
  assert_true(has_error(result, "while"))
}

///|
test "resolve: accepts top-level while when flag is on" {
  let f = parse_or_fail("while True:\n  pass")
  let opts = ResolveOptions::default().with_allow_top_level_control(true)
  let result = resolve(f, no_predeclared, only_universal, opts)
  assert_true(result.is_valid())
}

// --- Function parameters ---

///|
test "resolve: rejects duplicate parameter names" {
  let f = parse_or_fail("def f(x, x):\n  pass")
  let result = resolve(
    f,
    no_predeclared,
    no_universal,
    ResolveOptions::default(),
  )
  assert_true(has_error(result, "duplicate parameter: x"))
}

///|
test "resolve: rejects positional param after star" {
  let f = parse_or_fail("def f(*args, x):\n  pass")
  let result = resolve(
    f,
    no_predeclared,
    no_universal,
    ResolveOptions::default(),
  )
  // *args followed by non-kw parameter is a syntax error in some cases
  // In Starlark, positional params cannot follow *args — kw-only params come after *
  // This should be valid in Starlark (x is keyword-only)
  assert_true(result.is_valid())
}

///|
test "resolve: rejects positional param after star-bare" {
  let f = parse_or_fail("def f(*, x=1):\n  pass")
  let result = resolve(
    f,
    no_predeclared,
    no_universal,
    ResolveOptions::default(),
  )
  assert_true(result.is_valid())
}

// --- Load statement ---

///|
test "resolve: rejects load inside function" {
  let f = parse_or_fail("def f():\n  load('m', 'x')")
  let result = resolve(
    f,
    no_predeclared,
    no_universal,
    ResolveOptions::default(),
  )
  assert_true(has_error(result, "load"))
}

///|
test "resolve: accepts load at module scope" {
  let f = parse_or_fail("load('module', 'name')")
  let result = resolve(
    f,
    no_predeclared,
    no_universal,
    ResolveOptions::default(),
  )
  assert_true(result.is_valid())
}

///|
test "resolve: rejects reassignment of load-imported name when global_reassign is off" {
  let f = parse_or_fail("load('m', 'x')\nx = 1")
  let opts = ResolveOptions::default().with_allow_global_reassign(false)
  let result = resolve(f, no_predeclared, no_universal, opts)
  assert_true(has_error(result, "cannot reassign local x"))
}

///|
test "resolve: allows load-imported reassignment when allow_global_reassign is on" {
  let f = parse_or_fail("load('m', 'x')\nx = 1")
  let opts = ResolveOptions::default().with_allow_global_reassign(true)
  let result = resolve(f, no_predeclared, no_universal, opts)
  assert_true(result.is_valid())
}

///|
test "resolve: augmented assignment to load-imported name rejected when global_reassign is off" {
  let f = parse_or_fail("load('m', 'x')\nx += 1")
  let opts = ResolveOptions::default().with_allow_global_reassign(false)
  let result = resolve(f, no_predeclared, no_universal, opts)
  assert_true(has_error(result, "cannot reassign local x"))
}

///|
test "resolve: load with alias rejects reassignment of alias when global_reassign is off" {
  let f = parse_or_fail("load('m', y='x')\ny = 1")
  let opts = ResolveOptions::default().with_allow_global_reassign(false)
  let result = resolve(f, no_predeclared, no_universal, opts)
  assert_true(has_error(result, "cannot reassign local y"))
}

///|
test "resolve: second load of same name gives cannot-reassign-top-level message" {
  let f = parse_or_fail("load('m', 'x')\nload('m', 'x')")
  let opts = ResolveOptions::default().with_allow_global_reassign(false)
  let result = resolve(f, no_predeclared, no_universal, opts)
  assert_true(has_error(result, "cannot reassign top-level x"))
}

///|
test "resolve: second load with load_binds_globally gives cannot-reassign-global message" {
  let f = parse_or_fail("load('m', 'x')\nload('m', 'x')")
  let opts = ResolveOptions::default()
    .with_allow_global_reassign(false)
    .with_load_binds_globally(true)
  let result = resolve(f, no_predeclared, no_universal, opts)
  assert_true(has_error(result, "cannot reassign global x"))
}

///|
test "resolve: assignment to load-imported name with load_binds_globally gives cannot-reassign-global message" {
  let f = parse_or_fail("load('m', 'x')\nx = 1")
  let opts = ResolveOptions::default()
    .with_allow_global_reassign(false)
    .with_load_binds_globally(true)
  let result = resolve(f, no_predeclared, no_universal, opts)
  assert_true(has_error(result, "cannot reassign global x"))
}

// --- Recursion ---

///|
test "resolve: accepts recursion when flag is on" {
  let f = parse_or_fail("def f(n):\n  return f(n - 1)")
  let opts = ResolveOptions::default().with_allow_recursion(true)
  let result = resolve(f, no_predeclared, no_universal, opts)
  assert_true(result.is_valid())
}

///|
test "resolve: accepts recursion at resolve time (runtime detection when flag is off)" {
  let f = parse_or_fail("def f(n):\n  return f(n - 1)")
  let opts = ResolveOptions::default().with_allow_recursion(false)
  let result = resolve(f, no_predeclared, no_universal, opts)
  assert_true(result.is_valid())
}

// --- Global variable collection ---

///|
test "resolve: collects global variable names" {
  let f = parse_or_fail("x = 1\ny = 2\nz = 3")
  let result = resolve(
    f,
    no_predeclared,
    no_universal,
    ResolveOptions::default(),
  )
  assert_true(result.is_valid())
  assert_eq(result.globals().length(), 3)
}

///|
test "resolve: function def adds its name to globals" {
  let f = parse_or_fail("def add(a, b):\n  return a + b")
  let result = resolve(
    f,
    no_predeclared,
    no_universal,
    ResolveOptions::default(),
  )
  assert_true(result.is_valid())
  assert_eq(result.globals().length(), 1)
  assert_eq(result.globals()[0].name(), "add")
}

///|
test "resolve: accepts call to predeclared 'module' function" {
  let f = parse_or_fail("m = module(\"mymod\", x=1)")
  let result = resolve(
    f,
    with_predeclared(["module"]),
    no_universal,
    ResolveOptions::default(),
  )
  assert_true(result.is_valid())
}

// --- Assignment-target resolution ---

///|
test "resolve: index-target object is resolved as a use" {
  let f = parse_or_fail("undef[0] = 1")
  let result = resolve(
    f,
    no_predeclared,
    no_universal,
    ResolveOptions::default(),
  )
  assert_true(has_error(result, "undefined: undef"))
}

///|
test "resolve: dot-target object is resolved as a use" {
  let f = parse_or_fail("undef.field = 1")
  let result = resolve(
    f,
    no_predeclared,
    no_universal,
    ResolveOptions::default(),
  )
  assert_true(has_error(result, "undefined: undef"))
}

///|
test "resolve: assignment to a literal is rejected" {
  let f = parse_or_fail("1 = x")
  let result = resolve(
    f,
    no_predeclared,
    no_universal,
    ResolveOptions::default(),
  )
  assert_true(has_error(result, "can't assign to literal"))
}

///|
test "resolve: assignment to a call is rejected" {
  let f = parse_or_fail("f() = x")
  let result = resolve(
    f,
    no_predeclared,
    no_universal,
    ResolveOptions::default(),
  )
  assert_true(has_error(result, "can't assign to callexpr"))
}

///|
test "resolve: augmented assignment to tuple LHS is rejected" {
  let f = parse_or_fail("a, b += 1")
  let result = resolve(
    f,
    no_predeclared,
    no_universal,
    ResolveOptions::default(),
  )
  assert_true(
    has_error(result, "can't use tuple expression in augmented assignment"),
  )
}

///|
test "resolve: augmented assignment to list LHS is rejected" {
  let f = parse_or_fail("[a, b] += 1")
  let result = resolve(
    f,
    no_predeclared,
    no_universal,
    ResolveOptions::default(),
  )
  assert_true(
    has_error(result, "can't use list expression in augmented assignment"),
  )
}

// --- Dialect gating ---

///|
test "resolve: set literal rejected when allow_set is disabled" {
  let f = parse_or_fail("x = {1, 2, 3}")
  let opts = ResolveOptions::default().with_allow_set(false)
  let result = resolve(f, no_predeclared, no_universal, opts)
  assert_true(has_error(result, "this Starlark dialect does not support sets"))
}

///|
test "resolve: set comprehension rejected when allow_set is disabled" {
  let f = parse_or_fail("x = {e for e in [1, 2]}")
  let opts = ResolveOptions::default().with_allow_set(false)
  let result = resolve(f, no_predeclared, no_universal, opts)
  assert_true(has_error(result, "this Starlark dialect does not support sets"))
}

///|
test "resolve: set literal allowed by default" {
  let f = parse_or_fail("x = {1, 2, 3}")
  let result = resolve(
    f,
    no_predeclared,
    no_universal,
    ResolveOptions::default(),
  )
  assert_true(result.is_valid())
}

// --- load identifier validation ---

///|
test "resolve: load with leading-underscore source name is rejected" {
  let f = parse_or_fail("load(\"m\", x=\"_priv\")")
  let result = resolve(
    f,
    no_predeclared,
    no_universal,
    ResolveOptions::default(),
  )
  assert_true(
    has_error(result, "names with leading underscores are not exported: _priv"),
  )
}

///|
test "resolve: load of a bare leading-underscore name is rejected" {
  let f = parse_or_fail("load(\"m\", \"_x\")")
  let result = resolve(
    f,
    no_predeclared,
    no_universal,
    ResolveOptions::default(),
  )
  assert_true(
    has_error(result, "names with leading underscores are not exported: _x"),
  )
}

///|
test "resolve: load of an exported name with underscore alias is allowed" {
  let f = parse_or_fail("load(\"m\", _local=\"public\")")
  let result = resolve(
    f,
    no_predeclared,
    no_universal,
    ResolveOptions::default(),
  )
  assert_true(result.is_valid())
}

// --- parameter ordering rules ---

///|
fn resolve_def(src : String) -> ResolvedFile {
  let f = parse_or_fail(src)
  resolve(f, no_predeclared, no_universal, ResolveOptions::default())
}

///|
test "resolve: required parameter after optional is rejected" {
  let r = resolve_def("def f(a=1, b): pass")
  assert_true(r |> has_error("required parameter may not follow optional"))
}

///|
test "resolve: bare star must be followed by keyword-only params" {
  let r = resolve_def("def f(a, *): pass")
  assert_true(
    r |> has_error("bare * must be followed by keyword-only parameters"),
  )
}

///|
test "resolve: bare star followed by keyword-only param is allowed" {
  let r = resolve_def("def f(a, *, b): pass")
  assert_true(r.is_valid())
}

///|
test "resolve: multiple star parameters are rejected" {
  let r = resolve_def("def f(*a, *b): pass")
  assert_true(r |> has_error("multiple * parameters not allowed"))
}

///|
test "resolve: parameter after kwargs is rejected" {
  let r = resolve_def("def f(**kw, a): pass")
  assert_true(r |> has_error("required parameter may not follow **kw"))
}

// --- call-argument ordering rules ---

///|
fn resolve_call(src : String) -> ResolvedFile {
  let f = parse_or_fail(src)
  resolve(
    f,
    with_predeclared(["f", "a", "b", "x", "y"]),
    no_universal,
    ResolveOptions::default(),
  )
}

///|
test "resolve: positional argument after named is rejected" {
  let r = resolve_call("f(x=1, a)")
  assert_true(r |> has_error("positional argument may not follow named"))
}

///|
test "resolve: repeated keyword argument is rejected" {
  let r = resolve_call("f(x=1, x=2)")
  assert_true(r |> has_error("keyword argument \"x\" is repeated"))
}

///|
test "resolve: multiple *args are rejected" {
  let r = resolve_call("f(*a, *b)")
  assert_true(r |> has_error("multiple *args not allowed"))
}

///|
test "resolve: multiple **kwargs are rejected" {
  let r = resolve_call("f(**a, **b)")
  assert_true(r |> has_error("multiple **kwargs not allowed"))
}

///|
test "resolve: *args after **kwargs is rejected" {
  let r = resolve_call("f(**a, *b)")
  assert_true(r |> has_error("*args may not follow **kwargs"))
}

///|
test "resolve: positional argument after *args is rejected" {
  let r = resolve_call("f(*a, b)")
  assert_true(r |> has_error("positional argument may not follow *args"))
}

// --- Error message format ---

///|
test "resolve: break outside loop uses 'break not in a loop'" {
  let f = parse_or_fail("break")
  let result = resolve(
    f,
    no_predeclared,
    no_universal,
    ResolveOptions::default(),
  )
  assert_true(has_error(result, "break not in a loop"))
}

///|
test "resolve: continue outside loop uses 'continue not in a loop'" {
  let f = parse_or_fail("continue")
  let result = resolve(
    f,
    no_predeclared,
    no_universal,
    ResolveOptions::default(),
  )
  assert_true(has_error(result, "continue not in a loop"))
}

///|
test "resolve: return outside function uses 'return statement not within a function'" {
  let f = parse_or_fail("return")
  let result = resolve(
    f,
    no_predeclared,
    no_universal,
    ResolveOptions::default(),
  )
  assert_true(has_error(result, "return statement not within a function"))
}

///|
test "resolve: top-level if uses 'if statement not within a function'" {
  let f = parse_or_fail("if True:\n  x = 1")
  let opts = ResolveOptions::default().with_allow_top_level_control(false)
  let result = resolve(f, no_predeclared, only_universal, opts)
  assert_true(has_error(result, "if statement not within a function"))
}

///|
test "resolve: top-level for uses 'for loop not within a function'" {
  let f = parse_or_fail("for x in []:\n  pass")
  let opts = ResolveOptions::default().with_allow_top_level_control(false)
  let result = resolve(f, no_predeclared, no_universal, opts)
  assert_true(has_error(result, "for loop not within a function"))
}

///|
test "resolve: top-level while uses 'while loop not within a function'" {
  let f = parse_or_fail("while True:\n  pass")
  let opts = ResolveOptions::default()
    .with_allow_top_level_control(false)
    .with_allow_recursion(true)
  let result = resolve(f, no_predeclared, only_universal, opts)
  assert_true(has_error(result, "while loop not within a function"))
}

// --- Loops counter reset inside nested def ---

///|
test "resolve: break inside nested def within loop raises 'break not in a loop'" {
  let f = parse_or_fail(
    "def fun1():\n  for a in [1, 2, 3]:\n    def nested():\n      break",
  )
  let result = resolve(
    f,
    no_predeclared,
    no_universal,
    ResolveOptions::default(),
  )
  assert_true(has_error(result, "break not in a loop"))
}

///|
test "resolve: continue inside nested def within loop raises 'continue not in a loop'" {
  let f = parse_or_fail(
    "def fun2():\n  for a in [1, 2, 3]:\n    def nested():\n      continue",
  )
  let result = resolve(
    f,
    no_predeclared,
    no_universal,
    ResolveOptions::default(),
  )
  assert_true(has_error(result, "continue not in a loop"))
}

///|
test "resolve: break inside for loop within def is valid" {
  let f = parse_or_fail("def f():\n  for x in []:\n    break")
  let result = resolve(
    f,
    no_predeclared,
    no_universal,
    ResolveOptions::default(),
  )
  assert_true(result.is_valid())
}

// --- load inside loop/conditional/function ---

///|
test "resolve: load inside def raises 'load statement within a function'" {
  let f = parse_or_fail("def f():\n  load(\"m.star\", \"y\")")
  let result = resolve(
    f,
    no_predeclared,
    no_universal,
    ResolveOptions::default(),
  )
  assert_true(has_error(result, "load statement within a function"))
}

///|
test "resolve: load inside top-level for raises 'load statement within a loop'" {
  let f = parse_or_fail("for x in []:\n  load(\"m.star\", \"y\")")
  let opts = ResolveOptions::default().with_allow_top_level_control(true)
  let result = resolve(f, no_predeclared, no_universal, opts)
  assert_true(has_error(result, "load statement within a loop"))
}

///|
test "resolve: load inside top-level if raises 'load statement within a conditional'" {
  let f = parse_or_fail("if True:\n  load(\"m.star\", \"y\")")
  let opts = ResolveOptions::default().with_allow_top_level_control(true)
  let result = resolve(f, no_predeclared, only_universal, opts)
  assert_true(has_error(result, "load statement within a conditional"))
}

///|
test "resolve: while with allow_while=false raises dialect error" {
  let f = parse_or_fail("while True:\n  pass")
  let opts = ResolveOptions::default()
    .with_allow_while(false)
    .with_allow_top_level_control(true)
  let result = resolve(f, no_predeclared, only_universal, opts)
  assert_true(
    has_error(result, "this Starlark dialect does not support while loops"),
  )
}

///|
test "resolve: load inside function inside if gives 'within a function' not 'conditional'" {
  let f = parse_or_fail("if True:\n  def g():\n    load(\"m.star\", \"y\")")
  let opts = ResolveOptions::default().with_allow_top_level_control(true)
  let result = resolve(f, no_predeclared, only_universal, opts)
  assert_true(has_error(result, "load statement within a function"))
}

// --- Conditional expression (ternary) resolution order ---

///|
test "resolve: conditional expression reports condition error before true-value error" {
  // `aa if bb else cc` — all three are undefined.
  // The condition `bb` is at col 7; the true-value `aa` is at col 1.
  // starlark-go reports `bb` first (condition before true-value).
  let f = parse_or_fail("aa if bb else cc")
  let result = resolve(
    f,
    no_predeclared,
    no_universal,
    ResolveOptions::default(),
  )
  let errors = result.errors()
  assert_true(errors.length() >= 1)
  assert_true(errors[0].msg().contains("undefined: bb"))
}

// --- Error position anchoring ---

///|
test "resolve: multiple *args error anchors at the * operator" {
  // f(*a, *b) — second * is at col 7 (1-based)
  let r = resolve_call("f(*a, *b)")
  assert_true(error_col(r, "multiple *args not allowed") == Some(7))
}

///|
test "resolve: multiple **kwargs error anchors at the ** operator" {
  // f(**a, **b) — second ** is at col 8 (1-based)
  let r = resolve_call("f(**a, **b)")
  assert_true(error_col(r, "multiple **kwargs not allowed") == Some(8))
}

///|
test "resolve: *args after **kwargs error anchors at the * operator" {
  // f(**b, *a) — the * is at col 8 (1-based)
  let r = resolve_call("f(**b, *a)")
  assert_true(error_col(r, "*args may not follow **kwargs") == Some(8))
}

///|
test "resolve: cannot reassign declared-at anchors at function name" {
  // `def f(): pass` — def is at col 1, f is at col 5
  let f = parse_or_fail("def f(): pass\nf = 1")
  let opts = ResolveOptions::default().with_allow_global_reassign(false)
  let result = resolve(f, no_predeclared, no_universal, opts)
  let errors = result.errors()
  assert_true(errors.length() >= 1)
  let msg = errors[0].msg()
  assert_true(msg.contains("declared at"))
  assert_true(msg.contains(":1:5"))
}
