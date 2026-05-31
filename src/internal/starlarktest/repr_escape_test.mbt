// repr() escape parity with starlark-go syntax.Quote (ninth-pass gap analysis).

///|
test "repr uses named escapes for bell, backspace, formfeed, vtab" {
  let src =
    #|load("assert.star", "assert")
    #|assert.eq(repr("\x07\x08\x0c\x0b"), '"\\a\\b\\f\\v"')
    #|assert.eq(repr(b"\x07\x08\x0c\x0b"), 'b"\\a\\b\\f\\v"')
  let errs = run_star_string(src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}
