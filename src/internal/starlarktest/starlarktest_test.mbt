// Integration tests for the starlarktest harness.
// Verifies that assert.star can be loaded and its assertions work.

///|
test "starlarktest: assert.eq passes for equal values" {
  let errs = run_star_string(
    "load(\"assert.star\", \"assert\")\nassert.eq(1 + 1, 2)",
  )
  assert_eq(errs.length(), 0)
}

///|
test "starlarktest: assert.eq fails for unequal values" {
  let errs = run_star_string(
    "load(\"assert.star\", \"assert\")\nassert.eq(1, 2)",
  )
  assert_eq(errs.length(), 1)
}

///|
test "starlarktest: assert.true passes for truthy condition" {
  let errs = run_star_string(
    "load(\"assert.star\", \"assert\")\nassert.true(True)",
  )
  assert_eq(errs.length(), 0)
}

///|
test "starlarktest: assert.true fails for falsy condition" {
  let errs = run_star_string(
    "load(\"assert.star\", \"assert\")\nassert.true(False)",
  )
  assert_eq(errs.length(), 1)
}

///|
test "starlarktest: assert.fails captures expected error" {
  let errs = run_star_string(
    "load(\"assert.star\", \"assert\")\nassert.fails(lambda: 1//0, \"division\")",
  )
  assert_eq(errs.length(), 0)
}

///|
test "starlarktest: assert.fails fails when no error is raised" {
  let errs = run_star_string(
    "load(\"assert.star\", \"assert\")\nassert.fails(lambda: 1, \"error\")",
  )
  assert_eq(errs.length(), 1)
}

///|
test "run_chunked_string: chunk without error comment runs normally" {
  let src =
    #|load("assert.star", "assert")
    #|assert.eq(1 + 1, 2)
  let failures = run_chunked_string(src)
  assert_eq(failures.length(), 0)
}

///|
test "run_chunked_string: chunk with matching error comment passes" {
  let src =
    #|(a, b, c) = 1 ### "got int in sequence assignment"
  let failures = run_chunked_string(src)
  assert_eq(failures.length(), 0)
}

///|
test "run_chunked_string: chunk with unmatched error comment fails" {
  let src =
    #|(a, b, c) = 1 ### "wrong pattern"
  let failures = run_chunked_string(src)
  assert_eq(failures.length(), 1)
  assert_true(failures[0].contains("did not match pattern"))
}

///|
test "run_chunked_string: chunk expects error but none raised fails" {
  let src =
    #|x = 1 ### "some error"
  let failures = run_chunked_string(src)
  assert_eq(failures.length(), 1)
  assert_true(failures[0].contains("but none was raised"))
}

///|
test "run_chunked_string: unexpected error in normal chunk fails" {
  let src =
    #|(a, b, c) = 1
  let failures = run_chunked_string(src)
  assert_eq(failures.length(), 1)
  assert_true(failures[0].contains("unexpected error"))
}

///|
test "run_chunked_string: multiple chunks all passing" {
  let src =
    #|load("assert.star", "assert")
    #|assert.eq(1, 1)
    #|---
    #|(a, b) = () ### "too few values to unpack"
    #|---
    #|load("assert.star", "assert")
    #|assert.eq(2 + 2, 4)
  let failures = run_chunked_string(src)
  assert_eq(failures.length(), 0)
}

///|
test "run_chunked_string: backtick-quoted pattern" {
  let src =
    #|x = {} | 1 ### `unknown binary op: dict | int`
  let failures = run_chunked_string(src)
  assert_eq(failures.length(), 0)
}
