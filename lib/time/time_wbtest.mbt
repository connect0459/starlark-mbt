///|
test "fmt_duration: Duration minimum value formats without double minus" {
  assert_eq(fmt_duration(-9223372036854775808L), "-2562047h47m16.854775808s")
}

///|
test "fmt_duration: Duration maximum value formats correctly" {
  assert_eq(fmt_duration(9223372036854775807L), "2562047h47m16.854775807s")
}

///|
test "ymd_to_unix_day_i64: Unix epoch is day 0" {
  assert_eq(ymd_to_unix_day_i64(1970L, 1, 1), 0L)
}

///|
test "ymd_to_unix_day_i64: known historical date" {
  assert_eq(ymd_to_unix_day_i64(2000L, 1, 1), 10957L)
}

///|
test "ymd_to_unix_day_i64: year beyond 9999" {
  assert_eq(ymd_to_unix_day_i64(12021L, 1, 1), 3671053L)
}

///|
test "unix_day_to_ymd_i64: Unix epoch decomposes correctly" {
  let (y, m, d) = unix_day_to_ymd_i64(0L)
  assert_eq(y, 1970L)
  assert_eq(m, 1)
  assert_eq(d, 1)
}

///|
test "unix_day_to_ymd_i64: year beyond 9999 decomposes correctly" {
  let (y, m, d) = unix_day_to_ymd_i64(3671053L)
  assert_eq(y, 12021L)
  assert_eq(m, 1)
  assert_eq(d, 1)
}

///|
test "unix_day_to_ymd_i64: negative unix day decomposes correctly" {
  let (y, m, d) = unix_day_to_ymd_i64(-719162L)
  assert_eq(y, 1L)
  assert_eq(m, 1)
  assert_eq(d, 1)
}

///|
test "weekday_from_unix_day: Unix epoch is Thursday" {
  assert_eq(weekday_from_unix_day(0L), 4)
}

///|
test "weekday_from_unix_day: day before epoch is Wednesday" {
  assert_eq(weekday_from_unix_day(-1L), 3)
}

///|
test "normalize_to_unix_sec: year at representable limit is accepted" {
  assert_true(
    normalize_to_unix_sec(290_000_000_000L, 1L, 1L, 0L, 0L, 0L, 0L) is Ok(_),
  )
}

///|
test "normalize_to_unix_sec: year beyond representable limit is rejected" {
  assert_true(
    normalize_to_unix_sec(290_000_000_001L, 1L, 1L, 0L, 0L, 0L, 0L) is Err(_),
  )
}

///|
test "normalize_to_unix_sec: month normalization beyond representable limit is rejected" {
  assert_true(
    normalize_to_unix_sec(0L, 3_480_000_000_013L, 1L, 0L, 0L, 0L, 0L) is Err(_),
  )
}

///|
test "normalize_to_unix_sec: year beyond 9999 is accepted" {
  assert_true(normalize_to_unix_sec(12021L, 1L, 1L, 0L, 0L, 0L, 0L) is Ok(_))
}

///|
test "normalize_to_unix_sec: year beyond 9999 gives correct unix second" {
  match normalize_to_unix_sec(12021L, 1L, 1L, 0L, 0L, 0L, 0L) {
    Ok((sec, _)) => assert_eq(sec, 3671053L * 86400L)
    Err(e) => fail(e)
  }
}

///|
test "fmt_time_at_zone: 3-digit year is zero-padded to 4 digits" {
  match normalize_to_unix_sec(987L, 1L, 1L, 0L, 0L, 0L, 0L) {
    Ok((sec, _)) =>
      assert_eq(
        fmt_time_at_zone(sec, 0, 0, "UTC"),
        "0987-01-01 00:00:00 +0000 UTC",
      )
    Err(e) => fail(e)
  }
}

///|
test "fmt_time_at_zone: negative year is sign-prefixed and zero-padded" {
  match normalize_to_unix_sec(-1L, 1L, 1L, 0L, 0L, 0L, 0L) {
    Ok((sec, _)) => {
      let s = fmt_time_at_zone(sec, 0, 0, "UTC")
      assert_true(s.has_prefix("-0001-"))
    }
    Err(e) => fail(e)
  }
}

///|
test "fmt_time_at_zone: year beyond 9999 formats without error" {
  match normalize_to_unix_sec(12021L, 1L, 1L, 0L, 0L, 0L, 0L) {
    Ok((sec, _)) =>
      assert_eq(
        fmt_time_at_zone(sec, 0, 0, "UTC"),
        "12021-01-01 00:00:00 +0000 UTC",
      )
    Err(e) => fail(e)
  }
}

///|
test "fmt_go_layout: 3-digit year is zero-padded via 2006 token" {
  assert_eq(
    fmt_go_layout(987L, 1, 1, 0, 0, 0, 0, 0, "UTC", "2006-01-02"),
    "0987-01-01",
  )
}

///|
test "fmt_go_layout: negative year is sign-prefixed and zero-padded via 2006 token" {
  assert_eq(
    fmt_go_layout(-1L, 1, 1, 0, 0, 0, 0, 0, "UTC", "2006-01-02"),
    "-0001-01-01",
  )
}

///|
test "fmt_go_layout: negative year two-digit token is sign-prefixed and zero-padded" {
  assert_eq(fmt_go_layout(-1L, 1, 1, 0, 0, 0, 0, 0, "UTC", "06"), "-01")
}

///|
test "parse_go_layout: default year is 0 when layout omits year" {
  match parse_go_layout("06-01", "01-02") {
    Ok((year, _, _, _, _, _, _, _)) => assert_eq(year, 0)
    Err(e) => fail(e)
  }
}

///|
test "parse_duration_str: Int64 minimum value in nanoseconds is accepted" {
  match parse_duration_str("-9223372036854775808ns") {
    Ok(v) => assert_eq(v, -9223372036854775808L)
    Err(e) => fail("expected Ok, got Err(\{e})")
  }
}

///|
test "parse_duration_str: one less than Int64 minimum in nanoseconds is accepted" {
  match parse_duration_str("-9223372036854775807ns") {
    Ok(v) => assert_eq(v, -9223372036854775807L)
    Err(e) => fail("expected Ok, got Err(\{e})")
  }
}
