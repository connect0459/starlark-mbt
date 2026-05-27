// Integration tests derived from misc.star.

///|
let misc_ordered_cmp_src : String =
  #|load("assert.star", "assert")
  #|
  #|assert.fails(lambda: None < None, "not impl")
  #|assert.fails(lambda: None < False, "not impl")
  #|assert.fails(lambda: False < list, "not impl")
  #|assert.fails(lambda: list < {}, "not impl")
  #|assert.fails(lambda: {} < (lambda: None), "not impl")
  #|assert.fails(lambda: (lambda: None) < 0, "not impl")
  #|assert.fails(lambda: 0 < [], "not impl")
  #|assert.fails(lambda: [] < "", "not impl")
  #|assert.fails(lambda: "" < (), "not impl")
  #|assert.lt(1, 2.0)
  #|assert.lt(2.0, 3)

///|
test "misc.star: ordered comparisons require same type; int<float allowed" {
  let errs = run_star_string(misc_ordered_cmp_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let misc_regression_src : String =
  #|load("assert.star", "assert")
  #|
  #|assert.eq(("ababab"[2:]).replace("b", "c"), "acac")
  #|assert.eq("ababab"[2:].replace("b", "c"), "acac")
  #|
  #|three = 1 + \
  #|  2
  #|assert.eq(1 + \
  #|  2, three)

///|
test "misc.star: regression - string slice+replace and line continuation" {
  let errs = run_star_string(misc_regression_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let misc_load_globals_src : String =
  #|load('assert.star', 'assert', 'freeze')
  #|assert.eq(str(freeze), '<built-in function freeze>')

///|
test "misc.star: load exposes explicitly declared globals" {
  let errs = run_star_string(misc_load_globals_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let misc_load_predeclared_src : String =
  #|load('assert.star', 'assert', 'matches')

///|
test "misc.star: load does not expose pre-declared globals from other modules" {
  let errs = run_star_string(misc_load_predeclared_src)
  assert_true(errs.length() > 0 && errs.any(fn(e) { e.contains("matches") }))
}

///|
let misc_load_universals_src : String =
  #|load('assert.star', 'len')

///|
test "misc.star: load does not expose universals from other modules" {
  let errs = run_star_string(misc_load_universals_src)
  assert_true(errs.length() > 0 && errs.any(fn(e) { e.contains("len") }))
}

///|
let misc_plus_folding_src : String =
  #|load('assert.star', 'assert')
  #|
  #|s = "s"
  #|l = [4]
  #|t = (4,)
  #|
  #|assert.eq("a" + "b" + "c", "abc")
  #|assert.eq("a" + "b" + s + "c", "absc")
  #|assert.eq(() + (1,) + (2, 3), (1, 2, 3))
  #|assert.eq(() + (1,) + t + (2, 3), (1, 4, 2, 3))
  #|assert.eq([] + [1] + [2, 3], [1, 2, 3])
  #|assert.eq([] + [1] + l + [2, 3], [1, 4, 2, 3])
  #|
  #|assert.fails(lambda: "a" + "b" + 1 + "c", "unknown binary op: string")
  #|assert.fails(lambda: () + () + 1 + (), "unknown binary op: tuple")
  #|assert.fails(lambda: [] + [] + 1 + [], "unknown binary op: list")

///|
test "misc.star: plus folding with strings, lists, tuples" {
  let errs = run_star_string(misc_plus_folding_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let misc_error_positions_chunked : String =
  #|_ = {}.get(1, default=2) ### "get: unexpected keyword arguments"
  #|---
  #|load('assert.star', 'assert', 'matches') ### "matches not found in module"
  #|---
  #|load('assert.star', 'len') ### "len not found in module"

///|
test "misc.star: error position regression and load errors (chunked)" {
  let failures = run_chunked_string(misc_error_positions_chunked)
  if failures.length() != 0 {
    fail(failures.join("\n"))
  }
}

///|
let misc_load_did_you_mean_chunked : String =
  #|load('assert.star', 'froze') ### "froze not found.*did you mean freeze"

///|
test "misc.star: load error suggests spelling correction (did you mean)" {
  let failures = run_chunked_string(misc_load_did_you_mean_chunked)
  if failures.length() != 0 {
    fail(failures.join("\n"))
  }
}

///|
let misc_cycle_str_src : String =
  #|load("assert.star", "assert")
  #|cyclic = [1, 2, 3]
  #|cyclic[1] = cyclic
  #|assert.eq(str(cyclic), "[1, [...], 3]")
  #|cyclic3 = [1, [2, 3]]
  #|cyclic3[1][0] = cyclic3
  #|assert.eq(str(cyclic3), "[1, [[...], 3]]")
  #|cyclic4 = {"x": 1}
  #|cyclic4["x"] = cyclic4
  #|assert.eq(str(cyclic4), "{\"x\": {...}}")
  #|cyclic5 = [0, {"x": 1}]
  #|cyclic5[1]["x"] = cyclic5
  #|assert.eq(str(cyclic5), "[0, {\"x\": [...]}]")

///|
test "misc.star: cyclic data structures render with ellipsis in str/repr" {
  let errs = run_star_string(misc_cycle_str_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let misc_cycle_eq_chunked : String =
  #|load("assert.star", "assert")
  #|cyclic = [1, 2, 3]
  #|cyclic[1] = cyclic
  #|assert.fails(lambda: cyclic < cyclic, "maximum recursion")
  #|---
  #|load("assert.star", "assert")
  #|cyclic = [1, 2, 3]
  #|cyclic[1] = cyclic
  #|assert.fails(lambda: cyclic == cyclic, "maximum recursion")
  #|---
  #|load("assert.star", "assert")
  #|cyclic = [1, 2, 3]
  #|cyclic[1] = cyclic
  #|cyclic2 = [1, 2, 3]
  #|cyclic2[1] = cyclic2
  #|assert.fails(lambda: cyclic2 == cyclic, "maximum recursion")
  #|---
  #|load("assert.star", "assert")
  #|cyclic5 = [0, {"x": 1}]
  #|cyclic5[1]["x"] = cyclic5
  #|assert.fails(lambda: cyclic5 == cyclic5, "maximum recursion")

///|
test "misc.star: cyclic data structures raise maximum recursion on equality/comparison" {
  let failures = run_chunked_string(misc_cycle_eq_chunked)
  if failures.length() != 0 {
    fail(failures.join("\n"))
  }
}
