///|
/// Compares two strings lexicographically by Unicode code point order,
/// decoding UTF-16 surrogate pairs as needed.
///
/// Returns a negative integer if `a` < `b`, zero if equal, or a positive
/// integer if `a` > `b`.
fn str_lex_cmp(a : String, b : String) -> Int {
  let la = a.length()
  let lb = b.length()
  let mut ia = 0
  let mut ib = 0
  while ia < la && ib < lb {
    let (cp_a, step_a) = @utf8util.utf16_decode_cp(a, ia, la)
    let (cp_b, step_b) = @utf8util.utf16_decode_cp(b, ib, lb)
    if cp_a < cp_b {
      return -1
    }
    if cp_a > cp_b {
      return 1
    }
    ia += step_a
    ib += step_b
  }
  if ia < la {
    1
  } else if ib < lb {
    -1
  } else {
    0
  }
}

///|
// Reports whether every byte is printable ASCII (0x20..0x7f). Matches
// starlark-go's `isPrintableASCII` (`b >= 0x20 && b < 0x80`).
fn is_printable_ascii(bytes : Bytes) -> Bool {
  for i in 0..<bytes.length() {
    let b = bytes[i].to_int()
    if b < 0x20 || b >= 0x80 {
      return false
    }
  }
  true
}

///|
// UTF-16 surrogate-pair decoding bounds (used by JSON `\uXXXX` escapes).
// A code point above the BMP is encoded as a high surrogate in
// [0xD800, 0xDBFF] followed by a low surrogate in [0xDC00, 0xDFFF].
let high_surrogate_lo : Int = 0xD800

///|
let high_surrogate_hi : Int = 0xDBFF

///|
let low_surrogate_lo : Int = 0xDC00

///|
let low_surrogate_hi : Int = 0xDFFF

///|
// First code point of the supplementary planes (U+10000); the base added
// back when recombining a surrogate pair.
let supplementary_plane_base : Int = 0x10000

///|
// Each surrogate half contributes 10 bits, so the high half is scaled by
// 2^10 = 0x400 when recombining.
let surrogate_high_scale : Int = 0x400

///|
// U+FFFD REPLACEMENT CHARACTER, substituted for malformed surrogate escapes.
let json_replacement_rune : Int = 0xFFFD

///|
let max_materialise_len : Int64 = 2147483647L

///|
let json_max_nesting_depth : Int = 10000

///|
// Quotes a printable-ASCII string the way Go's `strconv.AppendQuote` does:
// only `"`, `\`, and the DEL byte (0x7f) are escaped; everything else is
// written verbatim.
fn quote_printable_ascii(bytes : Bytes, buf : StringBuilder) -> Unit {
  buf.write_char('"')
  for i in 0..<bytes.length() {
    let b = bytes[i].to_int()
    if b == 0x22 {
      buf.write_string("\\\"")
    } else if b == 0x5C {
      buf.write_string("\\\\")
    } else if b == 0x7F {
      buf.write_string("\\u007f")
    } else {
      buf.write_char(b.unsafe_to_char())
    }
  }
  buf.write_char('"')
}

///|
// Quotes a string the way Go's `encoding/json.Marshal` does: valid multi-byte
// runes are emitted as raw UTF-8, invalid bytes become U+FFFD, `<`/`>`/`&` and
// U+2028/U+2029 are escaped for HTML/JS safety, and control bytes use the
// `\n`/`\r`/`\t` shortcuts or `\u00XX`.
fn marshal_string(bytes : Bytes, buf : StringBuilder) -> Unit {
  buf.write_char('"')
  let len = bytes.length()
  let mut i = 0
  while i < len {
    let b0 = bytes[i].to_int()
    if b0 < 0x80 {
      match b0 {
        0x22 => buf.write_string("\\\"")
        0x5C => buf.write_string("\\\\")
        0x0A => buf.write_string("\\n")
        0x0D => buf.write_string("\\r")
        0x09 => buf.write_string("\\t")
        0x3C => buf.write_string("\\u003c")
        0x3E => buf.write_string("\\u003e")
        0x26 => buf.write_string("\\u0026")
        _ =>
          if b0 < 0x20 {
            buf.write_string("\\u00")
            buf.write_char(@utf8util.hex_char((b0 >> 4) & 0xF))
            buf.write_char(@utf8util.hex_char(b0 & 0xF))
          } else {
            buf.write_char(b0.unsafe_to_char())
          }
      }
      i += 1
    } else {
      let (r, width) = @utf8util.utf8_decode_rune(bytes, i)
      if r < 0 {
        buf.write_string("\\ufffd")
        i += 1
      } else if r == 0x2028 || r == 0x2029 {
        buf.write_string("\\u")
        @utf8util.write_hex4(buf, r)
        i += width
      } else {
        buf.write_char(r.unsafe_to_char())
        i += width
      }
    }
  }
  buf.write_char('"')
}

///|
/// Produces the JSON-quoted form of a Starlark string, choosing between
/// printable-ASCII fast path and full Unicode marshal as appropriate.
fn json_quote_string(s : @value.StarlarkString) -> String {
  let buf = StringBuilder::new()
  let bytes = s.to_bytes()
  if is_printable_ascii(bytes) {
    quote_printable_ascii(bytes, buf)
  } else {
    marshal_string(bytes, buf)
  }
  buf.to_string()
}

///|
fn format_nonfinite(f : Double) -> String {
  if f.is_nan() {
    "nan"
  } else if f > 0.0 {
    "+inf"
  } else {
    "-inf"
  }
}

///|
fn format_float_json(f : Double) -> String {
  @numeric.format_float(f)
}

///|
/// Tracks which mutable containers (lists, dicts, tuples) are currently on
/// the encoding stack to detect cycles in the value graph.
priv struct EncodeState {
  list_path : Array[@value.StarlarkList]
  dict_path : Array[@value.StarlarkDict]
  tuple_path : Array[Array[@value.Value]]
}

///|
/// Creates a fresh `EncodeState` with empty ancestor paths.
fn EncodeState::new() -> EncodeState {
  { list_path: [], dict_path: [], tuple_path: [] }
}

