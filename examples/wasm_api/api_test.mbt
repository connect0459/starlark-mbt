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

///|
test "exec_script_with_env: empty env behaves like exec_script" {
  assert_eq(
    exec_script_with_env("x = 1", "{}"),
    "{\"globals\":{\"x\":1},\"output\":\"\"}",
  )
}

///|
test "exec_script_with_env: string constant is readable from script" {
  assert_eq(
    exec_script_with_env("result = MY_CONST + \"!\"", "{\"MY_CONST\":\"hello\"}"),
    "{\"globals\":{\"result\":\"hello!\"},\"output\":\"\"}",
  )
}

///|
test "exec_script_with_env: integer constant is readable from script" {
  assert_eq(
    exec_script_with_env("doubled = BASE * 2", "{\"BASE\":21}"),
    "{\"globals\":{\"doubled\":42},\"output\":\"\"}",
  )
}

///|
test "exec_script_with_env: list constant is readable from script" {
  assert_eq(
    exec_script_with_env("n = len(ITEMS)", "{\"ITEMS\":[1,2,3]}"),
    "{\"globals\":{\"n\":3},\"output\":\"\"}",
  )
}

///|
test "exec_script_with_env: injected names are not in returned globals" {
  let result = exec_script_with_env("x = 1", "{\"INJECTED\":\"value\"}")
  assert_true(result.contains("\"x\":1"))
  assert_false(result.contains("INJECTED"))
}

///|
test "exec_script_with_env: print can use injected constant" {
  assert_eq(
    exec_script_with_env("print(GREETING)", "{\"GREETING\":\"hi\"}"),
    "{\"globals\":{},\"output\":\"hi\\n\"}",
  )
}

///|
test "exec_script_with_env: invalid JSON env returns error" {
  let result = exec_script_with_env("x = 1", "not-json")
  assert_true(result.has_prefix("{\"error\":"))
}

///|
test "exec_script_with_env: non-object JSON env returns error" {
  let result = exec_script_with_env("x = 1", "[1,2,3]")
  assert_true(result.has_prefix("{\"error\":"))
}
