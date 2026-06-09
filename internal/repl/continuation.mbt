///|
/// The outcome of feeding one input line to the REPL continuation detector.
pub enum FeedResult {
  /// The accumulated input forms a complete chunk, ready to evaluate. Carries
  /// the full source (empty for a blank line, which is a no-op).
  Complete(String)
  /// The input is incomplete; the REPL should read another line under the
  /// continuation prompt.
  NeedMore
  /// The input is definitively invalid; the buffer has been discarded.
  Invalid(@errors.EvalError)
}

///|
pub impl Show for FeedResult with fn output(self, logger) {
  match self {
    Complete(s) => logger.write_string("Complete(\{s})")
    NeedMore => logger.write_string("NeedMore")
    Invalid(e) => logger.write_string("Invalid(\{e.msg()})")
  }
}

///|
/// Accumulates input lines across continuation prompts and decides when a REPL
/// chunk is complete. Pure and IO-free, so the continuation logic is testable
/// on every backend independently of the stdin FFI.
pub struct ReplState {
  priv lines : Array[String]
  priv mut in_suite : Bool
}

///|
/// Creates an empty continuation state.
pub fn ReplState::new() -> ReplState {
  { lines: [], in_suite: false }
}

///|
/// Returns true when input has been partially accumulated (mid-chunk), so the
/// caller can show a continuation prompt and treat end-of-input as a discard.
pub fn ReplState::pending(self : ReplState) -> Bool {
  !self.lines.is_empty()
}

///|
fn ReplState::reset(self : ReplState) -> Unit {
  self.lines.clear()
  self.in_suite = false
}

///|
/// Discards any partially accumulated chunk, returning to the primary prompt.
/// Used when an interrupt abandons the current input.
pub fn ReplState::discard(self : ReplState) -> Unit {
  self.reset()
}

///|
fn ReplState::buffer(self : ReplState) -> String {
  let sb = StringBuilder::new()
  for i, line in self.lines {
    if i > 0 {
      sb.write_char('\n')
    }
    sb.write_string(line)
  }
  sb.to_string()
}

///|
fn ReplState::complete(self : ReplState) -> FeedResult {
  let src = self.buffer()
  self.reset()
  Complete(src)
}

///|
/// Feeds one raw input line (without its trailing newline) into the state
/// machine and reports whether the accumulated chunk is complete.
pub fn ReplState::feed(self : ReplState, line : String) -> FeedResult {
  if self.lines.is_empty() {
    self.feed_first(line)
  } else if self.in_suite {
    self.feed_suite(line)
  } else {
    self.feed_continuation(line)
  }
}

///|
fn ReplState::feed_first(self : ReplState, line : String) -> FeedResult {
  if is_blank(line) {
    return Complete("")
  }
  self.lines.push(line)
  match parse_status(self.buffer()) {
    Parsed => self.complete()
    Incomplete => {
      // An indented compound suite keeps reading until a blank line; a bare
      // unclosed bracket or string just needs its closing delimiter.
      if is_compound_opener(line) {
        self.in_suite = true
      }
      NeedMore
    }
    Bad(e) => {
      self.reset()
      Invalid(e)
    }
  }
}

///|
fn ReplState::feed_continuation(self : ReplState, line : String) -> FeedResult {
  self.lines.push(line)
  match parse_status(self.buffer()) {
    Parsed => self.complete()
    Incomplete => NeedMore
    Bad(e) => {
      self.reset()
      Invalid(e)
    }
  }
}

///|
fn ReplState::feed_suite(self : ReplState, line : String) -> FeedResult {
  if !is_blank(line) {
    self.lines.push(line)
    return NeedMore
  }
  // A blank line terminates the suite: the user has signalled completion, so an
  // unterminated suite (e.g. an empty body) is now a genuine error.
  let src = self.buffer()
  match @parser.parse_file("<repl>", src) {
    Ok(_) => self.complete()
    Err(e) => {
      self.reset()
      Invalid(@errors.EvalError::simple(e.to_string()))
    }
  }
}

///|
/// The result of parsing the accumulated buffer for continuation purposes.
priv enum ParseStatus {
  Parsed
  Incomplete
  Bad(@errors.EvalError)
}

///|
fn parse_status(src : String) -> ParseStatus {
  match @parser.parse_file("<repl>", src) {
    Ok(_) => Parsed
    Err(e) =>
      match e.kind() {
        UnexpectedEof | UnterminatedString => Incomplete
        Other => Bad(@errors.EvalError::simple(e.to_string()))
      }
  }
}

///|
fn is_blank(line : String) -> Bool {
  for c in line.iter() {
    if c != ' ' && c != '\t' && c != '\r' && c != '\n' {
      return false
    }
  }
  true
}

///|
/// True when `line`'s first identifier-like token opens an indented compound
/// statement (`def` / `if` / `for` / `while`), which requires a suite.
fn is_compound_opener(line : String) -> Bool {
  let word = StringBuilder::new()
  let mut started = false
  for c in line.iter() {
    if !started {
      if c == ' ' || c == '\t' {
        continue
      }
      started = true
    }
    if is_ident_char(c) {
      word.write_char(c)
    } else {
      break
    }
  }
  match word.to_string() {
    "def" | "if" | "for" | "while" => true
    _ => false
  }
}

///|
fn is_ident_char(c : Char) -> Bool {
  let n = c.to_int()
  (n >= 'a'.to_int() && n <= 'z'.to_int()) ||
  (n >= 'A'.to_int() && n <= 'Z'.to_int()) ||
  (n >= '0'.to_int() && n <= '9'.to_int()) ||
  c == '_'
}
