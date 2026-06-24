///|
test "tuple.star" {
  let errs = run_chunked_string(tuple_star)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}
