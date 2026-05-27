///|
pub struct Position {
  priv filename : String
  priv line : Int
  priv col : Int
}

///|
pub fn Position::new(filename : String, line : Int, col : Int) -> Position {
  { filename, line, col }
}

///|
pub fn Position::filename(self : Position) -> String {
  self.filename
}

///|
pub fn Position::line(self : Position) -> Int {
  self.line
}

///|
pub fn Position::col(self : Position) -> Int {
  self.col
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
pub struct Span {
  priv start : Position
  priv end_ : Position
}

///|
pub fn Span::new(start : Position, end_ : Position) -> Span {
  { start, end_ }
}

///|
pub fn Span::start(self : Span) -> Position {
  self.start
}

///|
pub fn Span::end_pos(self : Span) -> Position {
  self.end_
}

///|
pub fn Span::to_string(self : Span) -> String {
  "\{self.start.to_string()}-\{self.end_.to_string()}"
}

///|
pub struct SyntaxError {
  priv pos : Position
  priv msg : String
}

///|
pub fn SyntaxError::new(pos : Position, msg : String) -> SyntaxError {
  { pos, msg }
}

///|
pub fn SyntaxError::pos(self : SyntaxError) -> Position {
  self.pos
}

///|
pub fn SyntaxError::msg(self : SyntaxError) -> String {
  self.msg
}

///|
pub fn SyntaxError::to_string(self : SyntaxError) -> String {
  "\{self.pos.to_string()}: \{self.msg}"
}

///|
pub struct ResolveError {
  priv pos : Position
  priv msg : String
}

///|
pub fn ResolveError::new(pos : Position, msg : String) -> ResolveError {
  { pos, msg }
}

///|
pub fn ResolveError::pos(self : ResolveError) -> Position {
  self.pos
}

///|
pub fn ResolveError::msg(self : ResolveError) -> String {
  self.msg
}

///|
pub fn ResolveError::to_string(self : ResolveError) -> String {
  "\{self.pos.to_string()}: \{self.msg}"
}

///|
pub struct CallFrame {
  priv name : String
  priv pos : Position
}

///|
pub fn CallFrame::new(name : String, pos : Position) -> CallFrame {
  { name, pos }
}

///|
pub fn CallFrame::name(self : CallFrame) -> String {
  self.name
}

///|
pub fn CallFrame::pos(self : CallFrame) -> Position {
  self.pos
}

///|
pub struct CallStack {
  priv frames : Array[CallFrame]
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
pub struct EvalError {
  priv msg : String
  priv call_stack : CallStack
}

///|
pub fn EvalError::simple(msg : String) -> EvalError {
  { msg, call_stack: CallStack::new([]) }
}

///|
pub fn EvalError::with_stack(msg : String, call_stack : CallStack) -> EvalError {
  { msg, call_stack }
}

///|
pub fn EvalError::msg(self : EvalError) -> String {
  self.msg
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
pub struct Halt {
  priv reason : String
}

///|
pub fn Halt::new(reason : String) -> Halt {
  { reason, }
}

///|
pub fn Halt::reason(self : Halt) -> String {
  self.reason
}
