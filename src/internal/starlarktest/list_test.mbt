// Integration tests derived from list.star.
// Error patterns simplified to substrings; regex-style patterns are not supported.
// f7 (hasfields) is omitted: hasfields() is a test-only type not in the standard built-ins.
// Error message differences are noted inline.

///|
let list_star_src : String =
  #|load("assert.star", "assert", "freeze")
  #|
  #|# literals
  #|assert.eq([], [])
  #|assert.eq([1], [1])
  #|assert.eq([1, 2], [1, 2])
  #|assert.ne([1, 2, 3], [1, 2, 4])
  #|
  #|# truth
  #|assert.true([0])
  #|assert.true(not [])
  #|
  #|# indexing, x[i]
  #|abc = list("abc".elems())
  #|assert.fails(lambda: abc[-4], "out of range")
  #|assert.eq(abc[-3], "a")
  #|assert.eq(abc[-2], "b")
  #|assert.eq(abc[-1], "c")
  #|assert.eq(abc[0], "a")
  #|assert.eq(abc[1], "b")
  #|assert.eq(abc[2], "c")
  #|assert.fails(lambda: abc[3], "out of range")
  #|
  #|# x[i] = ...
  #|x3 = [0, 1, 2]
  #|x3[1] = 2
  #|x3[2] += 3
  #|assert.eq(x3, [0, 2, 5])
  #|
  #|def f2():
  #|    x3[3] = 4
  #|
  #|assert.fails(f2, "out of range")
  #|freeze(x3)
  #|
  #|def f3():
  #|    x3[0] = 0
  #|
  #|assert.fails(f3, "cannot assign to element of")
  #|assert.fails(x3.clear, "cannot clear frozen list")
  #|
  #|# list + list
  #|assert.eq([1, 2, 3] + [3, 4, 5], [1, 2, 3, 3, 4, 5])
  #|assert.fails(lambda: [1, 2] + (3, 4), "unknown binary op")
  #|assert.fails(lambda: (1, 2) + [3, 4], "unknown binary op")
  #|
  #|# list * int,  int * list
  #|assert.eq(abc * 0, [])
  #|assert.eq(abc * -1, [])
  #|assert.eq(abc * 1, abc)
  #|assert.eq(abc * 3, ["a", "b", "c", "a", "b", "c", "a", "b", "c"])
  #|assert.eq(0 * abc, [])
  #|assert.eq(-1 * abc, [])
  #|assert.eq(1 * abc, abc)
  #|assert.eq(3 * abc, ["a", "b", "c", "a", "b", "c", "a", "b", "c"])
  #|
  #|# list comprehensions
  #|assert.eq([2 * x for x in [1, 2, 3]], [2, 4, 6])
  #|assert.eq([2 * x for x in [1, 2, 3] if x > 1], [4, 6])
  #|assert.eq(
  #|    [(x, y) for x in [1, 2] for y in [3, 4]],
  #|    [(1, 3), (1, 4), (2, 3), (2, 4)],
  #|)
  #|assert.eq([(x, y) for x in [1, 2] if x == 2 for y in [3, 4]], [(2, 3), (2, 4)])
  #|assert.eq([2 * x for x in (1, 2, 3)], [2, 4, 6])
  #|assert.eq([x for x in "abc".elems()], ["a", "b", "c"])
  #|assert.eq([x for x in {"a": 1, "b": 2}], ["a", "b"])
  #|assert.eq([(y, x) for x, y in {1: 2, 3: 4}.items()], [(2, 1), (4, 3)])
  #|
  #|# corner cases of parsing
  #|assert.eq([x for x in range(12) if x % 2 == 0 if x % 3 == 0], [0, 6])
  #|
  #|# list function
  #|assert.eq(list(), [])
  #|assert.eq(list("ab".elems()), ["a", "b"])
  #|
  #|# list comprehension defines a separate lexical block at top-level
  #|a = [1, 2]
  #|b = [a for a in [3, 4]]
  #|assert.eq(a, [1, 2])
  #|assert.eq(b, [3, 4])
  #|
  #|# and local to a function
  #|def listcompblock():
  #|    c = [1, 2]
  #|    d = [c for c in [3, 4]]
  #|    assert.eq(c, [1, 2])
  #|    assert.eq(d, [3, 4])
  #|
  #|listcompblock()
  #|
  #|# list.pop
  #|x4 = [1, 2, 3, 4, 5]
  #|assert.fails(lambda: x4.pop(-6), "out of range")
  #|assert.fails(lambda: x4.pop(6), "out of range")
  #|assert.eq(x4.pop(), 5)
  #|assert.eq(x4, [1, 2, 3, 4])
  #|assert.eq(x4.pop(1), 2)
  #|assert.eq(x4, [1, 3, 4])
  #|assert.eq(x4.pop(0), 1)
  #|assert.eq(x4, [3, 4])
  #|assert.eq(x4.pop(-2), 3)
  #|assert.eq(x4, [4])
  #|assert.eq(x4.pop(-1), 4)
  #|assert.eq(x4, [])
  #|
  #|# x += y for lists is equivalent to x.extend(y) in place
  #|def list_extend():
  #|    a = [1, 2, 3]
  #|    b = a
  #|    a = a + [4]  # creates a new list
  #|    assert.eq(a, [1, 2, 3, 4])
  #|    assert.eq(b, [1, 2, 3])  # b is unchanged
  #|
  #|    a = [1, 2, 3]
  #|    b = a
  #|    a += [4]  # updates a (and thus b) in place
  #|    assert.eq(a, [1, 2, 3, 4])
  #|    assert.eq(b, [1, 2, 3, 4])  # alias observes the change
  #|
  #|    a = [1, 2, 3]
  #|    b = a
  #|    a.extend([4])  # updates existing list
  #|    assert.eq(a, [1, 2, 3, 4])
  #|    assert.eq(b, [1, 2, 3, 4])  # alias observes the change
  #|
  #|list_extend()
  #|
  #|# list += <not iterable>
  #|def f5():
  #|    x = []
  #|    x += 1
  #|
  #|assert.fails(f5, "unknown binary op")
  #|
  #|# frozen list += iterable
  #|def f6():
  #|    x = []
  #|    freeze(x)
  #|    x += [1]
  #|
  #|assert.fails(f6, "cannot apply")
  #|
  #|# append
  #|x5 = [1, 2, 3]
  #|x5.append(4)
  #|x5.append("abc")
  #|assert.eq(x5, [1, 2, 3, 4, "abc"])
  #|
  #|# extend
  #|x5a = [1, 2, 3]
  #|x5a.extend("abc".elems())  # string elems
  #|x5a.extend((True, False))  # tuple
  #|assert.eq(x5a, [1, 2, 3, "a", "b", "c", True, False])
  #|
  #|# list.insert
  #|def insert_at(index):
  #|    x = list(range(3))
  #|    x.insert(index, 42)
  #|    return x
  #|
  #|assert.eq(insert_at(-99), [42, 0, 1, 2])
  #|assert.eq(insert_at(-2), [0, 42, 1, 2])
  #|assert.eq(insert_at(-1), [0, 1, 42, 2])
  #|assert.eq(insert_at(0), [42, 0, 1, 2])
  #|assert.eq(insert_at(1), [0, 42, 1, 2])
  #|assert.eq(insert_at(2), [0, 1, 42, 2])
  #|assert.eq(insert_at(3), [0, 1, 2, 42])
  #|assert.eq(insert_at(4), [0, 1, 2, 42])
  #|
  #|# list.remove
  #|def remove(v):
  #|    x = [3, 1, 4, 1]
  #|    x.remove(v)
  #|    return x
  #|
  #|assert.eq(remove(3), [1, 4, 1])
  #|assert.eq(remove(1), [3, 4, 1])
  #|assert.eq(remove(4), [3, 1, 1])
  #|assert.fails(lambda: [3, 1, 4, 1].remove(42), "not found")
  #|
  #|# list.index
  #|bananas = list("bananas".elems())
  #|assert.eq(bananas.index("a"), 1)
  #|assert.fails(lambda: bananas.index("d"), "not in list")
  #|
  #|# with start
  #|assert.eq(bananas.index("a", -1000), 1)
  #|assert.eq(bananas.index("a", 0), 1)
  #|assert.eq(bananas.index("a", 1), 1)
  #|assert.eq(bananas.index("a", 2), 3)
  #|assert.eq(bananas.index("a", 3), 3)
  #|assert.eq(bananas.index("b", 0), 0)
  #|assert.eq(bananas.index("n", -3), 4)
  #|assert.fails(lambda: bananas.index("n", -2), "not in list")
  #|assert.eq(bananas.index("s", -2), 6)
  #|assert.fails(lambda: bananas.index("b", 1), "not in list")
  #|
  #|# with start and end
  #|assert.eq(bananas.index("s", -1000, 7), 6)
  #|assert.fails(lambda: bananas.index("s", -1000, 6), "not in list")
  #|assert.fails(lambda: bananas.index("d", -1000, 1000), "not in list")
  #|
  #|# slicing
  #|assert.eq(bananas[6::-2], list("snnb".elems()))
  #|assert.eq(bananas[5::-2], list("aaa".elems()))
  #|assert.eq(bananas[4::-2], list("nnb".elems()))
  #|assert.eq(bananas[99::-2], list("snnb".elems()))
  #|assert.eq(bananas[100::-2], list("snnb".elems()))
  #|
  #|# iterator invalidation: assignment during for loop
  #|def iterator1():
  #|    lst = [0, 1, 2]
  #|    for x in lst:
  #|        lst[x] = 2 * x
  #|    return lst
  #|
  #|assert.fails(iterator1, "assign to element")
  #|
  #|# iterator invalidation: remove during for loop
  #|def iterator2():
  #|    lst = [0, 1, 2]
  #|    for x in lst:
  #|        lst.remove(x)
  #|
  #|assert.fails(iterator2, "remove")
  #|
  #|# iterator invalidation: append during for loop
  #|def iterator3():
  #|    lst = [0, 1, 2]
  #|    for x in lst:
  #|        lst.append(3)
  #|
  #|assert.fails(iterator3, "append")
  #|
  #|# iterator invalidation: extend during for loop
  #|def iterator4():
  #|    lst = [0, 1, 2]
  #|    for x in lst:
  #|        lst.extend([3, 4])
  #|
  #|assert.fails(iterator4, "extend")
  #|
  #|# iterator invalidation: append inside list comprehension
  #|def iterator5():
  #|    def f(x):
  #|        x.append(4)
  #|
  #|    lst = [1, 2, 3]
  #|    _ = [f(lst) for x in lst]
  #|
  #|assert.fails(iterator5, "append")

