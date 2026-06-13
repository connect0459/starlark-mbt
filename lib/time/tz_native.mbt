///|
fn string_to_c_bytes(s : String) -> Bytes {
  let res : Array[Byte] = Array::new(capacity=s.length() + 1)
  let n = s.length()
  let mut i = 0
  while i < n {
    let mut cp = s.code_unit_at(i).to_int()
    if cp >= 0xD800 && cp <= 0xDBFF {
      cp -= 0xD800
      i += 1
      let lo = s.code_unit_at(i).to_int() - 0xDC00
      cp = (cp << 10) | lo | 0x10000
    }
    if cp < 0x80 {
      res.push(cp.to_byte())
    } else if cp < 0x800 {
      res.push((0xC0 | (cp >> 6)).to_byte())
      res.push((0x80 | (cp & 0x3F)).to_byte())
    } else if cp < 0x10000 {
      res.push((0xE0 | (cp >> 12)).to_byte())
      res.push((0x80 | ((cp >> 6) & 0x3F)).to_byte())
      res.push((0x80 | (cp & 0x3F)).to_byte())
    } else {
      res.push((0xF0 | (cp >> 18)).to_byte())
      res.push((0x80 | ((cp >> 12) & 0x3F)).to_byte())
      res.push((0x80 | ((cp >> 6) & 0x3F)).to_byte())
      res.push((0x80 | (cp & 0x3F)).to_byte())
    }
    i += 1
  }
  res.push(0) // null terminator for C
  Bytes::from_array(res)
}

///|
#borrow(name_bytes)
extern "C" fn ffi_is_valid_timezone(name_bytes : Bytes) -> Bool = "starlark_is_valid_timezone"

///|
#borrow(name_bytes, abbr_out)
extern "C" fn ffi_get_tz_abbr(
  name_bytes : Bytes,
  unix_time : Int64,
  abbr_out : Bytes,
) -> Int = "starlark_get_tz_abbr"

///|
#borrow(abbr_out)
extern "C" fn ffi_get_local_tz_at(unix_time : Int64, abbr_out : Bytes) -> Int = "starlark_get_local_tz_at"

///|
fn bytes_to_ascii_string(buf : Bytes) -> String {
  let sb = StringBuilder::new()
  let mut i = 0
  while i < buf.length() {
    let b = buf[i].to_int()
    if b == 0 {
      break
    }
    sb.write_char(b.unsafe_to_char())
    i += 1
  }
  sb.to_string()
}

///|
fn is_valid_timezone_impl(name : String) -> Bool {
  let bytes = string_to_c_bytes(name)
  ffi_is_valid_timezone(bytes)
}

///|
fn get_tz_abbr_at_impl(name : String, unix_time : Int64) -> (Int, String)? {
  // UTC has a constant offset of 0 at every timestamp; bypass localtime_r
  // which returns NULL for time_t values outside the system representable range.
  if name == "UTC" {
    return Some((0, "UTC"))
  }
  let name_bytes = string_to_c_bytes(name)
  let abbr_buf = Bytes::make(16, b'\x00')
  let offset = ffi_get_tz_abbr(name_bytes, unix_time, abbr_buf)
  if offset == -2147483648 {
    None
  } else {
    let abbr = bytes_to_ascii_string(abbr_buf)
    Some(
      (
        offset,
        if abbr.length() > 0 {
          abbr
        } else {
          tz_name_from_offset(offset)
        },
      ),
    )
  }
}

///|
fn get_local_tz_at_impl(unix_time : Int64) -> (Int, String)? {
  let abbr_buf = Bytes::make(16, b'\x00')
  let offset = ffi_get_local_tz_at(unix_time, abbr_buf)
  if offset == -2147483648 {
    None
  } else {
    let abbr = bytes_to_ascii_string(abbr_buf)
    Some(
      (
        offset,
        if abbr.length() > 0 {
          abbr
        } else {
          tz_name_from_offset(offset)
        },
      ),
    )
  }
}
