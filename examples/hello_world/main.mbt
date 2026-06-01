///|
fn main {
  let thread = @starlark.new_thread("main")
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
    @starlark.exec_file(thread, "hello.star", src, @starlark.default_options()) {
    Ok(_) => ()
    Err(e) => println(@starlark.error_message(e))
  }
}
