///|
test "bool.star" {
  let errs = @starlarktest.run_chunked_string(bool_star)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}
