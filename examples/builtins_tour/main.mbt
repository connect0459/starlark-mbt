fn main {
  let thread = @starlark.new_thread("main")
  let src =
    #|nums = [3, 1, 4, 1, 5, 9, 2, 6]
    #|asc = sorted(nums)
    #|desc = sorted(nums, reverse=True)
    #|lo = min(nums)
    #|hi = max(nums)
    #|pairs = list(zip(["a", "b", "c"], [1, 2, 3]))
    #|counts = {}
    #|for n in nums:
    #|    counts[n] = counts.get(n, 0) + 1
    #|has_even = any([x % 2 == 0 for x in nums])
    #|all_pos = all([x > 0 for x in nums])
    #|indexed = list(enumerate(["x", "y", "z"]))
  match @starlark.exec_file(thread, "builtins.star", src, @starlark.default_options()) {
    Ok(m) => {
      match @starlark.module_get(m, "asc") {
        Some(v) => println("sorted asc  = \{@starlark.repr(v)}")
        None => ()
      }
      match @starlark.module_get(m, "desc") {
        Some(v) => println("sorted desc = \{@starlark.repr(v)}")
        None => ()
      }
      match @starlark.module_get(m, "lo") {
        Some(lo) =>
          match @starlark.module_get(m, "hi") {
            Some(hi) => println("min=\{@starlark.repr(lo)} max=\{@starlark.repr(hi)}")
            None => ()
          }
        None => ()
      }
      match @starlark.module_get(m, "pairs") {
        Some(v) => println("zip pairs   = \{@starlark.repr(v)}")
        None => ()
      }
      match @starlark.module_get(m, "counts") {
        Some(v) => println("counts      = \{@starlark.repr(v)}")
        None => ()
      }
      match @starlark.module_get(m, "has_even") {
        Some(v) => println("any even    = \{@starlark.repr(v)}")
        None => ()
      }
      match @starlark.module_get(m, "all_pos") {
        Some(v) => println("all pos     = \{@starlark.repr(v)}")
        None => ()
      }
      match @starlark.module_get(m, "indexed") {
        Some(v) => println("enumerate   = \{@starlark.repr(v)}")
        None => ()
      }
    }
    Err(e) => println(@starlark.error_message(e))
  }
}