///|
/// Recursively encodes a Starlark value to a JSON string, tracking the
/// current nesting depth and ancestor containers to detect cycles.
///
/// Parameters:
///
/// - `v` : The Starlark value to encode.
/// - `state` : Ancestor-container sets used for cycle detection.
/// - `depth` : Current nesting depth; returns `Err` when it reaches
///   `json_max_nesting_depth`.
///
/// Returns `Ok(json_string)` or `Err(message)` describing the first
/// encoding failure encountered.
fn encode_inner(
  v : @value.Value,
  state : EncodeState,
  depth : Int,
) -> Result[String, String] {
  match v {
    @value.Value::None => Ok("null")
    @value.Value::Bool(b) => Ok(if b { "true" } else { "false" })
    @value.Value::Int(n) => Ok(n.to_string())
    @value.Value::Float(f) =>
      if f.is_nan() || f.is_inf() {
        Err("cannot encode non-finite float \{format_nonfinite(f)}")
      } else {
        Ok(format_float_json(f))
      }
    @value.Value::String(s) => Ok(json_quote_string(s))
    @value.Value::List(l) => {
      if depth >= json_max_nesting_depth {
        return Err("nesting depth limit exceeded")
      }
      if state.list_path.iter().any(fn(pl) { physical_equal(l, pl) }) {
        return Err("cycle in JSON structure")
      }
      state.list_path.push(l)
      let result = encode_sequence(l.iter(), "list", state, depth + 1)
      let _ = state.list_path.pop()
      result
    }
    @value.Value::Tuple(t) => {
      if depth >= json_max_nesting_depth {
        return Err("nesting depth limit exceeded")
      }
      if state.tuple_path.iter().any(fn(pt) { physical_equal(pt, t) }) {
        return Err("cycle in JSON structure")
      }
      state.tuple_path.push(t)
      let result = encode_sequence(t.iter(), "tuple", state, depth + 1)
      let _ = state.tuple_path.pop()
      result
    }
    @value.Value::Dict(d) => {
      if depth >= json_max_nesting_depth {
        return Err("nesting depth limit exceeded")
      }
      if state.dict_path.iter().any(fn(pd) { physical_equal(pd, d) }) {
        return Err("cycle in JSON structure")
      }
      state.dict_path.push(d)
      let result = encode_dict_val(d, state, depth + 1)
      let _ = state.dict_path.pop()
      result
    }
    @value.Value::Range(r) => {
      if depth >= json_max_nesting_depth {
        return Err("nesting depth limit exceeded")
      }
      let len = r.length()
      if len > max_materialise_len {
        return Err("cannot encode range of length \{len} as JSON: too large")
      }
      let n = len.to_int()
      let items : Array[@value.Value] = Array::make(n, @value.Value::None)
      for i in 0..<n {
        items[i] = @value.Value::Int(
          BigInt::from_int64(r.index_at(i.to_int64())),
        )
      }
      encode_sequence(items.iter(), "range", state, depth + 1)
    }
    @value.Value::Set(s) => {
      if depth >= json_max_nesting_depth {
        return Err("nesting depth limit exceeded")
      }
      let items : Array[@value.Value] = []
      s.each(fn(k) { items.push(k) })
      encode_sequence(items.iter(), "set", state, depth + 1)
    }
    @value.Value::ExtVal(c) =>
      match c.get_attr_names() {
        Some(names) => {
          if depth >= json_max_nesting_depth {
            return Err("nesting depth limit exceeded")
          }
          encode_ext_val_as_object(c, names, state, depth + 1)
        }
        None => Err("cannot encode \{v.type_name()} as JSON")
      }
    _ => Err("cannot encode \{v.type_name()} as JSON")
  }
}

///|
/// Encodes a custom Starlark value as a JSON object using its `dir()`
/// attribute names as keys, sorted lexicographically.
///
/// Parameters:
///
/// - `c` : The custom value to encode.
/// - `names` : The attribute names returned by `get_attr_names()`.
/// - `state` : Ancestor-container sets used for cycle detection.
/// - `depth` : Current nesting depth passed down to recursive calls.
fn encode_ext_val_as_object(
  c : @value.CustomValue,
  names : Array[String],
  state : EncodeState,
  depth : Int,
) -> Result[String, String] {
  let sorted = names.copy()
  sorted.sort_by(fn(a, b) { str_lex_cmp(a, b) })
  let buf = StringBuilder::new()
  buf.write_char('{')
  let mut first = true
  for name in sorted {
    match c.get_attr(name) {
      Err(e) =>
        return Err("cannot access attribute \{c.get_type_name()}.\{name}: \{e}")
      Ok(None) =>
        return Err(
          "missing attribute \{c.get_type_name()}.\{name} (despite appearing in dir())",
        )
      Ok(Some(v)) => {
        if first {
          first = false
        } else {
          buf.write_char(',')
        }
        buf.write_string(json_quote_string(@value.StarlarkString::new(name)))
        buf.write_char(':')
        match encode_inner(v, state, depth) {
          Err(e) => return Err("in field .\{name}: \{e}")
          Ok(s) => buf.write_string(s)
        }
      }
    }
  }
  buf.write_char('}')
  Ok(buf.to_string())
}

///|
/// Encodes an iterable of Starlark values as a JSON array.
///
/// Parameters:
///
/// - `items` : The elements to encode in order.
/// - `kind` : A human-readable name for the container type used in error
///   messages (e.g. `"list"`, `"tuple"`, `"range"`).
/// - `state` : Ancestor-container sets used for cycle detection.
/// - `depth` : Current nesting depth passed down to recursive calls.
fn encode_sequence(
  items : Iter[@value.Value],
  kind : String,
  state : EncodeState,
  depth : Int,
) -> Result[String, String] {
  let buf = StringBuilder::new()
  buf.write_char('[')
  let mut first = true
  let mut i = 0
  for elem in items {
    if first {
      first = false
    } else {
      buf.write_char(',')
    }
    match encode_inner(elem, state, depth) {
      Ok(s) => buf.write_string(s)
      Err(e) => return Err("at \{kind} index \{i}: \{e}")
    }
    i += 1
  }
  buf.write_char(']')
  Ok(buf.to_string())
}

