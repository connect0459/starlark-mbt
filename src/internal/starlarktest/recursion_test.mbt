// Integration tests derived from starlark-go recursion.star.
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
