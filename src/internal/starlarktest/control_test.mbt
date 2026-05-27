// Integration tests derived from control.star.
// Tests Starlark control flow: if/elif/else, for loops with break/continue,
// return semantics, and variable scoping.
// Omitted: fibonacci infinite iterable (requires external predeclared value).

///|
let control_star_src : String =
  #|load("assert.star", "assert")
  #|
  #|def controlflow():
  #|  # elif
  #|  x = 0
  #|  if True:
  #|    x=1
  #|  elif False:
  #|    assert.fail("else of true")
  #|  else:
  #|    assert.fail("else of else of true")
  #|  assert.true(x)
  #|
  #|  x = 0
  #|  if False:
  #|    assert.fail("then of false")
  #|  elif True:
  #|    x = 1
  #|  else:
  #|    assert.fail("else of true")
  #|  assert.true(x)
  #|
  #|  x = 0
  #|  if False:
  #|    assert.fail("then of false")
  #|  elif False:
  #|    assert.fail("then of false")
  #|  else:
  #|    x = 1
  #|  assert.true(x)
  #|controlflow()
  #|
  #|def loops():
  #|  y = ""
  #|  for x in [1, 2, 3, 4, 5]:
  #|    if x == 2:
  #|      continue
  #|    if x == 4:
  #|      break
  #|    y = y + str(x)
  #|  return y
  #|assert.eq(loops(), "13")
  #|
  #|# return
  #|g = 123
  #|def f(x):
  #|  for g in (1, 2, 3):
  #|    if g == x:
  #|      return g
  #|assert.eq(f(2), 2)
  #|assert.eq(f(4), None)
  #|assert.eq(g, 123)

///|
test "control.star: all assertions pass" {
  let errs = run_star_string(control_star_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}
