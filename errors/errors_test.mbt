///|
test "Position: format with filename line and col" {
  let pos = Position::new("test.star", 3, 7)
  inspect(pos.to_string(), content="test.star:3:7")
}

///|
test "Position: format with unknown col shows only line" {
  let pos = Position::new("a.star", 5, 0)
  inspect(pos.to_string(), content="a.star:5")
}

///|
test "Position: format with unknown line shows only filename" {
  let pos = Position::new("a.star", 0, 0)
  inspect(pos.to_string(), content="a.star")
}

///|
test "Position: is_valid returns true when line is set" {
  let pos = Position::new("f.star", 1, 1)
  assert_true(pos.is_valid())
}

///|
test "Position: is_valid returns false for zero line" {
  let pos = Position::new("", 0, 0)
  assert_false(pos.is_valid())
}

///|
test "Position: is_before compares line then col" {
  let a = Position::new("f.star", 2, 3)
  let b = Position::new("f.star", 2, 7)
  let c = Position::new("f.star", 3, 1)
  assert_true(a.is_before(b))
  assert_true(a.is_before(c))
  assert_false(b.is_before(a))
}

///|
test "SyntaxError: format as position plus message" {
  let pos = Position::new("bad.star", 4, 2)
  let err = SyntaxError::new(pos, "unexpected token '}'")
  inspect(err.to_string(), content="bad.star:4:2: unexpected token '}'")
}

///|
test "ResolveError: format as position plus message" {
  let pos = Position::new("x.star", 10, 1)
  let err = ResolveError::new(pos, "undefined variable 'foo'")
  inspect(err.to_string(), content="x.star:10:1: undefined variable 'foo'")
}

///|
test "CallFrame: stores name and position" {
  let pos = Position::new("m.star", 5, 1)
  let frame = CallFrame::new("myFunc", pos)
  assert_eq(frame.name(), "myFunc")
  assert_eq(frame.pos().line(), 5)
}

///|
test "CallStack: to_string formats as traceback" {
  let frame1 = CallFrame::new("outer", Position::new("m.star", 1, 1))
  let frame2 = CallFrame::new("inner", Position::new("m.star", 5, 3))
  let stack = CallStack::new([frame1, frame2])
  let s = stack.to_string()
  assert_true(s.contains("Traceback (most recent call last):"))
  assert_true(s.contains("m.star:1:1: in outer"))
  assert_true(s.contains("m.star:5:3: in inner"))
}

///|
test "CallStack: empty stack produces empty string" {
  let stack = CallStack::new([])
  assert_eq(stack.to_string(), "")
}

///|
test "EvalError: format shows message and backtrace" {
  let frame = CallFrame::new("f", Position::new("s.star", 3, 1))
  let stack = CallStack::new([frame])
  let err = EvalError::with_stack("division by zero", stack)
  let s = err.backtrace()
  assert_true(s.contains("Error: division by zero"))
  assert_true(s.contains("s.star:3:1: in f"))
}

///|
test "EvalError: to_string returns just the message" {
  let stack = CallStack::new([])
  let err = EvalError::with_stack("oops", stack)
  assert_eq(err.to_string(), "oops")
}

///|
test "EvalError: call_stack exposes the captured frames" {
  let frame = CallFrame::new("g", Position::new("s.star", 7, 2))
  let err = EvalError::with_stack("boom", CallStack::new([frame]))
  let stack = err.call_stack()
  assert_eq(stack.length(), 1)
  assert_eq(stack.at(0).unwrap().name(), "g")
}

///|
test "EvalError: call_stack returns a snapshot callers cannot mutate" {
  let frame = CallFrame::new("g", Position::new("s.star", 7, 2))
  let err = EvalError::with_stack("boom", CallStack::new([frame]))
  let _ = err.call_stack().pop()
  assert_eq(err.call_stack().length(), 1)
  assert_true(err.backtrace().contains("s.star:7:2: in g"))
}

///|
test "CallStack: length returns frame count" {
  let f1 = CallFrame::new("a", Position::new("f.star", 1, 1))
  let f2 = CallFrame::new("b", Position::new("f.star", 2, 1))
  let stack = CallStack::new([f1, f2])
  assert_eq(stack.length(), 2)
}

///|
test "CallStack: length returns zero for empty stack" {
  let stack = CallStack::new([])
  assert_eq(stack.length(), 0)
}

///|
test "CallStack: at returns frame at valid index" {
  let f1 = CallFrame::new("outer", Position::new("f.star", 1, 1))
  let f2 = CallFrame::new("inner", Position::new("f.star", 5, 3))
  let stack = CallStack::new([f1, f2])
  assert_true(stack.at(0) is Some(_))
  assert_eq(stack.at(0).unwrap().name(), "outer")
  assert_eq(stack.at(1).unwrap().name(), "inner")
}

///|
test "CallStack: at returns None for out-of-bounds index" {
  let stack = CallStack::new([])
  assert_true(stack.at(0) is None)
  let f = CallFrame::new("f", Position::new("f.star", 1, 1))
  let stack2 = CallStack::new([f])
  assert_true(stack2.at(1) is None)
  assert_true(stack2.at(-1) is None)
}

///|
test "CallStack: pop removes and returns last frame" {
  let f1 = CallFrame::new("outer", Position::new("f.star", 1, 1))
  let f2 = CallFrame::new("inner", Position::new("f.star", 5, 3))
  let stack = CallStack::new([f1, f2])
  let popped = stack.pop()
  assert_true(popped is Some(_))
  assert_eq(popped.unwrap().name(), "inner")
  assert_eq(stack.length(), 1)
}

///|
test "CallStack: pop on empty stack returns None" {
  let stack = CallStack::new([])
  assert_true(stack.pop() is None)
}
