///|
fn is_printable_ascii(b : Int) -> Bool {
  b >= 0x20 && b < 0x7F
}

///|
fn write_rune_utf8(r : Int, buf : StringBuilder) -> Unit {
  if r < 0x80 {
    buf.write_char(r.unsafe_to_char())
  } else if r < 0x800 {
    buf.write_char(((r >> 6) | 0xC0).unsafe_to_char())
    buf.write_char(((r & 0x3F) | 0x80).unsafe_to_char())
  } else if r < 0x10000 {
    buf.write_char(((r >> 12) | 0xE0).unsafe_to_char())
    buf.write_char((((r >> 6) & 0x3F) | 0x80).unsafe_to_char())
    buf.write_char(((r & 0x3F) | 0x80).unsafe_to_char())
  } else {
    buf.write_char(((r >> 18) | 0xF0).unsafe_to_char())
    buf.write_char((((r >> 12) & 0x3F) | 0x80).unsafe_to_char())
    buf.write_char((((r >> 6) & 0x3F) | 0x80).unsafe_to_char())
    buf.write_char(((r & 0x3F) | 0x80).unsafe_to_char())
  }
}

///|
pub fn quote(s : String, is_bytes : Bool) -> String {
  let raw = @utf8.encode(s)
  let buf = StringBuilder::new()
  if is_bytes {
    buf.write_char('b')
  }
  buf.write_char('"')
  let mut i = 0
  while i < raw.length() {
    let b = raw[i].to_int()
    match b {
      0x22 => {
        buf.write_string("\\\"")
        i += 1
      }
      0x5C => {
        buf.write_string("\\\\")
        i += 1
      }
      0x07 => {
        buf.write_string("\\a")
        i += 1
      }
      0x08 => {
        buf.write_string("\\b")
        i += 1
      }
      0x0C => {
        buf.write_string("\\f")
        i += 1
      }
      0x0A => {
        buf.write_string("\\n")
        i += 1
      }
      0x0D => {
        buf.write_string("\\r")
        i += 1
      }
      0x09 => {
        buf.write_string("\\t")
        i += 1
      }
      0x0B => {
        buf.write_string("\\v")
        i += 1
      }
      _ =>
        if b >= 0x80 {
          let (r, width) = @utf8util.utf8_decode_rune(raw, i)
          if r >= 0 && @utf8util.is_unicode_printable(r) {
            write_rune_utf8(r, buf)
            i += width
          } else if r >= 0 {
            if r < 0x10000 {
              buf.write_string("\\u")
              @utf8util.write_hex4(buf, r)
            } else {
              buf.write_string("\\U")
              @utf8util.write_hex8(buf, r)
            }
            i += width
          } else {
            buf.write_string("\\x")
            @utf8util.write_hex2(buf, b)
            i += 1
          }
        } else if is_printable_ascii(b) {
          buf.write_char(b.unsafe_to_char())
          i += 1
        } else {
          buf.write_string("\\x")
          @utf8util.write_hex2(buf, b)
          i += 1
        }
    }
  }
  buf.write_char('"')
  buf.to_string()
}

///|
fn xdigit_val_q(c : Byte) -> Int {
  let n = c.to_int()
  if n >= 0x30 && n <= 0x39 {
    n - 0x30
  } else if n >= 0x61 && n <= 0x66 {
    n - 0x61 + 10
  } else if n >= 0x41 && n <= 0x46 {
    n - 0x41 + 10
  } else {
    -1
  }
}

///|
fn is_odigit_q(c : Byte) -> Bool {
  let n = c.to_int()
  n >= 0x30 && n <= 0x37
}

///|
fn append_cp_utf8(cp : Int, buf : Array[Byte]) -> Unit {
  if cp < 0x80 {
    buf.push(cp.to_byte())
  } else if cp < 0x800 {
    buf.push(((cp >> 6) | 0xC0).to_byte())
    buf.push(((cp & 0x3F) | 0x80).to_byte())
  } else if cp < 0x10000 {
    buf.push(((cp >> 12) | 0xE0).to_byte())
    buf.push((((cp >> 6) & 0x3F) | 0x80).to_byte())
    buf.push(((cp & 0x3F) | 0x80).to_byte())
  } else {
    buf.push(((cp >> 18) | 0xF0).to_byte())
    buf.push((((cp >> 12) & 0x3F) | 0x80).to_byte())
    buf.push((((cp >> 6) & 0x3F) | 0x80).to_byte())
    buf.push(((cp & 0x3F) | 0x80).to_byte())
  }
}

