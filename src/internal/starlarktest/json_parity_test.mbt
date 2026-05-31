// json encode/decode parity with starlark-go (ninth-pass gap analysis).

///|
test "json.encode emits raw UTF-8 for non-ASCII, like Go json.Marshal" {
  let src =
    #|load("assert.star", "assert")
    #|load("json.star", "json")
    #|assert.eq(json.encode("é"), '"é"')
    #|assert.eq(json.encode("世界"), '"世界"')
    #|assert.eq(json.encode("😹"), '"😹"')
    #|# invalid UTF-8 -> U+FFFD
    #|assert.eq(json.encode("😹"[:1]), '"\\ufffd"')
  let errs = run_star_string(src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "json.encode escapes DEL as Go strconv.AppendQuote does" {
  let src =
    #|load("assert.star", "assert")
    #|load("json.star", "json")
    #|assert.eq(json.encode("\x7f"), '"\\x7f"')
  let errs = run_star_string(src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "json.encode HTML-escapes angle brackets and ampersand in Marshal branch" {
  let src =
    #|load("assert.star", "assert")
    #|load("json.star", "json")
    #|# pure printable-ASCII -> AppendQuote leaves <, >, & literal
    #|assert.eq(json.encode("<a>&b"), '"<a>&b"')
    #|# string forced into the Marshal branch by a non-ASCII byte
    #|assert.eq(json.encode("<é>&"), '"\\u003cé\\u003e\\u0026"')
  let errs = run_star_string(src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "json.decode rejects a non-string object key with Go wording" {
  let src =
    #|load("assert.star", "assert")
    #|load("json.star", "json")
    #|assert.fails(lambda: json.decode("{1:2}"), "got int for object key, want string")
  let errs = run_star_string(src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}
