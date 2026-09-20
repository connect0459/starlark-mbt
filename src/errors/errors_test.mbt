///|
test "Position: format with filename line and col" {
  let pos = @errors.Position::new("test.star", 3, 7)
  inspect(pos.to_string(), content="test.star:3:7")
}

///|
test "Position: format with unknown col shows only line" {
  let pos = @errors.Position::new("a.star", 5, 0)
  inspect(pos.to_string(), content="a.star:5")
}

///|
test "Position: format with unknown line shows only filename" {
  let pos = @errors.Position::new("a.star", 0, 0)
  inspect(pos.to_string(), content="a.star")
}

///|
test "Position: is_valid returns true when line is set" {
  let pos = @errors.Position::new("f.star", 1, 1)
  assert_true(pos.is_valid())
}

///|
test "Position: is_valid returns false for zero line" {
  let pos = @errors.Position::new("", 0, 0)
  assert_false(pos.is_valid())
}

///|
test "Position: is_before compares line then col" {
  let a = @errors.Position::new("f.star", 2, 3)
  let b = @errors.Position::new("f.star", 2, 7)
  let c = @errors.Position::new("f.star", 3, 1)
  assert_true(a.is_before(b))
  assert_true(a.is_before(c))
  assert_false(b.is_before(a))
}

///|
test "SyntaxError: format as position plus message" {
  let pos = @errors.Position::new("bad.star", 4, 2)
  let err = @errors.SyntaxError::new(pos, "unexpected token '}'")
  inspect(err.to_string(), content="bad.star:4:2: unexpected token '}'")
}

///|
test "SyntaxError: default kind is Other" {
  let pos = @errors.Position::new("bad.star", 1, 1)
  let err = @errors.SyntaxError::new(pos, "unexpected token")
  assert_true(err.kind() is Other)
}

///|
test "SyntaxError: carries an explicit kind without altering the message" {
  let pos = @errors.Position::new("bad.star", 1, 1)
  let err = @errors.SyntaxError::with_kind(
    pos,
    "got end of file, want primary expression",
    UnexpectedEof,
  )
  assert_true(err.kind() is UnexpectedEof)
  inspect(err.msg(), content="got end of file, want primary expression")
}

///|
test "SyntaxError: unterminated string kind is preserved" {
  let pos = @errors.Position::new("bad.star", 1, 1)
  let err = @errors.SyntaxError::with_kind(
    pos,
    "unexpected EOF in string",
    UnterminatedString,
  )
  assert_true(err.kind() is UnterminatedString)
}

///|
test "ResolveError: format as position plus message" {
  let pos = @errors.Position::new("x.star", 10, 1)
  let err = @errors.ResolveError::new(pos, "undefined variable 'foo'")
  inspect(err.to_string(), content="x.star:10:1: undefined variable 'foo'")
}

///|
test "CallFrame: stores name and position" {
  let pos = @errors.Position::new("m.star", 5, 1)
  let frame = @errors.CallFrame::new("myFunc", pos)
  assert_eq(frame.name(), "myFunc")
  assert_eq(frame.pos().line(), 5)
}

///|
test "CallStack: to_string formats as traceback" {
  let frame1 = @errors.CallFrame::new(
    "outer",
    @errors.Position::new("m.star", 1, 1),
  )
  let frame2 = @errors.CallFrame::new(
    "inner",
    @errors.Position::new("m.star", 5, 3),
  )
  let stack = @errors.CallStack::new([frame1, frame2])
  let s = stack.to_string()
  assert_true(s.contains("Traceback (most recent call last):"))
  assert_true(s.contains("m.star:1:1: in outer"))
  assert_true(s.contains("m.star:5:3: in inner"))
}

///|
test "CallStack: empty stack produces empty string" {
  let stack = @errors.CallStack::new([])
  assert_eq(stack.to_string(), "")
}

///|
test "EvalError: format shows message and backtrace" {
  let frame = @errors.CallFrame::new("f", @errors.Position::new("s.star", 3, 1))
  let stack = @errors.CallStack::new([frame])
  let err = @errors.EvalError::with_stack("division by zero", stack)
  let s = err.backtrace()
  assert_true(s.contains("Error: division by zero"))
  assert_true(s.contains("s.star:3:1: in f"))
}

///|
test "EvalError: to_string returns just the message" {
  let stack = @errors.CallStack::new([])
  let err = @errors.EvalError::with_stack("oops", stack)
  assert_eq(err.to_string(), "oops")
}

///|
test "EvalError: call_stack exposes the captured frames" {
  let frame = @errors.CallFrame::new("g", @errors.Position::new("s.star", 7, 2))
  let err = @errors.EvalError::with_stack(
    "boom",
    @errors.CallStack::new([frame]),
  )
  let stack = err.call_stack()
  assert_eq(stack.length(), 1)
  assert_eq(stack.at(0).unwrap().name(), "g")
}

///|
test "EvalError: call_stack returns a snapshot callers cannot mutate" {
  let frame = @errors.CallFrame::new("g", @errors.Position::new("s.star", 7, 2))
  let err = @errors.EvalError::with_stack(
    "boom",
    @errors.CallStack::new([frame]),
  )
  let _ = err.call_stack().pop()
  assert_eq(err.call_stack().length(), 1)
  assert_true(err.backtrace().contains("s.star:7:2: in g"))
}

///|
test "CallStack: length returns frame count" {
  let f1 = @errors.CallFrame::new("a", @errors.Position::new("f.star", 1, 1))
  let f2 = @errors.CallFrame::new("b", @errors.Position::new("f.star", 2, 1))
  let stack = @errors.CallStack::new([f1, f2])
  assert_eq(stack.length(), 2)
}

///|
test "CallStack: length returns zero for empty stack" {
  let stack = @errors.CallStack::new([])
  assert_eq(stack.length(), 0)
}

///|
test "CallStack: at returns frame at valid index" {
  let f1 = @errors.CallFrame::new(
    "outer",
    @errors.Position::new("f.star", 1, 1),
  )
  let f2 = @errors.CallFrame::new(
    "inner",
    @errors.Position::new("f.star", 5, 3),
  )
  let stack = @errors.CallStack::new([f1, f2])
  assert_true(stack.at(0) is Some(_))
  assert_eq(stack.at(0).unwrap().name(), "outer")
  assert_eq(stack.at(1).unwrap().name(), "inner")
}

///|
test "CallStack: at returns None for out-of-bounds index" {
  let stack = @errors.CallStack::new([])
  assert_true(stack.at(0) is None)
  let f = @errors.CallFrame::new("f", @errors.Position::new("f.star", 1, 1))
  let stack2 = @errors.CallStack::new([f])
  assert_true(stack2.at(1) is None)
  assert_true(stack2.at(-1) is None)
}

///|
test "CallStack: pop removes and returns last frame" {
  let f1 = @errors.CallFrame::new(
    "outer",
    @errors.Position::new("f.star", 1, 1),
  )
  let f2 = @errors.CallFrame::new(
    "inner",
    @errors.Position::new("f.star", 5, 3),
  )
  let stack = @errors.CallStack::new([f1, f2])
  let popped = stack.pop()
  assert_true(popped is Some(_))
  assert_eq(popped.unwrap().name(), "inner")
  assert_eq(stack.length(), 1)
}

///|
test "CallStack: pop on empty stack returns None" {
  let stack = @errors.CallStack::new([])
  assert_true(stack.pop() is None)
}
