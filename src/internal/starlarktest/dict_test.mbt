// Integration tests derived from dict.star.
// dict | dict union operator and dict |= in-place union are included.
// Chunked error-annotation tests ("### error") are inlined as assert.fails.
// hasfields-based tests are omitted.

///|
let dict_star_src : String =
  #|load("assert.star", "assert", "freeze")
  #|
  #|# literals
  #|assert.eq({}, {})
  #|assert.eq({"a": 1}, {"a": 1})
  #|assert.eq({"a": 1,}, {"a": 1})
  #|
  #|# truth
  #|assert.true({False: False})
  #|assert.true(not {})
  #|
  #|# dict + dict is not supported
  #|assert.fails(lambda: {"a": 1} + {"b": 2}, "unknown binary op")
  #|
  #|# dict comprehension
  #|assert.eq({x: x*x for x in range(3)}, {0: 0, 1: 1, 2: 4})
  #|
  #|# dict.pop
  #|x6 = {"a": 1, "b": 2}
  #|assert.eq(x6.pop("a"), 1)
  #|assert.eq(str(x6), '{"b": 2}')
  #|assert.fails(lambda: x6.pop("c"), "pop: missing key")
  #|assert.eq(x6.pop("c", 3), 3)
  #|assert.eq(x6.pop("c", None), None)
  #|assert.eq(x6.pop("b"), 2)
  #|assert.eq(len(x6), 0)
  #|
  #|# dict.popitem
  #|x7 = {"a": 1, "b": 2}
  #|assert.eq([x7.popitem(), x7.popitem()], [("a", 1), ("b", 2)])
  #|assert.fails(x7.popitem, "empty dict")
  #|assert.eq(len(x7), 0)
  #|
  #|# dict.keys, dict.values
  #|x8 = {"a": 1, "b": 2}
  #|assert.eq(x8.keys(), ["a", "b"])
  #|assert.eq(x8.values(), [1, 2])
  #|
  #|# equality (order-independent)
  #|assert.eq({"a": 1, "b": 2}, {"a": 1, "b": 2})
  #|assert.eq({"a": 1, "b": 2,}, {"a": 1, "b": 2})
  #|assert.eq({"a": 1, "b": 2}, {"b": 2, "a": 1})
  #|
  #|# insertion order is preserved
  #|assert.eq(dict([("a", 0), ("b", 1), ("c", 2), ("b", 3)]).keys(), ["a", "b", "c"])
  #|assert.eq(dict([("b", 0), ("a", 1), ("b", 2), ("c", 3)]).keys(), ["b", "a", "c"])
  #|assert.eq(dict([("b", 0), ("a", 1), ("b", 2), ("c", 3)])["b"], 2)
  #|small = dict([("a", 0), ("b", 1), ("c", 2)])
  #|small.update([("d", 4), ("e", 5), ("f", 6), ("g", 7), ("h", 8), ("i", 9), ("j", 10), ("k", 11)])
  #|assert.eq(small.keys(), ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k"])
  #|
  #|# duplicate keys are not permitted in dict expressions
  #|assert.fails(lambda: {"aa": 1, "bb": 2, "cc": 3, "bb": 4}, "duplicate key")
  #|
  #|# duplicate keyword args
  #|assert.fails(lambda: dict({'b': 3}, a=4, **dict(a=5)), "duplicate keyword arg")
  #|assert.fails(lambda: dict({'a': 2, 'b': 3}, a=4, **dict(a=5)), "duplicate keyword arg")
  #|assert.eq(dict((['a', 2], ), a=4), {'a': 4})
  #|assert.eq(dict((['a', 2], ['a', 3]), a=4), {'a': 4})
  #|
  #|# index
  #|def setIndex(d, k, v):
  #|  d[k] = v
  #|
  #|x9 = {}
  #|assert.fails(lambda: x9["a"], "not in dict")
  #|x9["a"] = 1
  #|assert.eq(x9["a"], 1)
  #|assert.eq(x9, {"a": 1})
  #|assert.fails(lambda: setIndex(x9, [], 2), "unhashable type: list")
  #|freeze(x9)
  #|assert.fails(lambda: setIndex(x9, "a", 3), "cannot insert into frozen hash table")
  #|
  #|# tuple key via unparenthesized tuple
  #|x9a = {}
  #|x9a[1, 2] = 3
  #|assert.eq(x9a.keys()[0], (1, 2))
  #|
  #|# dict.get
  #|x10 = {"a": 1}
  #|assert.eq(x10.get("a"), 1)
  #|assert.eq(x10.get("b"), None)
  #|assert.eq(x10.get("a", 2), 1)
  #|assert.eq(x10.get("b", 2), 2)
  #|
  #|# dict.clear
  #|x11 = {"a": 1}
  #|assert.contains(x11, "a")
  #|assert.eq(x11["a"], 1)
  #|x11.clear()
  #|assert.fails(lambda: x11["a"], "not in dict")
  #|assert.true("a" not in x11)
  #|freeze(x11)
  #|assert.fails(x11.clear, "cannot clear frozen hash table")
  #|
  #|# dict.setdefault
  #|x12 = {"a": 1}
  #|assert.eq(x12.setdefault("a"), 1)
  #|assert.eq(x12["a"], 1)
  #|assert.eq(x12.setdefault("b"), None)
  #|assert.eq(x12["b"], None)
  #|assert.eq(x12.setdefault("c", 2), 2)
  #|assert.eq(x12["c"], 2)
  #|assert.eq(x12.setdefault("c", 3), 2)
  #|assert.eq(x12["c"], 2)
  #|freeze(x12)
  #|assert.eq(x12.setdefault("a", 1), 1)
  #|assert.fails(lambda: x12.setdefault("d", 1), "cannot insert into frozen hash table")
  #|
  #|# dict.update
  #|x13 = {"a": 1}
  #|x13.update(a=2, b=3)
  #|assert.eq(x13, {"a": 2, "b": 3})
  #|x13.update([("b", 4), ("c", 5)])
  #|assert.eq(x13, {"a": 2, "b": 4, "c": 5})
  #|x13.update({"c": 6, "d": 7})
  #|assert.eq(x13, {"a": 2, "b": 4, "c": 6, "d": 7})
  #|freeze(x13)
  #|assert.fails(lambda: x13.update({"a": 8}), "cannot insert into frozen hash table")
  #|
  #|# dict as a sequence (for loop)
  #|x14 = {1:2, 3:4}
  #|def keys(d):
  #|  ks = []
  #|  for k in d: ks.append(k)
  #|  return ks
  #|assert.eq(keys(x14), [1, 3])
  #|assert.eq([x for x in x14], [1, 3])
  #|
  #|# varargs with dict
  #|def varargs(*args): return args
  #|x15 = {"one": 1}
  #|assert.eq(varargs(*x15), ("one",))
  #|
  #|# kwargs parameter does not alias the **kwargs dict
  #|def kwargs(**kw): return kw
  #|x16 = kwargs(**x15)
  #|assert.eq(x16, x15)
  #|x15["two"] = 2
  #|assert.ne(x16, x15)
  #|
  #|# iterator invalidation
  #|def iterator1():
  #|  d = {1:1, 2:1}
  #|  for k in d:
  #|    d[2*k] = d[k]
  #|assert.fails(iterator1, "during iteration")
  #|
  #|def iterator2():
  #|  d = {1:1, 2:1}
  #|  for k in d:
  #|    d.pop(k)
  #|assert.fails(iterator2, "during iteration")
  #|
  #|def iterator3():
  #|  def f(d):
  #|    d[3] = 3
  #|  d = {1:1, 2:1}
  #|  _ = [f(d) for x in d]
  #|assert.fails(iterator3, "during iteration")
  #|
  #|# assignment during iteration is not modification-during-iteration
  #|def f():
  #|  x = {1:2, 2:4}
  #|  a, x[0] = x
  #|  assert.eq(a, 1)
  #|  assert.eq(x, {1: 2, 2: 4, 0: 2})
  #|f()
  #|
  #|# regression: hashtable.delete correctness
  #|def test_delete():
  #|  d = {}
  #|  d["one"] = 1
  #|  d["two"] = 2
  #|  assert.eq(str(d), '{"one": 1, "two": 2}')
  #|  d.pop("two")
  #|  assert.eq(str(d), '{"one": 1}')
  #|  d.pop("one")
  #|  assert.eq(str(d), '{}')
  #|  d["one"] = 1
  #|  d["two"] = 2
  #|  d.pop("one")
  #|  assert.eq(str(d), '{"two": 2}')
  #|  d.pop("two")
  #|  assert.eq(str(d), '{}')
  #|  d["one"] = 1
  #|  d["two"] = 2
  #|  d["three"] = 3
  #|  assert.eq(str(d), '{"one": 1, "two": 2, "three": 3}')
  #|  d.pop("two")
  #|  assert.eq(str(d), '{"one": 1, "three": 3}')
  #|  d.pop("three")
  #|  assert.eq(str(d), '{"one": 1}')
  #|  d.pop("one")
  #|  assert.eq(str(d), '{}')
  #|test_delete()
  #|
  #|# unhashable key in dict literal
  #|assert.fails(lambda: {["two"]: 2}, "unhashable type: list")
  #|
  #|# unhashable key in dict comprehension
  #|assert.fails(lambda: {k: v for k, v in [("one", 1), (["two"], 2)]}, "unhashable type: list")
  #|
  #|# dict None arg errors
  #|assert.fails(lambda: dict(None), "want iterable")
  #|assert.fails(lambda: {}.update(None), "want iterable")

