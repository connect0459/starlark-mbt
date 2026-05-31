// Starlark lexical scanner.
// Converts UTF-8 source text into a sequence of ScannedToken values.

///|
let tab_width : Int = 8

///|
let unicode_surr_lo : Int = 0xD800

///|
let unicode_surr_hi : Int = 0xE000

///|
let unicode_max_codepoint : Int = 0x10FFFF

///|
/// A token produced by the scanner, paired with its source position.
pub struct ScannedToken {
  priv tok : Token
  priv pos : @errors.Position
}

///|
/// Returns the token kind.
pub fn ScannedToken::token(self : ScannedToken) -> Token {
  self.tok
}

///|
/// Returns the token's source position.
pub fn ScannedToken::pos(self : ScannedToken) -> @errors.Position {
  self.pos
}

///|
/// A UTF-8 source scanner that converts Starlark source text into a sequence
/// of `ScannedToken` values, tracking indentation and bracket depth.
pub struct Scanner {
  priv src : Bytes
  priv filename : String
  priv mut off : Int
  priv mut line : Int
  priv mut col : Int
  priv mut depth : Int
  priv mut indent_stack : Array[Int]
  priv mut dents : Int
  priv mut line_start : Bool
}

///|
/// Creates a new scanner for the given source string with position tracking
/// starting at line 1, column 1.
pub fn Scanner::new(filename : String, source : String) -> Scanner {
  {
    src: @utf8.encode(source),
    filename,
    off: 0,
    line: 1,
    col: 1,
    depth: 0,
    indent_stack: [0],
    dents: 0,
    line_start: true,
  }
}

///|
fn Scanner::peek_byte(self : Scanner) -> Byte {
  if self.off >= self.src.length() {
    b'\x00'
  } else {
    self.src[self.off]
  }
}

///|
fn Scanner::peek_byte_ahead(self : Scanner, n : Int) -> Byte {
  let i = self.off + n
  if i >= self.src.length() {
    b'\x00'
  } else {
    self.src[i]
  }
}

// read_byte consumes and returns the next byte.
// Normalizes \r and \r\n to \n. Returns 0 at EOF.

///|
fn Scanner::read_byte(self : Scanner) -> Byte {
  if self.off >= self.src.length() {
    return b'\x00'
  }
  let b = self.src[self.off]
  self.off += 1
  if b == b'\r' {
    if self.off < self.src.length() && self.src[self.off] == b'\n' {
      self.off += 1
    }
    self.line += 1
    self.col = 1
    return b'\n'
  } else if b == b'\n' {
    self.line += 1
    self.col = 1
    return b'\n'
  } else {
    self.col += 1
    return b
  }
}

///|
fn Scanner::current_pos(self : Scanner) -> @errors.Position {
  @errors.Position::new(self.filename, self.line, self.col)
}

///|
/// The scanner's current read position: one column past the last consumed
/// byte. Mirrors starlark-go's `scanner.pos`, which parser errors point at.
pub fn Scanner::position(self : Scanner) -> @errors.Position {
  self.current_pos()
}

///|
fn Scanner::make_error(
  _self : Scanner,
  pos : @errors.Position,
  msg : String,
) -> @errors.SyntaxError {
  @errors.SyntaxError::new(pos, msg)
}

// count_indent counts indentation at the start of a line (tab = 8 spaces).
// Consumes leading spaces and tabs; stops at any other character.

///|
fn Scanner::count_indent(self : Scanner) -> Int {
  // `col` is the tab-expanded indentation width; `src_col` is the number of
  // source columns (runes) consumed so far. A tab advances to the next stop
  // based on the source column, not the expanded width, so the two must be
  // tracked separately for mixed space+tab indentation.
  let mut col = 0
  let mut src_col = 0
  while true {
    let b = self.peek_byte()
    if b == b' ' {
      col += 1
      src_col += 1
      self.read_byte() |> ignore
    } else if b == b'\t' {
      col += tab_width - src_col % tab_width
      src_col += 1
      self.read_byte() |> ignore
    } else {
      break
    }
  }
  col
}

