///|
test "time module: parse_time accepts two-digit year, full month, and weekday verbs" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|assert.eq(
      #|  time.parse_time("21-03-22", format="06-01-02"),
      #|  time.parse_time("2021-03-22T00:00:00Z"),
      #|)
      #|assert.eq(
      #|  time.parse_time("March 22, 2021", format="January 2, 2006"),
      #|  time.parse_time("2021-03-22T00:00:00Z"),
      #|)
      #|assert.eq(
      #|  time.parse_time("Monday 2021-03-22", format="Monday 2006-01-02"),
      #|  time.parse_time("2021-03-22T00:00:00Z"),
      #|)
      #|assert.eq(
      #|  time.parse_time("Mon 2021-03-22", format="Mon 2006-01-02"),
      #|  time.parse_time("2021-03-22T00:00:00Z"),
      #|)
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time module: parse_time accepts space-padded day and single-digit verbs" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|assert.eq(
      #|  time.parse_time("Mar  3 2021", format="Jan _2 2006"),
      #|  time.parse_time("2021-03-03T00:00:00Z"),
      #|)
      #|assert.eq(
      #|  time.parse_time("3/22/2021", format="1/2/2006"),
      #|  time.parse_time("2021-03-22T00:00:00Z"),
      #|)
      #|assert.eq(
      #|  "17:08:06",
      #|  time.parse_time("17:8:6", format="15:4:5").format("15:04:05"),
      #|)
      #|assert.eq(
      #|  "17:38",
      #|  time.parse_time("5:38 PM", format="3:04 PM").format("15:04"),
      #|)
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time module: parse_time honors AM and PM around noon and midnight" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|assert.eq(
      #|  "00:00",
      #|  time.parse_time("12:00 AM", format="03:04 PM").format("15:04"),
      #|)
      #|assert.eq(
      #|  "12:00",
      #|  time.parse_time("12:00 PM", format="03:04 PM").format("15:04"),
      #|)
      #|assert.eq(
      #|  "13:00",
      #|  time.parse_time("01:00 pm", format="03:04 pm").format("15:04"),
      #|)
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time module: parse_time accepts numeric and abbreviated zone verbs" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|assert.eq(
      #|  time.parse_time("2021-03-22T14:30:00+0900", format="2006-01-02T15:04:05-0700"),
      #|  time.parse_time("2021-03-22T05:30:00Z"),
      #|)
      #|assert.eq(
      #|  time.parse_time("2021-03-22T14:30:00-07:00", format="2006-01-02T15:04:05-07:00"),
      #|  time.parse_time("2021-03-22T21:30:00Z"),
      #|)
      #|assert.eq(
      #|  time.parse_time("2021-03-22T14:30:00Z", format="2006-01-02T15:04:05Z0700"),
      #|  time.parse_time("2021-03-22T14:30:00Z"),
      #|)
      #|assert.eq(
      #|  time.parse_time("2021-03-22 JST", format="2006-01-02 MST"),
      #|  time.parse_time("2021-03-22T00:00:00Z"),
      #|)
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time module: parse_time reads fractional seconds of any width" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|assert.eq(
      #|  120000000,
      #|  time.parse_time("00:00:00.12", format="15:04:05.000").nanosecond,
      #|)
      #|assert.eq(
      #|  500000000,
      #|  time.parse_time("00:00:00.5", format="15:04:05.999").nanosecond,
      #|)
      #|assert.eq(
      #|  123456789,
      #|  time.parse_time("00:00:00.1234567891", format="15:04:05.000000000").nanosecond,
      #|)
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time module: parse_time rejects values that do not match the layout" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|assert.fails(lambda: time.parse_time("not-a-date", format="2006-01-02"), "cannot parse")
      #|assert.fails(lambda: time.parse_time("2021-03-22X", format="2006-01-02"), "cannot parse")
      #|assert.fails(lambda: time.parse_time("20XY-03-22", format="2006-01-02"), "cannot parse")
      #|assert.fails(lambda: time.parse_time("2021/03/22", format="2006-01-02"), "cannot parse")
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time module: parse_time reports malformed RFC3339 input" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|assert.fails(lambda: time.parse_time("2020"), "invalid RFC3339 time")
      #|assert.fails(lambda: time.parse_time("2020/01/01T00:00:00Z"), "invalid RFC3339 time")
      #|assert.fails(lambda: time.parse_time("2020-01-01X00:00:00Z"), "invalid RFC3339 time")
      #|assert.fails(lambda: time.parse_time("2020-01-01T00X00:00Z"), "invalid RFC3339 time")
      #|assert.fails(lambda: time.parse_time("2020-01-01T00:00X00Z"), "invalid RFC3339 time")
      #|assert.fails(lambda: time.parse_time("2020-01-01T00:00:00.Z"), "invalid fractional seconds")
      #|assert.fails(lambda: time.parse_time("2020-01-01T00:00:00Q"), "invalid timezone")
      #|assert.fails(lambda: time.parse_time("2020-01-01T00:00:00+0500"), "invalid timezone")
      #|assert.fails(lambda: time.parse_time("2020-01-01T00:00:00+05:0Z"), "invalid timezone")
      #|assert.fails(lambda: time.parse_time("2020-01-01T00:00:00"), "invalid timezone")
      #|assert.fails(lambda: time.parse_time("2024-06-11T10:20:30"), "invalid timezone")
      #|assert.fails(lambda: time.parse_time("2020-01-01T00:00:00.123"), "invalid timezone")
      #|assert.fails(lambda: time.parse_time("2020-13-01T00:00:00Z"), "invalid time")
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time module: parse_time rejects RFC3339 trailing garbage after Z" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|assert.fails(lambda: time.parse_time("2021-03-22T23:20:50Zgarbage"), "extra text")
      #|assert.fails(lambda: time.parse_time("2021-03-22T23:20:50Z "), "extra text")
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time module: parse_time rejects RFC3339 trailing garbage after numeric timezone" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|assert.fails(lambda: time.parse_time("2021-03-22T23:20:50+00:00garbage"), "extra text")
      #|assert.fails(lambda: time.parse_time("2021-03-22T23:20:50+00:00 "), "extra text")
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time module: parse_time still accepts valid RFC3339 without trailing garbage" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|assert.eq(
      #|  time.parse_time("2021-03-22T23:20:50Z"),
      #|  time.parse_time("2021-03-22T23:20:50+00:00"),
      #|)
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time module: parse_time normalizes fractional precision in RFC3339" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|assert.eq(500000000, time.parse_time("2020-01-01T00:00:00.5Z").nanosecond)
      #|assert.eq(123456789, time.parse_time("2020-01-01T00:00:00.1234567891Z").nanosecond)
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time module: parse_duration accepts every unit and the micro sign" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|assert.eq(time.parse_duration("1ns"), time.nanosecond)
      #|assert.eq(time.parse_duration("1us"), time.microsecond)
      #|assert.eq(time.parse_duration("1µs"), time.microsecond)
      #|assert.eq(time.parse_duration("1μs"), time.microsecond)
      #|assert.eq(time.parse_duration("1ms"), time.millisecond)
      #|assert.eq(time.parse_duration("1s"), time.second)
      #|assert.eq(time.parse_duration("1m"), time.minute)
      #|assert.eq(time.parse_duration("1h"), time.hour)
      #|assert.eq(time.parse_duration("+0"), time.parse_duration("0"))
      #|assert.eq(time.parse_duration("-0"), time.parse_duration("0"))
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time module: parse_duration rejects malformed strings" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|assert.fails(lambda: time.parse_duration("10"), "missing unit")
      #|assert.fails(lambda: time.parse_duration("10x"), "unknown unit")
      #|assert.fails(lambda: time.parse_duration("h"), "invalid duration")
      #|assert.fails(lambda: time.parse_duration("-"), "invalid duration")
      #|assert.fails(lambda: time.parse_duration("1.2.3s"), "invalid duration")
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time module: parse_time and from_timestamp validate argument types" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|assert.fails(lambda: time.parse_time(5), "x must be a string")
      #|assert.fails(lambda: time.parse_time(), "missing required argument")
      #|assert.fails(lambda: time.parse_time("x", format=5), "format must be a string")
      #|assert.fails(lambda: time.parse_time("x", location=5), "location must be a string")
      #|assert.fails(lambda: time.parse_time("x", 5), "format must be a string")
      #|assert.fails(lambda: time.parse_time("2020-01-01T00:00:00Z", "2006-01-02T15:04:05Z07:00", 5), "location must be a string")
      #|assert.fails(lambda: time.parse_time("x", bogus="y"), "unexpected keyword argument")
      #|assert.fails(lambda: time.from_timestamp("x"), "sec must be an integer")
      #|assert.fails(lambda: time.from_timestamp(0, "x"), "nsec must be an integer")
      #|assert.fails(lambda: time.from_timestamp(), "missing required argument")
      #|assert.fails(lambda: time.is_valid_timezone(5), "argument must be a string")
      #|assert.fails(lambda: time.is_valid_timezone(), "want 1")
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time module: parse_time rejects values missing a digit for each layout verb" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|def bad(value, layout):
      #|    return lambda: time.parse_time(value, format=layout)
      #|assert.fails(bad("abcd", "2006"), "cannot parse")
      #|assert.fails(bad("ab", "06"), "cannot parse")
      #|assert.fails(bad("Foobar", "January"), "cannot parse")
      #|assert.fails(bad("Xyz", "Jan"), "cannot parse")
      #|assert.fails(bad("Funday", "Monday"), "cannot parse")
      #|assert.fails(bad("Fnd", "Mon"), "cannot parse")
      #|assert.fails(bad("ab", "01"), "cannot parse")
      #|assert.fails(bad("ab", "02"), "cannot parse")
      #|assert.fails(bad("x", "_2"), "cannot parse")
      #|assert.fails(bad("ab", "15"), "cannot parse")
      #|assert.fails(bad("ab", "03"), "cannot parse")
      #|assert.fails(bad("ab", "04"), "cannot parse")
      #|assert.fails(bad("ab", "05"), "cannot parse")
      #|assert.fails(bad("XX", "PM"), "cannot parse")
      #|assert.fails(bad("xx", "pm"), "cannot parse")
      #|assert.fails(bad("x", "3"), "cannot parse")
      #|assert.fails(bad("x", "1"), "cannot parse")
      #|assert.fails(bad("x", "2"), "cannot parse")
      #|assert.fails(bad("x", "4"), "cannot parse")
      #|assert.fails(bad("x", "5"), "cannot parse")
      #|assert.fails(bad("x", "Z0700"), "cannot parse")
      #|assert.fails(bad("x", "-0700"), "cannot parse")
      #|assert.fails(bad("x", "Z07:00"), "cannot parse")
      #|assert.fails(bad("x", "-07:00"), "cannot parse")
      #|assert.fails(bad("05", "05.000"), "cannot parse")
      #|assert.fails(bad("Z", "T"), "cannot parse")
      #|assert.fails(bad("012", "01"), "cannot parse")
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time module: duration and time reject incompatible binary operands" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|d = time.parse_duration("10h")
      #|t = time.from_timestamp(0)
      #|assert.fails(lambda: d + "x", "unknown binary op")
      #|assert.fails(lambda: d - "x", "unknown binary op")
      #|assert.fails(lambda: 5 - d, "unknown binary op")
      #|assert.fails(lambda: d / "x", "unknown binary op")
      #|assert.fails(lambda: d // "x", "unknown binary op")
      #|assert.fails(lambda: 5 // d, "unknown binary op")
      #|assert.fails(lambda: d * "x", "unknown binary op")
      #|assert.fails(lambda: t + "x", "unknown binary op")
      #|assert.fails(lambda: t - "x", "unknown binary op")
      #|assert.fails(lambda: 5 + t, "unknown binary op")
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}
