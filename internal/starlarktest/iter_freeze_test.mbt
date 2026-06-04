// End-to-end tests for iterator mutation safety during for-loop iteration.
// Verifies that mutating a list, dict, or set while iterating over it in a
// for-loop raises an appropriate error, and that mutation is allowed again
// once the loop completes.

///|
let iter_freeze_src : String =
  #|# option:toplevelcontrol option:globalreassign
  #|load("assert.star", "assert")
  #|
  #|# List: appending during for loop raises error
  #|def list_append_in_for():
  #|    xs = [1, 2, 3]
  #|    for x in xs:
  #|        xs.append(4)
  #|assert.fails(list_append_in_for, "cannot append to list during iteration")
  #|
  #|# List: pop during for loop raises error
  #|def list_pop_in_for():
  #|    xs = [1, 2, 3]
  #|    for x in xs:
  #|        xs.pop()
  #|assert.fails(list_pop_in_for, "cannot pop from list during iteration")
  #|
  #|# List: insert during for loop raises error
  #|def list_insert_in_for():
  #|    xs = [1, 2, 3]
  #|    for x in xs:
  #|        xs.insert(0, 0)
  #|assert.fails(list_insert_in_for, "cannot insert into list during iteration")
  #|
  #|# List: remove during for loop raises error
  #|def list_remove_in_for():
  #|    xs = [1, 2, 3]
  #|    for x in xs:
  #|        xs.remove(1)
  #|assert.fails(list_remove_in_for, "cannot remove from list during iteration")
  #|
  #|# List: after loop finishes, mutation is allowed again
  #|xs_after = [1, 2, 3]
  #|for _ in xs_after:
  #|    pass
  #|xs_after.append(4)
  #|assert.eq(xs_after, [1, 2, 3, 4])
  #|
  #|# Dict: insertion during for loop raises error
  #|def dict_insert_in_for():
  #|    d = {"a": 1, "b": 2}
  #|    for k in d:
  #|        d["c"] = 3
  #|assert.fails(dict_insert_in_for, "hash table during iteration")
  #|
  #|# Dict: after loop finishes, mutation is allowed
  #|d_after = {"a": 1}
  #|for _ in d_after:
  #|    pass
  #|d_after["b"] = 2
  #|assert.eq(d_after, {"a": 1, "b": 2})
  #|
  #|# Set: insertion during for loop raises error
  #|def set_insert_in_for():
  #|    s = set([1, 2, 3])
  #|    for x in s:
  #|        s.add(4)
  #|assert.fails(set_insert_in_for, "hash table during iteration")
  #|
  #|# Set: after loop finishes, mutation is allowed
  #|s_after = set([1, 2])
  #|for _ in s_after:
  #|    pass
  #|s_after.add(3)
  #|assert.true(3 in s_after)
  #|
  #|# Nested iteration: inner loop does not affect outer list itercount
  #|outer = [1, 2, 3]
  #|inner = [4, 5]
  #|pairs = []
  #|for x in outer:
  #|    for y in inner:
  #|        pairs.append((x, y))
  #|assert.eq(len(pairs), 6)
  #|# After both loops, mutation is allowed on both
  #|outer.append(4)
  #|inner.append(6)
  #|assert.eq(outer, [1, 2, 3, 4])
  #|assert.eq(inner, [4, 5, 6])

///|
test "iterator freezing: mutating iterated container raises error" {
  let errs = run_star_string(iter_freeze_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}
