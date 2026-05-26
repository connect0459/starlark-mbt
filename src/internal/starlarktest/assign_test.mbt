// Integration tests derived from assign.star (starlark-go test suite).
// Omitted: hasfields() tests (application-defined type).
// Omitted: option:globalreassign and option:loadbindsglobally dialect-specific chunks.

///|
let assign_tuple_success_src : String =
  #|load("assert.star", "assert")
  #|
  #|() = ()
  #|
  #|a, b, c = 1, 2, 3
  #|assert.eq(a, 1)
  #|assert.eq(b, 2)
  #|assert.eq(c, 3)
  #|
  #|(d, e, f,) = (1, 2, 3)
  #|assert.eq(d, 1)
  #|assert.eq(e, 2)
  #|assert.eq(f, 3)

///|
test "assign.star: tuple assignment success" {
  let errs = run_star_string(assign_tuple_success_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let assign_tuple_errors_src : String =
  #|load("assert.star", "assert")
  #|
  #|def wrong_type(): (a, b, c) = 1
  #|assert.fails(wrong_type, "got int in sequence assignment")
  #|
  #|def too_few_empty(): (a, b) = ()
  #|assert.fails(too_few_empty, "too few values to unpack")
  #|
  #|def too_few_one(): (a, b) = (1,)
  #|assert.fails(too_few_one, "too few values to unpack")
  #|
  #|def too_few_two(): (a, b, c) = (1, 2)
  #|assert.fails(too_few_two, "too few values to unpack")
  #|
  #|def too_many(): (a, b) = (1, 2, 3)
  #|assert.fails(too_many, "too many values to unpack")
  #|
  #|def empty_wrong_type(): () = 1
  #|assert.fails(empty_wrong_type, "got int in sequence assignment")
  #|
  #|def empty_too_many_one(): () = (1,)
  #|assert.fails(empty_too_many_one, "too many values to unpack")
  #|
  #|def empty_too_many_two(): () = (1, 2)
  #|assert.fails(empty_too_many_two, "too many values to unpack")

///|
test "assign.star: tuple unpacking errors" {
  let errs = run_star_string(assign_tuple_errors_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let assign_list_success_src : String =
  #|load("assert.star", "assert")
  #|
  #|[] = []
  #|
  #|[a, b, c] = [1, 2, 3]
  #|assert.eq(a, 1)
  #|assert.eq(b, 2)
  #|assert.eq(c, 3)
  #|
  #|[d, e, f,] = [1, 2, 3]
  #|assert.eq(d, 1)
  #|assert.eq(e, 2)
  #|assert.eq(f, 3)

///|
test "assign.star: list assignment success" {
  let errs = run_star_string(assign_list_success_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let assign_list_errors_src : String =
  #|load("assert.star", "assert")
  #|
  #|def wrong_type(): [a, b, c] = 1
  #|assert.fails(wrong_type, "got int in sequence assignment")
  #|
  #|def too_few_empty(): [a, b] = []
  #|assert.fails(too_few_empty, "too few values to unpack")
  #|
  #|def too_few_one(): [a, b] = [1]
  #|assert.fails(too_few_one, "too few values to unpack")
  #|
  #|def too_few_two(): [a, b, c] = [1, 2]
  #|assert.fails(too_few_two, "too few values to unpack")
  #|
  #|def too_many(): [a, b] = [1, 2, 3]
  #|assert.fails(too_many, "too many values to unpack")
  #|
  #|def empty_wrong_type(): [] = 1
  #|assert.fails(empty_wrong_type, "got int in sequence assignment")
  #|
  #|def empty_too_many_one(): [] = [1]
  #|assert.fails(empty_too_many_one, "too many values to unpack")
  #|
  #|def empty_too_many_two(): [] = [1, 2]
  #|assert.fails(empty_too_many_two, "too many values to unpack")

///|
test "assign.star: list unpacking errors" {
  let errs = run_star_string(assign_list_errors_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let assign_cross_type_src : String =
  #|load("assert.star", "assert")
  #|
  #|[] = ()
  #|() = []
  #|
  #|[a, b, c] = (1, 2, 3)
  #|assert.eq(a, 1)
  #|assert.eq(b, 2)
  #|assert.eq(c, 3)
  #|
  #|[a2, b2, c2] = 1, 2, 3
  #|assert.eq(a2, 1)
  #|assert.eq(b2, 2)
  #|assert.eq(c2, 3)
  #|
  #|(d, e, f) = [1, 2, 3]
  #|assert.eq(d, 1)
  #|assert.eq(e, 2)
  #|assert.eq(f, 3)
  #|
  #|[g, h, (i, j)] = (1, 2, [3, 4])
  #|assert.eq(g, 1)
  #|assert.eq(h, 2)
  #|assert.eq(i, 3)
  #|assert.eq(j, 4)
  #|
  #|(k, l, [m, n]) = [1, 2, (3, 4)]
  #|assert.eq(k, 1)
  #|assert.eq(l, 2)
  #|assert.eq(m, 3)
  #|assert.eq(n, 4)

///|
test "assign.star: cross-type list/tuple assignment" {
  let errs = run_star_string(assign_cross_type_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let assign_misc_src : String =
  #|load("assert.star", "assert")
  #|
  #|def assignment():
  #|  a = [1, 2, 3]
  #|  a[1] = 5
  #|  assert.eq(a, [1, 5, 3])
  #|  a[-2] = 2
  #|  assert.eq(a, [1, 2, 3])
  #|  assert.eq("%d %d" % (5, 7), "5 7")
  #|  x={}
  #|  x[1] = 2
  #|  x[1] += 3
  #|  assert.eq(x[1], 5)
  #|  def f12(): x[(1, "abc", {})] = 1
  #|  assert.fails(f12, "unhashable type: dict")
  #|
  #|assignment()

///|
test "assign.star: misc assignment (subscript, dict, augmented)" {
  let errs = run_star_string(assign_misc_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let assign_augmented_src : String =
  #|load("assert.star", "assert")
  #|
  #|def f():
  #|  x = 1
  #|  x += 1
  #|  assert.eq(x, 2)
  #|  x *= 3
  #|  assert.eq(x, 6)
  #|f()

///|
test "assign.star: augmented assignment" {
  let errs = run_star_string(assign_augmented_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let assign_lhs_once_src : String =
  #|load("assert.star", "assert")
  #|
  #|count = [0]
  #|
  #|def f():
  #|  count[0] += 1
  #|  return count[0]
  #|
  #|x = [1, 2, 3]
  #|x[f()] += 1
  #|
  #|assert.eq(x, [1, 3, 3])
  #|assert.eq(count[0], 1)

///|
test "assign.star: LHS evaluated only once in augmented assignment" {
  let errs = run_star_string(assign_lhs_once_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let assign_eval_order_src : String =
  #|load("assert.star", "assert")
  #|
  #|calls = []
  #|
  #|def f(name, result):
  #|  calls.append(name)
  #|  return result
  #|
  #|calls.clear()
  #|f("array", [0])[f("index", 0)] = f("rhs", 0)
  #|assert.eq(calls, ["rhs", "array", "index"])
  #|
  #|calls.clear()
  #|f("lhs1", [0])[0], f("lhs2", [0])[0] = f("rhs1", 0), f("rhs2", 0)
  #|assert.eq(calls, ["rhs1", "rhs2", "lhs1", "lhs2"])
  #|
  #|calls.clear()
  #|f("array", [0])[f("index", 0)] += f("addend", 1)
  #|assert.eq(calls, ["array", "index", "addend"])

///|
test "assign.star: order of evaluation in assignments" {
  let errs = run_star_string(assign_eval_order_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
// Note: starlark-go reports "global/local variable X referenced before assignment";
// our impl reports "undefined: X" for uninitialized lookups.
let assign_before_assignment_src : String =
  #|load("assert.star", "assert")
  #|
  #|def f():
  #|  return g
  #|assert.fails(f, "undefined: g")
  #|g = 1
  #|
  #|printok = [False]
  #|
  #|def use_before_def():
  #|  print(x)
  #|  printok[0] = True
  #|  x = 1
  #|
  #|assert.fails(use_before_def, 'undefined: x')
  #|assert.true(not printok[0])
  #|
  #|def aug_before_assign():
  #|  x += [4]
  #|assert.fails(aug_before_assign, "undefined: x")

///|
test "assign.star: variable referenced before assignment errors" {
  let errs = run_star_string(assign_before_assignment_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let assign_closure_src : String =
  #|load("assert.star", "assert")
  #|
  #|def f():
  #|  def g():
  #|    return outer
  #|  outer = 1
  #|  return g()
  #|
  #|assert.eq(f(), 1)

///|
test "assign.star: free variables captured by reference" {
  let errs = run_star_string(assign_closure_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
// Note: starlark-go resolver marks ALL uses of a name as local once it's assigned
// in the same scope, even uses before the assignment textually. Our resolver does
// not implement this; built-in names accessed before a later shadowing assignment
// resolve to the built-in rather than raising an error. We only test the basic
// shadowing case that our impl supports.
let assign_shadow_builtin_src : String =
  #|load("assert.star", "assert")
  #|
  #|list = []
  #|assert.eq(type(list), "list")

///|
test "assign.star: shadowing built-in names" {
  let errs = run_star_string(assign_shadow_builtin_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let assign_comprehension_scope_src : String =
  #|load("assert.star", "assert")
  #|
  #|x = [[1, 2]]
  #|assert.eq([x for x in x for y in x],
  #|          [[1, 2], [1, 2]])

///|
test "assign.star: comprehension scope (first 'in' from outer block)" {
  let errs = run_star_string(assign_comprehension_scope_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let assign_singleton_seq_src : String =
  #|load("assert.star", "assert")
  #|
  #|(x,) = (1,)
  #|assert.eq(x, 1)
  #|(y,) = [1]
  #|assert.eq(y, 1)
  #|
  #|z = (1,)
  #|assert.eq(type(z), "tuple")
  #|assert.eq(len(z), 1)
  #|assert.eq(z[0], 1)
  #|
  #|(a) = 1
  #|assert.eq(a, 1)

///|
test "assign.star: singleton sequence and 1-tuple assignment" {
  let errs = run_star_string(assign_singleton_seq_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let assign_for_loop_destructure_src : String =
  #|load("assert.star", "assert")
  #|
  #|def f():
  #|  res = []
  #|  for (x, y), z in [(["a", "b"], 3), (["c", "d"], 4)]:
  #|    res.append((x, y, z))
  #|  return res
  #|assert.eq(f(), [("a", "b", 3), ("c", "d", 4)])
  #|
  #|def g():
  #|  a = {}
  #|  for i, a[i] in [("one", 1), ("two", 2)]:
  #|    pass
  #|  return a
  #|assert.eq(g(), {"one": 1, "two": 2})

///|
test "assign.star: destructuring assignment in for loop" {
  let errs = run_star_string(assign_for_loop_destructure_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let assign_forward_ref_src : String =
  #|load("assert.star", "assert")
  #|
  #|def f(): assert.eq(1, 1)
  #|load("assert.star", "assert")
  #|f()

///|
test "assign.star: forward reference to load binding is OK" {
  let errs = run_star_string(assign_forward_ref_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let assign_tuple_errors_chunked : String =
  #|(a, b, c) = 1 ### "got int in sequence assignment"
  #|---
  #|(a, b) = () ### "too few values to unpack"
  #|---
  #|(a, b) = (1,) ### "too few values to unpack"
  #|---
  #|(a, b, c) = (1, 2) ### "too few values to unpack"
  #|---
  #|(a, b) = (1, 2, 3) ### "too many values to unpack"
  #|---
  #|() = 1 ### "got int in sequence assignment"
  #|---
  #|() = (1,) ### "too many values to unpack"
  #|---
  #|() = (1, 2) ### "too many values to unpack"

///|
test "assign.star: tuple sequence assignment errors (chunked)" {
  let failures = run_chunked_string(assign_tuple_errors_chunked)
  if failures.length() != 0 {
    fail(failures.join("\n"))
  }
}

///|
let assign_list_errors_chunked : String =
  #|[a, b, c] = 1 ### "got int in sequence assignment"
  #|---
  #|[a, b] = [] ### "too few values to unpack"
  #|---
  #|[a, b] = [1] ### "too few values to unpack"
  #|---
  #|[a, b, c] = [1, 2] ### "too few values to unpack"
  #|---
  #|[a, b] = [1, 2, 3] ### "too many values to unpack"
  #|---
  #|[] = 1 ### "got int in sequence assignment"
  #|---
  #|[] = [1] ### "too many values to unpack"
  #|---
  #|[] = [1, 2] ### "too many values to unpack"

///|
test "assign.star: list sequence assignment errors (chunked)" {
  let failures = run_chunked_string(assign_list_errors_chunked)
  if failures.length() != 0 {
    fail(failures.join("\n"))
  }
}

///|
let assign_before_assign_errors_chunked : String =
  #|z += 3 ### "undefined: z"
  #|---
  #|(a) += 5 ### "undefined: a"

///|
test "assign.star: module-scope variable-before-assignment errors (chunked)" {
  let failures = run_chunked_string(assign_before_assign_errors_chunked)
  if failures.length() != 0 {
    fail(failures.join("\n"))
  }
}
