///|
test "time module: is_valid_timezone recognizes IANA names and rejects unknown ones" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|assert.true(time.is_valid_timezone("America/New_York"))
      #|assert.true(time.is_valid_timezone("UTC"))
      #|assert.true(time.is_valid_timezone("Asia/Tokyo"))
      #|assert.true(not time.is_valid_timezone("Mars/Olympus"))
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time module: in_location reports stable offsets for zones without daylight saving" {
  // Restricted to zones that never observe daylight saving, so the offset is
  // the same year-round and on every backend (the wasm/js timezone table uses
  // fixed offsets while native reads the OS tzdata).
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|t = time.from_timestamp(1593193116)
      #|def off(name):
      #|    return t.in_location(name).format("-0700")
      #|assert.eq("+0000", off("Etc/UTC"))
      #|assert.eq("+0400", off("Asia/Dubai"))
      #|assert.eq("+0430", off("Asia/Kabul"))
      #|assert.eq("+0500", off("Asia/Karachi"))
      #|assert.eq("+0530", off("Asia/Kolkata"))
      #|assert.eq("+0800", off("Asia/Shanghai"))
      #|assert.eq("+0900", off("Asia/Tokyo"))
      #|assert.eq("-0500", off("America/Bogota"))
      #|assert.eq("-1000", off("Pacific/Honolulu"))
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time module: in_location preserves the instant across every supported region" {
  // Re-expressing an instant in another zone never changes the underlying Unix
  // timestamp, whatever offset that zone carries. This holds on every backend,
  // so it exercises one representative of each region in the timezone table
  // without depending on daylight-saving-sensitive offsets.
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|t = time.from_timestamp(1593193116)
      #|def keeps(name):
      #|    return t.in_location(name).unix
      #|assert.eq(t.unix, keeps("UTC"))
      #|assert.eq(t.unix, keeps("America/New_York"))
      #|assert.eq(t.unix, keeps("America/Chicago"))
      #|assert.eq(t.unix, keeps("America/Denver"))
      #|assert.eq(t.unix, keeps("America/Los_Angeles"))
      #|assert.eq(t.unix, keeps("America/Anchorage"))
      #|assert.eq(t.unix, keeps("Pacific/Honolulu"))
      #|assert.eq(t.unix, keeps("Pacific/Pago_Pago"))
      #|assert.eq(t.unix, keeps("America/Halifax"))
      #|assert.eq(t.unix, keeps("America/St_Johns"))
      #|assert.eq(t.unix, keeps("America/Sao_Paulo"))
      #|assert.eq(t.unix, keeps("America/Buenos_Aires"))
      #|assert.eq(t.unix, keeps("America/Bogota"))
      #|assert.eq(t.unix, keeps("America/Caracas"))
      #|assert.eq(t.unix, keeps("America/Santiago"))
      #|assert.eq(t.unix, keeps("Europe/London"))
      #|assert.eq(t.unix, keeps("Europe/Berlin"))
      #|assert.eq(t.unix, keeps("Europe/Athens"))
      #|assert.eq(t.unix, keeps("Europe/Kaliningrad"))
      #|assert.eq(t.unix, keeps("Europe/Minsk"))
      #|assert.eq(t.unix, keeps("Europe/Moscow"))
      #|assert.eq(t.unix, keeps("Europe/Samara"))
      #|assert.eq(t.unix, keeps("Asia/Yekaterinburg"))
      #|assert.eq(t.unix, keeps("Asia/Omsk"))
      #|assert.eq(t.unix, keeps("Asia/Krasnoyarsk"))
      #|assert.eq(t.unix, keeps("Asia/Shanghai"))
      #|assert.eq(t.unix, keeps("Asia/Tokyo"))
      #|assert.eq(t.unix, keeps("Australia/Sydney"))
      #|assert.eq(t.unix, keeps("Australia/Darwin"))
      #|assert.eq(t.unix, keeps("Australia/Adelaide"))
      #|assert.eq(t.unix, keeps("Pacific/Auckland"))
      #|assert.eq(t.unix, keeps("Asia/Kolkata"))
      #|assert.eq(t.unix, keeps("Asia/Karachi"))
      #|assert.eq(t.unix, keeps("Asia/Dubai"))
      #|assert.eq(t.unix, keeps("Asia/Kabul"))
      #|assert.eq(t.unix, keeps("Asia/Tehran"))
      #|assert.eq(t.unix, keeps("Asia/Baghdad"))
      #|assert.eq(t.unix, keeps("Asia/Beirut"))
      #|assert.eq(t.unix, keeps("Africa/Cairo"))
      #|assert.eq(t.unix, keeps("Africa/Lagos"))
      #|assert.eq(t.unix, keeps("Africa/Nairobi"))
      #|assert.eq(t.unix, keeps("Africa/Johannesburg"))
      #|assert.eq(t.unix, keeps("Atlantic/Reykjavik"))
      #|assert.eq(t.unix, keeps("Atlantic/Azores"))
      #|assert.eq(t.unix, keeps("Atlantic/Cape_Verde"))
      #|assert.eq(t.unix, keeps("Atlantic/South_Georgia"))
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time module: in_location supports POSIX Etc/GMT offsets with inverted sign" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|t = time.from_timestamp(1593193116)
      #|def off(name):
      #|    return t.in_location(name).format("-0700")
      #|assert.eq("-0100", off("Etc/GMT+1"))
      #|assert.eq("-0200", off("Etc/GMT+2"))
      #|assert.eq("-0300", off("Etc/GMT+3"))
      #|assert.eq("-0400", off("Etc/GMT+4"))
      #|assert.eq("-0500", off("Etc/GMT+5"))
      #|assert.eq("-0600", off("Etc/GMT+6"))
      #|assert.eq("-0700", off("Etc/GMT+7"))
      #|assert.eq("-0800", off("Etc/GMT+8"))
      #|assert.eq("-0900", off("Etc/GMT+9"))
      #|assert.eq("-1000", off("Etc/GMT+10"))
      #|assert.eq("-1100", off("Etc/GMT+11"))
      #|assert.eq("-1200", off("Etc/GMT+12"))
      #|assert.eq("+0100", off("Etc/GMT-1"))
      #|assert.eq("+0200", off("Etc/GMT-2"))
      #|assert.eq("+0300", off("Etc/GMT-3"))
      #|assert.eq("+0400", off("Etc/GMT-4"))
      #|assert.eq("+0500", off("Etc/GMT-5"))
      #|assert.eq("+0600", off("Etc/GMT-6"))
      #|assert.eq("+0700", off("Etc/GMT-7"))
      #|assert.eq("+0800", off("Etc/GMT-8"))
      #|assert.eq("+0900", off("Etc/GMT-9"))
      #|assert.eq("+1000", off("Etc/GMT-10"))
      #|assert.eq("+1100", off("Etc/GMT-11"))
      #|assert.eq("+1200", off("Etc/GMT-12"))
      #|assert.eq("+1300", off("Etc/GMT-13"))
      #|assert.eq("+1400", off("Etc/GMT-14"))
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time module: in_location and format reject malformed arguments" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|t = time.from_timestamp(1593193116)
      #|assert.fails(lambda: t.in_location("Mars/Olympus"), "unsupported timezone")
      #|assert.fails(lambda: t.in_location(5), "must be a string")
      #|assert.fails(lambda: t.in_location("UTC", "extra"), "want 1")
      #|assert.fails(lambda: t.format(5), "must be a string")
      #|assert.fails(lambda: t.format("2006", "extra"), "want 1")
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time module: time constructor builds instants in UTC and named zones" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|utc = time.time(year=2021, month=3, day=22, hour=14, minute=30)
      #|assert.eq(utc, time.parse_time("2021-03-22T14:30:00Z"))
      #|tokyo = time.time(year=2021, month=3, day=22, hour=14, minute=30, location="Asia/Tokyo")
      #|assert.eq("+0900", tokyo.format("-0700"))
      #|assert.eq(tokyo, time.parse_time("2021-03-22T05:30:00Z"))
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time module: time constructor validates argument types and names" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|assert.fails(lambda: time.time(year="x"), "year must be an integer")
      #|assert.fails(lambda: time.time(month="x"), "month must be an integer")
      #|assert.fails(lambda: time.time(day="x"), "day must be an integer")
      #|assert.fails(lambda: time.time(hour="x"), "hour must be an integer")
      #|assert.fails(lambda: time.time(minute="x"), "minute must be an integer")
      #|assert.fails(lambda: time.time(second="x"), "second must be an integer")
      #|assert.fails(lambda: time.time(nanosecond="x"), "nanosecond must be an integer")
      #|assert.fails(lambda: time.time(location=5), "location must be a string")
      #|assert.fails(lambda: time.time(foo=1), "unexpected keyword argument")
      #|assert.fails(lambda: time.time(2021), "unexpected positional arguments")
      #|assert.fails(lambda: time.time(year=2021, location="Mars/Olympus"), "unsupported timezone")
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time module: parse_time interprets values relative to a location" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|wall = time.parse_time("2021-03-22T14:30:00", location="Asia/Tokyo")
      #|assert.eq("14:30", wall.format("15:04"))
      #|assert.eq("+0900", wall.format("-0700"))
      #|assert.eq(wall, time.parse_time("2021-03-22T05:30:00Z"))
      #|instant = time.parse_time("2021-03-22T14:30:00Z", location="Asia/Tokyo")
      #|assert.eq("14:30", instant.format("15:04"))
      #|assert.eq(instant, time.parse_time("2021-03-22T14:30:00Z"))
      #|offset = time.parse_time("2021-03-22T14:30:00+09:00", location="Asia/Tokyo")
      #|assert.eq(offset, time.parse_time("2021-03-22T05:30:00Z"))
      #|assert.fails(
      #|  lambda: time.parse_time("2021-03-22T14:30:00", location="Mars/Olympus"),
      #|  "unsupported timezone",
      #|)
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}
