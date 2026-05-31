// Error-message parity with starlark-go for slicing, indexing, and comparison
// operators (ninth-pass gap analysis).

///|
test "slice index and step type errors name the parameter" {
  let src =
    #|load("assert.star", "assert")
    #|assert.fails(lambda: [1, 2, 3]["x":], "invalid start index: got string, want int")
    #|assert.fails(lambda: [1, 2, 3][:"x"], "invalid end index: got string, want int")
    #|assert.fails(lambda: [1, 2, 3][1:2:"x"], "invalid slice step: got string, want int")
  let errs = run_star_string(src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "unhandled index operation reports both operand types" {
  let src =
    #|load("assert.star", "assert")
    #|assert.fails(lambda: 123[0], "unhandled index operation int[int]")
    #|assert.fails(lambda: None[0], "unhandled index operation NoneType[int]")
  let errs = run_star_string(src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "non-sliceable operand error uses Go wording" {
  let src =
    #|load("assert.star", "assert")
    #|assert.fails(lambda: True[0:1], "invalid slice operand bool")
  let errs = run_star_string(src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "comparison error uses the actual operator token" {
  let src =
    #|load("assert.star", "assert")
    #|assert.fails(lambda: 1 < "a", "int < string not implemented")
    #|assert.fails(lambda: 1 <= "a", "int <= string not implemented")
    #|assert.fails(lambda: 1 > "a", "int > string not implemented")
    #|assert.fails(lambda: 1 >= "a", "int >= string not implemented")
    #|assert.fails(lambda: [1] <= ["a"], "int <= string not implemented")
  let errs = run_star_string(src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}
