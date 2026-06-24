///|
test "function.star" {
  let errs = run_chunked_string(function_star)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}
