///|
fn main {
  let thread = @eval.Thread::new("main")
  let src =
    #|greeting = "hello " + "world"
    #|numbers = [1, 2, 3, 4, 5]
    #|total = 0
    #|for n in numbers:
    #|    total += n
    #|print(greeting)
    #|print("sum:", total)
    #|print("type:", type(numbers))
  // This script uses a top-level `for` loop and reassigns a global, both
  // non-standard extensions disabled by default; opt into them explicitly.
  let opts = @eval.Options::default()
    .with_allow_top_level_control(true)
    .with_allow_global_reassign(true)
  match @eval.exec_file(thread, "hello.star", src, opts) {
    Ok(_) => ()
    Err(e) => println(e.msg())
  }
}