///|
/// Encodes a Starlark dict as a JSON object, sorting keys lexicographically.
/// All keys must be strings; non-string keys produce an error.
///
/// Parameters:
///
/// - `d` : The dict to encode.
/// - `state` : Ancestor-container sets used for cycle detection.
/// - `depth` : Current nesting depth passed down to recursive calls.
fn encode_dict_val(
  d : @value.StarlarkDict,
  state : EncodeState,
  depth : Int,
) -> Result[String, String] {
  let pairs : Array[(String, @value.Value)] = []
  let mut first_err : String? = None
  d.each(fn(k, v) {
    if first_err is Some(_) {
      return
    }
    match k {
      @value.Value::String(s) => pairs.push((s.raw(), v))
      _ => first_err = Some("dict has \{k.type_name()} key, want string")
    }
  })
  if first_err is Some(e) {
    return Err(e)
  }
  pairs.sort_by(fn(a, b) { str_lex_cmp(a.0, b.0) })
  let buf = StringBuilder::new()
  buf.write_char('{')
  let mut first = true
  for pair in pairs {
    let (k, v) = pair
    if first {
      first = false
    } else {
      buf.write_char(',')
    }
    buf.write_string(json_quote_string(@value.StarlarkString::new(k)))
    buf.write_char(':')
    match encode_inner(v, state, depth) {
      Ok(s) => buf.write_string(s)
      Err(e) => return Err("in dict key \"\{k}\": \{e}")
    }
  }
  buf.write_char('}')
  Ok(buf.to_string())
}

///|
/// Encodes a Starlark value to a compact JSON string.
/// Supported types: `None`, `Bool`, `Int`, `Float`, `String`, `List`,
/// `Tuple`, `Dict`, `Range`, `Set`, and custom values (`ExtVal`) that
/// implement `get_attr_names()` (encoded as a JSON object). Returns `Err`
/// for non-finite floats, unsupported types, cycles, or nesting that
/// exceeds the depth limit.
///
/// Parameters:
///
/// - `v` : The Starlark value to encode.
///
/// Returns `Ok(json_string)` on success, or `Err(message)` if the value
/// cannot be represented as JSON.
///
/// ```mbt check
/// test {
///   inspect(encode_to_json(@value.Value::None).unwrap(), content="null")
///   inspect(encode_to_json(@value.Value::Bool(true)).unwrap(), content="true")
///   inspect(encode_to_json(@value.Value::new_int(42L)).unwrap(), content="42")
///   inspect(
///     encode_to_json(@value.Value::new_string("hi")).unwrap(),
///     content="\"hi\"",
///   )
///   let lst = @value.Value::new_list([
///     @value.Value::Int(1N),
///     @value.Value::Int(2N),
///   ])
///   inspect(encode_to_json(lst).unwrap(), content="[1,2]")
///   // Non-finite floats cannot be represented in JSON.
///   inspect(
///     encode_to_json(@value.Value::Float(@double.infinity)) is Err(_),
///     content="true",
///   )
/// }
/// ```
pub fn encode_to_json(v : @value.Value) -> Result[String, String] {
  let state = EncodeState::new()
  match encode_inner(v, state, 0) {
    Ok(s) => Ok(s)
    Err(e) => Err("json.encode: \{e}")
  }
}

///|
fn is_digit_char(c : Char) -> Bool {
  c.to_int() >= '0'.to_int() && c.to_int() <= '9'.to_int()
}

///|
fn is_hex_digit(c : Char) -> Bool {
  let cp = c.to_int()
  (cp >= '0'.to_int() && cp <= '9'.to_int()) ||
  (cp >= 'a'.to_int() && cp <= 'f'.to_int()) ||
  (cp >= 'A'.to_int() && cp <= 'F'.to_int())
}

///|
/// Parses exactly four hexadecimal characters starting at position `i` in
/// `chars` and returns the decoded integer value together with the position
/// after the four digits.
///
/// Parameters:
///
/// - `chars` : The character array being parsed.
/// - `i` : The index of the first hex digit.
///
/// Returns `(value, i+4)` on success or `(-1, i)` if fewer than four
/// characters remain or a non-hex character is encountered.
fn parse_hex4_at(chars : Array[Char], i : Int) -> (Int, Int) {
  if i + 4 > chars.length() {
    return (-1, i)
  }
  let mut val = 0
  for j in 0..<4 {
    let c = chars[i + j].to_int()
    let digit = if c >= '0'.to_int() && c <= '9'.to_int() {
      c - '0'.to_int()
    } else if c >= 'a'.to_int() && c <= 'f'.to_int() {
      c - 'a'.to_int() + 10
    } else if c >= 'A'.to_int() && c <= 'F'.to_int() {
      c - 'A'.to_int() + 10
    } else {
      return (-1, i)
    }
    val = (val << 4) | digit
  }
  (val, i + 4)
}

///|
/// Parses a JSON string literal starting at `start` (which must point to the
/// opening `"`), handling all standard JSON escape sequences including
/// `\uXXXX` and UTF-16 surrogate pairs.
///
/// Parameters:
///
/// - `chars` : The character array being parsed.
/// - `start` : Index of the opening `"`.
///
/// Returns `Ok((string_value, position_after_closing_quote))` on success, or
/// `Err((error_offset, message))` on a malformed escape, control character,
/// or unclosed literal.
fn parse_json_string(
  chars : Array[Char],
  start : Int,
) -> Result[(String, Int), (Int, String)] {
  let len = chars.length()
  let buf = StringBuilder::new()
  let mut i = start + 1
  while i < len {
    let c = chars[i]
    let cp = c.to_int()
    if cp == '"'.to_int() {
      return Ok((buf.to_string(), i + 1))
    } else if cp == '\\'.to_int() {
      i += 1
      if i >= len {
        return Err((start, "unclosed string literal"))
      }
      let esc = chars[i]
      match esc {
        '"' => {
          buf.write_char('"')
          i += 1
        }
        '\\' => {
          buf.write_char('\\')
          i += 1
        }
        '/' => {
          buf.write_char('/')
          i += 1
        }
        'b' => {
          buf.write_char('\u{0008}')
          i += 1
        }
        'f' => {
          buf.write_char('\u{000C}')
          i += 1
        }
        'n' => {
          buf.write_char('\n')
          i += 1
        }
        'r' => {
          buf.write_char('\r')
          i += 1
        }
        't' => {
          buf.write_char('\t')
          i += 1
        }
        'u' => {
          i += 1
          let (code, next_i) = parse_hex4_at(chars, i)
          if code < 0 {
            let mut found_bad = false
            let mut bad_char = ' '
            let mut j = i
            while j < len {
              let ch = chars[j]
              if !is_hex_digit(ch) {
                bad_char = ch
                found_bad = true
                break
              }
              j += 1
            }
            if found_bad {
              return Err(
                (
                  i,
                  "invalid character '\{bad_char}' in \\u hexadecimal character escape",
                ),
              )
            } else {
              return Err((i, "unexpected end of JSON input"))
            }
          }
          i = next_i
          let cp_out = if code >= high_surrogate_lo && code <= high_surrogate_hi {
            if i + 1 < len &&
              chars[i].to_int() == '\\'.to_int() &&
              chars[i + 1].to_int() == 'u'.to_int() {
              let (lo, next_i2) = parse_hex4_at(chars, i + 2)
              if lo >= low_surrogate_lo && lo <= low_surrogate_hi {
                i = next_i2
                // Recombine the UTF-16 surrogate pair: the high surrogate
                // carries the upper 10 bits, the low surrogate the lower 10,
                // offset back onto the supplementary plane (U+10000+).
                supplementary_plane_base +
                (code - high_surrogate_lo) * surrogate_high_scale +
                (lo - low_surrogate_lo)
              } else {
                json_replacement_rune
              }
            } else {
              json_replacement_rune
            }
          } else if code >= low_surrogate_lo && code <= low_surrogate_hi {
            json_replacement_rune
          } else {
            code
          }
          buf.write_char(cp_out.unsafe_to_char())
        }
        _ => return Err((i, "invalid escape sequence `\\\{esc}` in string"))
      }
    } else if cp < 0x20 {
      return Err((i, "invalid control character in string"))
    } else {
      buf.write_char(c)
      i += 1
    }
  }
  Err((start, "unclosed string literal"))
}

