///|
test "string.star" {
  let errs = run_chunked_string(string_star)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}
