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

///|
test "C1 controls U+0080-U+009F are escaped as \\uNNNN in repr" {
  let src =
    #|load("assert.star", "assert")
    #|assert.eq(repr(chr(0x85)), '"\\u0085"')
    #|assert.eq(repr(chr(0x80)), '"\\u0080"')
    #|assert.eq(repr(chr(0x9F)), '"\\u009f"')
  let errs = run_star_string(src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "NBSP U+00A0 is escaped as \\u00a0 in repr" {
  let src =
    #|load("assert.star", "assert")
    #|assert.eq(repr(chr(0xA0)), '"\\u00a0"')
  let errs = run_star_string(src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "private-use codepoints U+E000 and U+F8FF are escaped in repr" {
  let src =
    #|load("assert.star", "assert")
    #|assert.eq(repr(chr(0xE000)), '"\\ue000"')
    #|assert.eq(repr(chr(0xF8FF)), '"\\uf8ff"')
  let errs = run_star_string(src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "noncharacters U+FFFE and U+FFFF are escaped in repr" {
  let src =
    #|load("assert.star", "assert")
    #|assert.eq(repr(chr(0xFFFE)), '"\\ufffe"')
    #|assert.eq(repr(chr(0xFFFF)), '"\\uffff"')
  let errs = run_star_string(src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "supplemental private-use U+F0000 and U+10FFFF are escaped in repr" {
  let src =
    #|load("assert.star", "assert")
    #|assert.eq(repr(chr(0xF0000)), '"\\U000f0000"')
    #|assert.eq(repr(chr(0x10FFFF)), '"\\U0010ffff"')
  let errs = run_star_string(src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "lexer: \\U out-of-range error uses offending value in both slots" {
  let thread = @eval.Thread::new("test")
  let result = @eval.exec_file(
    thread,
    "test.star",
    (
      #|x = "\U00110000"
    ),
    @eval.Options::default(),
  )
  match result {
    Err(e) =>
      assert_true(
        e
        .msg()
        .contains("code point out of range: \\U00110000 (max \\U00110000)"),
      )
    Ok(_) => abort("expected error")
  }
}

///|
test "lexer: \\x with non-hex first char reports 'invalid escape', not 'truncated'" {
  let thread = @eval.Thread::new("test")
  let result = @eval.exec_file(
    thread,
    "test.star",
    (
      #|x = "\x-0"
    ),
    @eval.Options::default(),
  )
  match result {
    Err(e) => assert_true(e.msg().contains("invalid escape sequence \\x-0"))
    Ok(_) => abort("expected error")
  }
}

///|
test "lexer: escape errors in b-prefixed literals report opening-quote column" {
  let thread = @eval.Thread::new("test")
  // Source: `x = b"\400"` — `b` at col 5, opening `"` at col 6.
  // Old behavior reported col 5 (prefix char); fix reports col 6 (opening quote).
  let result = @eval.exec_file(
    thread,
    "test.star",
    (
      #|x = b"\400"
    ),
    @eval.Options::default(),
  )
  match result {
    Err(e) => {
      assert_true(e.msg().contains("invalid escape sequence"))
      assert_true(e.msg().contains("test.star:1:6:"))
    }
    Ok(_) => abort("expected error")
  }
}