///|
fn skip_ws(chars : Array[Char], i : Int) -> Int {
  let len = chars.length()
  let mut j = i
  while j < len {
    let c = chars[j].to_int()
    if c == ' '.to_int() ||
      c == '\t'.to_int() ||
      c == '\n'.to_int() ||
      c == '\r'.to_int() {
      j += 1
    } else {
      break
    }
  }
  j
}

///|
/// Reports whether `chars` contains `prefix` starting at position `pos`.
///
/// Parameters:
///
/// - `chars` : The character array to search within.
/// - `pos` : The starting index in `chars`.
/// - `prefix` : The string to match.
fn starts_with_at(chars : Array[Char], pos : Int, prefix : String) -> Bool {
  let pfx = prefix.to_array()
  if pos + pfx.length() > chars.length() {
    return false
  }
  for i in 0..<pfx.length() {
    if chars[pos + i] != pfx[i] {
      return false
    }
  }
  true
}

///|
/// Parses a single JSON value starting at position `i` in `chars`,
/// dispatching to the appropriate sub-parser based on the leading character.
///
/// Parameters:
///
/// - `chars` : The character array being parsed.
/// - `i` : The starting position (leading whitespace is skipped).
/// - `depth` : Current nesting depth; returns `Err` when it reaches the
///   maximum.
///
/// Returns `Ok((value, position_after_value))` on success, or
/// `Err((offset, message))` on a parse error.
fn parse_json_value(
  chars : Array[Char],
  i : Int,
  depth : Int,
) -> Result[(@value.Value, Int), (Int, String)] {
  let i = skip_ws(chars, i)
  let len = chars.length()
  if i >= len {
    return Err((i, "unexpected end of file"))
  }
  let c = chars[i]
  if c == '"' {
    match parse_json_string(chars, i) {
      Ok((raw, next_i)) =>
        Ok((@value.Value::String(@value.StarlarkString::new(raw)), next_i))
      Err(e) => Err(e)
    }
  } else if starts_with_at(chars, i, "null") {
    Ok((@value.Value::None, i + 4))
  } else if starts_with_at(chars, i, "true") {
    Ok((@value.Value::Bool(true), i + 4))
  } else if starts_with_at(chars, i, "false") {
    Ok((@value.Value::Bool(false), i + 5))
  } else if c == '[' {
    if depth >= json_max_nesting_depth {
      return Err((i, "nesting depth limit exceeded"))
    }
    parse_json_array(chars, i, depth)
  } else if c == '{' {
    if depth >= json_max_nesting_depth {
      return Err((i, "nesting depth limit exceeded"))
    }
    parse_json_object(chars, i, depth)
  } else if c == '-' ||
    (c.to_int() >= '0'.to_int() && c.to_int() <= '9'.to_int()) {
    parse_json_number(chars, i)
  } else {
    Err(
      (
        i,
        "unexpected character '\{if c == '\'' { "\\'" } else { c.to_string() }}'",
      ),
    )
  }
}

///|
/// Parses a JSON array starting at position `i` (which must point to `[`),
/// returning a Starlark `List` containing the decoded elements.
///
/// Parameters:
///
/// - `chars` : The character array being parsed.
/// - `i` : Index of the opening `[`.
/// - `depth` : Current nesting depth passed down to recursive calls.
///
/// Returns `Ok((List, position_after_closing_bracket))` on success, or
/// `Err((offset, message))` on a structural error (trailing comma, missing
/// separator, premature end of input, etc.).
fn parse_json_array(
  chars : Array[Char],
  i : Int,
  depth : Int,
) -> Result[(@value.Value, Int), (Int, String)] {
  let len = chars.length()
  let elems : Array[@value.Value] = []
  let mut j = skip_ws(chars, i + 1)
  if j < len && chars[j] == ']' {
    return Ok((@value.Value::List(@value.StarlarkList::new(elems)), j + 1))
  }
  while true {
    match parse_json_value(chars, j, depth + 1) {
      Err(e) => return Err(e)
      Ok((v, next_j)) => {
        elems.push(v)
        j = skip_ws(chars, next_j)
        if j >= len {
          return Err((j, "unexpected end of file"))
        }
        let c = chars[j]
        if c == ']' {
          return Ok(
            (@value.Value::List(@value.StarlarkList::new(elems)), j + 1),
          )
        } else if c == ',' {
          j = skip_ws(chars, j + 1)
          if j < len && chars[j] == ']' {
            return Err((j, "unexpected character '\{chars[j]}'"))
          }
        } else {
          return Err((j, "got '\{c}', want ',' or ']'"))
        }
      }
    }
  }
  Err((j, "unexpected end of file"))
}

