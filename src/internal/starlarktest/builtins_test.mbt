///|
test "builtins.star" {
  let errs = @starlarktest.run_chunked_string(builtins_star)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}
