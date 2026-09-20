///|
test "set.star" {
  let errs = @starlarktest.run_chunked_string(set_star)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}
