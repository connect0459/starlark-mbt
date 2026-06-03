// Integration tests derived from while.star.
// Tests while loop semantics: basic accumulation, break, and continue.

///|
let while_basic_src : String =
  #|load("assert.star", "assert")
  #|
  #|def sum(n):
  #|  r = 0
  #|  while n > 0:
  #|    r += n
  #|    n -= 1
  #|  return r
  #|
  #|assert.eq(sum(5), 5+4+3+2+1)

///|
test "while.star: basic while accumulation" {
  let errs = run_star_string(while_basic_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let while_break_src : String =
  #|load("assert.star", "assert")
  #|
  #|def while_break(n):
  #|  r = 0
  #|  while n > 0:
  #|    if n == 5:
  #|      break
  #|    r += n
  #|    n -= 1
  #|  return r
  #|
  #|assert.eq(while_break(10), 40)

///|
test "while.star: break exits loop early" {
  let errs = run_star_string(while_break_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let while_continue_src : String =
  #|load("assert.star", "assert")
  #|
  #|def while_continue(n):
  #|  r = 0
  #|  while n > 0:
  #|    if n % 2 == 0:
  #|      n -= 1
  #|      continue
  #|    r += n
  #|    n -= 1
  #|  return r
  #|
  #|assert.eq(while_continue(10), 25)

///|
test "while.star: continue skips even numbers" {
  let errs = run_star_string(while_continue_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}
