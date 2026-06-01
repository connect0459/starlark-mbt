fn main {
  let thread = @starlark.new_thread("main")
  let src =
    #|def fib(n):
    #|    if n <= 1:
    #|        return n
    #|    return fib(n - 1) + fib(n - 2)
    #|
    #|result = fib(15)
    #|sequence = [fib(i) for i in range(10)]
  match @starlark.exec_file(thread, "fibonacci.star", src, @starlark.default_options()) {
    Ok(m) => {
      match @starlark.module_get(m, "result") {
        Some(v) =>
          match @starlark.number_to_int(v) {
            Some(n) => println("fib(15) = \{n}")
            None => ()
          }
        None => ()
      }
      match @starlark.module_get(m, "sequence") {
        Some(v) => println("sequence = \{@starlark.repr(v)}")
        None => ()
      }
    }
    Err(e) => println(@starlark.error_message(e))
  }
}
