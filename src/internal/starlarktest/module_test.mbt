///|
test "module.star" {
  let errs = @starlarktest.run_chunked_string(module_star)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}
