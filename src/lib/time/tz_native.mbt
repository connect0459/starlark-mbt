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
#borrow(name_bytes)
extern "C" fn ffi_get_tz_offset(name_bytes : Bytes, unix_time : Int64) -> Int = "starlark_get_tz_offset"

///|
fn is_valid_timezone_impl(name : String) -> Bool {
  let bytes = string_to_c_bytes(name)
  ffi_is_valid_timezone(bytes)
}

///|
fn get_tz_offset_at_impl(name : String, unix_time : Int64) -> Int? {
  let bytes = string_to_c_bytes(name)
  let offset = ffi_get_tz_offset(bytes, unix_time)
  // INT32_MIN (-2147483648) is the sentinel for "error"
  if offset == -2147483648 {
    None
  } else {
    Some(offset)
  }
}