///|
/// Returns the next token from the source, or a `SyntaxError` on invalid input.
/// Manages INDENT/OUTDENT tokens based on indentation changes at line starts.
pub fn Scanner::next_token(
  self : Scanner,
) -> Result[ScannedToken, @errors.SyntaxError] {
  while true {
    let saved_line_start = self.line_start
    let mut blank = false

    // Process line start: measure indentation and compute INDENT/OUTDENT.
    if self.line_start {
      self.line_start = false
      let indent_col = self.count_indent()
      let cb = self.peek_byte().to_int()
      if cb == '\n'.to_int() ||
        cb == '#'.to_int() ||
        cb == 0 ||
        cb == '\r'.to_int() {
        blank = true
      }
      if !blank && self.depth == 0 {
        let cur = self.indent_stack[self.indent_stack.length() - 1]
        if indent_col > cur {
          self.dents += 1
          self.indent_stack.push(indent_col)
        } else if indent_col < cur {
          while self.indent_stack.length() > 0 &&
                indent_col < self.indent_stack[self.indent_stack.length() - 1] {
            self.dents -= 1
            self.indent_stack.pop() |> ignore
          }
          if self.indent_stack.length() == 0 ||
            indent_col != self.indent_stack[self.indent_stack.length() - 1] {
            let pos = self.current_pos()
            return Err(
              self.make_error(
                pos, "unindent does not match any outer indentation level",
              ),
            )
          }
        }
      }
    }

    // Return pending INDENT/OUTDENT tokens.
    if self.dents != 0 {
      let pos = self.current_pos()
      if self.dents < 0 {
        self.dents += 1
        return Ok({ tok: Outdent, pos })
      } else {
        self.dents -= 1
        return Ok({ tok: Indent, pos })
      }
    }

    // Skip spaces (outside of line_start; count_indent already consumed them at line start).
    while self.peek_byte() == b' ' || self.peek_byte() == b'\t' {
      self.read_byte() |> ignore
    }

    // Skip comment (# to end of line).
    if self.peek_byte() == b'#' {
      while true {
        let ch = self.peek_byte()
        if ch == b'\n' || ch == b'\r' || ch == b'\x00' {
          break
        }
        self.read_byte() |> ignore
      }
    }

    // Newline.
    if self.peek_byte() == b'\n' || self.peek_byte() == b'\r' {
      self.line_start = true
      if self.depth > 0 {
        // Inside brackets: implicit line continuation; skip newline.
        self.read_byte() |> ignore
        continue
      }
      if blank {
        // Blank line at top level: skip.
        self.read_byte() |> ignore
        continue
      }
      let pos = self.current_pos()
      self.read_byte() |> ignore
      return Ok({ tok: Newline, pos })
    }

    // EOF.
    if self.peek_byte() == b'\x00' {
      if self.indent_stack.length() > 1 {
        if saved_line_start {
          self.dents = 1 - self.indent_stack.length()
          self.indent_stack = [0]
          continue
        } else {
          // Emit synthetic NEWLINE before closing OUTDENTs.
          self.line_start = true
          let pos = self.current_pos()
          return Ok({ tok: Newline, pos })
        }
      }
      let pos = self.current_pos()
      return Ok({ tok: EOF, pos })
    }

    // Explicit line continuation.
    if self.peek_byte() == b'\\' {
      let pos = self.current_pos()
      self.read_byte() |> ignore
      let nb = self.peek_byte()
      if nb != b'\n' && nb != b'\r' {
        return Err(self.make_error(pos, "stray backslash in program"))
      }
      self.read_byte() |> ignore
      continue
    }

    // Real token starts here.
    let start = self.current_pos()
    let c = self.peek_byte()

    // String literal starting with " or '
    if c == b'"' || c == b'\'' {
      return self.scan_string(start, false, false)
    }

    // Identifier, keyword, or string/bytes prefix (r"...", b"...", rb"...", br"...")
    // Non-ASCII bytes are only valid here if they form a Unicode letter rune.
    let enters_ident = is_ident_start_byte(c) ||
      (
        c.to_int() >= 0x80 &&
        ({
          let (cp, _) = @utf8util.utf8_decode_rune(self.src, self.off)
          cp > 0 && is_unicode_letter_rune(cp)
        })
      )
    if enters_ident {
      if c == b'r' {
        let n1 = self.peek_byte_ahead(1)
        if n1 == b'"' || n1 == b'\'' {
          self.read_byte() |> ignore // consume 'r'
          return self.scan_string(start, false, true)
        }
        if n1 == b'b' {
          let n2 = self.peek_byte_ahead(2)
          if n2 == b'"' || n2 == b'\'' {
            self.read_byte() |> ignore // 'r'
            self.read_byte() |> ignore // 'b'
            return self.scan_string(start, true, true)
          }
        }
      }
      if c == b'b' {
        let n1 = self.peek_byte_ahead(1)
        if n1 == b'"' || n1 == b'\'' {
          self.read_byte() |> ignore // consume 'b'
          return self.scan_string(start, true, false)
        }
      }
      let raw_bytes = self.collect_ident_bytes()
      let name = @utf8.decode_lossy(raw_bytes[:])
      match keyword_token(name) {
        Some(kw) => return Ok({ tok: kw, pos: start })
        None => return Ok({ tok: Ident(name), pos: start })
      }
    }

    // Opening brackets.
    if c == b'(' || c == b'[' || c == b'{' {
      self.depth += 1
      self.read_byte() |> ignore
      let tok = if c == b'(' {
        LParen
      } else if c == b'[' {
        LBrack
      } else {
        LBrace
      }
      return Ok({ tok, pos: start })
    }

    // Closing brackets.
    if c == b')' || c == b']' || c == b'}' {
      if self.depth == 0 {
        let ch = if c == b')' { ")" } else if c == b']' { "]" } else { "}" }
        return Err(self.make_error(start, "unexpected '\{ch}'"))
      }
      self.depth -= 1
      self.read_byte() |> ignore
      let tok = if c == b')' {
        RParen
      } else if c == b']' {
        RBrack
      } else {
        RBrace
      }
      return Ok({ tok, pos: start })
    }

    // Comma.
    if c == b',' {
      self.read_byte() |> ignore
      return Ok({ tok: Comma, pos: start })
    }

    // Number or dot.
    if is_digit_byte(c) || c == b'.' {
      return self.scan_number(start)
    }

    // All other operators.
    return self.scan_operator(start)
  }
  let pos = self.current_pos()
  Err(self.make_error(pos, "internal scanner error"))
}

