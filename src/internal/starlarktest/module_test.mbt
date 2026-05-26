// Integration tests for Module value type.
// Ported from starlark-go/starlark/testdata/module.star with patterns
// adapted for substring matching (regex anchors and wildcards stripped).

///|
let module_type_src : String =
  #|load("assert.star", "assert")
  #|assert.eq(type(assert), "module")

///|
test "module.star: type(module) returns 'module'" {
  let errs = run_star_string(module_type_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let module_str_src : String =
  #|load("assert.star", "assert")
  #|assert.eq(str(assert), "<module \"assert\">")

///|
test "module.star: str(module) returns '<module \"name\">'" {
  let errs = run_star_string(module_str_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let module_dir_src : String =
  #|load("assert.star", "assert")
  #|assert.eq(dir(assert), ["contains", "eq", "fail", "fails", "lt", "ne", "true"])

///|
test "module.star: dir(module) returns sorted attribute names" {
  let errs = run_star_string(module_dir_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let module_unhashable_src : String =
  #|load("assert.star", "assert")
  #|assert.fails(lambda : {assert: None}, "unhashable: module")

///|
test "module.star: module is not hashable" {
  let errs = run_star_string(module_unhashable_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let module_assign_field_src : String =
  #|load("assert.star", "assert")
  #|def assignfield():
  #|    assert.foo = None
  #|assert.fails(assignfield, "can't assign to .foo field of module")

///|
test "module.star: assigning to module field raises error" {
  let errs = run_star_string(module_assign_field_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let module_no_such_field_src : String =
  #|load("assert.star", "assert")
  #|assert.fails(lambda : assert.nonesuch, "module has no .nonesuch field or method")

///|
test "module.star: accessing missing field raises descriptive error" {
  let errs = run_star_string(module_no_such_field_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}
