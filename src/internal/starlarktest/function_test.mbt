// Integration tests derived from function.star.
// Tests Starlark function semantics: lexical scope, closures, defaults, parameter binding.
// Omitted: hasfields(), recursion detection (fib/Y-combinator), BoundMethod identity in sets,
// local-variable-before-assignment (unbound cell detection not implemented).

///|
let function_closures_src : String =
  #|load("assert.star", "assert", "freeze")
  #|
  #|def outer(x):
  #|   def inner(y):
  #|     return x + x + y
  #|   return inner
  #|
  #|z = outer(3)
  #|assert.eq(z(5), 11)
  #|assert.eq(z(7), 13)
  #|z2 = outer(4)
  #|assert.eq(z2(5), 13)
  #|assert.eq(z2(7), 15)
  #|assert.eq(z(5), 11)
  #|assert.eq(z(7), 13)
  #|
  #|assert.eq(str(outer), '<function outer>')
  #|assert.eq(str(z), '<function inner>')
  #|assert.eq(str(str), '<built-in function str>')
  #|assert.eq(str("".startswith), '<built-in method startswith of string value>')
  #|
  #|def squares():
  #|    x = [0]
  #|    def f():
  #|      x[0] += 1
  #|      return x[0] * x[0]
  #|    return f
  #|
  #|sq = squares()
  #|assert.eq(sq(), 1)
  #|assert.eq(sq(), 4)
  #|assert.eq(sq(), 9)
  #|assert.eq(sq(), 16)
  #|
  #|sq2 = freeze(sq)
  #|assert.fails(sq2, "frozen list")
  #|
  #|def map(f, seq): return [f(x) for x in seq]
  #|def double(x): return x+x
  #|assert.eq(map(double, [1, 2, 3]), [2, 4, 6])
  #|assert.eq(map(double, ["a", "b", "c"]), ["aa", "bb", "cc"])
  #|
  #|def f():
  #|   return lambda: 1
  #|assert.eq(f()(), 1)
  #|assert.eq(["abc"][0][0].upper(), "A")
  #|
  #|calls = []
  #|def yin(x):
  #|  calls.append("yin")
  #|  if x:
  #|    yang(False)
  #|
  #|def yang(x):
  #|  calls.append("yang")
  #|  if x:
  #|    yin(False)
  #|
  #|yin(True)
  #|assert.eq(calls, ["yin", "yang"])
  #|
  #|calls.clear()
  #|yang(True)
  #|assert.eq(calls, ["yang", "yin"])

