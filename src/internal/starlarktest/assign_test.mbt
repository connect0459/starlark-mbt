///|
test "assign.star" {
  let errs = run_chunked_string(assign_star)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}
