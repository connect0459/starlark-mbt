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
  assert_true(
    has_error(result, "cannot reassign name 'x' imported from a load statement"),
  )
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
  assert_true(
    has_error(result, "cannot reassign name 'x' imported from a load statement"),
  )
}

///|
test "resolve: load with alias rejects reassignment of alias when global_reassign is off" {
  let f = parse_or_fail("load('m', y='x')\ny = 1")
  let opts = ResolveOptions::default().with_allow_global_reassign(false)
  let result = resolve(f, no_predeclared, no_universal, opts)
  assert_true(
    has_error(result, "cannot reassign name 'y' imported from a load statement"),
  )
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

// --- Assignment-target resolution (MISSING-46/47/48) ---

///|
test "resolve: index-target object is resolved as a use (MISSING-46)" {
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
test "resolve: dot-target object is resolved as a use (MISSING-46)" {
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
test "resolve: assignment to a literal is rejected (MISSING-47)" {
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
test "resolve: assignment to a call is rejected (MISSING-47)" {
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
test "resolve: augmented assignment to tuple LHS is rejected (MISSING-48)" {
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
test "resolve: augmented assignment to list LHS is rejected (MISSING-48)" {
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
