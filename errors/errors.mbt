///|
/// A source location using 1-based line and column numbers, matching
/// starlark-go's `syntax.Position` convention. Line 0 means unknown.
pub struct Position {
  priv filename : String
  priv line : Int
  priv col : Int
}

///|
/// Creates a `Position`. Use line=0 to represent an unknown location.
///
/// Parameters:
///
/// - `filename` : The source file name.
/// - `line` : The 1-based line number, or 0 for unknown.
/// - `col` : The 1-based column number, or 0 for unknown.
///
/// Returns a new `Position` value.
pub fn Position::new(filename : String, line : Int, col : Int) -> Position {
  { filename, line, col }
}

///|
/// Returns the filename component of this position.
///
/// Returns the source file name string.
pub fn Position::filename(self : Position) -> String {
  self.filename
}

///|
/// Returns the 1-based line number, or 0 if the position is unknown.
///
/// Returns the line number as an `Int`.
pub fn Position::line(self : Position) -> Int {
  self.line
}

///|
/// Returns the 1-based column number, or 0 if the position is unknown.
///
/// Returns the column number as an `Int`.
pub fn Position::col(self : Position) -> Int {
  self.col
}

///|
/// Returns `true` if the position carries a meaningful line number.
///
/// Returns `true` when `line > 0`, `false` otherwise.
pub fn Position::is_valid(self : Position) -> Bool {
  self.line > 0
}

///|
/// Formats the position as `"file:line:col"`, `"file:line"`, or `"file"`,
/// depending on which fields are non-zero.
///
/// Returns the formatted position string.
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
/// Returns `true` if this position precedes `other` in the same source file.
///
/// Parameters:
///
/// - `self` : The position to compare from.
/// - `other` : The position to compare against.
///
/// Returns `true` if `self` comes before `other` by line then column.
pub fn Position::is_before(self : Position, other : Position) -> Bool {
  if self.line != other.line {
    self.line < other.line
  } else {
    self.col < other.col
  }
}

///|
/// A parse-time error with a source position and a human-readable message.
pub struct SyntaxError {
  priv pos : Position
  priv msg : String
}

///|
/// Creates a `SyntaxError` at `pos` with message `msg`.
///
/// Parameters:
///
/// - `pos` : The source position where the error was detected.
/// - `msg` : The human-readable error message.
///
/// Returns a new `SyntaxError` value.
pub fn SyntaxError::new(pos : Position, msg : String) -> SyntaxError {
  { pos, msg }
}

///|
/// Returns the source position where the syntax error was detected.
///
/// Returns the `Position` associated with this error.
pub fn SyntaxError::pos(self : SyntaxError) -> Position {
  self.pos
}

///|
/// Returns the human-readable error message.
///
/// Returns the error message string.
pub fn SyntaxError::msg(self : SyntaxError) -> String {
  self.msg
}

///|
/// Formats the error as `"pos: msg"`.
///
/// Returns the formatted error string.
pub fn SyntaxError::to_string(self : SyntaxError) -> String {
  "\{self.pos.to_string()}: \{self.msg}"
}

///|
/// A name-resolution error with a source position and a human-readable message.
pub struct ResolveError {
  priv pos : Position
  priv msg : String
}

///|
/// Creates a `ResolveError` at `pos` with message `msg`.
///
/// Parameters:
///
/// - `pos` : The source position where the error was detected.
/// - `msg` : The human-readable error message.
///
/// Returns a new `ResolveError` value.
pub fn ResolveError::new(pos : Position, msg : String) -> ResolveError {
  { pos, msg }
}

///|
/// Returns the source position where the resolve error was detected.
///
/// Returns the `Position` associated with this error.
pub fn ResolveError::pos(self : ResolveError) -> Position {
  self.pos
}

///|
/// Returns the human-readable error message.
///
/// Returns the error message string.
pub fn ResolveError::msg(self : ResolveError) -> String {
  self.msg
}

///|
/// Formats the error as `"pos: msg"`.
///
/// Returns the formatted error string.
pub fn ResolveError::to_string(self : ResolveError) -> String {
  "\{self.pos.to_string()}: \{self.msg}"
}

///|
/// A local variable name together with its definition position; used by the
/// debugger API.
pub struct Binding {
  priv name : String
  priv pos : Position
}

///|
/// Creates a `Binding` with the given name and definition position.
///
/// Parameters:
///
/// - `name` : The variable name.
/// - `pos` : The source position where the variable is defined.
///
/// Returns a new `Binding` value.
pub fn Binding::new(name : String, pos : Position) -> Binding {
  { name, pos }
}

///|
/// Returns the variable name.
///
/// Returns the name string of this binding.
pub fn Binding::name(self : Binding) -> String {
  self.name
}

///|
/// Returns the definition position of the variable.
///
/// Returns the `Position` where this variable is defined.
pub fn Binding::pos(self : Binding) -> Position {
  self.pos
}

///|
/// A single frame in a Starlark call stack: the function name and the source
/// position of the call site within that function.
pub struct CallFrame {
  priv name : String
  priv pos : Position
}

