// Scanner tests — TDD: these tests define the contract before implementation.
// Reference: starlark-go/syntax/scan_test.go

// scan tokenises src and returns a space-joined string of token representations.
// On scan error the error position and message are returned instead.

///|
fn scan(src : String) -> String {
  let sc = Scanner::new("foo.star", src)
  let buf = StringBuilder::new()
  let mut first = true
  while true {
    let result = sc.next_token()
    let st = match result {
      Err(e) => return e.to_string()
      Ok(st) => st
    }
    if first {
      first = false
    } else {
      buf.write_char(' ')
    }
    let s = tok_to_test_string(st.token())
    buf.write_string(s)
    match st.token() {
      EOF => break
      _ => ()
    }
  }
  buf.to_string()
}

// tok_to_test_string formats a token the same way starlark-go scan_test.go does.

///|
fn tok_to_test_string(tok : Token) -> String {
  match tok {
    EOF => "EOF"
    Newline => "newline"
    Indent => "indent"
    Outdent => "outdent"
    Ident(s) => s
    Int(n) => n.to_string()
    BigInt(s) => s
    Float(f) => format_float_e(f)
    Str(s) => quote_str(s)
    Bytes(b) => quote_bytes(b)
    _ => tok.to_string()
  }
}

// format_float_e formats a double in Go-style %e format: d.ddddddE±dd

///|
fn format_float_e(f : Double) -> String {
  if f != f {
    return "nan"
  }
  if f == @double.infinity {
    return "+inf"
  }
  if f == @double.neg_infinity {
    return "-inf"
  }
  // Use simple representation for now and convert to e-notation
  // Compute exponent
  let abs = if f < 0.0 { -f } else { f }
  if abs == 0.0 {
    return "0.000000e+00"
  }
  let mut exp = 0
  let mut m = abs
  while m >= 10.0 {
    m /= 10.0
    exp += 1
  }
  while m < 1.0 {
    m *= 10.0
    exp -= 1
  }
  // Round to 6 decimal places
  let factor = 1000000.0
  let rounded = (m * factor + 0.5).to_int64().to_double() / factor
  let sign = if f < 0.0 { "-" } else { "" }
  let exp_sign = if exp >= 0 { "+" } else { "-" }
  let exp_abs = if exp >= 0 { exp } else { -exp }
  let exp_str = if exp_abs < 10 { "0\{exp_abs}" } else { exp_abs.to_string() }
  // Format mantissa with 6 decimal places
  let int_part = rounded.to_int64()
  let frac = rounded - int_part.to_double()
  let frac_int = (frac * factor + 0.5).to_int64()
  let frac_str = pad_left_zeros(frac_int.to_string(), 6)
  "\{sign}\{int_part}.\{frac_str}e\{exp_sign}\{exp_str}"
}

///|
fn pad_left_zeros(s : String, width : Int) -> String {
  if s.length() >= width {
    s
  } else {
    String::make(width - s.length(), '0') + s
  }
}

// quote_str produces a double-quoted Starlark string literal.

///|
fn quote_str(s : String) -> String {
  let b = StringBuilder::new()
  b.write_char('"')
  for c in s {
    match c {
      '"' => b.write_string("\\\"")
      '\\' => b.write_string("\\\\")
      '\n' => b.write_string("\\n")
      '\r' => b.write_string("\\r")
      '\t' => b.write_string("\\t")
      _ => {
        let n = c.to_int()
        if n >= 0x20 && n < 0x7F {
          b.write_char(c)
        } else if n < 0x80 {
          b.write_string("\\x")
          b.write_char(hex_digit((n >> 4) & 0xF))
          b.write_char(hex_digit(n & 0xF))
        } else {
          b.write_char(c)
        }
      }
    }
  }
  b.write_char('"')
  b.to_string()
}

// quote_bytes produces a b"..."-quoted Starlark bytes literal.

///|
fn quote_bytes(bs : Bytes) -> String {
  let b = StringBuilder::new()
  b.write_string("b\"")
  for i in 0..<bs.length() {
    let n = bs[i].to_int()
    match n {
      0x22 => b.write_string("\\\"")
      0x5C => b.write_string("\\\\")
      0x0A => b.write_string("\\n")
      0x0D => b.write_string("\\r")
      0x09 => b.write_string("\\t")
      _ =>
        if n >= 0x20 && n < 0x7F {
          b.write_char(n.unsafe_to_char())
        } else {
          b.write_string("\\x")
          b.write_char(hex_digit((n >> 4) & 0xF))
          b.write_char(hex_digit(n & 0xF))
        }
    }
  }
  b.write_char('"')
  b.to_string()
}

