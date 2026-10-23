///|
#borrow(data)
extern "C" fn ffi_println_bytes(data : Bytes, len : Int32) -> Unit = "starlark_println_bytes"

///|
fn default_println_bytes(bytes : Bytes) -> Unit {
  ffi_println_bytes(bytes, bytes.length())
}
