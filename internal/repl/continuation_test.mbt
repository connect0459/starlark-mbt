// Backend-independent tests for the REPL continuation state machine. These run
// on every target because `feed` performs no IO.

///|
test "feed: a complete expression is ready immediately" {
  let state = ReplState::new()
  match state.feed("1 + 2") {
    Complete(src) => assert_eq(src, "1 + 2")
    other => fail("expected Complete, got \{other}")
  }
}

///|
test "feed: a single-line compound is complete immediately" {
  let state = ReplState::new()
  match state.feed("if x: pass") {
    Complete(src) => assert_eq(src, "if x: pass")
    other => fail("expected Complete, got \{other}")
  }
}

///|
test "feed: a compound opener requests more input" {
  for opener in ["def f():", "if True:", "for x in y:"] {
    let state = ReplState::new()
    match state.feed(opener) {
      NeedMore => assert_true(state.pending())
      other => fail("expected NeedMore for \{opener}, got \{other}")
    }
  }
}

///|
test "feed: an unclosed bracket requests more input then completes" {
  let state = ReplState::new()
  assert_true(state.feed("(1 +") is NeedMore)
  match state.feed("2)") {
    Complete(src) => assert_eq(src, "(1 +\n2)")
    other => fail("expected Complete, got \{other}")
  }
}

///|
test "feed: an unterminated triple-quoted string requests more input" {
  let state = ReplState::new()
  assert_true(state.feed("'''abc") is NeedMore)
}

///|
test "feed: a multi-statement suite is held until a blank line" {
  let state = ReplState::new()
  assert_true(state.feed("def f():") is NeedMore)
  // Parses on its own, but the suite must keep reading until a blank line.
  assert_true(state.feed("  x = 1") is NeedMore)
  assert_true(state.feed("  return x") is NeedMore)
  match state.feed("") {
    Complete(src) => assert_eq(src, "def f():\n  x = 1\n  return x")
    other => fail("expected Complete, got \{other}")
  }
}

///|
test "feed: a genuine syntax error is reported as Invalid" {
  let state = ReplState::new()
  match state.feed("1 + * 2") {
    Invalid(e) => assert_true(e.msg().contains("primary expression"))
    other => fail("expected Invalid, got \{other}")
  }
  // State is discarded after a hard error.
  assert_false(state.pending())
}

///|
test "feed: a blank first line is a no-op completion" {
  let state = ReplState::new()
  match state.feed("   ") {
    Complete(src) => assert_eq(src, "")
    other => fail("expected Complete, got \{other}")
  }
}

///|
test "feed: an empty suite terminated early is reported as Invalid" {
  let state = ReplState::new()
  assert_true(state.feed("def f():") is NeedMore)
  assert_true(state.feed("") is Invalid(_))
  assert_false(state.pending())
}
