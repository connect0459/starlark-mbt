// bytes parity tests with starlark-go.

///|
test "bytes is not directly iterable; use b.elems()" {
  let src =
    #|load("assert.star", "assert")
    #|assert.fails(lambda: list(b"abc"), "got bytes, want iterable")
    #|def for_bytes():
    #|    for x in b"abc":
    #|        pass
    #|assert.fails(for_bytes, "bytes value is not iterable")
  let errs = run_star_string(src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}
