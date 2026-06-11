///|
test "int.star" {
  let errs = run_chunked_string(int_star)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}
