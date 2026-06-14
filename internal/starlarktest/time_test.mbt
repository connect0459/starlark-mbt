///|
test "time module: from_timestamp and parse_time basics" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|assert.eq(time.parse_time("2020-06-26T17:38:36Z"), time.from_timestamp(1593193116))
      #|assert.eq(time.parse_time("1970-01-01T00:00:00Z").unix, 0)
      #|assert.eq(time.parse_time("1970-01-01T00:00:00Z").unix_nano, 0)
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time module: from_timestamp with nanoseconds" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|assert.eq(
      #|  time.parse_time("2020-06-26T17:38:36.123456789", format="2006-01-02T15:04:05.999999999"),
      #|  time.from_timestamp(1593193116, 123456789)
      #|)
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time module: now() honors a thread-local clock override" {
  let loader : (@eval.Thread, String) -> Result[@eval.Module, @errors.EvalError] = fn(
    _t,
    path,
  ) {
    if path == "time.star" {
      Ok(@eval.Module::from_map({ "time": @time.time_module() }))
    } else {
      Err(@errors.EvalError::simple("no loader for \"\{path}\""))
    }
  }
  let thread = @eval.Thread::with_loader("test", loader)
  thread.set_local(@time.now_override_key, @time.time_value(1234567890L, 0))
  let src =
    #|load("time.star", "time")
    #|x = time.now().unix
    #|y = time.now().unix
  match @eval.exec_file(thread, "<test>", src, @eval.Options::default()) {
    Ok(m) => {
      assert_true(m.get("x") == Some(@value.Value::Int(1234567890N)))
      assert_true(m.get("y") == Some(@value.Value::Int(1234567890N)))
    }
    Err(e) => fail(e.msg())
  }
}

