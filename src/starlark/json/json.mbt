///|
fn hex_char(n : Int) -> Char {
  if n < 10 {
    ('0'.to_int() + n).unsafe_to_char()
  } else {
    ('a'.to_int() + n - 10).unsafe_to_char()
  }
}

///|
fn write_hex4(buf : StringBuilder, n : Int) -> Unit {
  buf.write_char(hex_char((n >> 12) & 0xF))
  buf.write_char(hex_char((n >> 8) & 0xF))
  buf.write_char(hex_char((n >> 4) & 0xF))
  buf.write_char(hex_char(n & 0xF))
}

///|
fn utf8_decode_rune(b : Bytes, pos : Int) -> (Int, Int) {
  let b0 = b[pos].to_int()
  if b0 < 0x80 {
    return (b0, 1)
  }
  let len = b.length()
  if b0 >= 0xC2 && b0 <= 0xDF && pos + 1 < len {
    let b1 = b[pos + 1].to_int()
    if b1 >= 0x80 && b1 <= 0xBF {
      return (((b0 & 0x1F) << 6) | (b1 & 0x3F), 2)
    }
  } else if b0 >= 0xE0 && b0 <= 0xEF && pos + 2 < len {
    let b1 = b[pos + 1].to_int()
    let b2 = b[pos + 2].to_int()
    if b1 >= 0x80 && b1 <= 0xBF && b2 >= 0x80 && b2 <= 0xBF {
      let r = ((b0 & 0x0F) << 12) | ((b1 & 0x3F) << 6) | (b2 & 0x3F)
      if r >= 0x0800 && !(r >= 0xD800 && r <= 0xDFFF) {
        return (r, 3)
      }
    }
  } else if b0 >= 0xF0 && b0 <= 0xF4 && pos + 3 < len {
    let b1 = b[pos + 1].to_int()
    let b2 = b[pos + 2].to_int()
    let b3 = b[pos + 3].to_int()
    if b1 >= 0x80 &&
      b1 <= 0xBF &&
      b2 >= 0x80 &&
      b2 <= 0xBF &&
      b3 >= 0x80 &&
      b3 <= 0xBF {
      let r = ((b0 & 0x07) << 18) |
        ((b1 & 0x3F) << 12) |
        ((b2 & 0x3F) << 6) |
        (b3 & 0x3F)
      if r >= 0x10000 && r <= 0x10FFFF {
        return (r, 4)
      }
    }
  }
  (-1, 1)
}

