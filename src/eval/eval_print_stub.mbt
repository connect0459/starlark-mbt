///|
fn default_println_bytes(bytes : Bytes) -> Unit {
  println(@utf8.decode_lossy(bytes[:]))
}
