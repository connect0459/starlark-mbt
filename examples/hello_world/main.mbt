///|
fn main {
  let thread = @starlark.Thread::new("main")
  let src =
    #|greeting = "hello " + "world"
    #|numbers = [1, 2, 3, 4, 5]
    #|total = 0
    #|for n in numbers:
    #|    total += n
    #|print(greeting)
    #|print("sum:", total)
    #|print("type:", type(numbers))
  match
    @starlark.exec_file(thread, "hello.star", src, @starlark.Options::default()) {
    Ok(_) => ()
    Err(e) => println(e.msg())
  }
}