///|
fn json_quote_string(s : @value.StarlarkString) -> String {
  let buf = StringBuilder::new()
  buf.write_char('"')
  let bytes = s.to_bytes()
  let len = bytes.length()
  let mut i = 0
  while i < len {
    let b0 = bytes[i].to_int()
    if b0 < 0x20 {
      match b0 {
        0x08 => buf.write_string("\\b")
        0x09 => buf.write_string("\\t")
        0x0A => buf.write_string("\\n")
        0x0C => buf.write_string("\\f")
        0x0D => buf.write_string("\\r")
        _ => {
          buf.write_string("\\u00")
          buf.write_char(hex_char((b0 >> 4) & 0xF))
          buf.write_char(hex_char(b0 & 0xF))
        }
      }
      i += 1
    } else if b0 == 0x22 {
      buf.write_string("\\\"")
      i += 1
    } else if b0 == 0x5C {
      buf.write_string("\\\\")
      i += 1
    } else if b0 < 0x80 {
      buf.write_char(b0.unsafe_to_char())
      i += 1
    } else {
      let (r, width) = utf8_decode_rune(bytes, i)
      if r < 0 {
        buf.write_string("\\ufffd")
        i += 1
      } else if r < 0x10000 {
        buf.write_string("\\u")
        write_hex4(buf, r)
        i += width
      } else {
        let hi = 0xD800 + (r - 0x10000) / 0x400
        let lo = 0xDC00 + (r - 0x10000) % 0x400
        buf.write_string("\\u")
        write_hex4(buf, hi)
        buf.write_string("\\u")
        write_hex4(buf, lo)
        i += width
      }
    }
  }
  buf.write_char('"')
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
fn is_neg_zero(f : Double) -> Bool {
  f == 0.0 && 1.0 / f == @double.neg_infinity
}

///|
fn format_float_json(f : Double) -> String {
  if is_neg_zero(f) {
    return "-0.0"
  }
  let s = f.to_string()
  if s.contains(".") || s.contains("e") || s.contains("E") {
    s
  } else {
    s + ".0"
  }
}

///|
priv struct EncodeState {
  list_path : Array[@value.StarlarkList]
  dict_path : Array[@value.StarlarkDict]
  tuple_path : Array[Array[@value.Value]]
}

///|
fn EncodeState::new() -> EncodeState {
  { list_path: [], dict_path: [], tuple_path: [] }
}

///|
fn encode_inner(
  v : @value.Value,
  state : EncodeState,
) -> Result[String, String] {
  match v {
    @value.Value::NoneVal => Ok("null")
    @value.Value::BoolVal(b) => Ok(if b { "true" } else { "false" })
    @value.Value::IntVal(n) => Ok(n.to_string())
    @value.Value::FloatVal(f) =>
      if f.is_nan() || f.is_inf() {
        Err("cannot encode non-finite float \{format_nonfinite(f)}")
      } else {
        Ok(format_float_json(f))
      }
    @value.Value::StrVal(s) => Ok(json_quote_string(s))
    @value.Value::ListVal(l) => {
      if state.list_path
        .iter()
        .any(fn(pl) { physical_equal(pl.items, l.items) }) {
        return Err("cycle in JSON structure")
      }
      state.list_path.push(l)
      let result = encode_sequence(l.items, "list", state)
      let _ = state.list_path.pop()
      result
    }
    @value.Value::TupleVal(t) => {
      if state.tuple_path.iter().any(fn(pt) { physical_equal(pt, t) }) {
        return Err("cycle in JSON structure")
      }
      state.tuple_path.push(t)
      let result = encode_sequence(t, "tuple", state)
      let _ = state.tuple_path.pop()
      result
    }
    @value.Value::DictVal(d) => {
      if state.dict_path.iter().any(fn(pd) { physical_equal(pd, d) }) {
        return Err("cycle in JSON structure")
      }
      state.dict_path.push(d)
      let result = encode_dict_val(d, state)
      let _ = state.dict_path.pop()
      result
    }
    @value.Value::RangeVal(r) => {
      let len = r.length()
      let items : Array[@value.Value] = Array::make(len, @value.Value::NoneVal)
      for i in 0..<len {
        items[i] = @value.Value::IntVal(r.index_at(i))
      }
      encode_sequence(items, "range", state)
    }
    @value.Value::SetVal(s) => {
      let items : Array[@value.Value] = []
      s.each(fn(k) { items.push(k) })
      encode_sequence(items, "set", state)
    }
    _ => Err("cannot encode \{@value.type_name(v)} as JSON")
  }
}

///|
fn encode_sequence(
  items : Array[@value.Value],
  kind : String,
  state : EncodeState,
) -> Result[String, String] {
  let buf = StringBuilder::new()
  buf.write_char('[')
  let mut first = true
  for i, elem in items {
    if first {
      first = false
    } else {
      buf.write_char(',')
    }
    match encode_inner(elem, state) {
      Ok(s) => buf.write_string(s)
      Err(e) => return Err("at \{kind} index \{i}: \{e}")
    }
  }
  buf.write_char(']')
  Ok(buf.to_string())
}

///|
fn encode_dict_val(
  d : @value.StarlarkDict,
  state : EncodeState,
) -> Result[String, String] {
  let pairs : Array[(String, @value.Value)] = []
  let mut first_err : String? = None
  d.each(fn(k, v) {
    if first_err is Some(_) {
      return
    }
    match k {
      @value.Value::StrVal(s) => pairs.push((s.raw, v))
      _ => first_err = Some("dict has \{@value.type_name(k)} key, want string")
    }
  })
  if first_err is Some(e) {
    return Err(e)
  }
  pairs.sort_by(fn(a, b) { a.0.compare(b.0) })
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
    match encode_inner(v, state) {
      Ok(s) => buf.write_string(s)
      Err(e) => return Err("in dict key \"\{k}\": \{e}")
    }
  }
  buf.write_char('}')
  Ok(buf.to_string())
}

