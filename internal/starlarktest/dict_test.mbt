///|
test "dict.star" {
  let errs = run_chunked_string(dict_star)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}