///|
test "list.star: all assertions pass" {
  let errs = run_star_string(list_star_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let list_unbound_local_src : String =
  #|load("assert.star", "assert")
  #|
  #|# Unlike list.extend(iterable), list += iterable makes its LHS name local.
  #|a_list = []
  #|
  #|def f4():
  #|    a_list += [1]  # binding use => a_list is a local var
  #|
  #|assert.fails(f4, "local variable a_list referenced before assignment")

///|
test "list augmented-assign to global name raises unbound local error" {
  let errs = run_star_string(list_unbound_local_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "lambda in comprehension if-clause is truthy and filters correctly" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|assert.eq([x for x in [1, 2] if lambda: None], [1, 2])
      #|assert.eq([x for x in [1, 2] if (lambda: 3 if True else 4)], [1, 2])
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "list.extend(self) doubles the list without error" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|xs = [1, 2, 3]
      #|xs.extend(xs)
      #|assert.eq(xs, [1, 2, 3, 1, 2, 3])
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "list += self doubles the list without error" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|xs = [1, 2, 3]
      #|xs += xs
      #|assert.eq(xs, [1, 2, 3, 1, 2, 3])
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "non-integer subscript reports <type> index error like starlark-go" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|assert.fails(lambda: [10, 20, 30][True], "list index: got bool, want int")
      #|assert.fails(lambda: (1, 2)[True], "tuple index: got bool, want int")
      #|assert.fails(lambda: "abc"[True], "string index: got bool, want int")
      #|assert.fails(lambda: b"abc"[1.0], "bytes index: got float, want int")
      #|assert.fails(lambda: range(3)[True], "range index: got bool, want int")
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "non-integer subscript assignment reports got/want int like starlark-go" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|def f():
      #|    xs = [1, 2, 3]
      #|    xs[True] = 9
      #|assert.fails(f, "got bool, want int")
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}