///|
pub fn encode_to_json(v : @value.Value) -> Result[String, String] {
  let state = EncodeState::new()
  match encode_inner(v, state) {
    Ok(s) => Ok(s)
    Err(e) => Err("json.encode: \{e}")
  }
}

///|
fn is_digit_char(c : Char) -> Bool {
  c.to_int() >= '0'.to_int() && c.to_int() <= '9'.to_int()
}

///|
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
fn parse_json_string(
  chars : Array[Char],
  start : Int,
) -> Result[(String, Int), String] {
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
        return Err("unclosed string literal")
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
            return Err("invalid \\u escape")
          }
          i = next_i
          let cp_out = if code >= 0xD800 && code <= 0xDBFF {
            if i + 1 < len &&
              chars[i].to_int() == '\\'.to_int() &&
              chars[i + 1].to_int() == 'u'.to_int() {
              let (lo, next_i2) = parse_hex4_at(chars, i + 2)
              if lo >= 0xDC00 && lo <= 0xDFFF {
                i = next_i2
                0x10000 + (code - 0xD800) * 0x400 + (lo - 0xDC00)
              } else {
                0xFFFD
              }
            } else {
              0xFFFD
            }
          } else {
            code
          }
          buf.write_char(cp_out.unsafe_to_char())
        }
        _ => return Err("invalid escape sequence `\\\{esc}` in string")
      }
    } else if cp < 0x20 {
      return Err("invalid control character in string")
    } else {
      buf.write_char(c)
      i += 1
    }
  }
  Err("unclosed string literal")
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
fn parse_json_value(
  chars : Array[Char],
  i : Int,
) -> Result[(@value.Value, Int), String] {
  let i = skip_ws(chars, i)
  let len = chars.length()
  if i >= len {
    return Err("unexpected end of file")
  }
  let c = chars[i]
  if c == '"' {
    match parse_json_string(chars, i) {
      Ok((raw, next_i)) =>
        Ok((@value.Value::StrVal(@value.StarlarkString::new(raw)), next_i))
      Err(e) => Err(e)
    }
  } else if starts_with_at(chars, i, "null") {
    Ok((@value.Value::NoneVal, i + 4))
  } else if starts_with_at(chars, i, "true") {
    Ok((@value.Value::BoolVal(true), i + 4))
  } else if starts_with_at(chars, i, "false") {
    Ok((@value.Value::BoolVal(false), i + 5))
  } else if c == '[' {
    parse_json_array(chars, i)
  } else if c == '{' {
    parse_json_object(chars, i)
  } else if c == '-' ||
    (c.to_int() >= '0'.to_int() && c.to_int() <= '9'.to_int()) {
    parse_json_number(chars, i)
  } else {
    Err("unexpected character '\{c}'")
  }
}

///|
fn parse_json_array(
  chars : Array[Char],
  i : Int,
) -> Result[(@value.Value, Int), String] {
  let len = chars.length()
  let elems : Array[@value.Value] = []
  let mut j = skip_ws(chars, i + 1)
  if j < len && chars[j] == ']' {
    return Ok((@value.Value::ListVal(@value.StarlarkList::new(elems)), j + 1))
  }
  while true {
    match parse_json_value(chars, j) {
      Err(e) => return Err(e)
      Ok((v, next_j)) => {
        elems.push(v)
        j = skip_ws(chars, next_j)
        if j >= len {
          return Err("unexpected end of file")
        }
        let c = chars[j]
        if c == ']' {
          return Ok(
            (@value.Value::ListVal(@value.StarlarkList::new(elems)), j + 1),
          )
        } else if c == ',' {
          j = skip_ws(chars, j + 1)
          if j < len && chars[j] == ']' {
            return Err("unexpected character '\{chars[j]}'")
          }
        } else {
          return Err("got '\{c}', want ',' or ']'")
        }
      }
    }
  }
  Err("unexpected end of file")
}