///|
test "dict.star: all assertions pass" {
  let errs = run_star_string(dict_star_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let dict_union_src : String =
  #|load("assert.star", "assert", "freeze")
  #|
  #|# dict | dict (union)
  #|empty_dict = dict()
  #|dict_with_a_b = dict(a=1, b=[1, 2])
  #|dict_with_b = dict(b=[1, 2])
  #|dict_with_other_b = dict(b=[3, 4])
  #|
  #|assert.eq(empty_dict | dict_with_a_b, dict_with_a_b)
  #|assert.eq((empty_dict | dict_with_a_b).items(), dict_with_a_b.items())
  #|assert.eq(dict_with_a_b | empty_dict, dict_with_a_b)
  #|assert.eq((dict_with_a_b | empty_dict).items(), dict_with_a_b.items())
  #|assert.eq(dict_with_b | dict_with_a_b, dict_with_a_b)
  #|assert.eq(dict_with_a_b | dict_with_b, dict_with_a_b)
  #|assert.eq(dict_with_b | dict_with_other_b, dict_with_other_b)
  #|assert.eq(dict_with_other_b | dict_with_b, dict_with_b)
  #|
  #|assert.eq(empty_dict, dict())
  #|assert.eq(dict_with_b, dict(b=[1,2]))
  #|
  #|assert.fails(lambda: dict() | [], "unknown binary op: dict | list")
  #|
  #|# dict |= dict (in-place union)
  #|def test_dict_union_assignment():
  #|    x = dict()
  #|    saved = x
  #|    x |= {"a": 1}
  #|    x |= {"b": 2}
  #|    x |= {"c": "3", 7: 4}
  #|    x |= {"b": "5", "e": 6}
  #|    want = {"a": 1, "b": "5", "c": "3", 7: 4, "e": 6}
  #|    assert.eq(x, want)
  #|    assert.eq(x.items(), want.items())
  #|    assert.eq(saved, x)
  #|
  #|    a = {8: 1, "b": 2}
  #|    b = {"b": 1, "c": 6}
  #|    c = {"d": 7}
  #|    d = {(5, "a"): ("c", 8)}
  #|    orig_a, orig_c = a, c
  #|    a |= b
  #|    c |= a
  #|    c |= d
  #|    expected_2 = {"d": 7, 8: 1, "b": 1, "c": 6, (5, "a"): ("c", 8)}
  #|    assert.eq(c, expected_2)
  #|    assert.eq(b, {"b": 1, "c": 6})
  #|    assert.eq(a, orig_a)
  #|    assert.eq(c, orig_c)
  #|    a.clear()
  #|    c.clear()
  #|    assert.eq(a, orig_a)
  #|    assert.eq(c, orig_c)
  #|
  #|test_dict_union_assignment()
  #|
  #|def dict_union_assignment_type_mismatch():
  #|    some_dict = dict()
  #|    some_dict |= []
  #|
  #|assert.fails(dict_union_assignment_type_mismatch, "unknown binary op: dict | list")

///|
test "dict.star: dict union (|) and in-place union (|=) assertions pass" {
  let errs = run_star_string(dict_union_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let dict_error_positions_chunked : String =
  #|_ = {
  #|    "one": 1,
  #|    ["two"]: 2, ### "unhashable type: list"
  #|    "three": 3,
  #|}
  #|---
  #|_ = {
  #|    "one": 1,
  #|    "one": 1, ### `duplicate key: "one"`
  #|    "three": 3,
  #|}
  #|---
  #|_ = {
  #|    k: v ### "unhashable type: list"
  #|    for k, v in [
  #|        ("one", 1),
  #|        (["two"], 2),
  #|        ("three", 3),
  #|    ]
  #|}

///|
test "dict.star: unhashable key and duplicate key error positions (chunked)" {
  let failures = run_chunked_string(dict_error_positions_chunked)
  if failures.length() != 0 {
    fail(failures.join("\n"))
  }
}

///|
let dict_update_argcheck_src : String =
  #|load("assert.star", "assert")
  #|assert.fails(lambda: {}.update({}, {}), "update: got 2 arguments, want at most 1")
  #|assert.fails(lambda: {}.update([(1, 2, 3)]), "update: dictionary update sequence element #0 has length 3, want 2")
  #|assert.fails(lambda: {}.update([1]), "update: dictionary update sequence element #0 is not iterable")
  #|assert.fails(lambda: {}.update(5), "update: got int, want iterable")
  #|# valid usage still works
  #|d = {}
  #|d.update([(1, 2)], x=3)
  #|assert.eq(d, {1: 2, "x": 3})

///|
test "dict.update rejects excess args and reports bad pairs" {
  let errs = run_star_string(dict_update_argcheck_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}
