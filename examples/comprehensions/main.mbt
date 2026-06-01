fn main {
  let thread = @starlark.new_thread("main")
  let src =
    #|squares = [x * x for x in range(1, 6)]
    #|evens = [x for x in range(20) if x % 2 == 0]
    #|word_lengths = {w: len(w) for w in ["apple", "banana", "cherry"]}
    #|flat = [x for row in [[1, 2], [3, 4], [5, 6]] for x in row]
  match @starlark.exec_file(thread, "comprehensions.star", src, @starlark.default_options()) {
    Ok(m) => {
      match @starlark.module_get(m, "squares") {
        Some(v) => println("squares (\{@starlark.len_of(v)} items) = \{@starlark.repr(v)}")
        None => ()
      }
      match @starlark.module_get(m, "evens") {
        Some(v) => println("evens (\{@starlark.len_of(v)} items) = \{@starlark.repr(v)}")
        None => ()
      }
      match @starlark.module_get(m, "word_lengths") {
        Some(v) => println("word_lengths = \{@starlark.repr(v)}")
        None => ()
      }
      match @starlark.module_get(m, "flat") {
        Some(v) => println("flat = \{@starlark.repr(v)}")
        None => ()
      }
    }
    Err(e) => println(@starlark.error_message(e))
  }
}
