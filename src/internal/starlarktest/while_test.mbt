///|
test "while.star" {
  let errs = run_chunked_string(while_star)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}
