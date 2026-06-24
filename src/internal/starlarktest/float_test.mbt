///|
test "float.star" {
  let errs = run_chunked_string(float_star)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}
