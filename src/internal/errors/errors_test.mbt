///|
test "Position: format with filename line and col" {
  let pos = Position::new("test.star", 3, 7)
  inspect(pos.to_string(), content="test.star:3:7")
}

///|
test "Position: format with unknown col shows only line" {
  let pos = Position::{ filename: "a.star", line: 5, col: 0 }
  inspect(pos.to_string(), content="a.star:5")
}

///|
test "Position: format with unknown line shows only filename" {
  let pos = Position::{ filename: "a.star", line: 0, col: 0 }
  inspect(pos.to_string(), content="a.star")
}

///|
test "Position: is_valid returns true when line is set" {
  let pos = Position::new("f.star", 1, 1)
  assert_true(pos.is_valid())
}

///|
test "Position: is_valid returns false for zero line" {
  let pos = Position::{ filename: "", line: 0, col: 0 }
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
test "Span: to_string shows start and end" {
  let start = Position::new("f.star", 1, 1)
  let end_ = Position::new("f.star", 1, 5)
  let span = Span::{ start, end_ }
  inspect(span.to_string(), content="f.star:1:1-f.star:1:5")
}

///|
test "SyntaxError: format as position plus message" {
  let pos = Position::new("bad.star", 4, 2)
  let err = SyntaxError::{ pos, msg: "unexpected token '}'" }
  inspect(err.to_string(), content="bad.star:4:2: unexpected token '}'")
}

///|
test "ResolveError: format as position plus message" {
  let pos = Position::new("x.star", 10, 1)
  let err = ResolveError::{ pos, msg: "undefined variable 'foo'" }
  inspect(err.to_string(), content="x.star:10:1: undefined variable 'foo'")
}

///|
test "CallFrame: stores name and position" {
  let pos = Position::new("m.star", 5, 1)
  let frame = CallFrame::{ name: "myFunc", pos }
  assert_eq(frame.name, "myFunc")
  assert_eq(frame.pos.line, 5)
}

///|
test "CallStack: to_string formats as traceback" {
  let frame1 = CallFrame::{ name: "outer", pos: Position::new("m.star", 1, 1) }
  let frame2 = CallFrame::{ name: "inner", pos: Position::new("m.star", 5, 3) }
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
  let frame = CallFrame::{ name: "f", pos: Position::new("s.star", 3, 1) }
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
test "Halt: is distinct from EvalError" {
  let h = Halt::{ reason: "cancelled" }
  assert_eq(h.reason, "cancelled")
}