///|
fn parse_hex_n(s : Bytes, pos : Int, n : Int) -> Result[Int, String] {
  if pos + n > s.length() {
    return Err("truncated hex escape")
  }
  let mut val = 0
  for i in 0..<n {
    let d = xdigit_val_q(s[pos + i])
    if d < 0 {
      return Err("invalid hex digit in escape")
    }
    val = val * 16 + d
  }
  Ok(val)
}

///|
pub fn unquote(literal : String) -> Result[(String, Bool), String] {
  let raw = @utf8.encode(literal)
  let len = raw.length()
  let mut pos = 0
  let mut is_raw = false
  let mut is_bytes = false
  if pos < len && raw[pos] == b'r' {
    is_raw = true
    pos += 1
  }
  if pos < len && raw[pos] == b'b' {
    is_bytes = true
    pos += 1
  } else if pos < len && raw[pos] == b'r' && !is_raw {
    is_raw = true
    pos += 1
  }
  if pos >= len {
    return Err("string literal too short")
  }
  let q = raw[pos]
  if q != b'"' && q != b'\'' {
    return Err("string literal has invalid quotes")
  }
  pos += 1
  let triple = pos + 1 < len &&
    raw[pos] == q &&
    pos + 2 < len &&
    raw[pos + 1] == q &&
    len >= 6 &&
    raw[len - 3] == q &&
    raw[len - 2] == q &&
    raw[len - 1] == q
  let content_end = if triple {
    if len < pos + 2 + 3 {
      return Err("string literal too short for triple quote")
    }
    pos += 2
    len - 3
  } else {
    if len - 1 < pos || raw[len - 1] != q {
      return Err("string literal has mismatched quotes")
    }
    len - 1
  }
  let out : Array[Byte] = []
  if is_raw {
    let mut i = pos
    while i < content_end {
      let c = raw[i]
      if c == b'\r' {
        out.push(b'\n')
        i += 1
        if i < content_end && raw[i] == b'\n' {
          i += 1
        }
      } else {
        out.push(c)
        i += 1
      }
    }
  } else {
    let mut i = pos
    while i < content_end {
      let c = raw[i]
      if c == b'\r' {
        out.push(b'\n')
        i += 1
        if i < content_end && raw[i] == b'\n' {
          i += 1
        }
        continue
      }
      if c != b'\\' {
        out.push(c)
        i += 1
        continue
      }
      i += 1
      if i >= content_end {
        return Err("truncated escape sequence at end of literal")
      }
      let ec = raw[i]
      i += 1
      match ec {
        b'a' => out.push(b'\x07')
        b'b' => out.push(b'\x08')
        b'f' => out.push(b'\x0c')
        b'n' => out.push(b'\n')
        b'r' => out.push(b'\r')
        b't' => out.push(b'\t')
        b'v' => out.push(b'\x0b')
        b'\\' => out.push(b'\\')
        b'\'' => out.push(b'\'')
        b'"' => out.push(b'"')
        b'\n' => ()
        b'\r' => if i < content_end && raw[i] == b'\n' { i += 1 }
        b'x' =>
          match parse_hex_n(raw, i, 2) {
            Err(e) => return Err(e)
            Ok(val) => {
              out.push(val.to_byte())
              i += 2
            }
          }
        b'u' => {
          if is_bytes {
            return Err("\\u escape not allowed in bytes literal")
          }
          match parse_hex_n(raw, i, 4) {
            Err(e) => return Err(e)
            Ok(cp) => {
              if cp >= 0xD800 && cp <= 0xDFFF {
                return Err("invalid Unicode surrogate")
              }
              append_cp_utf8(cp, out)
              i += 4
            }
          }
        }
        b'U' => {
          if is_bytes {
            return Err("\\U escape not allowed in bytes literal")
          }
          match parse_hex_n(raw, i, 8) {
            Err(e) => return Err(e)
            Ok(cp) => {
              if cp > 0x10FFFF {
                return Err("code point out of range")
              }
              if cp >= 0xD800 && cp <= 0xDFFF {
                return Err("invalid Unicode surrogate")
              }
              append_cp_utf8(cp, out)
              i += 8
            }
          }
        }
        c =>
          if is_odigit_q(c) {
            let mut val = c.to_int() - 0x30
            for _ in 0..<2 {
              if i < content_end && is_odigit_q(raw[i]) {
                val = val * 8 + (raw[i].to_int() - 0x30)
                i += 1
              } else {
                break
              }
            }
            if val >= 256 {
              return Err("invalid octal escape: value >= 256")
            }
            if !is_bytes && val > 127 {
              return Err("non-ASCII octal escape")
            }
            out.push(val.to_byte())
          } else {
            let ch = ec.to_int().unsafe_to_char()
            return Err("invalid escape sequence \\\{ch}")
          }
      }
    }
  }
  let result = @utf8.decode_lossy(Bytes::from_array(out)[:])
  Ok((result, is_bytes))
}
