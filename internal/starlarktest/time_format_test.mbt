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
