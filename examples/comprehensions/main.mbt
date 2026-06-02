fn main {
  let thread = @eval.Thread::new("main")
  let src =
    #|squares = [x * x for x in range(1, 6)]
    #|evens = [x for x in range(20) if x % 2 == 0]
    #|word_lengths = {w: len(w) for w in ["apple", "banana", "cherry"]}
    #|flat = [x for row in [[1, 2], [3, 4], [5, 6]] for x in row]
  match @starlark.exec_file(thread, "comprehensions.star", src, @eval.Options::default()) {
    Ok(m) => {
      match m.get("squares") {
        Some(v) => println("squares (\{@starlark.len_of(v)} items) = \{v.repr()}")
        None => ()
      }
      match m.get("evens") {
        Some(v) => println("evens (\{@starlark.len_of(v)} items) = \{v.repr()}")
        None => ()
      }
      match m.get("word_lengths") {
        Some(v) => println("word_lengths = \{v.repr()}")
        None => ()
      }
      match m.get("flat") {
        Some(v) => println("flat = \{v.repr()}")
        None => ()
      }
    }
    Err(e) => println(e.msg())
  }
}