///|
/// Parses a JSON object starting at position `i` (which must point to `{`),
/// returning a Starlark `Dict`. Duplicate keys are accepted; the last value
/// for a given key wins.
///
/// Parameters:
///
/// - `chars` : The character array being parsed.
/// - `i` : Index of the opening `{`.
/// - `depth` : Current nesting depth passed down to recursive calls.
///
/// Returns `Ok((Dict, position_after_closing_brace))` on success, or
/// `Err((offset, message))` on a structural error.
fn parse_json_object(
  chars : Array[Char],
  i : Int,
  depth : Int,
) -> Result[(@value.Value, Int), (Int, String)] {
  let len = chars.length()
  let dict = @value.StarlarkDict::new()
  let mut j = skip_ws(chars, i + 1)
  if j < len && chars[j] == '}' {
    return Ok((@value.Value::Dict(dict), j + 1))
  }
  while true {
    j = skip_ws(chars, j)
    if j >= len {
      return Err((j, "unexpected end of file"))
    }
    match parse_json_value(chars, j, depth + 1) {
      Err(e) => return Err(e)
      Ok((key, next_j)) => {
        match key {
          @value.Value::String(_) => ()
          _ =>
            return Err(
              (next_j, "got \{key.type_name()} for object key, want string"),
            )
        }
        j = skip_ws(chars, next_j)
        if j >= len {
          return Err((j, "unexpected end of file"))
        }
        if chars[j] != ':' {
          return Err((j, "after object key, got '\{chars[j]}', want ':' "))
        }
        j += 1
        match parse_json_value(chars, j, depth + 1) {
          Err(e) => return Err(e)
          Ok((val, next_j2)) => {
            let _ = dict.set(key, val)
            j = skip_ws(chars, next_j2)
            if j >= len {
              return Err((j, "unexpected end of file"))
            }
            let c = chars[j]
            if c == '}' {
              return Ok((@value.Value::Dict(dict), j + 1))
            } else if c == ',' {
              j = skip_ws(chars, j + 1)
              if j < len && chars[j] == '}' {
                return Err((j, "unexpected character '\{chars[j]}'"))
              }
            } else {
              return Err((j, "in object, got '\{c}', want ',' or '}'"))
            }
          }
        }
      }
    }
  }
  Err((j, "unexpected end of file"))
}

///|
/// Parses a JSON number (integer or floating-point) starting at position `i`,
/// returning a Starlark `Int` for integers and `Float` for decimals or
/// scientific notation.
///
/// Parameters:
///
/// - `chars` : The character array being parsed.
/// - `i` : Index of the first character of the number (`-` or a digit).
///
/// Returns `Ok((value, position_after_number))` on success, or
/// `Err((offset, message))` for invalid number syntax (e.g. leading zeros,
/// bare minus).
fn parse_json_number(
  chars : Array[Char],
  i : Int,
) -> Result[(@value.Value, Int), (Int, String)] {
  let len = chars.length()
  let mut j = i
  let mut is_float = false
  while j < len {
    let c = chars[j]
    if is_digit_char(c) {
      j += 1
    } else if c == '.' || c == 'e' || c == 'E' {
      is_float = true
      j += 1
    } else if c == '+' || c == '-' {
      j += 1
    } else {
      break
    }
  }
  let nbuf = StringBuilder::new()
  for idx in i..<j {
    nbuf.write_char(chars[idx])
  }
  let num_str = nbuf.to_string()
  let digits_start = if chars[i] == '-' { 1 } else { 0 }
  let first_digit_idx = i + digits_start
  if first_digit_idx >= j {
    return Err((j, "invalid number: \{num_str}"))
  }
  let first_digit = chars[first_digit_idx]
  if first_digit == '0' &&
    first_digit_idx + 1 < j &&
    is_digit_char(chars[first_digit_idx + 1]) {
    return Err((j, "invalid number: \{num_str}"))
  }
  if is_float {
    let f = @string.parse_double(num_str) catch {
      _ => return Err((j, "invalid number: \{num_str}"))
    }
    Ok((@value.Value::Float(f), j))
  } else {
    let digits = if num_str.length() > 0 && num_str[0] == '-' {
      num_str[1:]
    } else {
      num_str[:]
    }
    for c in digits.iter() {
      if c < '0' || c > '9' {
        return Err((j, "invalid number: \{num_str}"))
      }
    }
    if digits.length() == 0 {
      return Err((j, "invalid number: \{num_str}"))
    }
    let abs_n = BigInt::from_string(digits.to_owned())
    let n = if num_str.length() > 0 && num_str[0] == '-' {
      -abs_n
    } else {
      abs_n
    }
    Ok((@value.Value::Int(n), j))
  }
}

///|
/// Parses a JSON string into a Starlark value. Numbers become `Int` or `Float`,
/// objects become `Dict`, arrays become `List`. If parsing fails and `default`
/// is provided, returns the default; otherwise returns `Err`.
///
/// Parameters:
///
/// - `s` : The JSON text to parse.
/// - `default` : An optional fallback value returned when parsing fails.
///
/// Returns `Ok(value)` on success, or `Err(message)` if parsing fails and no
/// default is provided.
///
/// ```mbt check
/// test {
///   // Scalar types.
///   inspect(decode_from_json("null", None).unwrap().repr(), content="None")
///   inspect(decode_from_json("true", None).unwrap().repr(), content="True")
///   inspect(decode_from_json("42", None).unwrap().repr(), content="42")
///   inspect(decode_from_json("\"hi\"", None).unwrap().repr(), content="\"hi\"")
///   // Array becomes a Starlark list.
///   inspect(decode_from_json("[1,2]", None).unwrap().repr(), content="[1, 2]")
///   // Invalid JSON with a fallback returns the default instead of an error.
///   let fallback = @value.Value::None
///   inspect(
///     decode_from_json("???", Some(fallback)).unwrap().repr(),
///     content="None",
///   )
/// }
/// ```
pub fn decode_from_json(
  s : String,
  default : @value.Value?,
) -> Result[@value.Value, String] {
  let chars = s.to_array()
  match parse_json_value(chars, 0, 0) {
    Err((offset, msg)) =>
      match default {
        Some(d) => Ok(d)
        None => Err("json.decode: at offset \{offset}, \{msg}")
      }
    Ok((v, next_i)) => {
      let rest = skip_ws(chars, next_i)
      if rest < chars.length() {
        let err_msg = "unexpected character '\{chars[rest]}' after value"
        match default {
          Some(d) => Ok(d)
          None => Err("json.decode: at offset \{rest}, \{err_msg}")
        }
      } else {
        Ok(v)
      }
    }
  }
}

