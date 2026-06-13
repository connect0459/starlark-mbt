///|
#borrow(name, value)
extern "C" fn ffi_setenv(name : Bytes, value : Bytes, overwrite : Int) -> Int = "setenv"

///|
#borrow(name)
extern "C" fn ffi_unsetenv(name : Bytes) -> Int = "unsetenv"

///|
extern "C" fn ffi_tzset() = "tzset"

///|
fn set_tz_for_test(zone : String) -> Unit {
  let _ = ffi_setenv(string_to_c_bytes("TZ"), string_to_c_bytes(zone), 1)
  ffi_tzset()
}

///|
fn unset_tz_for_test() -> Unit {
  let _ = ffi_unsetenv(string_to_c_bytes("TZ"))
  ffi_tzset()
}

///|
test "local tz query: UTC environment yields zero offset and UTC abbreviation" {
  set_tz_for_test("UTC")
  let result = get_local_tz_at_impl(0L)
  unset_tz_for_test()
  match result {
    Some((offset, abbr)) => {
      assert_eq(offset, 0)
      assert_eq(abbr, "UTC")
    }
    None => fail("get_local_tz_at_impl returned None for TZ=UTC")
  }
}

///|
test "local tz query: Asia/Tokyo environment yields +32400 offset and JST abbreviation" {
  set_tz_for_test("Asia/Tokyo")
  let result = get_local_tz_at_impl(0L)
  unset_tz_for_test()
  match result {
    Some((offset, abbr)) => {
      assert_eq(offset, 32400)
      assert_eq(abbr, "JST")
    }
    None => fail("get_local_tz_at_impl returned None for TZ=Asia/Tokyo")
  }
}

///|
test "get_tz_abbr_at_impl: UTC resolves to offset 0 at a very large timestamp" {
  match get_tz_abbr_at_impl("UTC", 9000000000000000000L) {
    Some((offset, abbr)) => {
      assert_eq(offset, 0)
      assert_eq(abbr, "UTC")
    }
    None => fail("get_tz_abbr_at_impl returned None for UTC at large timestamp")
  }
}

///|
test "get_tz_abbr_at_impl: UTC resolves to offset 0 at the Unix epoch" {
  match get_tz_abbr_at_impl("UTC", 0L) {
    Some((offset, abbr)) => {
      assert_eq(offset, 0)
      assert_eq(abbr, "UTC")
    }
    None => fail("get_tz_abbr_at_impl returned None for UTC at epoch")
  }
}
