///|
fn main {
  let utils_src =
    #|def clamp(x, lo, hi):
    #|    if x < lo: return lo
    #|    if x > hi: return hi
    #|    return x
    #|
    #|def pipeline(value, *fns):
    #|    result = value
    #|    for f in fns:
    #|        result = f(result)
    #|    return result
  let modules : Map[String, String] = { "utils.star": utils_src }
  let loader = fn(
    _t : @eval.Thread,
    path : String,
  ) -> Result[@eval.Module, @errors.EvalError] {
    match modules.get(path) {
      Some(src) => {
        let lt = @eval.Thread::new("load:\{path}")
        @eval.exec_file(lt, path, src, @eval.Options::default())
      }
      None =>
        @eval.exec_file(
          @eval.Thread::new("err"),
          path,
          "raise_error = 1 // 0",
          @eval.Options::default(),
        )
    }
  }
  let thread = @eval.Thread::with_loader("main", loader)
  let src =
    #|load("utils.star", "clamp", "pipeline")
    #|
    #|data = [-5, 0, 3, 7, 12]
    #|clamped = [clamp(x, 0, 10) for x in data]
    #|
    #|result = pipeline(
    #|    "  Hello, World!  ",
    #|    lambda s: s.strip(),
    #|    lambda s: s.lower(),
    #|    lambda s: s.replace(",", ""),
    #|)
  match @eval.exec_file(thread, "main.star", src, @eval.Options::default()) {
    Ok(m) => {
      match m.get("clamped") {
        Some(v) => println("clamped = \{v.repr()}")
        None => ()
      }
      match m.get("result") {
        Some(v) => {
          let (s, _) = @value.as_string(v)
          println("pipeline result = \{s}")
        }
        None => ()
      }
    }
    Err(e) => println(e.msg())
  }
}