///|
test "function.star: closures and lexical scope" {
  let errs = run_star_string(function_closures_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let function_defaults_src : String =
  #|load("assert.star", "assert", "freeze")
  #|
  #|def f(x=[0]):
  #|  return x
  #|
  #|assert.eq(f(), [0])
  #|
  #|f().append(1)
  #|assert.eq(f(), [0, 1])
  #|
  #|freeze(f)
  #|assert.fails(lambda: f().append(2), "cannot append to frozen list")

///|
test "function.star: mutable default values and freeze" {
  let errs = run_star_string(function_defaults_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let function_lambda_parse_src : String =
  #|load("assert.star", "assert")
  #|
  #|f = lambda x: 1 if x else 0
  #|assert.eq(f(True), 1)
  #|assert.eq(f(False), 0)
  #|
  #|x = True
  #|f2 = (lambda x: 1) if x else 0
  #|assert.eq(f2(123), 1)
  #|
  #|tf = lambda: True, lambda: False
  #|assert.true(tf[0]())
  #|assert.true(not tf[1]())

///|
test "function.star: lambda parsing corner cases" {
  let errs = run_star_string(function_lambda_parse_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let function_param_errors_src : String =
  #|load("assert.star", "assert")
  #|
  #|def f(a, b, mm): pass
  #|
  #|assert.fails(lambda: f(1, 2), "missing")
  #|assert.fails(lambda: f(1, 2, 3, mm=4), "multiple values for parameter")

///|
test "function.star: missing and duplicate parameter errors" {
  let errs = run_star_string(function_param_errors_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let function_dynamic_checks_src : String =
  #|load("assert.star", "assert")
  #|
  #|def f(*args, **kwargs):
  #|  return args, kwargs
  #|
  #|assert.eq(f(x=1, y=2), ((), {"x": 1, "y": 2}))
  #|assert.fails(lambda: f(x=1, **dict(x=2)), "multiple values for parameter")
  #|
  #|def g(x, y):
  #|  return x, y
  #|
  #|assert.eq(g(1, y=2), (1, 2))
  #|assert.fails(lambda: g(1, y=2, **{"y": 3}), "multiple values for parameter")

///|
test "function.star: dynamic multiple-values checks" {
  let errs = run_star_string(function_dynamic_checks_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let function_call_var_kw_src : String =
  #|load("assert.star", "assert")
  #|
  #|def f(a, b, x, y):
  #|  return a+b+x+y
  #|
  #|assert.eq(f(*("a", "b"), **dict(y="y", x="x")) + ".", "abxy.")

///|
test "function.star: CALL_VAR_KW with *args and **kwargs" {
  let errs = run_star_string(function_call_var_kw_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let function_eval_order_src : String =
  #|load("assert.star", "assert")
  #|
  #|r = []
  #|
  #|def id(x):
  #|  r.append(x)
  #|  return x
  #|
  #|def f(*args, **kwargs):
  #|  return (args, kwargs)
  #|
  #|y = f(id(1), id(2), x=id(3), *[id(4)], **dict(z=id(5)))
  #|assert.eq(y, ((1, 2, 4), dict(x=3, z=5)))
  #|assert.eq(r, [1, 2, 3, 4, 5])

///|
test "function.star: order of argument evaluation" {
  let errs = run_star_string(function_eval_order_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let function_recursion_closure_src : String =
  #|load("assert.star", "assert")
  #|
  #|def a():
  #|    lst = []
  #|    def b(n):
  #|        lst.append(n)
  #|        if n > 0:
  #|            b(n - 1)
  #|    b(3)
  #|    return lst
  #|
  #|assert.eq(a(), [3, 2, 1, 0])
  #|
  #|def c():
  #|    lst = []
  #|    x = 1
  #|    def d():
  #|      lst.append(x)
  #|    d()
  #|    x = 2
  #|    d()
  #|    return lst
  #|
  #|assert.eq(c(), [1, 2])
  #|
  #|def e():
  #|    def f():
  #|      return x
  #|    x = 1
  #|    return f()
  #|
  #|assert.eq(e(), 1)

///|
test "function.star: recursive closure and live variable reference" {
  let errs = run_star_string(function_recursion_closure_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let function_trailing_comma_src : String =
  #|def a(x,): pass
  #|def b(x, y=None, ): pass
  #|def c(x, y=None, *args, ): pass
  #|
  #|a(1,)
  #|b(1, y=2, )

///|
test "function.star: trailing comma in defs and calls" {
  let errs = run_star_string(function_trailing_comma_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let function_bound_method_identity_src : String =
  #|load("assert.star", "assert")
  #|# builtin_function_or_method use identity equivalence.
  #|closures = set(["".count for _ in range(10)])
  #|assert.eq(len(closures), 10)

///|
test "function.star: bound method identity in sets (each access is unique)" {
  let errs = run_star_string(function_bound_method_identity_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let function_unbound_cell_src : String =
  #|load("assert.star", "assert")
  #|
  #|def e():
  #|    x = 1
  #|    def f():
  #|      print(x) # this reference to x fails
  #|      x = 3    # because this assignment makes x local to f
  #|    f()
  #|
  #|assert.fails(e, "local variable x referenced before assignment")
  #|
  #|def f():
  #|    def inner():
  #|        return x
  #|    if False:
  #|        x = 0
  #|    return x # fails (x is an uninitialized cell of this function)
  #|
  #|assert.fails(f, "local variable x referenced before assignment")
  #|
  #|def g():
  #|    def inner():
  #|        return x # fails (x is an uninitialized cell of the enclosing function)
  #|    if False:
  #|        x = 0
  #|    return inner()
  #|
  #|assert.fails(g, "local variable x referenced before assignment")

///|
test "function.star: local variable referenced before assignment" {
  let errs = run_star_string(function_unbound_cell_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}
