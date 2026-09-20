///|
test "bytes.star" {
  let errs = @starlarktest.run_chunked_string(bytes_star)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}
