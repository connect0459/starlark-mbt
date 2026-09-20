///|
test "math.star" {
  let errs = @starlarktest.run_chunked_string(math_star)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}
