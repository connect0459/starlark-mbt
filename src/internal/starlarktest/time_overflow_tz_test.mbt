///|
test "time: time - time saturates to maxDuration when result overflows Int64" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|t_far  = time.time(year=9999)
      #|t_epoch = time.from_timestamp(0)
      #|d = t_far - t_epoch
      #|assert.eq(str(d), "2562047h47m16.854775807s")
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time: time - time saturates to minDuration when result underflows Int64" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|t_epoch = time.from_timestamp(0)
      #|t_far   = time.time(year=9999)
      #|d = t_epoch - t_far
      #|assert.eq(d.nanoseconds, -9223372036854775808)
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time: time - time within maxDuration range is exact (no saturation)" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|t1 = time.parse_time("2011-04-22T13:33:48Z")
      #|t2 = time.parse_time("2011-04-22T03:33:48Z")
      #|assert.eq(t1 - t2, time.parse_duration("10h"))
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time.parse_duration: rejects integer mantissa that overflows Int64" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|assert.fails(lambda: time.parse_duration("9223372036854775808ns"),
      #|             "time: invalid duration")
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time.parse_duration: rejects overflow from large unit multiplication" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|assert.fails(lambda: time.parse_duration("9223372037h"),
      #|             "time: invalid duration")
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time.from_timestamp: rejects sec above Int64 maximum" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|assert.fails(
      #|  lambda: time.from_timestamp(1 << 63),
      #|  "from_timestamp: for parameter 1: 9223372036854775808 out of range (want value in signed 64-bit range)",
      #|)
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time.from_timestamp: rejects nsec above Int64 maximum" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|assert.fails(
      #|  lambda: time.from_timestamp(0, 1 << 63),
      #|  "from_timestamp: for parameter 2: 9223372036854775808 out of range (want value in signed 64-bit range)",
      #|)
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time.from_timestamp: Int64 minimum second matches Go normalization" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|t = time.from_timestamp(-1 << 63).in_location("UTC")
      #|assert.eq(str(t), "292277026596-12-04 15:30:08 +0000 UTC")
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time.from_timestamp: Int64 maximum second matches Go normalization" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|t = time.from_timestamp((1 << 63) - 1).in_location("UTC")
      #|assert.eq(str(t), "292277026596-12-04 15:30:07 +0000 UTC")
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time.parse_duration: rejects overflow when accumulating components" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|assert.fails(lambda: time.parse_duration("2562047h47m16.854775808s"),
      #|             "time: invalid duration")
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time.parse_duration: accepts maxDuration without error" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|d = time.parse_duration("2562047h47m16.854775807s")
      #|assert.eq(str(d), "2562047h47m16.854775807s")
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time.time: nanosecond larger than Int32 max is normalized correctly" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|t = time.time(year=2024, month=1, day=1, nanosecond=2500000000)
      #|assert.eq(t.year, 2024)
      #|assert.eq(t.month, 1)
      #|assert.eq(t.day, 1)
      #|assert.eq(t.second, 2)
      #|assert.eq(t.nanosecond, 500000000)
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time.time: rejects BigInt kwarg outside signed 64-bit range" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|assert.fails(lambda: time.time(year=10000000000000000000),
      #|             "time: for parameter \"year\":")
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time.parse_time: positive offset preserved in wall-clock attributes" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|t = time.parse_time("2024-06-11T10:20:30+09:00")
      #|assert.eq(t.hour, 10)
      #|assert.eq(t.minute, 20)
      #|assert.eq(t.second, 30)
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time.parse_time: negative offset preserved in wall-clock attributes" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|t = time.parse_time("2024-06-11T22:20:30-05:00")
      #|assert.eq(t.hour, 22)
      #|assert.eq(t.minute, 20)
      #|assert.eq(t.second, 30)
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time.parse_time: UTC instant is correct regardless of offset in string" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|t_plus9 = time.parse_time("2024-06-11T10:20:30+09:00")
      #|t_utc   = time.parse_time("2024-06-11T01:20:30Z")
      #|assert.eq(t_plus9.unix, t_utc.unix)
      #|assert.eq(t_plus9, t_utc)
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time.parse_time: str of time with non-UTC offset includes zone abbreviation" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|t = time.parse_time("2024-06-11T10:20:30+09:00")
      #|s = str(t)
      #|assert.true("+0900" in s, "expected +0900 in " + s)
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time.parse_time: Z suffix produces UTC wall-clock attributes" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|t = time.parse_time("2024-06-11T10:20:30Z")
      #|assert.eq(t.hour, 10)
      #|assert.eq(str(t), "2024-06-11 10:20:30 +0000 UTC")
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time.parse_time: go-layout with explicit offset preserves wall-clock hour" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|t = time.parse_time("2021-03-22T14:30:00+05:00",
      #|                     format="2006-01-02T15:04:05Z07:00")
      #|assert.eq(t.hour, 14)
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}