///|
/// Reports whether `tok` is a syntactically valid JSON scalar token: one of
/// the keywords `null`, `true`, `false`, or a well-formed JSON number (no
/// leading zeros, no bare minus, valid optional fraction and exponent).
fn is_valid_json_scalar(tok : String) -> Bool {
  if tok == "null" || tok == "true" || tok == "false" {
    return true
  }
  let chars = tok.to_array()
  let n = chars.length()
  let mut i = 0
  if i < n && chars[i] == '-' {
    i += 1
  }
  if i >= n {
    return false
  }
  if chars[i] == '0' {
    i += 1
  } else if chars[i].to_int() >= '1'.to_int() &&
    chars[i].to_int() <= '9'.to_int() {
    while i < n &&
          chars[i].to_int() >= '0'.to_int() &&
          chars[i].to_int() <= '9'.to_int() {
      i += 1
    }
  } else {
    return false
  }
  if i < n && chars[i] == '.' {
    i += 1
    if i >= n ||
      chars[i].to_int() < '0'.to_int() ||
      chars[i].to_int() > '9'.to_int() {
      return false
    }
    while i < n &&
          chars[i].to_int() >= '0'.to_int() &&
          chars[i].to_int() <= '9'.to_int() {
      i += 1
    }
  }
  if i < n && (chars[i] == 'e' || chars[i] == 'E') {
    i += 1
    if i < n && (chars[i] == '+' || chars[i] == '-') {
      i += 1
    }
    if i >= n ||
      chars[i].to_int() < '0'.to_int() ||
      chars[i].to_int() > '9'.to_int() {
      return false
    }
    while i < n &&
          chars[i].to_int() >= '0'.to_int() &&
          chars[i].to_int() <= '9'.to_int() {
      i += 1
    }
  }
  i == n
}

///|
// Starts a fresh pretty-printed line: a newline, the global `prefix`, then
// `depth` copies of `indent_str`. Shared by the `{`/`[`, `}`/`]`, and `,`
// branches of `indent_json`.
fn write_indent_line(
  buf : StringBuilder,
  prefix : String,
  indent_str : String,
  depth : Int,
) -> Unit {
  buf.write_char('\n')
  buf.write_string(prefix)
  for _ in 0..<depth {
    buf.write_string(indent_str)
  }
}

///|
/// Represents the parser state for the container currently at the top of the
/// stack in `indent_json`, tracking what token is expected next within that
/// array or object.
priv enum Context {
  ArrayEmpty
  ArrayAfterVal
  ArrayAfterComma
  ObjEmpty
  ObjAfterKey
  ObjAfterColon
  ObjAfterVal
  ObjAfterComma
}

///|
/// Advances the parent container context after a complete value has been
/// consumed, transitioning the top-of-stack state from "awaiting value" to
/// "after value".
///
/// Parameters:
///
/// - `stack` : The current stack of open container contexts; mutated in place.
/// - `top_done` : Whether the top-level value was already complete before
///   this call.
///
/// Returns the updated `top_done` flag.
fn advance_after_value(stack : Array[Context], top_done : Bool) -> Bool {
  if stack.is_empty() {
    true
  } else {
    match stack[stack.length() - 1] {
      ArrayEmpty | ArrayAfterComma => {
        stack[stack.length() - 1] = ArrayAfterVal
        top_done
      }
      ObjAfterColon => {
        stack[stack.length() - 1] = ObjAfterVal
        top_done
      }
      _ => top_done
    }
  }
}

