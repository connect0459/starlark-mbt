// Integration tests derived from builtins.star.
// Excluded: hasfields() tests (application-defined type) and chunked --- sections.

///|
let builtins_star_src : String =
  #|load("assert.star", "assert")
  #|
  #|# len
  #|assert.eq(len([1, 2, 3]), 3)
  #|assert.eq(len((1, 2, 3)), 3)
  #|assert.eq(len({1: 2}), 1)
  #|assert.fails(lambda: len(1), "int.*has no len")
  #|
  #|# and, or
  #|assert.eq(123 or "foo", 123)
  #|assert.eq(0 or "foo", "foo")
  #|assert.eq(123 and "foo", "foo")
  #|assert.eq(0 and "foo", 0)
  #|none = None
  #|_1 = none and none[0]
  #|_2 = (not none) or none[0]
  #|
  #|# abs
  #|assert.eq(abs(2.0), 2.0)
  #|assert.eq(abs(0.0), 0.0)
  #|assert.eq(abs(-2.0), 2.0)
  #|assert.eq(abs(2), 2)
  #|assert.eq(abs(0), 0)
  #|assert.eq(abs(-2), 2)
  #|assert.eq(abs(float("inf")), float("inf"))
  #|assert.eq(abs(float("-inf")), float("inf"))
  #|assert.eq(abs(float("nan")), float("nan"))
  #|assert.fails(lambda: abs("0"), "got string, want int or float")
  #|
  #|# any, all
  #|assert.true(all([]))
  #|assert.true(all([1, True, "foo"]))
  #|assert.true(not all([1, True, ""]))
  #|assert.true(not any([]))
  #|assert.true(any([0, False, "foo"]))
  #|assert.true(not any([0, False, ""]))
  #|
  #|# in
  #|assert.true(3 in [1, 2, 3])
  #|assert.true(4 not in [1, 2, 3])
  #|assert.true(3 in (1, 2, 3))
  #|assert.true(4 not in (1, 2, 3))
  #|assert.fails(lambda: 3 in "foo", "in.*requires string as left operand")
  #|assert.true(123 in {123: ""})
  #|assert.true(456 not in {123:""})
  #|assert.true([] not in {123: ""})
  #|
  #|# sorted
  #|assert.eq(sorted([42, 123, 3]), [3, 42, 123])
  #|assert.eq(sorted([42, 123, 3], reverse=True), [123, 42, 3])
  #|assert.eq(sorted(["wiz", "foo", "bar"]), ["bar", "foo", "wiz"])
  #|assert.eq(sorted(["wiz", "foo", "bar"], reverse=True), ["wiz", "foo", "bar"])
  #|assert.fails(lambda: sorted([1, 2, None, 3]), "not impl")
  #|assert.fails(lambda: sorted([1, "one"]), "not impl")
  #|assert.eq(sorted(["two", "three", "four"], key=len),
  #|          ["two", "four", "three"])
  #|assert.eq(sorted(["two", "three", "four"], key=len, reverse=True),
  #|          ["three", "four", "two"])
  #|assert.fails(lambda: sorted([1, 2, 3], key=None), "got NoneType, want callable")
  #|pairs = [(4, 0), (3, 1), (4, 2), (2, 3), (3, 4), (1, 5), (2, 6), (3, 7)]
  #|assert.eq(sorted(pairs, key=lambda x: x[0]),
  #|          [(1, 5), (2, 3), (2, 6), (3, 1), (3, 4), (3, 7), (4, 0), (4, 2)])
  #|assert.fails(lambda: sorted(1), 'sorted: for parameter iterable: got int, want iterable')
  #|
  #|# reversed
  #|assert.eq(reversed([1, 144, 81, 16]), [16, 81, 144, 1])
  #|
  #|# set
  #|assert.contains(set([1, 2, 3]), 1)
  #|assert.true(4 not in set([1, 2, 3]))
  #|assert.eq(len(set([1, 2, 3])), 3)
  #|assert.eq(sorted([x for x in set([1, 2, 3])]), [1, 2, 3])
  #|
  #|# dict
  #|assert.eq(dict([(1, 2), (3, 4)]), {1: 2, 3: 4})
  #|assert.eq(dict([(1, 2), (3, 4)], foo="bar"), {1: 2, 3: 4, "foo": "bar"})
  #|assert.eq(dict({1:2, 3:4}), {1: 2, 3: 4})
  #|assert.eq(dict({1:2, 3:4}.items()), {1: 2, 3: 4})
  #|
  #|# range
  #|assert.eq("range", type(range(10)))
  #|assert.eq("range(10)", str(range(0, 10, 1)))
  #|assert.eq("range(1, 10)", str(range(1, 10)))
  #|assert.eq(range(0, 5, 10), range(0, 5, 11))
  #|assert.eq("range(0, 10, -1)", str(range(0, 10, -1)))
  #|assert.fails(lambda: {range(10): 10}, "unhashable: range")
  #|assert.true(bool(range(1, 2)))
  #|assert.true(not(range(2, 1)))
  #|assert.eq([x*x for x in range(5)], [0, 1, 4, 9, 16])
  #|assert.eq(list(range(5)), [0, 1, 2, 3, 4])
  #|assert.eq(list(range(-5)), [])
  #|assert.eq(list(range(2, 5)), [2, 3, 4])
  #|assert.eq(list(range(5, 2)), [])
  #|assert.eq(list(range(-2, -5)), [])
  #|assert.eq(list(range(-5, -2)), [-5, -4, -3])
  #|assert.eq(list(range(2, 10, 3)), [2, 5, 8])
  #|assert.eq(list(range(10, 2, -3)), [10, 7, 4])
  #|assert.eq(list(range(-2, -10, -3)), [-2, -5, -8])
  #|assert.eq(list(range(-10, -2, 3)), [-10, -7, -4])
  #|assert.eq(list(range(10, 2, -1)), [10, 9, 8, 7, 6, 5, 4, 3])
  #|assert.eq(list(range(5)[1:]), [1, 2, 3, 4])
  #|assert.eq(len(range(5)[1:]), 4)
  #|assert.eq(list(range(5)[:2]), [0, 1])
  #|assert.eq(list(range(10)[1:]), [1, 2, 3, 4, 5, 6, 7, 8, 9])
  #|assert.eq(list(range(10)[1:9:2]), [1, 3, 5, 7])
  #|assert.eq(list(range(10)[1:10:2]), [1, 3, 5, 7, 9])
  #|assert.eq(list(range(10)[1:11:2]), [1, 3, 5, 7, 9])
  #|assert.eq(list(range(10)[::-2]), [9, 7, 5, 3, 1])
  #|assert.eq(list(range(0, 10, 2)[::2]), [0, 4, 8])
  #|assert.eq(list(range(0, 10, 2)[::-2]), [8, 4, 0])
  #|assert.eq(len(range(0x7fffffff)), 0x7fffffff)
  #|assert.eq(range(0), range(2, 1, 3))
  #|assert.eq(range(0, 3, 2), range(0, 4, 2))
  #|assert.ne(range(1, 10), range(2, 10))
  #|assert.fails(lambda: range(0) < range(0), "range < range not implemented")
  #|assert.contains(range(3), 1)
  #|assert.fails(lambda: True in range(3), "requires integer")
  #|assert.fails(lambda: "one" in range(10), "requires integer")
  #|assert.true(4 not in range(4))
  #|assert.fails(lambda: range(0, 0, 2)[:][0], "index 0 out of range")
  #|assert.fails(lambda: range(1<<64), ".* out of range .*want value in signed .*-bit range")
  #|
  #|# list
  #|assert.eq(list("abc".elems()), ["a", "b", "c"])
  #|assert.eq(sorted(list({"a": 1, "b": 2})), ['a', 'b'])
  #|
  #|# min, max
  #|assert.eq(min(5, -2, 1, 7, 3), -2)
  #|assert.eq(max(5, -2, 1, 7, 3), 7)
  #|assert.eq(min([5, -2, 1, 7, 3]), -2)
  #|assert.eq(min("one", "two", "three", "four"), "four")
  #|assert.eq(max("one", "two", "three", "four"), "two")
  #|assert.fails(min, "min requires at least one positional argument")
  #|assert.fails(lambda: min(1), "not iterable")
  #|assert.fails(lambda: min([]), "empty")
  #|assert.eq(min(5, -2, 1, 7, 3, key=lambda x: x*x), 1)
  #|assert.eq(min(5, -2, 1, 7, 3, key=lambda x: -x), 7)
  #|
  #|# enumerate
  #|assert.eq(enumerate("abc".elems()), [(0, "a"), (1, "b"), (2, "c")])
  #|assert.eq(enumerate([False, True, None], 42), [(42, False), (43, True), (44, None)])
  #|
  #|# zip
  #|assert.eq(zip(), [])
  #|assert.eq(zip([]), [])
  #|assert.eq(zip([1, 2, 3]), [(1,), (2,), (3,)])
  #|assert.eq(zip("".elems()), [])
  #|assert.eq(zip("abc".elems(),
  #|              list("def".elems()),
  #|              "hijk".elems()),
  #|          [("a", "d", "h"), ("b", "e", "i"), ("c", "f", "j")])
  #|z1 = [1]
  #|assert.eq(zip(z1), [(1,)])
  #|z1.append(2)
  #|assert.eq(zip(z1), [(1,), (2,)])
  #|assert.fails(lambda: zip(z1, 1), "zip: argument #2 is not iterable: int")
  #|z1.append(3)
  #|
  #|# dir for builtin_function_or_method
  #|assert.eq(dir(None), [])
  #|assert.eq(dir({})[:3], ["clear", "get", "items"])
  #|assert.eq(dir(1), [])
  #|assert.eq(dir([])[:3], ["append", "clear", "extend"])
  #|
  #|# repr
  #|assert.eq(repr(1), "1")
  #|assert.eq(repr("x"), '"x"')
  #|assert.eq(repr(["x", 1]), '["x", 1]')
  #|
  #|# fail with sep
  #|assert.fails(lambda: fail(1, 2, 3, sep="/"), "1/2/3")

///|
test "builtins.star: all assertions pass" {
  let errs = run_star_string(builtins_star_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let hash_type_errors_src : String =
  #|load("assert.star", "assert")
  #|assert.fails(lambda: hash(True), "hash: got bool, want string or bytes")
  #|assert.fails(lambda: hash(1), "hash: got int, want string or bytes")
  #|assert.fails(lambda: hash(None), "hash: got NoneType, want string or bytes")
  #|assert.fails(lambda: hash((1, 2)), "hash: got tuple, want string or bytes")

///|
test "hash() rejects non-string/bytes types with error" {
  let errs = run_star_string(hash_type_errors_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let builtins_fail_chunked : String =
  #|fail() ### `fail: $`
  #|---
  #|fail(1) ### `fail: 1`
  #|---
  #|fail(1, 2, 3) ### `fail: 1 2 3`
  #|---
  #|fail(1, 2, 3, sep="/") ### `fail: 1/2/3`

///|
test "builtins.star: fail() error messages (chunked)" {
  let failures = run_chunked_string(builtins_fail_chunked)
  if failures.length() != 0 {
    fail(failures.join("\n"))
  }
}
