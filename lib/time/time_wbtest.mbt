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
test "decompose_unix_sec: Int64 minimum second matches Go normalization" {
  let (year, month, day, hour, minute, second) = decompose_unix_sec(
    -9223372036854775808L, 0,
  )
  assert_eq(year, 292277026596L)
  assert_eq(month, 12)
  assert_eq(day, 4)
  assert_eq(hour, 15)
  assert_eq(minute, 30)
  assert_eq(second, 8)
}

///|
test "decompose_unix_sec: Int64 maximum second matches Go normalization" {
  let (year, month, day, hour, minute, second) = decompose_unix_sec(
    9223372036854775807L, 0,
  )
  assert_eq(year, 292277026596L)
  assert_eq(month, 12)
  assert_eq(day, 4)
  assert_eq(hour, 15)
  assert_eq(minute, 30)
  assert_eq(second, 7)
}

///|
test "normalize_to_unix_sec: year at representable limit is accepted" {
  let _ = normalize_to_unix_sec(290_000_000_000L, 1L, 1L, 0L, 0L, 0L, 0L)
}

///|
test "normalize_to_unix_sec: year just above old 290e9 limit is accepted" {
  let (sec, _) = normalize_to_unix_sec(290_000_000_001L, 1L, 1L, 0L, 0L, 0L, 0L)
  assert_eq(sec, 9_151_516_017_864_403_200L)
}

///|
test "normalize_to_unix_sec: negative year just below old -290e9 limit is accepted" {
  let _ = normalize_to_unix_sec(-300_000_000_000L, 1L, 1L, 0L, 0L, 0L, 0L)
}

///|
test "normalize_to_unix_sec: month normalization producing year above old limit is accepted" {
  let _ = normalize_to_unix_sec(0L, 3_480_000_000_013L, 1L, 0L, 0L, 0L, 0L)
}

///|
test "normalize_to_unix_sec: year beyond 9999 is accepted" {
  let _ = normalize_to_unix_sec(12021L, 1L, 1L, 0L, 0L, 0L, 0L)
}

///|
test "normalize_to_unix_sec: year beyond 9999 gives correct unix second" {
  let (sec, _) = normalize_to_unix_sec(12021L, 1L, 1L, 0L, 0L, 0L, 0L)
  assert_eq(sec, 3671053L * 86400L)
}

///|
test "fmt_time_at_zone: 3-digit year is zero-padded to 4 digits" {
  let (sec, _) = normalize_to_unix_sec(987L, 1L, 1L, 0L, 0L, 0L, 0L)
  assert_eq(fmt_time_at_zone(sec, 0, 0, "UTC"), "0987-01-01 00:00:00 +0000 UTC")
}

///|
test "fmt_time_at_zone: negative year is sign-prefixed and zero-padded" {
  let (sec, _) = normalize_to_unix_sec(-1L, 1L, 1L, 0L, 0L, 0L, 0L)
  assert_true(fmt_time_at_zone(sec, 0, 0, "UTC").has_prefix("-0001-"))
}

