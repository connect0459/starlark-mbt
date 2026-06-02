fn main {
  let thread = @eval.Thread::new("main")
  let src =
    #|words = ["starlark", "moonbit", "interpreter"]
    #|joined = ", ".join(words)
    #|upper_first = words[0].upper()
    #|csv = "alice,30,engineer"
    #|parts = csv.split(",")
    #|formatted = "name={} age={} role={}".format(*parts)
  match @eval.exec_file(thread, "string_fmt.star", src, @eval.Options::default()) {
    Ok(m) => {
      match m.get("joined") {
        Some(v) => {
          let (s, _) = @value.as_string(v)
          println("joined = \{s}")
        }
        None => ()
      }
      match m.get("upper_first") {
        Some(v) => {
          let (s, _) = @value.as_string(v)
          println("upper_first = \{s}")
        }
        None => ()
      }
      match m.get("parts") {
        Some(v) => println("parts = \{v.repr()}")
        None => ()
      }
      match m.get("formatted") {
        Some(v) => {
          let (s, _) = @value.as_string(v)
          println("formatted = \{s}")
        }
        None => ()
      }
    }
    Err(e) => println(e.msg())
  }
}
