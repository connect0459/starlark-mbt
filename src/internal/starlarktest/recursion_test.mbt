///|
test "recursion.star" {
  let errs = run_chunked_string(recursion_star)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}
