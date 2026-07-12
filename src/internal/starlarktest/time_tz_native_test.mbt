///|
test "time module: DST-aware time constructor with EDT offset" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|t1 = time.time(year=2009, month=6, day=12, hour=12, minute=6, second=10, nanosecond=99, location="US/Eastern")
      #|assert.eq(t1, time.parse_time("2009-06-12T12:06:10.000000099", format="2006-01-02T15:04:05.999999999", location="US/Eastern"))
      #|assert.eq(2009, t1.year)
      #|assert.eq(6, t1.month)
      #|assert.eq(12, t1.day)
      #|assert.eq(12, t1.hour)
      #|assert.eq(6, t1.minute)
      #|assert.eq(10, t1.second)
      #|assert.eq(99, t1.nanosecond)
      #|assert.eq(1244822770, t1.unix)
      #|assert.eq(1244822770000000099, t1.unix_nano)
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time module: DST-aware in_location converts UTC to EDT" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|t = time.parse_time("2009-06-12T16:06:10Z")
      #|assert.eq(t.in_location("US/Eastern"), time.parse_time("2009-06-12T12:06:10-04:00"))
      #|assert.eq(t.in_location("US/Eastern").format("3 04 PM"), "12 06 PM")
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time module: in_location shows zone abbreviation for Asia/Tokyo" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|t = time.from_timestamp(0).in_location("Asia/Tokyo")
      #|s = str(t)
      #|assert.eq(s, "1970-01-01 09:00:00 +0900 JST")
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time module: in_location shows EST abbreviation for US/Eastern at epoch" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|t = time.from_timestamp(0).in_location("US/Eastern")
      #|s = str(t)
      #|assert.eq(s, "1969-12-31 19:00:00 -0500 EST")
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time module: from_timestamp preserves unix instant" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|t = time.from_timestamp(1593193116)
      #|assert.eq(t.unix, 1593193116)
      #|assert.eq(t, time.parse_time("2020-06-26T17:38:36Z"))
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time module: time constructor normalizes a spring-forward DST gap in America/New_York" {
  // These DST transition-boundary tests live here rather than in
  // time_zone_test.mbt because the wasm/js stub timezone table returns a
  // fixed offset regardless of the queried instant and cannot represent DST
  // transitions at all; only the native backend's OS tzdata lookup can.
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|t = time.time(year=2024, month=3, day=10, hour=2, minute=30, location="America/New_York")
      #|assert.eq("2024-03-10 01:30:00 -0500 EST", str(t))
      #|assert.eq(t, time.parse_time("2024-03-10T06:30:00Z"))
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time module: parse_time normalizes a spring-forward DST gap in America/New_York" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|t = time.parse_time("2024-03-10T02:30:00", format="2006-01-02T15:04:05", location="America/New_York")
      #|assert.eq("2024-03-10 01:30:00 -0500 EST", str(t))
      #|assert.eq(t, time.parse_time("2024-03-10T06:30:00Z"))
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time module: time constructor normalizes a spring-forward DST gap in Europe/London" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|t = time.time(year=2024, month=3, day=31, hour=1, minute=30, location="Europe/London")
      #|assert.eq("2024-03-31 02:30:00 +0100 BST", str(t))
      #|assert.eq(t, time.parse_time("2024-03-31T01:30:00Z"))
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time module: time constructor keeps the ambiguous DST fall-back reading in America/New_York" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|t = time.time(year=2024, month=11, day=3, hour=1, minute=30, location="America/New_York")
      #|assert.eq("2024-11-03 01:30:00 -0400 EDT", str(t))
      #|assert.eq(t, time.parse_time("2024-11-03T05:30:00Z"))
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time module: now is after a known past date" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|assert.true(time.now() > time.parse_time("2021-03-20T00:00:00Z"))
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}
