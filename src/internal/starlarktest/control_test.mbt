///|
test "control.star" {
  let errs = @starlarktest.run_chunked_string(control_star)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}
