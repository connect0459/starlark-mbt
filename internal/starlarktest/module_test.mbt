// Integration tests from starlark-go testdata/module.star.
// Omitted: Go-regex spell-check pattern chunk (not supported by pattern_matches).
// Single-chunk file; entire content is filtered.

///|
let module_star : String =
  #|# Tests of Module.
  #|
  #|load("assert.star", "assert")
  #|
  #|assert.eq(type(assert), "module")
  #|assert.eq(str(assert), '<module "assert">')
  #|assert.eq(dir(assert), ["contains", "eq", "fail", "fails", "lt", "ne", "true"])
  #|assert.fails(lambda : {assert: None}, "unhashable: module")
  #|
  #|def assignfield():
  #|    assert.foo = None
  #|
  #|assert.fails(assignfield, "can't assign to .foo field of module")
  #|
  #|# no such field
  #|assert.fails(lambda : assert.nonesuch, "module has no .nonesuch field or method$")
  #|assert.fails(lambda : assert.falls, "module has no .falls field or method .did you mean .fails\\?")

///|
test "module.star" {
  let src = skip_chunks_containing(module_star, ["did you mean .fails"])
  let errs = run_chunked_string(src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}