///|
fn Scanner::collect_ident_bytes(self : Scanner) -> Bytes {
  let buf : Array[Byte] = []
  while true {
    let b = self.peek_byte()
    if b.to_int() < 0x80 {
      // ASCII: use the fast per-byte check
      if is_ident_byte(b) {
        buf.push(b)
        self.read_byte() |> ignore
      } else {
        break
      }
    } else {
      // Non-ASCII: decode the full UTF-8 rune and validate as a Unicode letter.
      // Starlark identifiers allow non-ASCII letters but not digits or symbols.
      let (cp, rlen) = @utf8util.utf8_decode_rune(self.src, self.off)
      if cp <= 0 || !is_unicode_letter_rune(cp) {
        break
      }
      for _ in 0..<rlen {
        buf.push(self.peek_byte())
        self.read_byte() |> ignore
      }
    }
  }
  Bytes::from_array(buf)
}

///|
fn Scanner::scan_operator(
  self : Scanner,
  start : @errors.Position,
) -> Result[ScannedToken, @errors.SyntaxError] {
  let c = self.read_byte()
  let cn = c.to_int()
  match cn {
    0x2B => {
      // + or +=
      if self.peek_byte() == b'=' {
        self.read_byte() |> ignore
        return Ok({ tok: PlusAssign, pos: start })
      }
      Ok({ tok: Plus, pos: start })
    }
    0x2D => {
      // - or -=
      if self.peek_byte() == b'=' {
        self.read_byte() |> ignore
        return Ok({ tok: MinusAssign, pos: start })
      }
      Ok({ tok: Minus, pos: start })
    }
    0x2A => {
      // * or *= or **
      if self.peek_byte() == b'*' {
        self.read_byte() |> ignore
        return Ok({ tok: StarStar, pos: start })
      }
      if self.peek_byte() == b'=' {
        self.read_byte() |> ignore
        return Ok({ tok: StarAssign, pos: start })
      }
      Ok({ tok: Star, pos: start })
    }
    0x2F => {
      // / or /= or // or //=
      if self.peek_byte() == b'/' {
        self.read_byte() |> ignore
        if self.peek_byte() == b'=' {
          self.read_byte() |> ignore
          return Ok({ tok: SlashSlashAssign, pos: start })
        }
        return Ok({ tok: SlashSlash, pos: start })
      }
      if self.peek_byte() == b'=' {
        self.read_byte() |> ignore
        return Ok({ tok: SlashAssign, pos: start })
      }
      Ok({ tok: Slash, pos: start })
    }
    0x25 => {
      // % or %=
      if self.peek_byte() == b'=' {
        self.read_byte() |> ignore
        return Ok({ tok: PercentAssign, pos: start })
      }
      Ok({ tok: Percent, pos: start })
    }
    0x26 => {
      // & or &=
      if self.peek_byte() == b'=' {
        self.read_byte() |> ignore
        return Ok({ tok: AmpAssign, pos: start })
      }
      Ok({ tok: Amp, pos: start })
    }
    0x7C => {
      // | or |=
      if self.peek_byte() == b'=' {
        self.read_byte() |> ignore
        return Ok({ tok: PipeAssign, pos: start })
      }
      Ok({ tok: Pipe, pos: start })
    }
    0x5E => {
      // ^ or ^=
      if self.peek_byte() == b'=' {
        self.read_byte() |> ignore
        return Ok({ tok: CircumflexAssign, pos: start })
      }
      Ok({ tok: Circumflex, pos: start })
    }
    0x3C => {
      // < or <= or << or <<=
      if self.peek_byte() == b'<' {
        self.read_byte() |> ignore
        if self.peek_byte() == b'=' {
          self.read_byte() |> ignore
          return Ok({ tok: LtLtAssign, pos: start })
        }
        return Ok({ tok: LtLt, pos: start })
      }
      if self.peek_byte() == b'=' {
        self.read_byte() |> ignore
        return Ok({ tok: Le, pos: start })
      }
      Ok({ tok: Lt, pos: start })
    }
    0x3E => {
      // > or >= or >> or >>=
      if self.peek_byte() == b'>' {
        self.read_byte() |> ignore
        if self.peek_byte() == b'=' {
          self.read_byte() |> ignore
          return Ok({ tok: GtGtAssign, pos: start })
        }
        return Ok({ tok: GtGt, pos: start })
      }
      if self.peek_byte() == b'=' {
        self.read_byte() |> ignore
        return Ok({ tok: Ge, pos: start })
      }
      Ok({ tok: Gt, pos: start })
    }
    0x3D => {
      // = or ==
      if self.peek_byte() == b'=' {
        self.read_byte() |> ignore
        return Ok({ tok: Eql, pos: start })
      }
      Ok({ tok: Assign, pos: start })
    }
    0x21 => {
      // ! or !=
      if self.peek_byte() == b'=' {
        self.read_byte() |> ignore
        return Ok({ tok: Neq, pos: start })
      }
      Err(self.make_error(start, "unexpected input character '!'"))
    }
    0x7E => Ok({ tok: Tilde, pos: start }) // ~
    0x3B => Ok({ tok: Semi, pos: start }) // ;
    0x3A => {
      // : or :=
      if self.peek_byte() == b'=' {
        self.read_byte() |> ignore
        return Err(
          self.make_error(
            start, "walrus operator (:=) is not allowed in Starlark",
          ),
        )
      }
      Ok({ tok: Colon, pos: start })
    }
    _ => Err(self.make_error(start, "unexpected input character"))
  }
}

