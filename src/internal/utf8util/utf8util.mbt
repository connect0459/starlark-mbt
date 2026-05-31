///|
/// Returns the lowercase hexadecimal character for a nibble value (0–15).
///
/// Parameters:
///
/// * `n` : A nibble value in the range 0–15.
///
/// Returns the corresponding lowercase hex character (`'0'`–`'9'` or `'a'`–`'f'`).
pub fn hex_char(n : Int) -> Char {
  if n < 10 {
    ('0'.to_int() + n).unsafe_to_char()
  } else {
    ('a'.to_int() + n - 10).unsafe_to_char()
  }
}

///|
/// Appends a 2-digit lowercase hex representation of n to buf.
///
/// Parameters:
///
/// * `buf` : The string builder to append to.
/// * `n` : The integer value whose low 8 bits are formatted.
pub fn write_hex2(buf : StringBuilder, n : Int) -> Unit {
  buf.write_char(hex_char((n >> 4) & 0xF))
  buf.write_char(hex_char(n & 0xF))
}

///|
/// Appends a 4-digit lowercase hex representation of n to buf.
///
/// Parameters:
///
/// * `buf` : The string builder to append to.
/// * `n` : The integer value whose low 16 bits are formatted.
pub fn write_hex4(buf : StringBuilder, n : Int) -> Unit {
  buf.write_char(hex_char((n >> 12) & 0xF))
  buf.write_char(hex_char((n >> 8) & 0xF))
  buf.write_char(hex_char((n >> 4) & 0xF))
  buf.write_char(hex_char(n & 0xF))
}

///|
/// Appends an 8-digit lowercase hex representation of n to buf.
///
/// Parameters:
///
/// * `buf` : The string builder to append to.
/// * `n` : The integer value whose full 32 bits are formatted.
pub fn write_hex8(buf : StringBuilder, n : Int) -> Unit {
  buf.write_char(hex_char((n >> 28) & 0xF))
  buf.write_char(hex_char((n >> 24) & 0xF))
  buf.write_char(hex_char((n >> 20) & 0xF))
  buf.write_char(hex_char((n >> 16) & 0xF))
  buf.write_char(hex_char((n >> 12) & 0xF))
  buf.write_char(hex_char((n >> 8) & 0xF))
  buf.write_char(hex_char((n >> 4) & 0xF))
  buf.write_char(hex_char(n & 0xF))
}

///|
/// Decodes a single UTF-8 rune from `b` starting at `pos`.
///
/// Parameters:
///
/// * `b` : The byte sequence to decode from.
/// * `pos` : The byte offset at which to start decoding.
///
/// Returns `(rune, byte_width)`. Returns `(-1, 1)` for invalid or truncated sequences.
pub fn utf8_decode_rune(b : Bytes, pos : Int) -> (Int, Int) {
  // RFC 3629 valid leading byte ranges:
  //   2-byte: 0xC2..0xDF (0xC0/0xC1 are overlong; start bits: 110xxxxx)
  //   3-byte: 0xE0..0xEF (start bits: 1110xxxx)
  //   4-byte: 0xF0..0xF4 (0xF5..0xF7 encode > U+10FFFF; start bits: 11110xxx)
  // Continuation bytes: 0x80..0xBF (10xxxxxx); payload mask: 0x3F (6 bits).
  // Reassembly: the leading byte keeps 7-len payload bits (mask 0x1F/0x0F/0x07
  // for 2/3/4-byte forms) shifted left by 6*(len-1); each later continuation
  // byte fills the next-lower 6-bit slot, so shifts step down 18→12→6→0.
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
/// Reports whether a Unicode codepoint is printable, matching Go's
/// `strconv.IsPrint`. Used by `repr` to decide whether to emit `\xNN` escapes.
///
/// Parameters:
///
/// * `r` : The Unicode codepoint to test.
///
/// Returns `true` if the codepoint is considered printable, `false` otherwise.
pub fn is_unicode_printable(r : Int) -> Bool {
  if r < 0x20 || r == 0x7F {
    return false
  }
  if r < 0x80 {
    return true
  }
  // C1 controls (Cc)
  if r <= 0x9F {
    return false
  }
  // NBSP and other Zs space separators (not printable in Go's strconv.IsPrint)
  if r == 0xA0 {
    return false
  }
  // soft hyphen
  if r == 0xAD {
    return false
  }
  // line and paragraph separators
  if r >= 0x2028 && r <= 0x2029 {
    return false
  }
  // zero-width and directional format chars
  if r >= 0x200B && r <= 0x200F {
    return false
  }
  if r >= 0x202A && r <= 0x202E {
    return false
  }
  if r >= 0x2060 && r <= 0x2064 {
    return false
  }
  if r >= 0x2066 && r <= 0x206F {
    return false
  }
  // BOM
  if r == 0xFEFF {
    return false
  }
  // misc special chars (interlinear annotation, etc.)
  if r >= 0xFFF9 && r <= 0xFFFB {
    return false
  }
  // noncharacters U+FFFE, U+FFFF
  if r == 0xFFFE || r == 0xFFFF {
    return false
  }
  // private-use area (BMP)
  if r >= 0xE000 && r <= 0xF8FF {
    return false
  }
  // noncharacters FDD0-FDEF
  if r >= 0xFDD0 && r <= 0xFDEF {
    return false
  }
  // supplemental private-use areas and high noncharacters
  if r >= 0xF0000 {
    return false
  }
  true
}