///|
fn parse_json_object(
  chars : Array[Char],
  i : Int,
) -> Result[(@value.Value, Int), String] {
  let len = chars.length()
  let dict = @value.StarlarkDict::new()
  let mut j = skip_ws(chars, i + 1)
  if j < len && chars[j] == '}' {
    return Ok((@value.Value::DictVal(dict), j + 1))
  }
  while true {
    j = skip_ws(chars, j)
    if j >= len {
      return Err("unexpected end of file")
    }
    if chars[j] != '"' {
      return Err("unexpected character '\{chars[j]}'")
    }
    match parse_json_string(chars, j) {
      Err(e) => return Err(e)
      Ok((key_raw, next_j)) => {
        j = skip_ws(chars, next_j)
        if j >= len {
          return Err("unexpected end of file")
        }
        if chars[j] != ':' {
          return Err("after object key, got '\{chars[j]}', want ':' ")
        }
        j += 1
        match parse_json_value(chars, j) {
          Err(e) => return Err(e)
          Ok((val, next_j2)) => {
            let key = @value.Value::StrVal(@value.StarlarkString::new(key_raw))
            let _ = dict.set(key, val)
            j = skip_ws(chars, next_j2)
            if j >= len {
              return Err("unexpected end of file")
            }
            let c = chars[j]
            if c == '}' {
              return Ok((@value.Value::DictVal(dict), j + 1))
            } else if c == ',' {
              j = skip_ws(chars, j + 1)
              if j < len && chars[j] == '}' {
                return Err("unexpected character '\{chars[j]}'")
              }
            } else {
              return Err("in object, got '\{c}', want ',' or '}'")
            }
          }
        }
      }
    }
  }
  Err("unexpected end of file")
}

///|
fn parse_json_number(
  chars : Array[Char],
  i : Int,
) -> Result[(@value.Value, Int), String] {
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
    return Err("invalid number: \{num_str}")
  }
  let first_digit = chars[first_digit_idx]
  if first_digit == '0' &&
    first_digit_idx + 1 < j &&
    is_digit_char(chars[first_digit_idx + 1]) {
    return Err("invalid number: \{num_str}")
  }
  if is_float {
    let f = @string.parse_double(num_str) catch {
      _ => return Err("invalid number: \{num_str}")
    }
    Ok((@value.Value::FloatVal(f), j))
  } else {
    let n = @string.parse_int64(num_str) catch {
      _ => return Err("invalid number: \{num_str}")
    }
    Ok((@value.Value::IntVal(n), j))
  }
}