///|
fn hex_digit(n : Int) -> Char {
  if n < 10 {
    ('0'.to_int() + n).unsafe_to_char()
  } else {
    ('a'.to_int() + n - 10).unsafe_to_char()
  }
}

// --- Basic token tests ---

///|
test "scan: empty source produces EOF" {
  assert_eq(scan(""), "EOF")
}

///|
test "scan: integer literal" {
  assert_eq(scan("123"), "123 EOF")
}

///|
test "scan: zero" {
  assert_eq(scan("0"), "0 EOF")
}

///|
test "scan: identifier" {
  assert_eq(scan("x"), "x EOF")
}

///|
test "scan: dotted access" {
  assert_eq(scan("x.y"), "x . y EOF")
}

///|
test "scan: identifier with dot and Unicode" {
  assert_eq(scan("chocolate.éclair"), "chocolate . éclair EOF")
}

///|
test "scan: mixed tokens on one line" {
  assert_eq(scan("123 \"foo\" hello x.y"), "123 \"foo\" hello x . y EOF")
}

///|
test "scan: function call" {
  assert_eq(scan("print(x)"), "print ( x ) EOF")
}

///|
test "scan: semicolons" {
  assert_eq(scan("print(x); print(y)"), "print ( x ) ; print ( y ) EOF")
}

///|
test "scan: newline inside parens is ignored" {
  assert_eq(scan("\nprint(\n1\n)\n"), "print ( 1 ) newline EOF")
}

///|
test "scan: slash operators" {
  assert_eq(scan("/ // /= //= ///="), "/ // /= //= // /= EOF")
}

///|
test "scan: comment is skipped" {
  assert_eq(scan("# hello\nprint(x)"), "print ( x ) EOF")
}

///|
test "scan: EOF acts as implicit newline at top level" {
  assert_eq(scan("def f(): pass"), "def f ( ) : pass EOF")
}

///|
test "scan: indented block with tab" {
  assert_eq(
    scan("def f():\n\tpass"),
    "def f ( ) : newline indent pass newline outdent EOF",
  )
}

///|
test "scan: comment after dedented block" {
  assert_eq(
    scan("def f():\n\tpass\n# oops"),
    "def f ( ) : newline indent pass newline outdent EOF",
  )
}

///|
test "scan: trailing spaces after dedent" {
  assert_eq(
    scan("def f():\n\tpass\n"),
    "def f ( ) : newline indent pass newline outdent EOF",
  )
}

///|
test "scan: consecutive blank lines are consolidated" {
  assert_eq(scan("pass\n\n\npass"), "pass newline pass EOF")
}

///|
test "scan: trailing whitespace after final newline" {
  assert_eq(
    scan("def f():\n    pass\n    "),
    "def f ( ) : newline indent pass newline outdent EOF",
  )
}

///|
test "scan: bare pass with no newline" {
  assert_eq(scan("pass"), "pass EOF")
}

///|
test "scan: pass with newline" {
  assert_eq(scan("pass\n"), "pass newline EOF")
}

///|
test "scan: pass with trailing spaces" {
  assert_eq(scan("pass\n "), "pass newline EOF")
}

///|
test "scan: if block indentation" {
  assert_eq(
    scan("if x:\n  pass\n "),
    "if x : newline indent pass newline outdent EOF",
  )
}

///|
test "scan: line continuation with backslash" {
  assert_eq(scan("x = 1 + \\\n2"), "x = 1 + 2 EOF")
}

// --- String literal tests ---

///|
test "scan: string with escape newline" {
  assert_eq(scan("x = 'a\\nb'"), "x = \"a\\nb\" EOF")
}

///|
test "scan: raw string does not interpret escapes" {
  assert_eq(scan("x = r'a\\nb'"), "x = \"a\\\\nb\" EOF")
}

///|
test "scan: string with backslash-newline continuation in literal" {
  assert_eq(scan("x = 'a\\\nb'"), "x = \"ab\" EOF")
}

///|
test "scan: string with escaped single quote" {
  assert_eq(scan("x = '\\''"), "x = \"'\" EOF")
}

///|
test "scan: string with escaped double quote" {
  assert_eq(scan("x = \"\\\"\""), "x = \"\\\"\" EOF")
}

///|
test "scan: triple-quoted string" {
  assert_eq(scan("x = '''\\''''"), "x = \"'\" EOF")
}

///|
test "scan: triple-quoted string with internal quotes" {
  assert_eq(scan("x = ''''a'b'c'''"), "x = \"'a'b'c\" EOF")
}

///|
test "scan: triple-quoted string with newline" {
  assert_eq(scan("x = '''a\nb'''"), "x = \"a\\nb\" EOF")
}

// --- Number tests ---

///|
test "scan: float starting with dot" {
  assert_eq(scan(".0"), "0.000000e+00 EOF")
}

