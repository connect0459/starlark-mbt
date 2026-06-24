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
  let result = get_local_tz_at(0L)
  unset_tz_for_test()
  match result {
    Some((offset, abbr)) => {
      assert_eq(offset, 0)
      assert_eq(abbr, "UTC")
    }
    None => fail("local timezone should never return None for TZ=UTC")
  }
}

///|
test "local tz query: Asia/Tokyo environment yields +32400 offset and JST abbreviation" {
  set_tz_for_test("Asia/Tokyo")
  let result = get_local_tz_at(0L)
  unset_tz_for_test()
  match result {
    Some((offset, abbr)) => {
      assert_eq(offset, 32400)
      assert_eq(abbr, "JST")
    }
    None => fail("local timezone should never return None for TZ=Asia/Tokyo")
  }
}

///|
test "UTC resolves to offset 0 at a very large timestamp" {
  match get_tz_abbr_at("UTC", 9000000000000000000L) {
    Some((offset, abbr)) => {
      assert_eq(offset, 0)
      assert_eq(abbr, "UTC")
    }
    None =>
      fail("UTC timezone should not return None at a very large timestamp")
  }
}

///|
test "UTC resolves to offset 0 at the Unix epoch" {
  match get_tz_abbr_at("UTC", 0L) {
    Some((offset, abbr)) => {
      assert_eq(offset, 0)
      assert_eq(abbr, "UTC")
    }
    None => fail("UTC timezone should not return None at the Unix epoch")
  }
}

///|
test "Asia/Tokyo resolves at a timestamp within the representable range but above the old threshold" {
  // 5e16 was needlessly clamped at the old 9e15 threshold; the raised limit
  // lets localtime_r handle it directly, so JST is always +32400.
  match get_tz_abbr_at("Asia/Tokyo", 50000000000000000L) {
    Some((offset, abbr)) => {
      assert_eq(offset, 32400)
      assert_eq(abbr, "JST")
    }
    None => fail("Asia/Tokyo timezone should not return None at 5e16")
  }
}

///|
test "Asia/Tokyo resolves at a timestamp beyond localtime_r range" {
  // 9e18 exceeds the ±6e16 limit; safe_localtime_sec aligns to the same
  // Julian-year phase inside the safe range.  Japan has no DST so JST is
  // always +32400 regardless of phase.
  match get_tz_abbr_at("Asia/Tokyo", 9000000000000000000L) {
    Some((offset, abbr)) => {
      assert_eq(offset, 32400)
      assert_eq(abbr, "JST")
    }
    None =>
      fail(
        "Asia/Tokyo timezone should not return None at a very large timestamp",
      )
  }
}

///|
test "named zone returns Some (not None) at extreme negative timestamp" {
  // Phase alignment maps -9e18 to a modern-era positive instant; for a
  // non-DST zone the abbreviation is stable regardless of era.
  match get_tz_abbr_at("Asia/Tokyo", -9000000000000000000L) {
    Some((offset, abbr)) => {
      assert_eq(offset, 32400)
      assert_eq(abbr, "JST")
    }
    None =>
      fail(
        "Asia/Tokyo timezone should not return None at a large negative timestamp",
      )
  }
}
