// Integration tests derived from bool.star (bazelbuild/starlark test suite).

///|
let bool_star_src : String =
  #|load("assert.star", "assert")
  #|
  #|assert.true(True)
  #|assert.true(not False)
  #|assert.true(not not True)
  #|assert.true(not not 1 >= 1)
  #|assert.true(not not 2 > 1)
  #|
  #|assert.eq(
  #|    [bool(), bool(1), bool(0), bool("hello"), bool("")],
  #|    [False, True, False, True, False],
  #|)
  #|
  #|assert.true(None == None)
  #|assert.true(None != False)
  #|assert.true(None != True)
  #|assert.eq(1 == 1, True)
  #|assert.eq(1 == 2, False)
  #|assert.true(False == False)
  #|assert.true(True == True)
  #|
  #|assert.true(False < True)
  #|assert.true(False <= True)
  #|assert.true(False <= False)
  #|assert.true(True > False)
  #|assert.true(True >= False)
  #|assert.true(True >= True)
  #|
  #|assert.eq(1 if 3 > 2 else 0, 1)
  #|assert.eq(1 if "foo" else 0, 1)
  #|assert.eq(1 if "" else 0, 0)
  #|
  #|assert.eq(0 or "" or [] or 0, 0)
  #|assert.eq(0 or "" or [] or 123 or 1 // 0, 123)
  #|assert.fails(lambda : 0 or "" or [] or 0 or 1 // 0, "division by zero")
  #|
  #|assert.eq(1 and "a" and [1] and 123, 123)
  #|assert.eq(1 and "a" and [1] and 0 and 1 // 0, 0)
  #|assert.fails(lambda : 1 and "a" and [1] and 123 and 1 // 0, "division by zero")
  #|
  #|assert.eq(''.splitlines(True), [])
  #|assert.fails(lambda: ''.splitlines(1), 'got int, want bool')
  #|assert.fails(lambda: ''.splitlines("hello"), 'got string, want bool')
  #|assert.fails(lambda: ''.splitlines(0.0), 'got float, want bool')

///|
test "bool.star: all assertions pass" {
  let errs = run_star_string(bool_star_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}
