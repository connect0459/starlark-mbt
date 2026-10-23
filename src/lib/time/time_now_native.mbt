///|
extern "C" fn ffi_get_unix_sec() -> Int64 = "starlark_time_get_unix_sec"

///|
extern "C" fn ffi_get_unix_nsec() -> Int32 = "starlark_time_get_unix_nsec"

///|
pub fn get_unix_time_now() -> (Int64, Int32) {
  (ffi_get_unix_sec(), ffi_get_unix_nsec())
}