///|
/// Pretty-prints a JSON string, prefixing each line with `prefix` and
/// indenting each nesting level with `indent_str`.
///
/// Validates JSON structure: unbalanced brackets, unterminated string
/// literals, missing value separators (`,` between elements, `:` between
/// key and value), trailing commas, surplus tokens after the top-level
/// value, and empty input. Scalar tokens must be a JSON keyword (`null`,
/// `true`, `false`) or a syntactically-valid JSON number. Semantic
/// validity (e.g. numeric range) is not checked.
///
/// Parameters:
///
/// - `s` : The compact JSON string to pretty-print.
/// - `prefix` : A string prepended to every output line.
/// - `indent_str` : The string used for each level of nesting indentation.
///
/// Returns `Ok(indented_string)` on success, or `Err(message)` on a
/// structural error.
///
/// ```mbt check
/// test {
///   // Scalars and empty containers pass through unchanged.
///   inspect(indent_json("null", "", "  ").unwrap(), content="null")
///   inspect(indent_json("{}", "", "  ").unwrap(), content="{}")
///   // Nested arrays are expanded across lines.
///   inspect(indent_json("[1,2]", "", "  ").unwrap(), content="[\n  1,\n  2\n]")
///   // Structural errors produce Err.
///   inspect(indent_json("!bad", "", "  ") is Err(_), content="true")
/// }
/// ```
pub fn indent_json(
  s : String,
  prefix : String,
  indent_str : String,
) -> Result[String, String] {
  if s.is_empty() {
    return Err("unexpected end of JSON input")
  }
  let chars = s.to_array()
  let len = chars.length()
  let buf = StringBuilder::new()
  let stack : Array[Context] = []
  let mut top_done = false
  let mut i = 0
  let mut in_string = false
  while i < len {
    let c = chars[i]
    if in_string {
      buf.write_char(c)
      if c == '\\' {
        i += 1
        if i < len {
          buf.write_char(chars[i])
        }
      } else if c == '"' {
        in_string = false
      }
      i += 1
      continue
    }
    let cp = c.to_int()
    if cp == ' '.to_int() ||
      cp == '\t'.to_int() ||
      cp == '\n'.to_int() ||
      cp == '\r'.to_int() {
      i += 1
      continue
    }
    if c == '"' {
      if stack.is_empty() {
        if top_done {
          return Err("invalid character '\"' after top-level value")
        }
        top_done = true
      } else {
        match stack[stack.length() - 1] {
          ArrayEmpty | ArrayAfterComma =>
            stack[stack.length() - 1] = ArrayAfterVal
          ArrayAfterVal =>
            return Err("invalid character '\"' after array element")
          ObjEmpty | ObjAfterComma => stack[stack.length() - 1] = ObjAfterKey
          ObjAfterKey => return Err("invalid character '\"' after object key")
          ObjAfterColon => stack[stack.length() - 1] = ObjAfterVal
          ObjAfterVal =>
            return Err("invalid character '\"' after object key:value pair")
        }
      }
      in_string = true
      buf.write_char('"')
      i += 1
      continue
    }
    if c == '{' || c == '[' {
      if stack.is_empty() {
        if top_done {
          return Err("invalid character '\{c}' after top-level value")
        }
      } else {
        match stack[stack.length() - 1] {
          ArrayEmpty | ArrayAfterComma => ()
          ArrayAfterVal =>
            return Err("invalid character '\{c}' after array element")
          ObjEmpty | ObjAfterComma =>
            return Err(
              "invalid character '\{c}' looking for beginning of object key string",
            )
          ObjAfterKey => return Err("invalid character '\{c}' after object key")
          ObjAfterColon => ()
          ObjAfterVal =>
            return Err("invalid character '\{c}' after object key:value pair")
        }
      }
      buf.write_char(c)
      i += 1
      let ni = skip_ws(chars, i)
      let close = if c == '{' { '}' } else { ']' }
      if ni < len && chars[ni] == close {
        buf.write_char(close)
        i = ni + 1
        top_done = advance_after_value(stack, top_done)
        continue
      }
      let new_ctx = if c == '{' { ObjEmpty } else { ArrayEmpty }
      stack.push(new_ctx)
      write_indent_line(buf, prefix, indent_str, stack.length())
      continue
    }
    if c == '}' {
      if stack.is_empty() {
        if top_done {
          return Err("invalid character '}' after top-level value")
        } else {
          return Err("invalid character '}' looking for beginning of value")
        }
      }
      match stack[stack.length() - 1] {
        ObjAfterVal => {
          write_indent_line(buf, prefix, indent_str, stack.length() - 1)
          buf.write_char('}')
          let _ = stack.pop()
          top_done = advance_after_value(stack, top_done)
        }
        ObjAfterComma =>
          return Err(
            "invalid character '}' looking for beginning of object key string",
          )
        ObjAfterKey => return Err("invalid character '}' after object key")
        ObjAfterColon =>
          return Err("invalid character '}' looking for beginning of value")
        ArrayAfterVal => return Err("invalid character '}' after array element")
        ArrayEmpty | ArrayAfterComma | ObjEmpty =>
          return Err("invalid character '}' looking for beginning of value")
      }
      i += 1
      continue
    }
    if c == ']' {
      if stack.is_empty() {
        if top_done {
          return Err("invalid character ']' after top-level value")
        } else {
          return Err("invalid character ']' looking for beginning of value")
        }
      }
      match stack[stack.length() - 1] {
        ArrayAfterVal => {
          write_indent_line(buf, prefix, indent_str, stack.length() - 1)
          buf.write_char(']')
          let _ = stack.pop()
          top_done = advance_after_value(stack, top_done)
        }
        ArrayAfterComma =>
          return Err("invalid character ']' looking for beginning of value")
        ObjAfterVal =>
          return Err("invalid character ']' after object key:value pair")
        ObjEmpty | ObjAfterComma =>
          return Err(
            "invalid character ']' looking for beginning of object key string",
          )
        ObjAfterKey => return Err("invalid character ']' after object key")
        ObjAfterColon =>
          return Err("invalid character ']' looking for beginning of value")
        ArrayEmpty =>
          return Err("invalid character ']' looking for beginning of value")
      }
      i += 1
      continue
    }
    if c == ',' {
      if stack.is_empty() {
        if top_done {
          return Err("invalid character ',' after top-level value")
        } else {
          return Err("invalid character ',' looking for beginning of value")
        }
      }
      match stack[stack.length() - 1] {
        ArrayAfterVal => {
          stack[stack.length() - 1] = ArrayAfterComma
          buf.write_char(',')
          write_indent_line(buf, prefix, indent_str, stack.length())
        }
        ArrayEmpty | ArrayAfterComma =>
          return Err("invalid character ',' looking for beginning of value")
        ObjAfterVal => {
          stack[stack.length() - 1] = ObjAfterComma
          buf.write_char(',')
          write_indent_line(buf, prefix, indent_str, stack.length())
        }
        ObjEmpty | ObjAfterComma =>
          return Err(
            "invalid character ',' looking for beginning of object key string",
          )
        ObjAfterKey => return Err("invalid character ',' after object key")
        ObjAfterColon =>
          return Err("invalid character ',' looking for beginning of value")
      }
      i += 1
      continue
    }
    if c == ':' {
      if stack.is_empty() {
        if top_done {
          return Err("invalid character ':' after top-level value")
        } else {
          return Err("invalid character ':' looking for beginning of value")
        }
      }
      match stack[stack.length() - 1] {
        ObjAfterKey => {
          stack[stack.length() - 1] = ObjAfterColon
          buf.write_string(": ")
        }
        ArrayEmpty | ArrayAfterComma | ObjAfterColon =>
          return Err("invalid character ':' looking for beginning of value")
        ArrayAfterVal => return Err("invalid character ':' after array element")
        ObjEmpty | ObjAfterComma =>
          return Err(
            "invalid character ':' looking for beginning of object key string",
          )
        ObjAfterVal =>
          return Err("invalid character ':' after object key:value pair")
      }
      i += 1
      continue
    }
    let cp2 = c.to_int()
    if (cp2 >= 'a'.to_int() && cp2 <= 'z'.to_int()) ||
      (cp2 >= 'A'.to_int() && cp2 <= 'Z'.to_int()) ||
      (cp2 >= '0'.to_int() && cp2 <= '9'.to_int()) ||
      c == '-' ||
      c == '+' ||
      c == '.' {
      if stack.is_empty() {
        if top_done {
          return Err("invalid character '\{c}' after top-level value")
        }
      } else {
        match stack[stack.length() - 1] {
          ArrayEmpty | ArrayAfterComma => ()
          ArrayAfterVal =>
            return Err("invalid character '\{c}' after array element")
          ObjEmpty | ObjAfterComma =>
            return Err(
              "invalid character '\{c}' looking for beginning of object key string",
            )
          ObjAfterKey => return Err("invalid character '\{c}' after object key")
          ObjAfterColon => ()
          ObjAfterVal =>
            return Err("invalid character '\{c}' after object key:value pair")
        }
      }
      let tok_start = i
      i += 1
      while i < len {
        let tc = chars[i].to_int()
        if (tc >= 'a'.to_int() && tc <= 'z'.to_int()) ||
          (tc >= 'A'.to_int() && tc <= 'Z'.to_int()) ||
          (tc >= '0'.to_int() && tc <= '9'.to_int()) ||
          chars[i] == '-' ||
          chars[i] == '+' ||
          chars[i] == '.' {
          i += 1
        } else {
          break
        }
      }
      let tok_buf = StringBuilder::new()
      for k in tok_start..<i {
        tok_buf.write_char(chars[k])
      }
      let tok = tok_buf.to_string()
      if !is_valid_json_scalar(tok) {
        return Err(
          "invalid character '\{chars[tok_start]}' looking for beginning of value",
        )
      }
      buf.write_string(tok)
      top_done = advance_after_value(stack, top_done)
    } else {
      return Err("invalid character '\{c}' in JSON")
    }
  }
  if in_string {
    return Err("unterminated string in JSON")
  }
  if !stack.is_empty() || !top_done {
    return Err("unexpected end of JSON input")
  }
  Ok(buf.to_string())
}

