fn main {
  let thread = @starlark.new_thread("main")
  let src =
    #|words = ["starlark", "moonbit", "interpreter"]
    #|joined = ", ".join(words)
    #|upper_first = words[0].upper()
    #|csv = "alice,30,engineer"
    #|parts = csv.split(",")
    #|formatted = "name={} age={} role={}".format(*parts)
  match @starlark.exec_file(thread, "string_fmt.star", src, @starlark.default_options()) {
    Ok(m) => {
      match @starlark.module_get(m, "joined") {
        Some(v) => {
          let (s, _) = @starlark.as_string(v)
          println("joined = \{s}")
        }
        None => ()
      }
      match @starlark.module_get(m, "upper_first") {
        Some(v) => {
          let (s, _) = @starlark.as_string(v)
          println("upper_first = \{s}")
        }
        None => ()
      }
      match @starlark.module_get(m, "parts") {
        Some(v) => println("parts = \{@starlark.repr(v)}")
        None => ()
      }
      match @starlark.module_get(m, "formatted") {
        Some(v) => {
          let (s, _) = @starlark.as_string(v)
          println("formatted = \{s}")
        }
        None => ()
      }
    }
    Err(e) => println(@starlark.error_message(e))
  }
}