///|
test "fmt_time_at_zone: year beyond 9999 formats without error" {
  let (sec, _) = normalize_to_unix_sec(12021L, 1L, 1L, 0L, 0L, 0L, 0L)
  assert_eq(
    fmt_time_at_zone(sec, 0, 0, "UTC"),
    "12021-01-01 00:00:00 +0000 UTC",
  )
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

///|
test "parse_duration_str: go canonical form of Int64 minimum duration is accepted" {
  match parse_duration_str("-2562047h47m16.854775808s") {
    Ok(v) => assert_eq(v, -9223372036854775808L)
    Err(e) => fail("expected Ok, got Err(\{e})")
  }
}

///|
test "parse_duration_str: leading-zero nanosecond form of Int64 minimum is accepted" {
  match parse_duration_str("-09223372036854775808ns") {
    Ok(v) => assert_eq(v, -9223372036854775808L)
    Err(e) => fail("expected Ok, got Err(\{e})")
  }
}

///|
test "parse_duration_str: positive 2^63 nanoseconds is rejected" {
  assert_true(parse_duration_str("9223372036854775808ns") is Err(_))
}

///|
test "parse_duration_str: magnitude one beyond Int64 minimum is rejected" {
  assert_true(parse_duration_str("-9223372036854775809ns") is Err(_))
}

///|
test "parse_rfc3339: completely wrong input includes remaining text and first token in error" {
  match parse_rfc3339("not a date") {
    Ok(_) => fail("expected Err")
    Err(e) =>
      assert_true(e.has_suffix("cannot parse \"not a date\" as \"2006\""))
  }
}

///|
test "parse_rfc3339: wrong separator after year includes remaining and expected token" {
  match parse_rfc3339("2021/03/22T00:00:00Z") {
    Ok(_) => fail("expected Err")
    Err(e) =>
      assert_true(e.has_suffix("cannot parse \"/03/22T00:00:00Z\" as \"-\""))
  }
}

///|
test "parse_rfc3339: missing timezone includes remaining text and expected token" {
  match parse_rfc3339("2021-03-22T00:00:00") {
    Ok(_) => fail("expected Err")
    Err(e) => assert_true(e.has_suffix("cannot parse \"\" as \"Z07:00\""))
  }
}

///|
test "parse_rfc3339: trailing garbage uses Go-format extra text: suffix" {
  match parse_rfc3339("2021-03-22T23:20:50Zgarbage") {
    Ok(_) => fail("expected Err")
    Err(e) =>
      assert_eq(
        e, "parsing time \"2021-03-22T23:20:50Zgarbage\": extra text: \"garbage\"",
      )
  }
}

///|
test "parse_rfc3339: space date-time separator is rejected" {
  match parse_rfc3339("2021-03-22 10:42:13Z") {
    Ok(_) => fail("expected Err")
    Err(e) => assert_true(e.has_suffix("cannot parse \" 10:42:13Z\" as \"T\""))
  }
}

///|
test "parse_rfc3339: lowercase t separator is rejected" {
  match parse_rfc3339("2021-03-22t10:42:13Z") {
    Ok(_) => fail("expected Err")
    Err(e) => assert_true(e.has_suffix("cannot parse \"t10:42:13Z\" as \"T\""))
  }
}

///|
test "parse_rfc3339: lowercase z timezone marker is rejected" {
  match parse_rfc3339("2021-03-22T10:42:13z") {
    Ok(_) => fail("expected Err")
    Err(e) => assert_true(e.has_suffix("cannot parse \"z\" as \"Z07:00\""))
  }
}

///|
test "parse_rfc3339: year shorter than four digits is rejected" {
  match parse_rfc3339("21-03-22T10:42:13Z") {
    Ok(_) => fail("expected Err")
    Err(e) =>
      assert_true(
        e.has_suffix("cannot parse \"21-03-22T10:42:13Z\" as \"2006\""),
      )
  }
}

///|
test "parse_rfc3339: out-of-range month emits field-specific error" {
  match parse_rfc3339("2021-13-22T10:42:13Z") {
    Ok(_) => fail("expected Err")
    Err(e) =>
      assert_eq(e, "parsing time \"2021-13-22T10:42:13Z\": month out of range")
  }
}

///|
test "parse_rfc3339: month 0 emits field-specific error" {
  match parse_rfc3339("2021-00-22T10:42:13Z") {
    Ok(_) => fail("expected Err")
    Err(e) =>
      assert_eq(e, "parsing time \"2021-00-22T10:42:13Z\": month out of range")
  }
}

///|
test "parse_rfc3339: out-of-range day emits field-specific error" {
  match parse_rfc3339("2021-03-32T10:42:13Z") {
    Ok(_) => fail("expected Err")
    Err(e) =>
      assert_eq(e, "parsing time \"2021-03-32T10:42:13Z\": day out of range")
  }
}

///|
test "parse_rfc3339: day 0 emits field-specific error" {
  match parse_rfc3339("2021-03-00T10:42:13Z") {
    Ok(_) => fail("expected Err")
    Err(e) =>
      assert_eq(e, "parsing time \"2021-03-00T10:42:13Z\": day out of range")
  }
}

///|
test "parse_rfc3339: out-of-range hour emits field-specific error" {
  match parse_rfc3339("2021-03-23T24:00:00Z") {
    Ok(_) => fail("expected Err")
    Err(e) =>
      assert_eq(e, "parsing time \"2021-03-23T24:00:00Z\": hour out of range")
  }
}

///|
test "parse_rfc3339: out-of-range minute emits field-specific error" {
  match parse_rfc3339("2021-03-23T00:60:00Z") {
    Ok(_) => fail("expected Err")
    Err(e) =>
      assert_eq(e, "parsing time \"2021-03-23T00:60:00Z\": minute out of range")
  }
}

///|
test "parse_rfc3339: out-of-range second emits field-specific error" {
  match parse_rfc3339("2021-03-23T00:00:60Z") {
    Ok(_) => fail("expected Err")
    Err(e) =>
      assert_eq(e, "parsing time \"2021-03-23T00:00:60Z\": second out of range")
  }
}

///|
test "parse_rfc3339: out-of-range timezone offset hour emits field-specific error" {
  match parse_rfc3339("2021-01-01T00:00:00+25:00") {
    Ok(_) => fail("expected Err")
    Err(e) =>
      assert_eq(
        e, "parsing time \"2021-01-01T00:00:00+25:00\": time zone offset hour out of range",
      )
  }
}

///|
test "parse_rfc3339: out-of-range timezone offset minute emits field-specific error" {
  match parse_rfc3339("2021-01-01T00:00:00+00:60") {
    Ok(_) => fail("expected Err")
    Err(e) =>
      assert_eq(
        e, "parsing time \"2021-01-01T00:00:00+00:60\": time zone offset minute out of range",
      )
  }
}

///|
test "parse_go_layout: completely wrong input includes remaining text and first token" {
  match parse_go_layout("not a date", "2006-01-02") {
    Ok(_) => fail("expected Err")
    Err(e) =>
      assert_true(e.has_suffix("cannot parse \"not a date\" as \"2006\""))
  }
}

///|
test "parse_go_layout: wrong separator includes remaining text and expected separator token" {
  match parse_go_layout("2021/03/22", "2006-01-02") {
    Ok(_) => fail("expected Err")
    Err(e) => assert_true(e.has_suffix("cannot parse \"/03/22\" as \"-\""))
  }
}
