// Integration tests derived from recursion.star.
// Tests recursion: fibonacci and recursion depth limit enforcement.

///|
let recursion_fib_src : String =
  #|load("assert.star", "assert")
  #|
  #|def fib(n):
  #|  if n <= 1: return 1
  #|  return fib(n-1) + fib(n-2)
  #|
  #|assert.eq(fib(5), 8)

///|
test "recursion.star: fibonacci via mutual recursion" {
  let errs = run_star_string(recursion_fib_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let recursion_limit_src : String =
  #|load("assert.star", "assert")
  #|
  #|def runaway():
  #|  return runaway()
  #|
  #|assert.fails(runaway, "maximum recursion depth exceeded")

///|
test "recursion.star: infinite recursion hits depth limit" {
  let errs = run_star_string(recursion_limit_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let recursion_disallowed_chunked : String =
  #|# option:norecursion
  #|load("assert.star", "assert")
  #|def fib(x):
  #|  if x < 2: return x
  #|  return fib(x-2) + fib(x-1)
  #|assert.fails(lambda: fib(10), "function fib called recursively")
  #|---
  #|# option:norecursion
  #|load("assert.star", "assert")
  #|Y = lambda f: (lambda x: x(x))(lambda y: f(lambda *args: y(y)(*args)))
  #|fibgen = lambda fib: lambda x: (x if x<2 else fib(x-1)+fib(x-2))
  #|fib2 = Y(fibgen)
  #|assert.fails(lambda: [fib2(x) for x in range(10)], "function lambda called recursively")
  #|---
  #|# option:norecursion
  #|load("assert.star", "assert")
  #|def map(f, seq): return [f(x) for x in seq]
  #|def double(x): return x+x
  #|def mapdouble(x): return map(double, x)
  #|assert.fails(lambda: map(mapdouble, ([1,2,3],["a","b","c"])), "function map called recursively")

///|
test "function.star: recursion detected at runtime when allow_recursion=false" {
  let failures = run_chunked_string(recursion_disallowed_chunked)
  if failures.length() != 0 {
    fail(failures.join("\n"))
  }
}