///|
fn Scanner::scan_number(
  self : Scanner,
  start : @errors.Position,
) -> Result[ScannedToken, @errors.SyntaxError] {
  let mut fraction = false
  let mut exponent = false
  let raw : Array[Byte] = []
  let c = self.peek_byte()

  if c == b'.' {
    // Dot: float if followed by digit, otherwise DOT token.
    self.read_byte() |> ignore
    if !is_digit_byte(self.peek_byte()) {
      return Ok({ tok: Dot, pos: start })
    }
    raw.push(b'.')
    fraction = true
    while is_digit_byte(self.peek_byte()) {
      raw.push(self.peek_byte())
      self.read_byte() |> ignore
    }
    if self.peek_byte() == b'e' || self.peek_byte() == b'E' {
      exponent = true
    }
  } else if c == b'0' {
    raw.push(b'0')
    self.read_byte() |> ignore
    let n = self.peek_byte()
    if n == b'x' || n == b'X' {
      // Hexadecimal: 0x[0-9A-Fa-f]+
      self.read_byte() |> ignore
      if !is_xdigit_byte(self.peek_byte()) {
        return Err(self.make_error(start, "invalid hex literal"))
      }
      let digits : Array[Byte] = []
      while is_xdigit_byte(self.peek_byte()) {
        digits.push(self.peek_byte())
        self.read_byte() |> ignore
      }
      let s = @utf8.decode_lossy(Bytes::from_array(digits)[:])
      match parse_int_hex(s) {
        Err(e) => return Err(self.make_error(start, e))
        Ok(v) => return Ok({ tok: Int(v), pos: start })
      }
    } else if n == b'o' || n == b'O' {
      // Octal: 0o[0-7]+
      self.read_byte() |> ignore
      if !is_odigit_byte(self.peek_byte()) {
        return Err(self.make_error(self.current_pos(), "invalid octal literal"))
      }
      let digits : Array[Byte] = []
      while is_odigit_byte(self.peek_byte()) {
        digits.push(self.peek_byte())
        self.read_byte() |> ignore
      }
      let s = @utf8.decode_lossy(Bytes::from_array(digits)[:])
      match parse_int_base(s, 8) {
        Err(e) => return Err(self.make_error(start, e))
        Ok(v) => return Ok({ tok: Int(v), pos: start })
      }
    } else if n == b'b' || n == b'B' {
      // Binary: 0b[01]+
      self.read_byte() |> ignore
      if !is_bdigit_byte(self.peek_byte()) {
        return Err(
          self.make_error(self.current_pos(), "invalid binary literal"),
        )
      }
      let digits : Array[Byte] = []
      while is_bdigit_byte(self.peek_byte()) {
        digits.push(self.peek_byte())
        self.read_byte() |> ignore
      }
      let s = @utf8.decode_lossy(Bytes::from_array(digits)[:])
      match parse_int_base(s, 2) {
        Err(e) => return Err(self.make_error(start, e))
        Ok(v) => return Ok({ tok: Int(v), pos: start })
      }
    } else if n == b'.' {
      fraction = true
    } else if n == b'e' || n == b'E' {
      exponent = true
    } else {
      // Digit(s) after 0: could be obsolete octal or just 0
      let mut all_zeros = true
      let mut is_octal_digits = true
      let extra : Array[Byte] = []
      while is_digit_byte(self.peek_byte()) {
        let d = self.peek_byte()
        if d != b'0' {
          all_zeros = false
        }
        if d > b'7' {
          is_octal_digits = false
        }
        extra.push(d)
        self.read_byte() |> ignore
      }
      if self.peek_byte() == b'.' {
        for b in extra {
          raw.push(b)
        }
        fraction = true
      } else if self.peek_byte() == b'e' || self.peek_byte() == b'E' {
        for b in extra {
          raw.push(b)
        }
        exponent = true
      } else if !all_zeros && is_octal_digits && extra.length() > 0 {
        let digits = @utf8.decode_lossy(Bytes::from_array(extra)[:])
        return Err(
          self.make_error(
            self.current_pos(),
            "obsolete form of octal literal; use 0o\{digits}",
          ),
        )
      } else if !all_zeros && extra.length() > 0 {
        return Err(self.make_error(start, "invalid int literal"))
      } else {
        // Just 0 (or 00...0 which equals 0)
        return Ok({ tok: Int(0N), pos: start })
      }
    }
  } else {
    // Decimal integer
    while is_digit_byte(self.peek_byte()) {
      raw.push(self.peek_byte())
      self.read_byte() |> ignore
    }
    if self.peek_byte() == b'.' {
      fraction = true
    } else if self.peek_byte() == b'e' || self.peek_byte() == b'E' {
      exponent = true
    }
  }

  // Collect fractional digits.
  if fraction {
    if self.peek_byte() == b'.' {
      raw.push(b'.')
      self.read_byte() |> ignore
    }
    while is_digit_byte(self.peek_byte()) {
      raw.push(self.peek_byte())
      self.read_byte() |> ignore
    }
    if self.peek_byte() == b'e' || self.peek_byte() == b'E' {
      exponent = true
    }
  }

  // Collect exponent.
  if exponent {
    raw.push(self.peek_byte()) // 'e' or 'E'
    self.read_byte() |> ignore
    if self.peek_byte() == b'+' || self.peek_byte() == b'-' {
      raw.push(self.peek_byte())
      self.read_byte() |> ignore
    }
    if !is_digit_byte(self.peek_byte()) {
      return Err(self.make_error(self.current_pos(), "invalid float literal"))
    }
    while is_digit_byte(self.peek_byte()) {
      raw.push(self.peek_byte())
      self.read_byte() |> ignore
    }
  }

  let raw_str = @utf8.decode_lossy(Bytes::from_array(raw)[:])
  if fraction || exponent {
    match parse_float_str(raw_str) {
      Err(e) => Err(self.make_error(self.current_pos(), e))
      Ok(f) => Ok({ tok: Float(f), pos: start })
    }
  } else {
    match parse_int_decimal(raw_str) {
      Err(_) =>
        Err(self.make_error(self.current_pos(), "invalid decimal literal"))
      Ok(n) => Ok({ tok: Int(n), pos: start })
    }
  }
}

