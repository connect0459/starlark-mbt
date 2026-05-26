///|
pub(all) struct Position {
  filename : String
  line : Int
  col : Int
}

///|
pub fn Position::new(filename : String, line : Int, col : Int) -> Position {
  { filename, line, col }
}

///|
pub fn Position::is_valid(self : Position) -> Bool {
  self.line > 0
}

///|
pub fn Position::to_string(self : Position) -> String {
  if self.line > 0 {
    if self.col > 0 {
      "\{self.filename}:\{self.line}:\{self.col}"
    } else {
      "\{self.filename}:\{self.line}"
    }
  } else {
    self.filename
  }
}

///|
pub fn Position::is_before(self : Position, other : Position) -> Bool {
  if self.line != other.line {
    self.line < other.line
  } else {
    self.col < other.col
  }
}

///|
pub(all) struct Span {
  start : Position
  end_ : Position
}

///|
pub fn Span::to_string(self : Span) -> String {
  "\{self.start.to_string()}-\{self.end_.to_string()}"
}

///|
pub(all) struct SyntaxError {
  pos : Position
  msg : String
}

///|
pub fn SyntaxError::to_string(self : SyntaxError) -> String {
  "\{self.pos.to_string()}: \{self.msg}"
}

///|
pub(all) struct ResolveError {
  pos : Position
  msg : String
}

///|
pub fn ResolveError::to_string(self : ResolveError) -> String {
  "\{self.pos.to_string()}: \{self.msg}"
}

///|
pub(all) struct CallFrame {
  name : String
  pos : Position
}

///|
pub(all) struct CallStack {
  frames : Array[CallFrame]
}

///|
pub fn CallStack::new(frames : Array[CallFrame]) -> CallStack {
  { frames, }
}

///|
pub fn CallStack::to_string(self : CallStack) -> String {
  if self.frames.is_empty() {
    return ""
  }
  let buf = StringBuilder::new()
  buf.write_string("Traceback (most recent call last):\n")
  for frame in self.frames {
    buf.write_string("  \{frame.pos.to_string()}: in \{frame.name}\n")
  }
  buf.to_string()
}

///|
pub(all) struct EvalError {
  msg : String
  call_stack : CallStack
  cause : String?
}

///|
pub fn EvalError::simple(msg : String) -> EvalError {
  { msg, call_stack: CallStack::new([]), cause: None }
}

///|
pub fn EvalError::to_string(self : EvalError) -> String {
  self.msg
}

///|
pub fn EvalError::backtrace(self : EvalError) -> String {
  "\{self.call_stack.to_string()}Error: \{self.msg}"
}

///|
pub(all) struct Halt {
  reason : String
}
