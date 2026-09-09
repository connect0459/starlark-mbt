///|
pub fn utf8_encode(s : String) -> Bytes {
  @utf8.encode(s)
}

///|
pub fn utf8_decode_lossy(bytes : Bytes) -> String {
  @utf8.decode_lossy(bytes[:])
}
