///|
fn make_thread() -> @eval.Thread {
  @eval.Thread::new("repl")
}

///|
fn empty_globals() -> @value.StarlarkDict {
  @value.StarlarkDict::new()
}

// --- eval_input ---

///|
test "eval_input: expression returns Value output" {
  let t = make_thread()
  let g = empty_globals()
  match eval_input(t, g, "1 + 2") {
    Value(s) => assert_eq(s, "3")
    other => {
      println(other)
      assert_true(false)
    }
  }
}

///|
test "eval_input: None expression returns Empty" {
  let t = make_thread()
  let g = empty_globals()
  assert_true(eval_input(t, g, "None") is Empty)
}

///|
test "eval_input: statement assigns variable and returns Empty" {
  let t = make_thread()
  let g = empty_globals()
  assert_true(eval_input(t, g, "x = 7") is Empty)
  match eval_input(t, g, "x") {
    Value(s) => assert_eq(s, "7")
    other => {
      println(other)
      assert_true(false)
    }
  }
}

///|
test "eval_input: runtime error returns EvalError output" {
  let t = make_thread()
  let g = empty_globals()
  match eval_input(t, g, "1 // 0") {
    EvalError(msg) => assert_true(msg.contains("zero"))
    other => {
      println(other)
      assert_true(false)
    }
  }
}

///|
test "eval_input: stores last expression result in _ variable" {
  let t = make_thread()
  let g = empty_globals()
  let _ = eval_input(t, g, "42")
  match eval_input(t, g, "_") {
    Value(s) => assert_eq(s, "42")
    other => {
      println(other)
      assert_true(false)
    }
  }
}

///|
test "eval_input: string expression returns quoted repr" {
  let t = make_thread()
  let g = empty_globals()
  match eval_input(t, g, "\"hello\"") {
    Value(s) => assert_eq(s, "\"hello\"")
    other => {
      println(other)
      assert_true(false)
    }
  }
}

// --- format_error ---

///|
test "format_error: includes error message" {
  let e = @errors.EvalError::simple("something went wrong")
  let s = format_error(e)
  assert_true(s.contains("something went wrong"))
}

// --- make_load ---

///|
test "make_load: returns a loader function" {
  let loader = make_load(".")
  assert_true(loader is _)
}
