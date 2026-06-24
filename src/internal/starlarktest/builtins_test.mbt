///|
test "builtins.star" {
  let errs = run_chunked_string(builtins_star)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}
