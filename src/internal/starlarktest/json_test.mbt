///|
test "json.star" {
  let errs = run_chunked_string(json_star)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}
