// Compliance tests for Starlark function calling conventions.
// Covers systematic verification of positional, keyword, *args, **kwargs,
// keyword-only params, and all their error cases.

///|
let basic_param_src : String =
  #|load("assert.star", "assert")
  #|
  #|def a():
  #|    return
  #|def b(a, b):
  #|    return a, b
  #|def c(a, b=42):
  #|    return a, b
  #|def d(*args):
  #|    return args
  #|def e(**kwargs):
  #|    return kwargs
  #|def f(a, b=42, *args, **kwargs):
  #|    return a, b, args, kwargs
  #|
  #|# a()
  #|assert.eq(a(), None)
  #|assert.fails(lambda: a(1), "")
  #|
  #|# b(a, b)
  #|assert.fails(lambda: b(), "missing")
  #|assert.fails(lambda: b(1), "missing")
  #|assert.eq(b(1, 2), (1, 2))
  #|assert.fails(lambda: b(1, 2, 3), "positional")
  #|assert.eq(b(1, b=2), (1, 2))
  #|assert.fails(lambda: b(1, a=2), "multiple values")
  #|assert.fails(lambda: b(1, x=2), "unexpected keyword")
  #|assert.eq(b(a=1, b=2), (1, 2))
  #|assert.eq(b(b=1, a=2), (2, 1))
  #|
  #|# c(a, b=42)
  #|assert.fails(lambda: c(), "missing")
  #|assert.eq(c(1), (1, 42))
  #|assert.eq(c(1, 2), (1, 2))
  #|assert.fails(lambda: c(1, 2, 3), "positional")
  #|assert.eq(c(1, b=2), (1, 2))
  #|assert.fails(lambda: c(1, a=2), "multiple values")
  #|assert.eq(c(a=1, b=2), (1, 2))
  #|assert.eq(c(b=1, a=2), (2, 1))
  #|
  #|# d(*args)
  #|assert.eq(d(), ())
  #|assert.eq(d(1), (1,))
  #|assert.eq(d(1, 2), (1, 2))
  #|assert.fails(lambda: d(1, 2, k=3), "unexpected keyword")
  #|assert.fails(lambda: d(args=[]), "unexpected keyword")
  #|
  #|# e(**kwargs)
  #|assert.eq(e(), {})
  #|assert.fails(lambda: e(1), "positional")
  #|assert.eq(e(k=1), {"k": 1})
  #|
  #|# f(a, b=42, *args, **kwargs)
  #|assert.fails(lambda: f(), "missing")
  #|assert.eq(f(0), (0, 42, (), {}))
  #|assert.eq(f(0, 1), (0, 1, (), {}))
  #|assert.eq(f(0, 1, 2), (0, 1, (2,), {}))
  #|assert.eq(f(0, 1, 2, 3), (0, 1, (2, 3), {}))
  #|assert.eq(f(a=0), (0, 42, (), {}))
  #|assert.eq(f(0, b=1), (0, 1, (), {}))
  #|assert.fails(lambda: f(0, a=1), "multiple values")
  #|assert.eq(f(0, b=1, c=2), (0, 1, (), {"c": 2}))