///|
fn Scanner::scan_string(
  self : Scanner,
  start : @errors.Position,
  is_bytes : Bool,
  is_raw : Bool,
) -> Result[ScannedToken, @errors.SyntaxError] {
  // Capture the position of the opening quote, not the prefix character
  // (b, r, br, etc.). Escape-sequence errors are reported here, matching
  // starlark-go scan.go which sets `start := sc.pos` after consuming the
  // prefix but before consuming the quote.
  let quote_start = self.current_pos()
  let quote = self.peek_byte()
  let triple = self.peek_byte_ahead(1) == quote &&
    self.peek_byte_ahead(2) == quote
  self.read_byte() |> ignore // first quote
  if triple {
    self.read_byte() |> ignore // second quote
    self.read_byte() |> ignore // third quote
  }
  let buf : Array[Byte] = []
  if triple {
    match self.scan_string_triple(quote_start, quote, is_bytes, is_raw, buf) {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  } else {
    match self.scan_string_single(quote_start, quote, is_bytes, is_raw, buf) {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  let content = Bytes::from_array(buf)
  if is_bytes {
    Ok({ tok: Bytes(content), pos: start })
  } else {
    Ok({ tok: Str(@utf8.decode_lossy(content[:])), pos: start })
  }
}

///|
fn Scanner::scan_string_single(
  self : Scanner,
  start : @errors.Position,
  quote : Byte,
  is_bytes : Bool,
  is_raw : Bool,
  buf : Array[Byte],
) -> Result[Unit, @errors.SyntaxError] {
  while true {
    if self.peek_byte() == b'\x00' {
      return Err(self.make_error(start, "unexpected EOF in string"))
    }
    let ch = self.read_byte()
    if ch == quote {
      break
    }
    if ch == b'\n' || ch == b'\r' {
      return Err(self.make_error(start, "unexpected newline in string"))
    }
    if ch == b'\\' {
      if is_raw {
        // Raw: backslash is kept literally; next char too (except \<newline>)
        buf.push(b'\\')
        if self.peek_byte() == b'\x00' {
          return Err(self.make_error(start, "unexpected EOF in string"))
        }
        let next = self.read_byte()
        if next == b'\r' {
          buf.push(b'\n')
        } else {
          buf.push(next)
        }
      } else {
        if self.peek_byte() == b'\x00' {
          return Err(self.make_error(start, "unexpected EOF in string"))
        }
        let next = self.read_byte()
        match self.decode_escape(start, next, is_bytes, buf) {
          Err(e) => return Err(e)
          Ok(_) => ()
        }
      }
    } else {
      buf.push(ch)
    }
  }
  Ok(())
}

///|
fn Scanner::scan_string_triple(
  self : Scanner,
  start : @errors.Position,
  quote : Byte,
  is_bytes : Bool,
  is_raw : Bool,
  buf : Array[Byte],
) -> Result[Unit, @errors.SyntaxError] {
  let mut quote_count = 0
  while true {
    if self.peek_byte() == b'\x00' {
      return Err(self.make_error(start, "unexpected EOF in string"))
    }
    let ch = self.read_byte()
    if ch == quote {
      quote_count += 1
      buf.push(ch)
      if quote_count == 3 {
        // Remove the 3 closing quotes from content.
        buf.pop() |> ignore
        buf.pop() |> ignore
        buf.pop() |> ignore
        break
      }
    } else {
      quote_count = 0
      if ch == b'\\' {
        if is_raw {
          buf.push(b'\\')
          if self.peek_byte() == b'\x00' {
            return Err(self.make_error(start, "unexpected EOF in string"))
          }
          let next = self.read_byte()
          if next == b'\r' {
            buf.push(b'\n')
          } else {
            buf.push(next)
          }
        } else {
          if self.peek_byte() == b'\x00' {
            return Err(self.make_error(start, "unexpected EOF in string"))
          }
          let next = self.read_byte()
          match self.decode_escape(start, next, is_bytes, buf) {
            Err(e) => return Err(e)
            Ok(_) => ()
          }
        }
      } else if ch == b'\r' {
        // normalize CR to LF
        buf.push(b'\n')
        // skip following \n
        if self.peek_byte() == b'\n' {
          self.read_byte() |> ignore
        }
      } else {
        buf.push(ch)
      }
    }
  }
  Ok(())
}

///|
fn Scanner::decode_escape(
  self : Scanner,
  str_start : @errors.Position,
  c : Byte,
  is_bytes : Bool,
  buf : Array[Byte],
) -> Result[Unit, @errors.SyntaxError] {
  let n = c.to_int()
  match n {
    0x61 => buf.push(b'\x07') // \a
    0x62 => buf.push(b'\x08') // \b
    0x66 => buf.push(b'\x0C') // \f
    0x6E => buf.push(b'\n') // \n
    0x72 => buf.push(b'\r') // \r
    0x74 => buf.push(b'\t') // \t
    0x76 => buf.push(b'\x0B') // \v
    0x5C => buf.push(b'\\') // \\
    0x27 => buf.push(b'\'') // \'
    0x22 => buf.push(b'"') // \"
    0x0A => () // \<LF> → line continuation: skip
    0x0D =>
      // \<CR> → skip; also skip following \n
      if self.peek_byte() == b'\n' {
        self.read_byte() |> ignore
      }
    0x30 | 0x31 | 0x32 | 0x33 | 0x34 | 0x35 | 0x36 | 0x37 => {
      // Octal: \NNN (up to 3 digits)
      let mut val = n - 0x30
      for _ in 0..<2 {
        if is_odigit_byte(self.peek_byte()) {
          val = val * 8 + (self.peek_byte().to_int() - 0x30)
          self.read_byte() |> ignore
        } else {
          break
        }
      }
      // Match starlark-go: check n > 127 FIRST (non-ASCII), then n >= 256 (invalid)
      if !is_bytes && val > 127 {
        let octal_str = int_to_octal(val)
        let hex4 = int_to_hex4_upper(val)
        return Err(
          self.make_error(
            str_start,
            "non-ASCII octal escape \\\{octal_str} (use \\u\{hex4} for the UTF-8 encoding of U+\{hex4})",
          ),
        )
      }
      if val >= 256 {
        let octal3 = int_to_octal3(val)
        return Err(
          self.make_error(str_start, "invalid escape sequence \\\{octal3}"),
        )
      }
      buf.push(val.to_byte())
    }
    0x78 => {
      // Hex: \xNN (exactly 2 digits).
      // "truncated" only when a required digit slot is occupied by EOF or a
      // string delimiter; any other character (including non-hex punctuation)
      // is "invalid", matching starlark-go quote.go:198-203.
      fn is_str_end(b : Byte) -> Bool {
        b == b'\x00' || b == b'"' || b == b'\'' || b == b'\n'
      }

      let h1 = self.peek_byte()
      if !is_xdigit_byte(h1) {
        if is_str_end(h1) {
          return Err(
            self.make_error(str_start, "truncated escape sequence \\x"),
          )
        }
        self.read_byte() |> ignore
        let h2 = self.peek_byte()
        if !is_str_end(h2) {
          self.read_byte() |> ignore
          return Err(
            self.make_error(
              str_start,
              "invalid escape sequence \\x\{h1.to_int().unsafe_to_char()}\{h2.to_int().unsafe_to_char()}",
            ),
          )
        }
        return Err(
          self.make_error(
            str_start,
            "invalid escape sequence \\x\{h1.to_int().unsafe_to_char()}",
          ),
        )
      }
      self.read_byte() |> ignore
      let h2 = self.peek_byte()
      if !is_xdigit_byte(h2) {
        if is_str_end(h2) {
          return Err(
            self.make_error(
              str_start,
              "truncated escape sequence \\x\{h1.to_int().unsafe_to_char()}",
            ),
          )
        }
        self.read_byte() |> ignore
        return Err(
          self.make_error(
            str_start,
            "invalid escape sequence \\x\{h1.to_int().unsafe_to_char()}\{h2.to_int().unsafe_to_char()}",
          ),
        )
      }
      self.read_byte() |> ignore
      let val = xdigit_to_int(h1) * 16 + xdigit_to_int(h2)
      if !is_bytes && val > 127 {
        return Err(self.make_error(str_start, "non-ASCII hex escape"))
      }
      buf.push(val.to_byte())
    }
    0x75 =>
      // Unicode: \uNNNN — accepted in both string and bytes literals.
      // In bytes, the codepoint is encoded as UTF-8 bytes.
      match self.read_unicode_escape(str_start, "\\u", 4) {
        Err(e) => return Err(e)
        Ok(cp) => {
          if cp >= unicode_surr_lo && cp < unicode_surr_hi {
            return Err(
              self.make_error(
                str_start,
                "invalid Unicode code point U+\{int_to_hex4_upper(cp)}",
              ),
            )
          }
          append_utf8_codepoint(cp, buf)
        }
      }
    0x55 =>
      // Unicode: \UNNNNNNNN — accepted in both string and bytes literals.
      match self.read_unicode_escape(str_start, "\\U", 8) {
        Err(e) => return Err(e)
        Ok(cp) => {
          if cp > unicode_max_codepoint {
            let seq = int_to_hex8_lower(cp)
            return Err(
              self.make_error(
                str_start,
                "code point out of range: \\U\{seq} (max \\U\{seq})",
              ),
            )
          }
          if cp >= unicode_surr_lo && cp < unicode_surr_hi {
            return Err(
              self.make_error(
                str_start,
                "invalid Unicode code point U+\{int_to_hex4_upper(cp)}",
              ),
            )
          }
          append_utf8_codepoint(cp, buf)
        }
      }
    _ =>
      return Err(
        self.make_error(
          str_start,
          "invalid escape sequence \\\{n.unsafe_to_char()}",
        ),
      )
  }
  Ok(())
}

///|
// Read count hex digits for a Unicode escape (\uNNNN or \UNNNNNNNN).
// prefix is the already-consumed prefix ("\\u" or "\\U") for error messages.
// Distinguishes truncated (not enough chars) from invalid (non-hex char present).
fn Scanner::read_unicode_escape(
  self : Scanner,
  pos : @errors.Position,
  prefix : String,
  count : Int,
) -> Result[Int, @errors.SyntaxError] {
  let digits : Array[Char] = []
  let mut result = 0
  for _ in 0..<count {
    let b = self.peek_byte()
    if is_xdigit_byte(b) {
      digits.push(b.to_int().unsafe_to_char())
      result = result * 16 + xdigit_to_int(b)
      self.read_byte() |> ignore
    } else {
      // Peek: is the next char a visible (non-terminator) char?
      let is_visible = b != b'\x00' && b != b'"' && b != b'\'' && b != b'\n'
      let partial = String::from_array(digits)
      if is_visible {
        // Consume the non-hex char and call it "invalid"
        self.read_byte() |> ignore
        let bad = b.to_int().unsafe_to_char()
        return Err(
          self.make_error(
            pos,
            "invalid escape sequence \{prefix}\{partial}\{bad}",
          ),
        )
      } else {
        return Err(
          self.make_error(pos, "truncated escape sequence \{prefix}\{partial}"),
        )
      }
    }
  }
  Ok(result)
}

///|
fn int_to_octal(n : Int) -> String {
  if n == 0 {
    return "0"
  }
  let mut v = n
  let buf = StringBuilder::new()
  let mut shift = 1
  while shift * 8 <= v {
    shift *= 8
  }
  while shift > 0 {
    buf.write_char((0x30 + v / shift).unsafe_to_char())
    v = v % shift
    shift /= 8
  }
  buf.to_string()
}

///|
fn int_to_octal3(n : Int) -> String {
  let d2 = n / 64
  let rem = n % 64
  let d1 = rem / 8
  let d0 = rem % 8
  "\{d2}\{d1}\{d0}"
}

///|
fn hex_char_upper(n : Int) -> Char {
  if n < 10 {
    (b'0'.to_int() + n).unsafe_to_char()
  } else {
    (b'A'.to_int() + n - 10).unsafe_to_char()
  }
}

///|
fn int_to_hex4_upper(n : Int) -> String {
  let buf = StringBuilder::new()
  buf.write_char(hex_char_upper((n >> 12) & 0xF))
  buf.write_char(hex_char_upper((n >> 8) & 0xF))
  buf.write_char(hex_char_upper((n >> 4) & 0xF))
  buf.write_char(hex_char_upper(n & 0xF))
  buf.to_string()
}

///|
fn int_to_hex8_lower(n : Int) -> String {
  let buf = StringBuilder::new()
  @utf8util.write_hex8(buf, n)
  buf.to_string()
}

// --- Byte classification ---

///|
fn is_digit_byte(b : Byte) -> Bool {
  b >= b'0' && b <= b'9'
}

///|
fn is_odigit_byte(b : Byte) -> Bool {
  b >= b'0' && b <= b'7'
}

///|
fn is_xdigit_byte(b : Byte) -> Bool {
  (b >= b'0' && b <= b'9') ||
  (b >= b'a' && b <= b'f') ||
  (b >= b'A' && b <= b'F')
}

///|
fn is_bdigit_byte(b : Byte) -> Bool {
  b == b'0' || b == b'1'
}

///|
fn is_ident_start_byte(b : Byte) -> Bool {
  (b >= b'a' && b <= b'z') || (b >= b'A' && b <= b'Z') || b == b'_'
}

///|
fn is_ident_byte(b : Byte) -> Bool {
  is_digit_byte(b) || is_ident_start_byte(b)
}

// is_unicode_letter_rune returns true if cp is a Unicode letter (L category).
// Backed by an exact, sorted range table (`unicode_letter_ranges`) derived from
// the Unicode Character Database; looked up by binary search.

///|
fn is_unicode_letter_rune(cp : Int) -> Bool {
  let ranges = unicode_letter_ranges
  let n = ranges.length() / 2
  let mut lo = 0
  let mut hi = n
  while lo < hi {
    let mid = (lo + hi) / 2
    let start = ranges[mid * 2]
    let end = ranges[mid * 2 + 1]
    if cp < start {
      hi = mid
    } else if cp > end {
      lo = mid + 1
    } else {
      return true
    }
  }
  false
}

///|
fn xdigit_to_int(b : Byte) -> Int {
  let n = b.to_int()
  if n >= 0x30 && n <= 0x39 {
    n - 0x30
  } else if n >= 0x61 && n <= 0x66 {
    n - 0x61 + 10
  } else {
    n - 0x41 + 10
  }
}

// --- UTF-8 encoder for Unicode codepoints ---

///|
fn append_utf8_codepoint(cp : Int, buf : Array[Byte]) -> Unit {
  if cp < 0x80 {
    buf.push(cp.to_byte())
  } else if cp < 0x800 {
    buf.push((0xC0 | (cp >> 6)).to_byte())
    buf.push((0x80 | (cp & 0x3F)).to_byte())
  } else if cp < 0x10000 {
    buf.push((0xE0 | (cp >> 12)).to_byte())
    buf.push((0x80 | ((cp >> 6) & 0x3F)).to_byte())
    buf.push((0x80 | (cp & 0x3F)).to_byte())
  } else {
    buf.push((0xF0 | (cp >> 18)).to_byte())
    buf.push((0x80 | ((cp >> 12) & 0x3F)).to_byte())
    buf.push((0x80 | ((cp >> 6) & 0x3F)).to_byte())
    buf.push((0x80 | (cp & 0x3F)).to_byte())
  }
}

// --- Integer and float parsers ---

///|
fn parse_int_decimal(s : String) -> Result[BigInt, String] {
  if s.length() == 0 {
    return Err("empty integer")
  }
  for i in 0..<s.length() {
    let c = s[i]
    if c < '0' || c > '9' {
      return Err("invalid digit in decimal literal")
    }
  }
  Ok(BigInt::from_string(s))
}

///|
fn parse_int_hex(s : String) -> Result[BigInt, String] {
  if s.length() == 0 {
    return Err("empty hex literal")
  }
  let bytes = @utf8.encode(s)
  for i in 0..<bytes.length() {
    if !is_xdigit_byte(bytes[i]) {
      return Err("invalid hex digit")
    }
  }
  Ok(BigInt::from_string(s, radix=16))
}

///|
fn parse_int_base(s : String, base : Int) -> Result[BigInt, String] {
  if s.length() == 0 {
    return Err("empty literal")
  }
  let bytes = @utf8.encode(s)
  for i in 0..<bytes.length() {
    let d = bytes[i].to_int() - 0x30
    if d < 0 || d >= base {
      return Err("invalid digit for base \{base}")
    }
  }
  Ok(BigInt::from_string(s, radix=base))
}

///|
fn parse_float_str(s : String) -> Result[Double, String] {
  if s.length() == 0 {
    return Err("empty float string")
  }
  Ok(@string.parse_double(s)) catch {
    _ => Err("invalid float literal: \{s}")
  }
}