///|
/// Creates a `CallFrame` with the given function name and call-site position.
///
/// Parameters:
///
/// - `name` : The function name for this frame.
/// - `pos` : The source position of the call site within the function.
///
/// Returns a new `CallFrame` value.
pub fn CallFrame::new(name : String, pos : Position) -> CallFrame {
  { name, pos }
}

///|
/// Returns the function name for this frame.
///
/// Returns the function name string.
pub fn CallFrame::name(self : CallFrame) -> String {
  self.name
}

///|
/// Returns the source position recorded in this frame.
///
/// Returns the call-site `Position` for this frame.
pub fn CallFrame::pos(self : CallFrame) -> Position {
  self.pos
}

///|
/// An ordered snapshot of call frames, outermost first, innermost last.
pub struct CallStack {
  priv frames : Array[CallFrame]
}

///|
/// Creates a `CallStack` from a pre-built array of frames.
///
/// Parameters:
///
/// - `frames` : An array of `CallFrame` values, outermost first.
///
/// Returns a new `CallStack` wrapping the given frames.
pub fn CallStack::new(frames : Array[CallFrame]) -> CallStack {
  { frames, }
}

///|
/// Returns the number of frames in the stack.
///
/// Returns the frame count as an `Int`.
pub fn CallStack::length(self : CallStack) -> Int {
  self.frames.length()
}

///|
/// Returns the frame at index `i` (0 = outermost), or `None` if out of range.
///
/// Parameters:
///
/// - `self` : The call stack to index into.
/// - `i` : The zero-based index of the frame to retrieve.
///
/// Returns `Some(frame)` if `i` is in range, `None` otherwise.
pub fn CallStack::at(self : CallStack, i : Int) -> CallFrame? {
  if i < 0 || i >= self.frames.length() {
    None
  } else {
    Some(self.frames[i])
  }
}

///|
/// Removes and returns the innermost (last) frame, or `None` if the stack is
/// empty.
///
/// Returns `Some(frame)` with the removed innermost frame, or `None` if empty.
pub fn CallStack::pop(self : CallStack) -> CallFrame? {
  if self.frames.is_empty() {
    None
  } else {
    Some(self.frames.unsafe_pop())
  }
}

///|
/// Formats the stack as a Python-style traceback string, or `""` if empty.
///
/// Returns the formatted traceback string.
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
/// A runtime evaluation error carrying a message, a call-stack snapshot, and
/// an optional inner cause for load-error chaining.
pub struct EvalError {
  priv msg : String
  priv call_stack : CallStack
  priv cause : EvalError?
}

///|
/// Creates an `EvalError` with only a message and an empty call stack.
///
/// Parameters:
///
/// - `msg` : The human-readable error message.
///
/// Returns a new `EvalError` with an empty call stack and no cause.
pub fn EvalError::simple(msg : String) -> EvalError {
  { msg, call_stack: CallStack::new([]), cause: None }
}

///|
/// Creates an `EvalError` with a message and a call-stack snapshot.
///
/// Parameters:
///
/// - `msg` : The human-readable error message.
/// - `call_stack` : The call-stack snapshot at the point of the error.
///
/// Returns a new `EvalError` with the given message and stack, and no cause.
pub fn EvalError::with_stack(msg : String, call_stack : CallStack) -> EvalError {
  { msg, call_stack, cause: None }
}

///|
/// Creates an `EvalError` that wraps an inner `cause`, used to chain load
/// errors so the original inner backtrace is accessible.
///
/// Parameters:
///
/// - `msg` : The human-readable error message for the outer error.
/// - `call_stack` : The call-stack snapshot at the point of the outer error.
/// - `cause` : The inner `EvalError` being wrapped.
///
/// Returns a new `EvalError` that chains to the given cause.
pub fn EvalError::with_cause(
  msg : String,
  call_stack : CallStack,
  cause : EvalError,
) -> EvalError {
  { msg, call_stack, cause: Some(cause) }
}

///|
/// Returns the error message string.
///
/// Returns the message string of this error.
pub fn EvalError::msg(self : EvalError) -> String {
  self.msg
}

///|
/// Returns the inner cause error, if this error was created with
/// `with_cause`.
///
/// Returns `Some(inner)` if a cause was set, `None` otherwise.
pub fn EvalError::cause(self : EvalError) -> EvalError? {
  self.cause
}

///|
/// Returns just the error message (same as `msg`); implements the `Show`
/// trait.
///
/// Returns the error message string.
pub fn EvalError::to_string(self : EvalError) -> String {
  self.msg
}

///|
/// Returns a formatted traceback string ending with `"Error: msg"`. Strips a
/// trailing `<builtin>` frame and appends it as `" in name"` instead.
///
/// Returns the full backtrace string including the error message.
pub fn EvalError::backtrace(self : EvalError) -> String {
  let frames = self.call_stack.frames
  let n = frames.length()
  let (stack_str, suffix) = if n > 0 &&
    frames[n - 1].pos.filename == "<builtin>" {
    let name = frames[n - 1].name
    let trimmed : Array[CallFrame] = []
    for i in 0..<(n - 1) {
      trimmed.push(frames[i])
    }
    (CallStack::new(trimmed).to_string(), " in " + name)
  } else {
    (self.call_stack.to_string(), "")
  }
  "\{stack_str}Error\{suffix}: \{self.msg}"
}
