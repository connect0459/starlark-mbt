///|
test "while.star" {
  let errs = @starlarktest.run_chunked_string(while_star)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}
