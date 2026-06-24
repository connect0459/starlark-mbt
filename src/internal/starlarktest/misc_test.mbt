///|
test "misc.star" {
  let errs = run_chunked_string(misc_star)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}