///|
test "scan: integer zero with dot" {
  assert_eq(scan("0."), "0.000000e+00 EOF")
}

///|
test "scan: float 1.5" {
  assert_eq(scan("1.5"), "1.500000e+00 EOF")
}

///|
test "scan: float with exponent" {
  assert_eq(scan("1e1"), "1.000000e+01 EOF")
}

///|
test "scan: float with positive exponent" {
  assert_eq(scan("1e+1"), "1.000000e+01 EOF")
}

///|
test "scan: float with negative exponent" {
  assert_eq(scan("1e-1"), "1.000000e-01 EOF")
}

///|
test "scan: float 1.0" {
  assert_eq(scan("1."), "1.000000e+00 EOF")
}

///|
test "scan: float 0.1" {
  assert_eq(scan(".1"), "1.000000e-01 EOF")
}

///|
test "scan: lone dot is not a float" {
  assert_eq(scan(".e1"), ". e1 EOF")
}

///|
test "scan: hex integer" {
  assert_eq(scan("0xA"), "10 EOF")
}

///|
test "scan: hex integer uppercase X" {
  assert_eq(scan("0XA"), "10 EOF")
}

///|
test "scan: hex followed by non-hex" {
  assert_eq(scan("0xAAG"), "170 G EOF")
}

///|
test "scan: invalid hex literal error" {
  assert_true(scan("0xG").contains("invalid hex literal"))
}

///|
test "scan: hex integer with dot is int then dot" {
  assert_eq(scan("0xA."), "10 . EOF")
}

///|
test "scan: binary integer" {
  assert_eq(scan("0b1010"), "10 EOF")
}

///|
test "scan: binary uppercase B" {
  assert_eq(scan("0B111101"), "61 EOF")
}

///|
test "scan: invalid binary literal" {
  assert_true(scan("0b3").contains("invalid binary literal"))
}

///|
test "scan: octal integer" {
  assert_eq(scan("0o123"), "83 EOF")
}

///|
test "scan: old-style octal is error" {
  assert_true(scan("0123").contains("obsolete form of octal literal"))
}

///|
test "scan: zero followed by zero is valid" {
  assert_eq(scan("00"), "0 EOF")
}

// --- Newline handling ---

///|
test "scan: carriage return treated as newline" {
  assert_eq(scan("a\rb"), "a newline b EOF")
}

///|
test "scan: CRLF treated as single newline" {
  assert_eq(scan("a\r\nb"), "a newline b EOF")
}

///|
test "scan: double newline consolidated" {
  assert_eq(scan("a\n\nb"), "a newline b EOF")
}

// --- Operator tests ---

///|
test "scan: all augmented assignment operators" {
  assert_eq(scan("+="), "+= EOF")
  assert_eq(scan("-="), "-= EOF")
  assert_eq(scan("*="), "*= EOF")
  assert_eq(scan("/="), "/= EOF")
  assert_eq(scan("//="), "//= EOF")
  assert_eq(scan("%="), "%= EOF")
  assert_eq(scan("&="), "&= EOF")
  assert_eq(scan("|="), "|= EOF")
  assert_eq(scan("^="), "^= EOF")
  assert_eq(scan("<<="), "<<= EOF")
  assert_eq(scan(">>="), ">>= EOF")
  assert_eq(scan("**"), "** EOF")
}

///|
test "scan: comparison operators" {
  assert_eq(scan("=="), "== EOF")
  assert_eq(scan("!="), "!= EOF")
  assert_eq(scan("<="), "<= EOF")
  assert_eq(scan(">="), ">= EOF")
  assert_eq(scan("<<"), "<< EOF")
  assert_eq(scan(">>"), ">> EOF")
}

///|
test "scan: keywords" {
  assert_eq(
    scan(
      "and break continue def elif else for if in lambda load not or pass return while",
    ),
    "and break continue def elif else for if in lambda load not or pass return while EOF",
  )
}

///|
test "scan: reserved keywords" {
  assert_eq(
    scan(
      "as async await class del except finally from global import is nonlocal raise try with yield",
    ),
    "as async await class del except finally from global import is nonlocal raise try with yield EOF",
  )
}

///|
test "scan: program with function calls and indented block" {
  let src =
    #|print(1)
    #|cc_binary(name="foo")
    #|def f(x):
    #|	return x+1
    #|print(1)
    #|
  assert_eq(
    scan(src),
    "print ( 1 ) newline cc_binary ( name = \"foo\" ) newline def f ( x ) : newline indent return x + 1 newline outdent print ( 1 ) newline EOF",
  )
}

// --- Bytes literal tests ---

///|
test "scan: bytes literal" {
  let result = sc_tok("b\"abc\"")
  match result {
    Bytes(b) => assert_eq(@utf8.decode_lossy(b[:]), "abc")
    _ => fail("expected Bytes token")
  }
}