///|
test "time module: parse_time honors a custom Go layout" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|assert.eq(
      #|  time.parse_time("2021/03/22", format="2006/01/02"),
      #|  time.parse_time("2021-03-22T00:00:00Z"),
      #|)
      #|assert.eq(
      #|  time.parse_time("22 Mar 2021 14:30", format="02 Jan 2006 15:04"),
      #|  time.parse_time("2021-03-22T14:30:00Z"),
      #|)
      #|assert.eq(
      #|  time.parse_time("2021-03-22 02:30 PM", format="2006-01-02 03:04 PM"),
      #|  time.parse_time("2021-03-22T14:30:00Z"),
      #|)
      #|assert.eq(
      #|  time.parse_time("2021-03-22T14:30:00+05:00", format="2006-01-02T15:04:05Z07:00"),
      #|  time.parse_time("2021-03-22T09:30:00Z"),
      #|)
      #|assert.eq(
      #|  time.parse_time("Mon, 22 Mar 2021 14:30:00", format="Mon, 02 Jan 2006 15:04:05"),
      #|  time.parse_time("2021-03-22T14:30:00Z"),
      #|)
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time module: time attributes" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|t = time.parse_time("2000-01-02T03:04:05Z")
      #|assert.eq(t.year, 2000)
      #|assert.eq(t.month, 1)
      #|assert.eq(t.day, 2)
      #|assert.eq(t.hour, 3)
      #|assert.eq(t.minute, 4)
      #|assert.eq(t.second, 5)
      #|assert.eq(t.nanosecond, 0)
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time module: time - time = duration" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|t = time.parse_time("2000-01-02T03:04:05Z")
      #|assert.eq(t - t, time.parse_duration("0s"))
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time module: duration arithmetic" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|d1s = time.parse_duration("1s")
      #|assert.eq(d1s - d1s, time.parse_duration("0"))
      #|assert.eq(d1s + d1s, time.parse_duration("2s"))
      #|assert.eq(d1s * 5, time.parse_duration("5s"))
      #|assert.eq(time.parse_duration("0s") + time.parse_duration("3m35s"), time.parse_duration("3m35s"))
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time module: parse_duration errors use the full original string" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|assert.fails(lambda: time.parse_duration("abc"), 'time: invalid duration "abc"')
      #|assert.fails(lambda: time.parse_duration("1h_bad"), 'time: invalid duration "1h_bad"')
      #|assert.fails(lambda: time.parse_duration("1.2.3s"), 'time: invalid duration "1.2.3s"')
      #|assert.fails(lambda: time.parse_duration("10"), 'time: missing unit in duration "10"')
      #|assert.fails(lambda: time.parse_duration("1q"), 'time: unknown unit "q" in duration "1q"')
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time module: duration attributes" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|d10h = time.parse_duration("10h")
      #|assert.eq(10.0, d10h.hours)
      #|assert.eq(10*60.0, d10h.minutes)
      #|assert.eq(10*60*60.0, d10h.seconds)
      #|assert.eq(10*60*60*1000, d10h.milliseconds)
      #|assert.eq(10*60*60*1000000, d10h.microseconds)
      #|assert.eq(10*60*60*1000000000, d10h.nanoseconds)
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time module: duration type and str" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|d10h = time.parse_duration("10h")
      #|assert.eq("time.duration", type(d10h))
      #|assert.eq("10h0m0s", str(d10h))
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time module: duration hash (usable as dict key)" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|d10h = time.parse_duration("10h")
      #|d1s = time.parse_duration("1s")
      #|durations = {d10h: "10h", d1s: "1s"}
      #|assert.eq("10h", durations[d10h])
      #|assert.eq("1s", durations[d1s])
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time module: duration comparison" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|assert.eq(time.parse_duration("1h"), time.parse_duration("1h"))
      #|assert.ne(time.parse_duration("1h"), time.parse_duration("1m"))
      #|assert.lt(time.parse_duration("1m"), time.parse_duration("1h"))
      #|assert.true(not time.parse_duration("1h") < time.parse_duration("1h"))
      #|assert.true(not time.parse_duration("1h") < time.parse_duration("1m"))
      #|assert.true(time.parse_duration("1m") <= time.parse_duration("1h"))
      #|assert.true(time.parse_duration("1h") <= time.parse_duration("1h"))
      #|assert.true(not time.parse_duration("1h") <= time.parse_duration("1m"))
      #|assert.true(not time.parse_duration("1m") > time.parse_duration("1h"))
      #|assert.true(not time.parse_duration("1h") > time.parse_duration("1h"))
      #|assert.true(time.parse_duration("1h") > time.parse_duration("1m"))
      #|assert.true(not time.parse_duration("1m") >= time.parse_duration("1h"))
      #|assert.true(time.parse_duration("1h") >= time.parse_duration("1h"))
      #|assert.true(time.parse_duration("1h") >= time.parse_duration("1m"))
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time module: duration binary operations" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|d10h = time.parse_duration("10h")
      #|d1s = time.parse_duration("1s")
      #|refTime = time.parse_time("2011-04-22T13:33:48Z")
      #|tenHoursAfterRefTime = time.parse_time("2011-04-22T23:33:48Z")
      #|assert.eq(d10h + d1s, time.parse_duration("10h01s"))
      #|assert.eq(d10h + refTime, tenHoursAfterRefTime)
      #|assert.eq(d10h - d1s, time.parse_duration("9h59m59s"))
      #|assert.eq(d10h / time.parse_duration("16m"), 37.5)
      #|assert.fails(lambda: d10h / time.parse_duration("0"), "division by zero")
      #|assert.eq(d10h / 20, time.parse_duration("30m"))
      #|assert.fails(lambda: d10h / 0, "division by zero")
      #|assert.fails(lambda: 20 / d10h, "unsupported operation")
      #|assert.eq(d10h / 37.5, time.parse_duration("16m"))
      #|assert.fails(lambda: d10h / 0.0, "division by zero")
      #|assert.eq(d10h // time.parse_duration("16m"), 37)
      #|assert.fails(lambda: d10h // time.parse_duration("0"), "division by zero")
      #|assert.eq(d1s * 1000, time.parse_duration("16m40s"))
      #|assert.eq(1000 * d1s, time.parse_duration("16m40s"))
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time module: is_valid_timezone" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|assert.true(time.is_valid_timezone("UTC"))
      #|assert.true(not time.is_valid_timezone("UKN"))
      #|assert.true(time.is_valid_timezone("US/Eastern"))
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time module: in_location with US/Eastern" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|t = time.parse_time("2000-01-02T03:04:05Z")
      #|assert.eq(t.in_location("US/Eastern"), time.parse_time("2000-01-01T22:04:05-05:00"))
      #|assert.eq(t.in_location("US/Eastern").format("3 04 PM"), "10 04 PM")
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time module: time constructor" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|assert.fails(lambda: time.time(2009, 6, 12, 12, 6, 10, 99, "UTC"), "unexpected positional argument")
      #|assert.eq(time.time(year=2012, month=12, day=31), time.parse_time("2012-12-31T00:00:00Z"))
      #|assert.eq(
      #|  time.time(year=2009, month=6, day=12, hour=12, minute=6, second=10, nanosecond=99, location="UTC"),
      #|  time.time(year=2009, month=6, day=12, hour=12, minute=6, second=10, nanosecond=99)
      #|)
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time module: time constructor attributes" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|t1 = time.time(year=2009, month=6, day=12, hour=12, minute=6, second=10, nanosecond=99)
      #|assert.eq(2009, t1.year)
      #|assert.eq(6, t1.month)
      #|assert.eq(12, t1.day)
      #|assert.eq(12, t1.hour)
      #|assert.eq(6, t1.minute)
      #|assert.eq(10, t1.second)
      #|assert.eq(99, t1.nanosecond)
      #|assert.eq(1244808370, t1.unix)
      #|assert.eq(1244808370000000099, t1.unix_nano)
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time module: time truth value" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|assert.true(not time.parse_time("0001-01-01T00:00:00Z"))
      #|assert.true(time.parse_time("2022-01-01T00:00:00Z"))
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time module: time type and str" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|refTime = time.parse_time("2011-04-22T13:33:48Z")
      #|assert.eq("time.time", type(refTime))
      #|assert.eq("2011-04-22 13:33:48 +0000 UTC", str(refTime))
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time module: time hash (usable as dict key)" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|refTime = time.parse_time("2011-04-22T13:33:48Z")
      #|t1 = time.time(year=2009, month=6, day=12, hour=12, minute=6, second=10, nanosecond=99)
      #|times = {refTime: "refTime", t1: "t1"}
      #|assert.eq("refTime", times[refTime])
      #|assert.eq("t1", times[t1])
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time module: time comparison" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|refTime = time.parse_time("2011-04-22T13:33:48Z")
      #|oneSecondAfterRefTime = time.parse_time("2011-04-22T13:33:49Z")
      #|oneYearAfterRefTime = time.parse_time("2012-04-22T13:33:48Z")
      #|oneYearBeforeRefTime = time.parse_time("2010-04-22T13:33:48Z")
      #|twoYearsBeforeRefTime = time.parse_time("2009-04-22T13:33:48Z")
      #|assert.eq(refTime, refTime)
      #|assert.ne(refTime, oneSecondAfterRefTime)
      #|assert.lt(oneYearBeforeRefTime, refTime)
      #|assert.true(not oneYearBeforeRefTime < oneYearBeforeRefTime)
      #|assert.true(not oneYearBeforeRefTime < twoYearsBeforeRefTime)
      #|assert.true(oneYearBeforeRefTime <= refTime)
      #|assert.true(oneYearBeforeRefTime <= oneYearBeforeRefTime)
      #|assert.true(not oneYearBeforeRefTime <= twoYearsBeforeRefTime)
      #|assert.true(oneYearAfterRefTime > refTime)
      #|assert.true(not refTime > refTime)
      #|assert.true(not oneYearBeforeRefTime > refTime)
      #|assert.true(oneYearAfterRefTime >= refTime)
      #|assert.true(refTime >= refTime)
      #|assert.true(not oneYearBeforeRefTime >= refTime)
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time module: time binary operations" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|d10h = time.parse_duration("10h")
      #|refTime = time.parse_time("2011-04-22T13:33:48Z")
      #|tenHoursAfterRefTime = time.parse_time("2011-04-22T23:33:48Z")
      #|tenHoursBeforeRefTime = time.parse_time("2011-04-22T03:33:48Z")
      #|assert.eq(refTime + d10h, tenHoursAfterRefTime)
      #|assert.eq(refTime - d10h, tenHoursBeforeRefTime)
      #|assert.eq(refTime - tenHoursBeforeRefTime, d10h)
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time module: now returns a time.time" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|assert.eq("time.time", type(time.now()))
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time: repr uses bare function name without 'time.' prefix" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|assert.eq(repr(time.now), "<built-in function now>")
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time.time: unexpected positional arguments (no prefix, plural)" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|assert.fails(lambda: time.time(1), "time: unexpected positional arguments")
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time.parse_duration: accepts existing time.duration value" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|d = time.parse_duration("1s")
      #|assert.eq(time.parse_duration(d), d)
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time.from_timestamp: rejects more than 2 positional args" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|assert.fails(lambda: time.from_timestamp(1, 0, 99), "from_timestamp: got 3 arguments, want at most 2")
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time.duration: unknown attribute raises unrecognized error" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|d = time.parse_duration("1s")
      #|assert.fails(lambda: d.bogus, "unrecognized time.duration attribute \"bogus\"")
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time.parse_duration: type error uses Go format" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|assert.fails(lambda: time.parse_duration(42), "parse_duration: for parameter 1: got int, want a duration, string, or int")
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time.parse_duration: string parse error carries parameter prefix" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|assert.fails(lambda: time.parse_duration("abc"), "parse_duration: for parameter 1: time: invalid duration")
      #|assert.fails(lambda: time.parse_duration("10"), "parse_duration: for parameter 1: time: missing unit")
      #|assert.fails(lambda: time.parse_duration("10x"), "parse_duration: for parameter 1: time: unknown unit")
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time.time: out-of-range kwarg error includes parameter name and value" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|assert.fails(
      #|  lambda: time.time(year=9999999999999999999),
      #|  "time: for parameter year: 9999999999999999999 out of range (want value in signed 64-bit range)",
      #|)
      #|assert.fails(
      #|  lambda: time.time(month=9999999999999999999),
      #|  "time: for parameter month: 9999999999999999999 out of range (want value in signed 64-bit range)",
      #|)
      #|assert.fails(
      #|  lambda: time.time(nanosecond=9999999999999999999),
      #|  "time: for parameter nanosecond: 9999999999999999999 out of range (want value in signed 64-bit range)",
      #|)
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time: duration * BigInt outside int64 range raises out-of-range error" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|assert.fails(lambda: time.second * 10000000000000000000, "out of range")
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time: time + duration does not overflow Int64 for year 2500" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|t = time.time(year=2500)
      #|t2 = t + time.second
      #|assert.true(bool(t2))
      #|assert.eq(t2.unix - t.unix, 1)
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time: time - duration crossing epoch produces valid sub-second result" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|t = time.from_timestamp(0)
      #|t2 = t - time.parse_duration("100ms")
      #|assert.true(bool(t2))
      #|assert.eq(t2.unix, -1)
      #|assert.eq(t2.nanosecond, 900000000)
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time: duration + time does not overflow Int64 for far-future dates" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|t = time.time(year=2500)
      #|t2 = time.second + t
      #|assert.true(bool(t2))
      #|assert.eq(t2.unix - t.unix, 1)
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time: from_timestamp normalizes nsec >= 1e9 by carrying into seconds" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|t = time.from_timestamp(0, 1500000000)
      #|assert.true(bool(t))
      #|assert.eq(t.unix, 1)
      #|assert.eq(t.nanosecond, 500000000)
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time: from_timestamp normalizes negative nsec by borrowing from seconds" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|t = time.from_timestamp(1, -500000000)
      #|assert.eq(t.unix, 0)
      #|assert.eq(t.nanosecond, 500000000)
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time.time: normalizes month=13 to next year January" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|assert.eq(time.time(year=2021, month=13), time.time(year=2022, month=1))
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time.time: normalizes month=0 to previous year December" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|assert.eq(time.time(year=2021, month=0), time.time(year=2020, month=12))
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time module: time + duration preserves timezone" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|t = time.parse_time("2021-03-22T23:20:50+05:30")
      #|assert.eq(str(t + time.hour), "2021-03-23 00:20:50 +0530 +0530")
      #|assert.eq(str(t - time.hour), "2021-03-22 22:20:50 +0530 +0530")
      #|assert.eq(str(time.hour + t), "2021-03-23 00:20:50 +0530 +0530")
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "time.time: month=0 with default day=0 produces Go-equivalent normalized date" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|load("time.star", "time")
      #|t = time.time(month=0)
      #|assert.eq(t.year, -1)
      #|assert.eq(t.month, 11)
      #|assert.eq(t.day, 30)
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}
