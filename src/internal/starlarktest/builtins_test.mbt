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
  #|assert.fails(lambda: fail("msg", x=1), "unexpected keyword argument x")
  #|assert.fails(lambda: fail("msg", sep=1), "for parameter sep: got int, want string")

///|
test "builtins.star: all assertions pass" {
  let errs = run_star_string(builtins_star_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let getattr_hasattr_argerr_src : String =
  #|load("assert.star", "assert")
  #|# arity: getattr accepts 2..3 positional args, hasattr exactly 2
  #|assert.fails(lambda: getattr(1, "real", 9, 99), "getattr: got 4 arguments, want at most 3")
  #|assert.fails(lambda: getattr(1), "getattr: got 1 arguments, want at least 2")
  #|assert.fails(lambda: hasattr(1, "a", "b"), "hasattr: got 3 arguments, want 2")
  #|assert.fails(lambda: hasattr(1), "hasattr: got 1 arguments, want 2")
  #|# attribute name must be a string
  #|assert.fails(lambda: getattr(1, 2), "getattr: for parameter 2: got int, want string")
  #|assert.fails(lambda: hasattr(1, 2), "hasattr: for parameter 2: got int, want string")
  #|# keyword arguments are rejected
  #|assert.fails(lambda: getattr(1, "real", default=9), "getattr: unexpected keyword arguments")
  #|assert.fails(lambda: hasattr([], "append", x=1), "hasattr: unexpected keyword arguments")

///|
test "getattr/hasattr validate arity and argument types" {
  let errs = run_star_string(getattr_hasattr_argerr_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let len_type_errors_src : String =
  #|load("assert.star", "assert")
  #|assert.fails(lambda: len(1), "len: value of type int has no len")
  #|assert.fails(lambda: len(True), "len: value of type bool has no len")
  #|assert.fails(lambda: len(None), "len: value of type NoneType has no len")
  #|assert.fails(lambda: len(b"abc".elems()), "len: value of type bytes.elems has no len")
  #|assert.fails(lambda: len("ab".codepoints()), "len: value of type string.codepoints has no len")

///|
test "len() rejects non-sized values with the starlark-go message" {
  let errs = run_star_string(len_type_errors_src)
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

///|
let abs_bigint_src : String =
  #|load("assert.star", "assert")
  #|# abs() on BigInt values (builtins.star lines 32-34)
  #|maxint32 = (1 << 31) - 1
  #|assert.eq(abs(+123 * maxint32), +123 * maxint32)
  #|assert.eq(abs(-123 * maxint32), +123 * maxint32)

///|
test "builtins.star: abs() on BigInt values" {
  let errs = run_star_string(abs_bigint_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let enumerate_range_argcheck_src : String =
  #|load("assert.star", "assert")
  #|assert.fails(lambda: enumerate([1, 2], "x"), "enumerate: for parameter 2: got string, want int")
  #|assert.fails(lambda: enumerate([1], 0, 9), "enumerate: got 3 arguments, want at most 2")
  #|assert.fails(lambda: enumerate([1], start=0), "enumerate: unexpected keyword arguments")
  #|assert.fails(lambda: range("x"), "range: for parameter 1: got string, want int")
  #|assert.fails(lambda: range(1, "x"), "range: for parameter 2: got string, want int")
  #|assert.fails(lambda: range(1, 2, "x"), "range: for parameter 3: got string, want int")
  #|# valid usage still works
  #|assert.eq(list(range(3)), [0, 1, 2])
  #|assert.eq(enumerate([7, 8], 5), [(5, 7), (6, 8)])

///|
test "enumerate/range validate argument types and arity" {
  let errs = run_star_string(enumerate_range_argcheck_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let builtin_kwarg_rejection_src : String =
  #|load("assert.star", "assert")
  #|assert.fails(lambda: bytes("x", k=1), "bytes does not accept keyword arguments")
  #|assert.fails(lambda: chr(65, k=1), "chr does not accept keyword arguments")
  #|assert.fails(lambda: abs(-1, k=1), "abs: unexpected keyword arguments")
  #|assert.fails(lambda: hash("x", k=1), "hash: unexpected keyword arguments")

///|
test "bytes/abs/chr/hash reject keyword arguments" {
  let errs = run_star_string(builtin_kwarg_rejection_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let nameerr_messages_src : String =
  #|load("assert.star", "assert")
  #|assert.fails(lambda: min([]), "min: argument is an empty sequence")
  #|assert.fails(lambda: max([]), "max: argument is an empty sequence")
  #|assert.fails(lambda: min(1), "min: int value is not iterable")
  #|assert.fails(lambda: [1, 2].index(9), "index: value not in list")
  #|assert.fails(lambda: getattr(1, "nope"), "getattr: int has no .nope field or method")
  #|assert.fails(lambda: float([]), "float got list, want number or string")
  #|assert.fails(lambda: "123".startswith((1, 2)), "startswith: want string, got int, for element 0")
  #|assert.fails(lambda: "123".endswith(["3"]), "endswith: got list, want string or tuple of string")

///|
test "builtin/method error messages use nameErr prefix" {
  let errs = run_star_string(nameerr_messages_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let sorted_stability_src : String =
  #|load("assert.star", "assert")
  #|pairs = [(1, "a"), (1, "b"), (0, "c"), (1, "d"), (0, "e")]
  #|by_key = sorted(pairs, key=lambda p: p[0])
  #|assert.eq(by_key, [(0, "c"), (0, "e"), (1, "a"), (1, "b"), (1, "d")])
  #|rev = sorted(pairs, key=lambda p: p[0], reverse=True)
  #|assert.eq(rev, [(1, "a"), (1, "b"), (1, "d"), (0, "c"), (0, "e")])

///|
test "sorted is stable for equal keys including reverse" {
  let errs = run_star_string(sorted_stability_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

// --- Functions and builtins are usable as dict/set keys ---

///|
let hash_functions_src : String =
  #|load("assert.star", "assert")
  #|# Builtins can be used as dict keys (hashed by name)
  #|d = {len: "found"}
  #|assert.eq(d[len], "found")
  #|# User-defined functions can be used as dict keys
  #|def f(): pass
  #|d2 = {f: 42}
  #|assert.eq(d2[f], 42)
  #|# Builtins can be used in sets
  #|s = {len, abs}
  #|assert.true(len in s)
  #|assert.true(abs in s)

///|
test "functions and builtins are usable as dict and set keys" {
  let errs = run_star_string(hash_functions_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

// --- Float in range truncates toward zero ---

///|
let float_in_range_src : String =
  #|load("assert.star", "assert")
  #|# NumberToInt truncates toward zero, so 3.7 -> 3, and 3 in range(5) -> True
  #|assert.true(3.0 in range(5))
  #|assert.true(3.7 in range(5))
  #|assert.true(-1.9 in range(-5, 0))
  #|assert.true(not (5.0 in range(5)))
  #|assert.true(not (5.9 in range(5)))
  #|# NaN and Inf raise errors (NumberToInt fails)
  #|assert.fails(lambda: float("nan") in range(5), "requires integer")
  #|assert.fails(lambda: float("inf") in range(5), "requires integer")

///|
test "float in range truncates toward zero" {
  let errs = run_star_string(float_in_range_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

// --- Builtins reject keyword arguments ---

///|
let kwarg_rejection_src : String =
  #|load("assert.star", "assert")
  #|assert.fails(lambda: list([1, 2], foo=3), "list: unexpected keyword arguments")
  #|assert.fails(lambda: tuple([1], foo=3), "tuple: unexpected keyword arguments")
  #|assert.fails(lambda: set([1], foo=3), "set: unexpected keyword arguments")
  #|assert.fails(lambda: reversed([1], foo=3), "reversed: unexpected keyword arguments")
  #|assert.fails(lambda: zip([1], foo=3), "zip does not accept keyword arguments")
  #|assert.fails(lambda: any([True], foo=3), "any: unexpected keyword arguments")
  #|assert.fails(lambda: all([True], foo=3), "all: unexpected keyword arguments")
  #|assert.fails(lambda: bool(1, foo=3), "bool: unexpected keyword arguments")
  #|assert.fails(lambda: type(1, foo=3), "type does not accept keyword arguments")
  #|assert.fails(lambda: len([1], foo=3), "len: unexpected keyword arguments")
  #|assert.fails(lambda: repr(1, foo=3), "repr: unexpected keyword arguments")

///|
test "builtins reject keyword arguments" {
  let errs = run_star_string(kwarg_rejection_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

// --- str() with zero arguments errors ---

///|
let str_zero_args_src : String =
  #|load("assert.star", "assert")
  #|assert.fails(lambda: str(), "str.*got 0 arguments")

///|
test "str() with zero arguments raises error" {
  let errs = run_star_string(str_zero_args_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

// --- string.index / rindex error prefix ---

///|
let index_prefix_src : String =
  #|load("assert.star", "assert")
  #|assert.fails(lambda: "abc".index("x"), "index: substring not found")
  #|assert.fails(lambda: "abc".rindex("x"), "rindex: substring not found")

///|
test "string.index and rindex not-found error has method name prefix" {
  let errs = run_star_string(index_prefix_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "max: non-callable key raises error before iteration" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|assert.fails(lambda: max(1, 2, key="x"), "max: for parameter key: got string, want callable")
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "min: non-callable key raises error before iteration" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|assert.fails(lambda: min(1, 2, key=3), "min: for parameter key: got int, want callable")
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "sorted: non-callable key raises error before iteration" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|assert.fails(lambda: sorted([1, 2], key="x"), "sorted: for parameter key: got string, want callable")
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "print: non-string sep raises type error" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|assert.fails(lambda: print(1, 2, sep=3), 'print: for parameter "sep": got int, want string')
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "print: unknown keyword argument raises error" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|assert.fails(lambda: print(1, end="\n"), 'print: unexpected keyword argument "end"')
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}
