fn main {
  let thread = @eval.Thread::new("main")
  let src =
    #|def fib(n):
    #|    if n <= 1:
    #|        return n
    #|    return fib(n - 1) + fib(n - 2)
    #|
    #|result = fib(15)
    #|sequence = [fib(i) for i in range(10)]
  match @starlark.exec_file(thread, "fibonacci.star", src, @eval.Options::default()) {
    Ok(m) => {
      match m.get("result") {
        Some(v) =>
          match @starlark.number_to_int(v) {
            Some(n) => println("fib(15) = \{n}")
            None => ()
          }
        None => ()
      }
      match m.get("sequence") {
        Some(v) => println("sequence = \{v.repr()}")
        None => ()
      }
    }
    Err(e) => println(e.msg())
  }
}