///|
/// Builds the `json.encode` builtin function value.
fn make_encode_fn() -> @value.Value {
  @value.Value::new_builtin("json.encode", fn(_ctx, pos_args, kw_args) {
    if kw_args.length() != 0 {
      return Err("json.encode: unexpected keyword arguments")
    }
    if pos_args.length() != 1 {
      return Err("json.encode: got \{pos_args.length()} arguments, want 1")
    }
    encode_to_json(pos_args[0]).map(fn(s) {
      @value.Value::String(@value.StarlarkString::new(s))
    })
  })
}

///|
/// Builds the `json.encode_indent` builtin function value.
fn make_encode_indent_fn() -> @value.Value {
  @value.Value::new_builtin("json.encode_indent", fn(_ctx, pos_args, kw_args) {
    let mut pfx = ""
    let mut ind = "\t"
    for kw in kw_args {
      let (k, v) = kw
      match (k, v) {
        ("prefix", @value.Value::String(s)) => pfx = s.raw()
        ("indent", @value.Value::String(s)) => ind = s.raw()
        ("prefix", _) =>
          return Err(
            "json.encode_indent: for parameter \"prefix\": got \{v.type_name()}, want string",
          )
        ("indent", _) =>
          return Err(
            "json.encode_indent: for parameter \"indent\": got \{v.type_name()}, want string",
          )
        _ =>
          return Err("json.encode_indent: unexpected keyword argument \"\{k}\"")
      }
    }
    if pos_args.length() != 1 {
      return Err(
        "json.encode_indent: got \{pos_args.length()} arguments, want 1",
      )
    }
    let state = EncodeState::new()
    match encode_inner(pos_args[0], state, 0) {
      Err(e) => Err("json.encode_indent: \{e}")
      Ok(json_str) =>
        indent_json(json_str, pfx, ind).map(fn(result) {
          @value.Value::String(@value.StarlarkString::new(result))
        })
    }
  })
}

///|
/// Builds the `json.decode` builtin function value.
fn make_decode_fn() -> @value.Value {
  @value.Value::new_builtin("json.decode", fn(_ctx, pos_args, kw_args) {
    // positional cap: go allows at most 2 (x + default?)
    if pos_args.length() > 2 {
      return Err(
        "json.decode: got \{pos_args.length()} arguments, want at most 2",
      )
    }
    // type-check positional x first so that go's error-precedence is preserved:
    // json.decode(2, foo=3) → type error, not unknown-kwarg error
    let mut x_str : String? = None
    if pos_args.length() >= 1 {
      match pos_args[0] {
        @value.Value::String(s) => x_str = Some(s.raw())
        v =>
          return Err(
            "json.decode: for parameter x: got \{v.type_name()}, want string",
          )
      }
    }
    // process kwargs; defer the x-string-kwarg positional-only error to after
    // the loop so that unknown kwargs appearing later are detected first,
    // matching go's UnpackArgs kwloop order (json.go:322 check runs post-loop)
    let mut default_from_kw : @value.Value? = None
    let mut x_kwarg_string = false
    for kw in kw_args {
      let (k, v) = kw
      match k {
        "default" =>
          if pos_args.length() >= 2 || default_from_kw is Some(_) {
            return Err(
              "json.decode: got multiple values for keyword argument \"default\"",
            )
          } else {
            default_from_kw = Some(v)
          }
        "x" =>
          if pos_args.length() >= 1 {
            return Err(
              "json.decode: got multiple values for keyword argument \"x\"",
            )
          } else {
            match v {
              @value.Value::String(_) => x_kwarg_string = true
              _ =>
                return Err(
                  "json.decode: for parameter \"x\": got \{v.type_name()}, want string",
                )
            }
          }
        _ => return Err("json.decode: unexpected keyword argument \"\{k}\"")
      }
    }
    // deferred positional-only rejection for x string-kwarg (post-loop, like go)
    if x_kwarg_string {
      return Err("json.decode: unexpected keyword argument x")
    }
    // required check
    let x = match x_str {
      Some(s) => s
      None => return Err("json.decode: missing argument for x")
    }
    let default_val = if pos_args.length() >= 2 {
      Some(pos_args[1])
    } else {
      default_from_kw
    }
    decode_from_json(x, default_val)
  })
}

///|
/// Builds the `json.indent` builtin function value.
fn make_indent_fn() -> @value.Value {
  @value.Value::new_builtin("json.indent", fn(_ctx, pos_args, kw_args) {
    let mut pfx = ""
    let mut ind = "\t"
    for kw in kw_args {
      let (k, v) = kw
      match (k, v) {
        ("prefix", @value.Value::String(sv)) => pfx = sv.raw()
        ("indent", @value.Value::String(sv)) => ind = sv.raw()
        ("prefix", _) =>
          return Err(
            "json.indent: for parameter \"prefix\": got \{v.type_name()}, want string",
          )
        ("indent", _) =>
          return Err(
            "json.indent: for parameter \"indent\": got \{v.type_name()}, want string",
          )
        _ => return Err("json.indent: unexpected keyword argument \"\{k}\"")
      }
    }
    if pos_args.length() != 1 {
      return Err("json.indent: got \{pos_args.length()} arguments, want 1")
    }
    let s = match pos_args[0] {
      @value.Value::String(s) => s.raw()
      _ =>
        return Err(
          "json.indent: for parameter 1: got \{pos_args[0].type_name()}, want string",
        )
    }
    match indent_json(s, pfx, ind) {
      Ok(result) => Ok(@value.Value::String(@value.StarlarkString::new(result)))
      Err(e) => Err("json.indent: \{e}")
    }
  })
}

///|
/// Returns the `json` Starlark module value, providing `encode`, `decode`,
/// `encode_indent`, and `indent` as attributes.
///
/// Returns the constructed `json` module as a `@value.Value::Module`.
///
/// ```mbt check
/// test {
///   let m = json_module()
///   guard m is @value.Value::Module(mod) else { fail("expected module") }
///   inspect(mod.name(), content="json")
///   inspect(mod.attr_names().contains("encode"), content="true")
///   inspect(mod.attr_names().contains("decode"), content="true")
/// }
/// ```
pub fn json_module() -> @value.Value {
  let attrs : Map[String, @value.Value] = {}
  attrs["encode"] = make_encode_fn()
  attrs["encode_indent"] = make_encode_indent_fn()
  attrs["decode"] = make_decode_fn()
  attrs["indent"] = make_indent_fn()
  @value.Value::Module(@value.StarlarkModule::new("json", attrs))
}