///|
test "parameter passing: basic positional, keyword, *args, **kwargs" {
  let errs = run_star_string(basic_param_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let kwonly_param_src : String =
  #|load("assert.star", "assert")
  #|
  #|# g(a, b=42, *args, c=123, **kwargs) — keyword-only with default after *args
  #|def g(a, b=42, *args, c=123, **kwargs):
  #|    return a, b, args, c, kwargs
  #|
  #|assert.fails(lambda: g(), "missing")
  #|assert.eq(g(0), (0, 42, (), 123, {}))
  #|assert.eq(g(0, 1), (0, 1, (), 123, {}))
  #|assert.eq(g(0, 1, 2), (0, 1, (2,), 123, {}))
  #|assert.eq(g(0, 1, 2, 3), (0, 1, (2, 3), 123, {}))
  #|assert.eq(g(a=0), (0, 42, (), 123, {}))
  #|assert.eq(g(0, b=1), (0, 1, (), 123, {}))
  #|assert.fails(lambda: g(0, a=1), "multiple values")
  #|assert.eq(g(0, b=1, c=2, d=3), (0, 1, (), 2, {"d": 3}))
  #|
  #|# h(a, b=42, *, c=123, **kwargs) — keyword-only after bare *
  #|def h(a, b=42, *, c=123, **kwargs):
  #|    return a, b, c, kwargs
  #|
  #|assert.fails(lambda: h(), "missing")
  #|assert.eq(h(0), (0, 42, 123, {}))
  #|assert.eq(h(0, 1), (0, 1, 123, {}))
  #|assert.fails(lambda: h(0, 1, 2), "positional")
  #|assert.eq(h(a=0), (0, 42, 123, {}))
  #|assert.eq(h(0, b=1), (0, 1, 123, {}))
  #|assert.fails(lambda: h(0, a=1), "multiple values")
  #|assert.eq(h(0, b=1, c=2), (0, 1, 2, {}))
  #|assert.eq(h(0, b=1, d=2), (0, 1, 123, {"d": 2}))
  #|assert.eq(h(0, b=1, c=2, d=3), (0, 1, 2, {"d": 3}))

///|
test "parameter passing: keyword-only params after * and *args" {
  let errs = run_star_string(kwonly_param_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let required_kwonly_src : String =
  #|load("assert.star", "assert")
  #|
  #|# i(a, b=42, *, c, d=123, e, **kwargs) — required keyword-only params
  #|def i(a, b=42, *, c, d=123, e, **kwargs):
  #|    return a, b, c, d, e, kwargs
  #|
  #|assert.fails(lambda: i(), "missing")
  #|assert.fails(lambda: i(0), "missing")
  #|assert.fails(lambda: i(0, 1), "missing")
  #|assert.fails(lambda: i(0, 1, 2), "positional")
  #|assert.fails(lambda: i(0, 1, e=2), "missing")
  #|assert.fails(lambda: i(a=0), "missing")
  #|assert.fails(lambda: i(0, b=1), "missing")
  #|assert.fails(lambda: i(0, a=1), "multiple values")
  #|assert.eq(i(0, b=1, c=2, d=3, e=4), (0, 1, 2, 3, 4, {}))

///|
test "parameter passing: required keyword-only params" {
  let errs = run_star_string(required_kwonly_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let mixed_varargs_kwonly_src : String =
  #|load("assert.star", "assert")
  #|
  #|# j(a, b=42, *args, c, d=123, e, **kwargs) — *args with required keyword-only params
  #|def j(a, b=42, *args, c, d=123, e, **kwargs):
  #|    return a, b, args, c, d, e, kwargs
  #|
  #|assert.fails(lambda: j(), "missing")
  #|assert.fails(lambda: j(0), "missing")
  #|assert.fails(lambda: j(0, 1), "missing")
  #|assert.fails(lambda: j(0, 1, 2), "missing")
  #|assert.fails(lambda: j(0, 1, e=2), "missing")
  #|assert.fails(lambda: j(0, 1, 2, 3), "missing")
  #|assert.fails(lambda: j(a=0), "missing")
  #|assert.fails(lambda: j(0, b=1), "missing")
  #|assert.fails(lambda: j(0, a=1), "multiple values")
  #|assert.fails(lambda: j(0, b=1, c=2), "missing")
  #|assert.fails(lambda: j(0, b=1, d=2), "missing")
  #|assert.fails(lambda: j(0, b=1, c=2, d=3), "missing")
  #|assert.eq(j(0, b=1, c=2, d=3, e=4), (0, 1, (), 2, 3, 4, {}))
  #|assert.fails(lambda: j(0, 1, b=1, c=2, d=3, e=4), "multiple values")
  #|assert.eq(j(0, 1, 2, c=3, e=4), (0, 1, (2,), 3, 123, 4, {}))

///|
test "parameter passing: *args with required keyword-only params (function j)" {
  let errs = run_star_string(mixed_varargs_kwonly_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let kwargs_non_string_key_src : String =
  #|load("assert.star", "assert")
  #|
  #|def e(**kwargs):
  #|    return kwargs
  #|
  #|assert.fails(lambda: e(**{1: 2}), "keywords must be strings, not int$")
  #|assert.fails(lambda: e(**{"x": 1, 2: 3}), "keywords must be strings, not int$")
  #|assert.fails(lambda: e(**{None: 1}), "keywords must be strings, not NoneType$")

///|
test "**kwargs expansion rejects non-string keys" {
  let errs = run_star_string(kwargs_non_string_key_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let splat_operand_type_src : String =
  #|load("assert.star", "assert")
  #|
  #|def f(*args, **kwargs):
  #|    return args, kwargs
  #|
  #|assert.fails(lambda: f(*5), "argument after * must be iterable, not int$")
  #|assert.fails(lambda: f(*"abc"), "argument after * must be iterable, not string$")
  #|assert.fails(lambda: f(**5), "argument after ** must be a mapping, not int$")

///|
test "splat operand type errors match starlark-go wording" {
  let errs = run_star_string(splat_operand_type_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let non_callable_src : String =
  #|load("assert.star", "assert")
  #|
  #|assert.fails(lambda: (5)(), "invalid call of non-function \\(int\\)$")
  #|assert.fails(lambda: "abc"(), "invalid call of non-function \\(string\\)$")

///|
test "calling a non-callable value matches starlark-go wording" {
  let errs = run_star_string(non_callable_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}
