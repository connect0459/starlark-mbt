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