///|
test "scan: bytes literal with escape" {
  let result = sc_tok("b\"\\x41\"")
  match result {
    Bytes(b) => assert_eq(b[0].to_int(), 0x41)
    _ => fail("expected Bytes token")
  }
}

// sc_tok returns the first non-whitespace token (skipping EOF check)

///|
fn sc_tok(src : String) -> Token {
  let sc = Scanner::new("test.star", src)
  match sc.next_token() {
    Ok(st) => st.token()
    Err(e) => abort(e.to_string())
  }
}

// --- Position tests ---

///|
test "scan: position of first token" {
  let sc = Scanner::new("foo.star", "abc")
  let st = sc.next_token().unwrap()
  assert_eq(st.pos().line(), 1)
  assert_eq(st.pos().col(), 1)
}

///|
test "scan: position after leading whitespace" {
  let sc = Scanner::new("foo.star", "  abc")
  let st = sc.next_token().unwrap()
  assert_eq(st.pos().line(), 1)
  assert_eq(st.pos().col(), 3)
}

// --- Quote / Unquote ---

///|
test "quote: plain ASCII string produces double-quoted literal" {
  assert_eq(quote("hello", false), "\"hello\"")
}

///|
test "quote: string with special chars escapes them" {
  assert_eq(quote("a\nb", false), "\"a\\nb\"")
  assert_eq(quote("a\tb", false), "\"a\\tb\"")
  assert_eq(quote("a\\b", false), "\"a\\\\b\"")
  assert_eq(quote("a\"b", false), "\"a\\\"b\"")
}

///|
test "quote: bytes mode adds b prefix" {
  assert_eq(quote("hello", true), "b\"hello\"")
}

///|
test "quote: newline escape" {
  assert_eq(quote("\n", false), "\"\\n\"")
}

///|
test "unquote: plain double-quoted string" {
  match unquote("\"hello\"") {
    Ok((s, is_bytes)) => {
      assert_eq(s, "hello")
      assert_eq(is_bytes, false)
    }
    Err(e) => fail("unexpected error: \{e}")
  }
}

///|
test "unquote: plain single-quoted string" {
  match unquote("'hello'") {
    Ok((s, is_bytes)) => {
      assert_eq(s, "hello")
      assert_eq(is_bytes, false)
    }
    Err(e) => fail("unexpected error: \{e}")
  }
}

///|
test "unquote: escape sequences decoded" {
  match unquote("\"a\\nb\"") {
    Ok((s, _)) => assert_eq(s, "a\nb")
    Err(e) => fail("unexpected error: \{e}")
  }
  match unquote("\"a\\tb\"") {
    Ok((s, _)) => assert_eq(s, "a\tb")
    Err(e) => fail("unexpected error: \{e}")
  }
}

///|
test "unquote: bytes literal detected" {
  match unquote("b\"hello\"") {
    Ok((s, is_bytes)) => {
      assert_eq(s, "hello")
      assert_eq(is_bytes, true)
    }
    Err(e) => fail("unexpected error: \{e}")
  }
}

///|
test "unquote: raw string skips escape processing" {
  match unquote("r\"a\\nb\"") {
    Ok((s, _)) => assert_eq(s, "a\\nb")
    Err(e) => fail("unexpected error: \{e}")
  }
}

///|
test "unquote: triple-quoted string" {
  match unquote("\"\"\"hello world\"\"\"") {
    Ok((s, _)) => assert_eq(s, "hello world")
    Err(e) => fail("unexpected error: \{e}")
  }
}

///|
test "unquote: hex escape \\xNN" {
  match unquote("\"\\x41\"") {
    Ok((s, _)) => assert_eq(s, "A")
    Err(e) => fail("unexpected error: \{e}")
  }
}

///|
test "unquote: error on truncated literal" {
  match unquote("\"") {
    Ok(_) => fail("expected error")
    Err(_) => ()
  }
}

///|
test "unquote: error on invalid escape" {
  match unquote("\"\\q\"") {
    Ok(_) => fail("expected error")
    Err(_) => ()
  }
}

// --- Keyword literal token tests ---

///|
test "scan: None is a keyword token" {
  assert_eq(scan("None"), "None EOF")
}

///|
test "scan: True is a keyword token" {
  assert_eq(scan("True"), "True EOF")
}

///|
test "scan: False is a keyword token" {
  assert_eq(scan("False"), "False EOF")
}

///|
test "scan: None True False in expression context" {
  assert_eq(scan("x = None"), "x = None EOF")
  assert_eq(scan("if True:"), "if True : EOF")
  assert_eq(scan("not False"), "not False EOF")
}
