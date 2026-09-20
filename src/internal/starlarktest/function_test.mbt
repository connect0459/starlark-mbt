///|
test "function.star" {
  let errs = @starlarktest.run_chunked_string(function_star)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}
