///|
test "misc.star" {
  let errs = @starlarktest.run_chunked_string(misc_star)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}