///|
pub fn decode_from_json(
  s : String,
  default : @value.Value?,
) -> Result[@value.Value, String] {
  let chars = s.to_array()
  match parse_json_value(chars, 0) {
    Err(e) =>
      match default {
        Some(d) => Ok(d)
        None => Err("json.decode: at offset 0, \{e}")
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
pub fn indent_json(
  s : String,
  prefix : String,
  indent_str : String,
) -> Result[String, String] {
  let chars = s.to_array()
  let len = chars.length()
  let buf = StringBuilder::new()
  let mut depth = 0
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
    } else {
      let cp = c.to_int()
      if cp == ' '.to_int() ||
        cp == '\t'.to_int() ||
        cp == '\n'.to_int() ||
        cp == '\r'.to_int() {
        i += 1
      } else if c == '"' {
        in_string = true
        buf.write_char(c)
        i += 1
      } else if c == '{' || c == '[' {
        buf.write_char(c)
        depth += 1
        i += 1
        let ni = skip_ws(chars, i)
        if ni < len && (chars[ni] == '}' || chars[ni] == ']') {
          depth -= 1
          buf.write_char(chars[ni])
          i = ni + 1
          continue
        }
        buf.write_char('\n')
        buf.write_string(prefix)
        for _ in 0..<depth {
          buf.write_string(indent_str)
        }
      } else if c == '}' || c == ']' {
        depth -= 1
        buf.write_char('\n')
        buf.write_string(prefix)
        for _ in 0..<depth {
          buf.write_string(indent_str)
        }
        buf.write_char(c)
        i += 1
      } else if c == ',' {
        buf.write_char(',')
        buf.write_char('\n')
        buf.write_string(prefix)
        for _ in 0..<depth {
          buf.write_string(indent_str)
        }
        i += 1
      } else if c == ':' {
        buf.write_string(": ")
        i += 1
      } else {
        let cp2 = c.to_int()
        if (cp2 >= 'a'.to_int() && cp2 <= 'z'.to_int()) ||
          (cp2 >= 'A'.to_int() && cp2 <= 'Z'.to_int()) ||
          (cp2 >= '0'.to_int() && cp2 <= '9'.to_int()) ||
          c == '-' ||
          c == '+' ||
          c == '.' {
          buf.write_char(c)
          i += 1
        } else {
          return Err("invalid character '\{c}' in JSON")
        }
      }
    }
  }
  if depth != 0 {
    return Err("unexpected end of JSON")
  }
  Ok(buf.to_string())
}

///|
fn make_encode_fn() -> @value.Value {
  @value.Value::new_builtin("json.encode", fn(_ctx, pos_args, kw_args) {
    if pos_args.length() != 1 || kw_args.length() != 0 {
      return Err("json.encode: got \{pos_args.length()} arguments, want 1")
    }
    encode_to_json(pos_args[0]).map(fn(s) {
      @value.Value::StrVal(@value.StarlarkString::new(s))
    })
  })
}

///|
fn make_encode_indent_fn() -> @value.Value {
  @value.Value::new_builtin("json.encode_indent", fn(_ctx, pos_args, kw_args) {
    if pos_args.length() != 1 {
      return Err(
        "json.encode_indent: got \{pos_args.length()} arguments, want 1",
      )
    }
    let mut pfx = ""
    let mut ind = "\t"
    for kw in kw_args {
      let (k, v) = kw
      match (k, v) {
        ("prefix", @value.Value::StrVal(s)) => pfx = s.raw
        ("indent", @value.Value::StrVal(s)) => ind = s.raw
        ("prefix" | "indent", _) =>
          return Err("json.encode_indent: prefix and indent must be strings")
        _ => return Err("json.encode_indent: unexpected keyword argument \{k}")
      }
    }
    match encode_to_json(pos_args[0]) {
      Err(e) => Err(e)
      Ok(json_str) =>
        indent_json(json_str, pfx, ind).map(fn(result) {
          @value.Value::StrVal(@value.StarlarkString::new(result))
        })
    }
  })
}

///|
fn make_decode_fn() -> @value.Value {
  @value.Value::new_builtin("json.decode", fn(_ctx, pos_args, kw_args) {
    for kw in kw_args {
      let (k, _) = kw
      if k == "x" {
        return Err("json.decode: unexpected keyword argument x")
      }
    }
    if pos_args.length() < 1 {
      return Err("json.decode: missing required argument 'x'")
    }
    let x = match pos_args[0] {
      @value.Value::StrVal(s) => s.raw
      _ => return Err("json.decode: x must be a string")
    }
    let default_val : @value.Value? = if pos_args.length() >= 2 {
      Some(pos_args[1])
    } else {
      let mut found : @value.Value? = None
      for kw in kw_args {
        let (k, v) = kw
        if k == "default" {
          found = Some(v)
          break
        }
      }
      found
    }
    decode_from_json(x, default_val)
  })
}

///|
fn make_indent_fn() -> @value.Value {
  @value.Value::new_builtin("json.indent", fn(_ctx, pos_args, kw_args) {
    if pos_args.length() != 1 {
      return Err("json.indent: got \{pos_args.length()} arguments, want 1")
    }
    let s = match pos_args[0] {
      @value.Value::StrVal(s) => s.raw
      _ => return Err("json.indent: argument must be a string")
    }
    let mut pfx = ""
    let mut ind = "\t"
    for kw in kw_args {
      let (k, v) = kw
      match (k, v) {
        ("prefix", @value.Value::StrVal(sv)) => pfx = sv.raw
        ("indent", @value.Value::StrVal(sv)) => ind = sv.raw
        ("prefix" | "indent", _) =>
          return Err("json.indent: prefix and indent must be strings")
        _ => return Err("json.indent: unexpected keyword argument \{k}")
      }
    }
    indent_json(s, pfx, ind).map(fn(result) {
      @value.Value::StrVal(@value.StarlarkString::new(result))
    })
  })
}

///|
pub fn json_module() -> @value.Value {
  let attrs : Map[String, @value.Value] = {}
  attrs["encode"] = make_encode_fn()
  attrs["encode_indent"] = make_encode_indent_fn()
  attrs["decode"] = make_decode_fn()
  attrs["indent"] = make_indent_fn()
  @value.Value::ModuleVal(@value.StarlarkModule::new("json", attrs))
}
