///|
test "time module: duration str renders sub-second magnitudes like Go" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|assert.eq("0s", str(time.parse_duration("0")))
      #|assert.eq("500ns", str(time.parse_duration("500ns")))
      #|assert.eq("1.5µs", str(time.parse_duration("1500ns")))
      #|assert.eq("2µs", str(time.parse_duration("2us")))
      #|assert.eq("2ms", str(time.parse_duration("2ms")))
      #|assert.eq("2.5ms", str(time.parse_duration("2500us")))
      #|assert.eq("1.0005ms", str(time.parse_duration("1000500ns")))
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time module: duration str renders hours, minutes, and fractions" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|assert.eq("5m0s", str(time.parse_duration("5m")))
      #|assert.eq("1.5s", str(time.parse_duration("1.5s")))
      #|assert.eq("1.25s", str(time.parse_duration("1.25s")))
      #|assert.eq("-1h0m0s", str(time.parse_duration("-1h")))
      #|assert.eq("1h30m0s", str(time.parse_duration("90m")))
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time module: format renders date, name, and clock verbs" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|t = time.parse_time("2020-06-26T17:38:36Z")
      #|assert.eq("2020-06-26", t.format("2006-01-02"))
      #|assert.eq("20", t.format("06"))
      #|assert.eq("June", t.format("January"))
      #|assert.eq("Jun", t.format("Jan"))
      #|assert.eq("Friday", t.format("Monday"))
      #|assert.eq("Fri", t.format("Mon"))
      #|assert.eq("17:38:36", t.format("15:04:05"))
      #|assert.eq("05:38:36 PM", t.format("03:04:05 PM"))
      #|assert.eq("05:38:36 pm", t.format("03:04:05 pm"))
      #|assert.eq("5:38:36", t.format("3:4:5"))
      #|assert.eq("6/26", t.format("1/2"))
      #|assert.eq("UTC", t.format("MST"))
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time module: format renders fractional seconds with fixed and trimmed widths" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|t = time.from_timestamp(1593193116, 123456789)
      #|assert.eq(".123", t.format(".000"))
      #|assert.eq(".123456789", t.format(".000000000"))
      #|assert.eq(".123", t.format(".999"))
      #|tz = time.from_timestamp(0, 120000000)
      #|assert.eq(".120", tz.format(".000"))
      #|assert.eq(".12", tz.format(".999"))
      #|whole = time.from_timestamp(0)
      #|assert.eq("", whole.format(".999"))
      #|assert.eq(".000", whole.format(".000"))
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time module: format renders numeric timezone offsets" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|t = time.parse_time("2020-06-26T17:38:36Z")
      #|assert.eq("+0000", t.format("-0700"))
      #|assert.eq("Z", t.format("Z0700"))
      #|assert.eq("Z", t.format("Z07:00"))
      #|east = t.in_location("Asia/Tokyo")
      #|assert.eq("+0900", east.format("-0700"))
      #|assert.eq("+09:00", east.format("Z07:00"))
      #|west = t.in_location("Pacific/Honolulu")
      #|assert.eq("-1000", west.format("-0700"))
      #|assert.eq("-10:00", west.format("Z07:00"))
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time module: format renders hour-only timezone offset with Z07 and -07" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|utc = time.parse_time("2020-06-26T17:38:36Z")
      #|assert.eq("Z", utc.format("Z07"))
      #|assert.eq("+00", utc.format("-07"))
      #|east = utc.in_location("Asia/Tokyo")
      #|assert.eq("+09", east.format("Z07"))
      #|assert.eq("+09", east.format("-07"))
      #|west = utc.in_location("Pacific/Honolulu")
      #|assert.eq("-10", west.format("Z07"))
      #|assert.eq("-10", west.format("-07"))
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time module: parse_time accepts hour-only timezone with Z07 and -07" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|assert.eq(
      #|  time.parse_time("2021-03-22 14:30 Z", format="2006-01-02 15:04 Z07"),
      #|  time.parse_time("2021-03-22T14:30:00Z"),
      #|)
      #|assert.eq(
      #|  time.parse_time("2021-03-22 14:30 +09", format="2006-01-02 15:04 Z07"),
      #|  time.parse_time("2021-03-22T05:30:00Z"),
      #|)
      #|assert.eq(
      #|  time.parse_time("2021-03-22 14:30 -10", format="2006-01-02 15:04 -07"),
      #|  time.parse_time("2021-03-23T00:30:00Z"),
      #|)
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time module: format renders zero-padded day-of-year with 002 verb" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|# Jan 1 = day 1
      #|t1 = time.parse_time("2021-01-01T00:00:00Z")
      #|assert.eq("001", t1.format("002"))
      #|# Jun 12 = 31+28+31+30+31+12 = 163
      #|t2 = time.parse_time("2021-06-12T00:00:00Z")
      #|assert.eq("163", t2.format("002"))
      #|# Dec 31 in a leap year (2020) = 366
      #|t3 = time.parse_time("2020-12-31T00:00:00Z")
      #|assert.eq("366", t3.format("002"))
      #|# Dec 31 in a common year = 365
      #|t4 = time.parse_time("2021-12-31T00:00:00Z")
      #|assert.eq("365", t4.format("002"))
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time module: parse_time reads zero-padded day-of-year with 002 verb" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|assert.eq(
      #|  time.parse_time("2021 001", format="2006 002"),
      #|  time.parse_time("2021-01-01T00:00:00Z"),
      #|)
      #|assert.eq(
      #|  time.parse_time("2021 163", format="2006 002"),
      #|  time.parse_time("2021-06-12T00:00:00Z"),
      #|)
      #|assert.eq(
      #|  time.parse_time("2020 366", format="2006 002"),
      #|  time.parse_time("2020-12-31T00:00:00Z"),
      #|)
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time module: format renders space-padded day-of-month with _2 verb" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|t1 = time.parse_time("2020-06-01T00:00:00Z")
      #|assert.eq(" 1", t1.format("_2"))
      #|t2 = time.parse_time("2020-06-26T00:00:00Z")
      #|assert.eq("26", t2.format("_2"))
      #|t3 = time.parse_time("2020-01-09T00:00:00Z")
      #|assert.eq(" 9", t3.format("_2"))
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time module: str renders fractional seconds and zoned offsets" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|t = time.parse_time("2020-06-26T17:38:36.123456789Z",
      #|                     format="2006-01-02T15:04:05.999999999Z07:00")
      #|assert.eq("2020-06-26 17:38:36.123456789 +0000 UTC", str(t))
      #|east = time.parse_time("2020-06-26T17:38:36Z").in_location("Asia/Tokyo")
      #|assert.true(str(east).startswith("2020-06-27 02:38:36 +0900 "), str(east))
      #|west = time.parse_time("2020-06-26T17:38:36Z").in_location("Pacific/Honolulu")
      #|assert.true(str(west).startswith("2020-06-26 07:38:36 -1000 "), str(west))
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}
