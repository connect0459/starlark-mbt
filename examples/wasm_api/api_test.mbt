///|
test "exec_script: empty script returns empty globals and output" {
  assert_eq(exec_script(""), "{\"globals\":{},\"output\":\"\"}")
}

///|
test "exec_script: integer global is encoded as bare JSON number" {
  assert_eq(exec_script("x = 42"), "{\"globals\":{\"x\":42},\"output\":\"\"}")
}

///|
test "exec_script: list global is encoded as JSON array" {
  assert_eq(
    exec_script("nums = [1, 2, 3]"),
    "{\"globals\":{\"nums\":[1,2,3]},\"output\":\"\"}",
  )
}

///|
test "exec_script: print output is captured and appended with newline" {
  assert_eq(
    exec_script("print(\"hello\")"),
    "{\"globals\":{},\"output\":\"hello\\n\"}",
  )
}

///|
test "exec_script: syntax error returns JSON error object" {
  let result = exec_script("x = (")
  assert_true(result.has_prefix("{\"error\":"))
}

///|
test "exec_script: print of bytes is byte-faithful for ASCII bytes" {
  assert_eq(
    exec_script("print(b\"\\x41\")"),
    "{\"globals\":{},\"output\":\"A\\n\"}",
  )
}
