fn main {
  let thread = @eval.Thread::new("main")
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
  match @eval.exec_file(thread, "builtins.star", src, @eval.Options::default()) {
    Ok(m) => {
      match m.get("asc") {
        Some(v) => println("sorted asc  = \{v.repr()}")
        None => ()
      }
      match m.get("desc") {
        Some(v) => println("sorted desc = \{v.repr()}")
        None => ()
      }
      match m.get("lo") {
        Some(lo) =>
          match m.get("hi") {
            Some(hi) => println("min=\{lo.repr()} max=\{hi.repr()}")
            None => ()
          }
        None => ()
      }
      match m.get("pairs") {
        Some(v) => println("zip pairs   = \{v.repr()}")
        None => ()
      }
      match m.get("counts") {
        Some(v) => println("counts      = \{v.repr()}")
        None => ()
      }
      match m.get("has_even") {
        Some(v) => println("any even    = \{v.repr()}")
        None => ()
      }
      match m.get("all_pos") {
        Some(v) => println("all pos     = \{v.repr()}")
        None => ()
      }
      match m.get("indexed") {
        Some(v) => println("enumerate   = \{v.repr()}")
        None => ()
      }
    }
    Err(e) => println(e.msg())
  }
}
