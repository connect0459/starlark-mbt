///|
let ns_per_second : Int64 = 1_000_000_000L

///|
let ns_per_millisecond : Int64 = 1_000_000L

///|
let ns_per_microsecond : Int64 = 1_000L

///|
let ns_per_minute : Int64 = 60_000_000_000L

///|
let ns_per_hour : Int64 = 3_600_000_000_000L

///|
let secs_per_hour : Int = 3600

///|
let secs_per_minute : Int = 60

///|
fn extract_duration_ns(v : @value.Value) -> Int64? {
  match v {
    @value.Value::ExtVal(c) =>
      if c.get_type_name() == "time.duration" {
        match c.get_attr("__ns") {
          Ok(Some(@value.Value::Int(n))) => Some(n.to_int64())
          _ => None
        }
      } else {
        None
      }
    _ => None
  }
}

///|
fn extract_time_parts(v : @value.Value) -> (Int64, Int)? {
  match v {
    @value.Value::ExtVal(c) =>
      if c.get_type_name() == "time.time" {
        match (c.get_attr("__sec"), c.get_attr("__nsec")) {
          (Ok(Some(@value.Value::Int(s))), Ok(Some(@value.Value::Int(n)))) =>
            Some((s.to_int64(), n.to_int()))
          _ => None
        }
      } else {
        None
      }
    _ => None
  }
}

///|
/// Folds a 64-bit value into a 32-bit hash by XOR-ing its high and low halves,
/// so both word boundaries contribute to the result (a bare truncation would
/// drop the high 32 bits entirely).
fn hash_int64_fold(v : Int64) -> UInt {
  let lo = v.to_int().reinterpret_as_uint()
  let hi = (v >> 32).to_int().reinterpret_as_uint()
  lo ^ hi
}

///|
fn duration_hash(ns : Int64) -> Result[UInt, String] {
  Ok(hash_int64_fold(ns))
}

///|
fn duration_compare(ns : Int64, other : @value.Value) -> Int? {
  match extract_duration_ns(other) {
    Some(other_ns) =>
      if ns < other_ns {
        Some(-1)
      } else if ns > other_ns {
        Some(1)
      } else {
        Some(0)
      }
    None => None
  }
}

///|
fn duration_equals(ns : Int64, other : @value.Value) -> Bool {
  match duration_compare(ns, other) {
    Some(0) => true
    _ => false
  }
}

///|
fn duration_attr(ns : Int64, name : String) -> Result[@value.Value?, String] {
  match name {
    "__ns" => Ok(Some(@value.Value::Int(BigInt::from_int64(ns))))
    "hours" =>
      Ok(Some(@value.Value::Float(ns.to_double() / ns_per_hour.to_double())))
    "minutes" =>
      Ok(Some(@value.Value::Float(ns.to_double() / ns_per_minute.to_double())))
    "seconds" =>
      Ok(Some(@value.Value::Float(ns.to_double() / ns_per_second.to_double())))
    "milliseconds" =>
      Ok(Some(@value.Value::Int(BigInt::from_int64(ns / ns_per_millisecond))))
    "microseconds" =>
      Ok(Some(@value.Value::Int(BigInt::from_int64(ns / ns_per_microsecond))))
    "nanoseconds" => Ok(Some(@value.Value::Int(BigInt::from_int64(ns))))
    _ => Ok(None)
  }
}

///|
fn duration_attr_names() -> Array[String] {
  ["hours", "minutes", "seconds", "milliseconds", "microseconds", "nanoseconds"]
}

///|
fn duration_binary(
  ns : Int64,
  op : String,
  rhs : @value.Value,
  is_left : Bool,
) -> Result[@value.Value, String]? {
  match op {
    "+" =>
      match extract_duration_ns(rhs) {
        Some(rhs_ns) => Some(Ok(make_duration(ns + rhs_ns)))
        None =>
          match extract_time_parts(rhs) {
            Some((sec, nsec)) => {
              let total_ns = sec * ns_per_second + nsec.to_int64() + ns
              let new_sec = total_ns / ns_per_second
              let new_nsec = (total_ns % ns_per_second).to_int()
              Some(Ok(make_time(new_sec, new_nsec)))
            }
            None => None
          }
      }
    "-" =>
      if is_left {
        match extract_duration_ns(rhs) {
          Some(rhs_ns) => Some(Ok(make_duration(ns - rhs_ns)))
          None => None
        }
      } else {
        None
      }
    "/" =>
      if is_left {
        match rhs {
          @value.Value::Int(i) =>
            if i.is_zero() {
              Some(Err("time.duration division by zero"))
            } else {
              Some(Ok(make_duration(ns / i.to_int64())))
            }
          @value.Value::Float(f) =>
            if f == 0.0 {
              Some(Err("time.duration division by zero"))
            } else {
              Some(Ok(make_duration((ns.to_double() / f).to_int64())))
            }
          _ =>
            match extract_duration_ns(rhs) {
              Some(rhs_ns) =>
                if rhs_ns == 0L {
                  Some(Err("time.duration division by zero"))
                } else {
                  Some(
                    Ok(@value.Value::Float(ns.to_double() / rhs_ns.to_double())),
                  )
                }
              None => None
            }
        }
      } else {
        Some(Err("unsupported operation"))
      }
    "//" =>
      if is_left {
        match extract_duration_ns(rhs) {
          Some(rhs_ns) =>
            if rhs_ns == 0L {
              Some(Err("time.duration division by zero"))
            } else {
              Some(Ok(@value.Value::Int(BigInt::from_int64(ns / rhs_ns))))
            }
          None => None
        }
      } else {
        None
      }
    "*" =>
      match rhs {
        @value.Value::Int(i) => {
          let max_int64 = 9223372036854775807L
          let min_int64 = -9223372036854775808L
          if i.compare_int64(max_int64) > 0 || i.compare_int64(min_int64) < 0 {
            Some(Err("int value out of range (want signed 64-bit value)"))
          } else {
            Some(Ok(make_duration(ns * i.to_int64())))
          }
        }
        _ => None
      }
    _ => None
  }
}

///|
fn fmt_frac9(ns_frac : Int64) -> String {
  let s = ns_frac.to_string()
  let pad_len = 9 - s.length()
  let buf = StringBuilder::new()
  for _ in 0..<pad_len {
    buf.write_char('0')
  }
  buf.write_string(s)
  let full = buf.to_string()
  let chars = full.to_array()
  let mut end = chars.length()
  while end > 1 && chars[end - 1] == '0' {
    end -= 1
  }
  full[0:end].to_owned()
}

///|
fn fmt_duration(ns : Int64) -> String {
  if ns == 0L {
    return "0s"
  }
  let buf = StringBuilder::new()
  let abs_ns = if ns < 0L { 0L - ns } else { ns }
  if ns < 0L {
    buf.write_char('-')
  }
  if abs_ns < ns_per_second {
    if abs_ns < ns_per_microsecond {
      buf.write_string(abs_ns.to_string())
      buf.write_string("ns")
    } else if abs_ns < ns_per_millisecond {
      let us = abs_ns / ns_per_microsecond
      let frac = abs_ns % ns_per_microsecond
      if frac == 0L {
        buf.write_string(us.to_string())
        buf.write_string("µs")
      } else {
        buf.write_string(abs_ns.to_string())
        buf.write_string("ns")
      }
    } else {
      let ms = abs_ns / ns_per_millisecond
      let frac = abs_ns % ns_per_millisecond
      if frac == 0L {
        buf.write_string(ms.to_string())
        buf.write_string("ms")
      } else {
        let us = abs_ns / ns_per_microsecond
        let ns_frac = abs_ns % ns_per_microsecond
        if ns_frac == 0L {
          buf.write_string(us.to_string())
          buf.write_string("µs")
        } else {
          buf.write_string(abs_ns.to_string())
          buf.write_string("ns")
        }
      }
    }
  } else {
    let total_sec = abs_ns / ns_per_second
    let ns_frac = abs_ns % ns_per_second
    let hours = total_sec / secs_per_hour.to_int64()
    let minutes = total_sec %
      secs_per_hour.to_int64() /
      secs_per_minute.to_int64()
    let secs = total_sec % secs_per_minute.to_int64()
    if hours > 0L {
      buf.write_string(hours.to_string())
      buf.write_char('h')
      buf.write_string(minutes.to_string())
      buf.write_char('m')
    } else if minutes > 0L {
      buf.write_string(minutes.to_string())
      buf.write_char('m')
    }
    if ns_frac == 0L {
      buf.write_string(secs.to_string())
      buf.write_char('s')
    } else {
      buf.write_string(secs.to_string())
      buf.write_char('.')
      buf.write_string(fmt_frac9(ns_frac))
      buf.write_char('s')
    }
  }
  buf.to_string()
}

///|
fn make_duration(ns : Int64) -> @value.Value {
  @value.Value::ExtVal(
    @value.CustomValue::new(fn() { "time.duration" }, fn() { ns != 0L }, fn() {
      fmt_duration(ns)
    })
    .with_hash(fn() { duration_hash(ns) })
    .with_equals(fn(other) { duration_equals(ns, other) })
    .with_compare(fn(other) { duration_compare(ns, other) })
    .with_binary(fn(op, rhs, is_left) { duration_binary(ns, op, rhs, is_left) })
    .with_attrs(fn(name) { duration_attr(ns, name) }, fn() {
      duration_attr_names()
    }),
  )
}

///|
fn parse_digits_at(chars : Array[Char], i : Int) -> (String, Int) {
  let buf = StringBuilder::new()
  let mut j = i
  while j < chars.length() && chars[j] >= '0' && chars[j] <= '9' {
    buf.write_char(chars[j])
    j += 1
  }
  (buf.to_string(), j)
}

///|
fn parse_int64_str(s : String) -> Int64? {
  if s.is_empty() {
    return None
  }
  let chars = s.to_array()
  let mut result = 0L
  for c in chars {
    if c < '0' || c > '9' {
      return None
    }
    result = result * 10L + (c.to_int() - '0'.to_int()).to_int64()
  }
  Some(result)
}

///|
fn parse_duration_number(
  num_str : String,
  scale : Int64,
  orig : String,
) -> Result[Int64, String] {
  match num_str.find(".") {
    None =>
      match parse_int64_str(num_str) {
        Some(n) => Ok(n * scale)
        None => Err("time: invalid duration \"\{orig}\"")
      }
    Some(dot_pos) => {
      let int_part = num_str[0:dot_pos].to_owned()
      let frac_part = num_str[dot_pos + 1:].to_owned()
      let int_val = if int_part.is_empty() {
        0L
      } else {
        match parse_int64_str(int_part) {
          Some(n) => n
          None => return Err("time: invalid duration \"\{orig}\"")
        }
      }
      let int_ns = int_val * scale
      let frac_ns = if frac_part.is_empty() {
        0L
      } else {
        let chars = frac_part.to_array()
        let mut frac_val = 0L
        let mut frac_scale = scale
        for c in chars {
          if c < '0' || c > '9' {
            return Err("time: invalid duration \"\{orig}\"")
          }
          frac_scale = frac_scale / 10L
          if frac_scale > 0L {
            frac_val = frac_val +
              (c.to_int() - '0'.to_int()).to_int64() * frac_scale
          }
        }
        frac_val
      }
      Ok(int_ns + frac_ns)
    }
  }
}

///|
fn parse_duration_component(
  s : String,
  orig : String,
) -> Result[(String, String, String), String] {
  let chars = s.to_array()
  let len = chars.length()
  if len == 0 {
    return Err("time: invalid duration \"\{orig}\"")
  }
  let mut i = 0
  let num_buf = StringBuilder::new()
  while i < len && (chars[i] == '.' || (chars[i] >= '0' && chars[i] <= '9')) {
    num_buf.write_char(chars[i])
    i += 1
  }
  let num_str = num_buf.to_string()
  if num_str.is_empty() {
    return Err("time: invalid duration \"\{orig}\"")
  }
  let unit_buf = StringBuilder::new()
  while i < len {
    let c = chars[i]
    // Accept both the MICRO SIGN (U+00B5) and GREEK SMALL LETTER MU (U+03BC),
    // which render identically; Go's time.ParseDuration treats either as "us".
    if (c >= 'a' && c <= 'z') || c == 'µ' || c == 'μ' {
      unit_buf.write_char(c)
      i += 1
    } else {
      break
    }
  }
  let unit_str = unit_buf.to_string()
  if unit_str.is_empty() {
    return Err("time: missing unit in duration \"\{orig}\"")
  }
  let remaining = s[i:].to_owned()
  Ok((num_str, unit_str, remaining))
}

///|
fn parse_duration_str(s : String) -> Result[Int64, String] {
  if s == "0" || s == "+0" || s == "-0" {
    return Ok(0L)
  }
  let orig = s
  let mut neg = false
  let mut rest = s
  if rest.has_prefix("-") {
    neg = true
    rest = rest[1:].to_owned()
  } else if rest.has_prefix("+") {
    rest = rest[1:].to_owned()
  }
  if rest.is_empty() {
    return Err("time: invalid duration \"\{orig}\"")
  }
  let mut total_ns : Int64 = 0L
  while !rest.is_empty() {
    match parse_duration_component(rest, orig) {
      Err(e) => return Err(e)
      Ok((num_str, unit_str, remaining)) => {
        let scale : Int64 = match unit_str {
          "ns" => 1L
          "us" | "µs" | "μs" => ns_per_microsecond
          "ms" => ns_per_millisecond
          "s" => ns_per_second
          "m" => ns_per_minute
          "h" => ns_per_hour
          _ =>
            return Err(
              "time: unknown unit \"\{unit_str}\" in duration \"\{orig}\"",
            )
        }
        match parse_duration_number(num_str, scale, orig) {
          Err(e) => return Err(e)
          Ok(ns_val) => {
            total_ns = total_ns + ns_val
            rest = remaining
          }
        }
      }
    }
  }
  if neg {
    Ok(0L - total_ns)
  } else {
    Ok(total_ns)
  }
}

///|
fn write_pad2(buf : StringBuilder, n : Int) -> Unit {
  if n < 10 {
    buf.write_char('0')
  }
  buf.write_string(n.to_string())
}

///|
fn write_tz_offset(buf : StringBuilder, tz_offset : Int) -> Unit {
  let abs_off = if tz_offset < 0 { -tz_offset } else { tz_offset }
  if tz_offset >= 0 {
    buf.write_char('+')
  } else {
    buf.write_char('-')
  }
  write_pad2(buf, abs_off / secs_per_hour)
  write_pad2(buf, abs_off % secs_per_hour / secs_per_minute)
}

///|
fn fmt_time_at_zone(
  sec : Int64,
  nsec : Int,
  tz_offset : Int,
  tz_name : String,
) -> String {
  let zone = if tz_offset == 0 {
    @x_time.utc_zone
  } else {
    @x_time.fixed_zone(tz_name, tz_offset) catch {
      _ => @x_time.utc_zone
    }
  }
  let dt = @x_time.ZonedDateTime::from_unix_second(sec, nanosecond=nsec, zone~) catch {
    _ => return "invalid time"
  }
  let buf = StringBuilder::new()
  buf.write_string(dt.year().to_string())
  buf.write_char('-')
  write_pad2(buf, dt.month())
  buf.write_char('-')
  write_pad2(buf, dt.day())
  buf.write_char(' ')
  write_pad2(buf, dt.hour())
  buf.write_char(':')
  write_pad2(buf, dt.minute())
  buf.write_char(':')
  write_pad2(buf, dt.second())
  if nsec != 0 {
    buf.write_char('.')
    buf.write_string(fmt_frac9(nsec.to_int64()))
  }
  buf.write_char(' ')
  let off = dt.offset().seconds()
  if off >= 0 {
    buf.write_char('+')
    write_pad2(buf, off / secs_per_hour)
    write_pad2(buf, off % secs_per_hour / secs_per_minute)
  } else {
    let abs = -off
    buf.write_char('-')
    write_pad2(buf, abs / secs_per_hour)
    write_pad2(buf, abs % secs_per_hour / secs_per_minute)
  }
  buf.write_char(' ')
  buf.write_string(tz_name)
  buf.to_string()
}

///|
let month_full_names : FixedArray[String] = [
  "", "January", "February", "March", "April", "May", "June", "July", "August", "September",
  "October", "November", "December",
]

///|
let month_abbrev_names : FixedArray[String] = [
  "", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov",
  "Dec",
]

///|
let weekday_full_names : FixedArray[String] = [
  "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday",
]

///|
let weekday_abbrev_names : FixedArray[String] = [
  "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat",
]

///|
fn weekday_index(year : Int, month : Int, day : Int) -> Int {
  let dt = @x_time.ZonedDateTime::of(year, month, day, zone=@x_time.utc_zone) catch {
    _ => return 0
  }
  match dt.weekday() {
    @x_time.Weekday::Sunday => 0
    @x_time.Weekday::Monday => 1
    @x_time.Weekday::Tuesday => 2
    @x_time.Weekday::Wednesday => 3
    @x_time.Weekday::Thursday => 4
    @x_time.Weekday::Friday => 5
    @x_time.Weekday::Saturday => 6
  }
}

///|
fn fmt_nsec_frac(nsec : Int, digits : Int, trimmed : Bool) -> String {
  let ns9 = fmt_frac9(nsec.to_int64())
  let padded = StringBuilder::new()
  let pad_len = 9 - ns9.length()
  for _ in 0..<pad_len {
    padded.write_char('0')
  }
  padded.write_string(ns9)
  let full = padded.to_string()
  let trunc = if digits >= 9 {
    full
  } else {
    let chars = full.to_array()
    chars[0:digits]
    .iter()
    .fold(init=StringBuilder::new(), fn(buf, c) {
      buf.write_char(c)
      buf
    })
    .to_string()
  }
  if trimmed {
    let chars = trunc.to_array()
    let mut end = chars.length()
    while end > 1 && chars[end - 1] == '0' {
      end -= 1
    }
    trunc[0:end].to_owned()
  } else {
    trunc
  }
}

///|
// Render a time against a Go reference-time layout. Go encodes each field as a
// fixed mnemonic drawn from the reference instant "Mon Jan 2 15:04:05 MST 2006"
// (01/02 03:04:05PM '06 -0700): e.g. "2006" = 4-digit year, "January"/"Jan" =
// full/abbrev month, "Monday"/"Mon" = weekday, "15" = 24-hour, "-0700"/"Z0700"
// = numeric zone. Each branch advances `i` by the matched mnemonic's length.
fn fmt_go_layout(
  year : Int,
  month : Int,
  day : Int,
  hour24 : Int,
  minute : Int,
  second : Int,
  nsec : Int,
  tz_offset : Int,
  tz_name : String,
  layout : String,
) -> String {
  let buf = StringBuilder::new()
  let lchars = layout.to_array()
  let n = lchars.length()
  let mut i = 0
  while i < n {
    let c = lchars[i]
    if c == 'J' && i + 2 < n && lchars[i + 1] == 'a' && lchars[i + 2] == 'n' {
      if i + 6 < n &&
        lchars[i + 3] == 'u' &&
        lchars[i + 4] == 'a' &&
        lchars[i + 5] == 'r' &&
        lchars[i + 6] == 'y' {
        buf.write_string(month_full_names[month])
        i += 7
      } else {
        buf.write_string(month_abbrev_names[month])
        i += 3
      }
    } else if c == 'M' &&
      i + 2 < n &&
      lchars[i + 1] == 'o' &&
      lchars[i + 2] == 'n' {
      if i + 5 < n &&
        lchars[i + 3] == 'd' &&
        lchars[i + 4] == 'a' &&
        lchars[i + 5] == 'y' {
        buf.write_string(weekday_full_names[weekday_index(year, month, day)])
        i += 6
      } else {
        buf.write_string(weekday_abbrev_names[weekday_index(year, month, day)])
        i += 3
      }
    } else if c == 'M' &&
      i + 2 < n &&
      lchars[i + 1] == 'S' &&
      lchars[i + 2] == 'T' {
      buf.write_string(tz_name)
      i += 3
    } else if c == '2' &&
      i + 3 < n &&
      lchars[i + 1] == '0' &&
      lchars[i + 2] == '0' &&
      lchars[i + 3] == '6' {
      buf.write_string(year.to_string())
      i += 4
    } else if c == '1' && i + 1 < n && lchars[i + 1] == '5' {
      write_pad2(buf, hour24)
      i += 2
    } else if c == '0' && i + 1 < n {
      let next = lchars[i + 1]
      if next == '1' {
        write_pad2(buf, month)
        i += 2
      } else if next == '2' {
        write_pad2(buf, day)
        i += 2
      } else if next == '3' {
        let h12 = if hour24 == 0 {
          12
        } else if hour24 <= 12 {
          hour24
        } else {
          hour24 - 12
        }
        write_pad2(buf, h12)
        i += 2
      } else if next == '4' {
        write_pad2(buf, minute)
        i += 2
      } else if next == '5' {
        write_pad2(buf, second)
        i += 2
      } else if next == '6' {
        write_pad2(buf, year % 100)
        i += 2
      } else {
        buf.write_char('0')
        i += 1
      }
    } else if c == 'P' && i + 1 < n && lchars[i + 1] == 'M' {
      buf.write_string(if hour24 >= 12 { "PM" } else { "AM" })
      i += 2
    } else if c == 'p' && i + 1 < n && lchars[i + 1] == 'm' {
      buf.write_string(if hour24 >= 12 { "pm" } else { "am" })
      i += 2
    } else if c == '3' {
      let h12 = if hour24 == 0 {
        12
      } else if hour24 <= 12 {
        hour24
      } else {
        hour24 - 12
      }
      buf.write_string(h12.to_string())
      i += 1
    } else if c == '4' {
      buf.write_string(minute.to_string())
      i += 1
    } else if c == '5' {
      buf.write_string(second.to_string())
      i += 1
    } else if c == '1' {
      buf.write_string(month.to_string())
      i += 1
    } else if c == '2' {
      buf.write_string(day.to_string())
      i += 1
    } else if c == '.' &&
      i + 1 < n &&
      (lchars[i + 1] == '9' || lchars[i + 1] == '0') {
      let is_trimmed = lchars[i + 1] == '9'
      let mut j = i + 1
      while j < n && (lchars[j] == '9' || lchars[j] == '0') {
        j += 1
      }
      let frac_digits = j - i - 1
      if nsec != 0 || !is_trimmed {
        buf.write_char('.')
        buf.write_string(fmt_nsec_frac(nsec, frac_digits, is_trimmed))
      }
      i = j
    } else if c == '-' &&
      i + 4 < n &&
      lchars[i + 1] == '0' &&
      lchars[i + 2] == '7' &&
      lchars[i + 3] == '0' &&
      lchars[i + 4] == '0' {
      write_tz_offset(buf, tz_offset)
      i += 5
    } else if c == 'Z' &&
      i + 4 < n &&
      lchars[i + 1] == '0' &&
      lchars[i + 2] == '7' &&
      lchars[i + 3] == '0' &&
      lchars[i + 4] == '0' {
      if tz_offset == 0 {
        buf.write_char('Z')
      } else {
        write_tz_offset(buf, tz_offset)
      }
      i += 5
    } else {
      buf.write_char(c)
      i += 1
    }
  }
  buf.to_string()
}

///|
fn time_hash(sec : Int64, nsec : Int) -> Result[UInt, String] {
  let unix_nano = sec * ns_per_second + nsec.to_int64()
  Ok(hash_int64_fold(unix_nano))
}

///|
fn time_compare(sec : Int64, nsec : Int, other : @value.Value) -> Int? {
  match extract_time_parts(other) {
    Some((other_sec, other_nsec)) =>
      if sec < other_sec || (sec == other_sec && nsec < other_nsec) {
        Some(-1)
      } else if sec > other_sec || (sec == other_sec && nsec > other_nsec) {
        Some(1)
      } else {
        Some(0)
      }
    None => None
  }
}

///|
fn time_equals(sec : Int64, nsec : Int, other : @value.Value) -> Bool {
  match time_compare(sec, nsec, other) {
    Some(0) => true
    _ => false
  }
}

///|
fn time_truth(sec : Int64, nsec : Int) -> Bool {
  let dt = @x_time.ZonedDateTime::from_unix_second(
    sec,
    nanosecond=nsec,
    zone=@x_time.utc_zone,
  ) catch {
    _ => return false
  }
  !(dt.year() == 1 &&
  dt.month() == 1 &&
  dt.day() == 1 &&
  dt.hour() == 0 &&
  dt.minute() == 0 &&
  dt.second() == 0 &&
  dt.nanosecond() == 0)
}

///|
fn time_attr(
  sec : Int64,
  nsec : Int,
  tz_offset : Int,
  tz_name : String,
  name : String,
) -> Result[@value.Value?, String] {
  match name {
    "__sec" => Ok(Some(@value.Value::Int(BigInt::from_int64(sec))))
    "__nsec" => Ok(Some(@value.Value::Int(BigInt::from_int(nsec))))
    "unix" => Ok(Some(@value.Value::Int(BigInt::from_int64(sec))))
    "unix_nano" =>
      Ok(
        Some(
          @value.Value::Int(
            BigInt::from_int64(sec * ns_per_second + nsec.to_int64()),
          ),
        ),
      )
    "in_location" => {
      let m = make_in_location_method(sec, nsec)
      Ok(Some(m))
    }
    "format" => {
      let m = make_format_method(sec, nsec, tz_offset, tz_name)
      Ok(Some(m))
    }
    _ => {
      let zone = if tz_offset == 0 {
        @x_time.utc_zone
      } else {
        @x_time.fixed_zone(tz_name, tz_offset) catch {
          _ => @x_time.utc_zone
        }
      }
      let dt = @x_time.ZonedDateTime::from_unix_second(
        sec,
        nanosecond=nsec,
        zone~,
      ) catch {
        _ => return Err("invalid time")
      }
      let v = match name {
        "year" => @value.Value::Int(BigInt::from_int(dt.year()))
        "month" => @value.Value::Int(BigInt::from_int(dt.month()))
        "day" => @value.Value::Int(BigInt::from_int(dt.day()))
        "hour" => @value.Value::Int(BigInt::from_int(dt.hour()))
        "minute" => @value.Value::Int(BigInt::from_int(dt.minute()))
        "second" => @value.Value::Int(BigInt::from_int(dt.second()))
        "nanosecond" => @value.Value::Int(BigInt::from_int(dt.nanosecond()))
        _ => return Ok(None)
      }
      Ok(Some(v))
    }
  }
}

///|
fn time_attr_names() -> Array[String] {
  [
    "year", "month", "day", "hour", "minute", "second", "nanosecond", "unix", "unix_nano",
    "in_location", "format",
  ]
}

///|
fn time_binary(
  sec : Int64,
  nsec : Int,
  op : String,
  rhs : @value.Value,
  is_left : Bool,
) -> Result[@value.Value, String]? {
  if !is_left {
    return None
  }
  match op {
    "+" =>
      match extract_duration_ns(rhs) {
        Some(dns) => {
          let total_ns = sec * ns_per_second + nsec.to_int64() + dns
          let new_sec = total_ns / ns_per_second
          let new_nsec = (total_ns % ns_per_second).to_int()
          Some(Ok(make_time(new_sec, new_nsec)))
        }
        None => None
      }
    "-" =>
      match extract_duration_ns(rhs) {
        Some(dns) => {
          let total_ns = sec * ns_per_second + nsec.to_int64() - dns
          let new_sec = total_ns / ns_per_second
          let new_nsec = (total_ns % ns_per_second).to_int()
          Some(Ok(make_time(new_sec, new_nsec)))
        }
        None =>
          match extract_time_parts(rhs) {
            Some((other_sec, other_nsec)) => {
              let diff_ns = sec * ns_per_second +
                nsec.to_int64() -
                (other_sec * ns_per_second + other_nsec.to_int64())
              Some(Ok(make_duration(diff_ns)))
            }
            None => None
          }
      }
    _ => None
  }
}

///|
fn make_time_at_zone(
  sec : Int64,
  nsec : Int,
  tz_offset : Int,
  tz_name : String,
) -> @value.Value {
  @value.Value::ExtVal(
    @value.CustomValue::new(
      fn() { "time.time" },
      fn() { time_truth(sec, nsec) },
      fn() { fmt_time_at_zone(sec, nsec, tz_offset, tz_name) },
    )
    .with_hash(fn() { time_hash(sec, nsec) })
    .with_equals(fn(other) { time_equals(sec, nsec, other) })
    .with_compare(fn(other) { time_compare(sec, nsec, other) })
    .with_binary(fn(op, rhs, is_left) {
      time_binary(sec, nsec, op, rhs, is_left)
    })
    .with_attrs(fn(name) { time_attr(sec, nsec, tz_offset, tz_name, name) }, fn() {
      time_attr_names()
    }),
  )
}

///|
fn make_time(sec : Int64, nsec : Int) -> @value.Value {
  make_time_at_zone(sec, nsec, 0, "UTC")
}

///|
fn make_in_location_method(sec : Int64, nsec : Int) -> @value.Value {
  @value.Value::new_builtin("in_location", fn(_ctx, pos_args, kw_args) {
    if pos_args.length() != 1 || kw_args.length() != 0 {
      return Err("in_location: got \{pos_args.length()} arguments, want 1")
    }
    let loc = match pos_args[0] {
      @value.Value::String(s) => s.raw()
      _ => return Err("in_location: argument must be a string")
    }
    if !is_valid_timezone_impl(loc) {
      return Err("in_location: unsupported timezone \"\{loc}\"")
    }
    let offset = match get_tz_offset_at_impl(loc, sec) {
      Some(o) => o
      None => return Err("in_location: cannot determine offset for \"\{loc}\"")
    }
    Ok(make_time_at_zone(sec, nsec, offset, loc))
  })
}

///|
fn make_format_method(
  sec : Int64,
  nsec : Int,
  tz_offset : Int,
  tz_name : String,
) -> @value.Value {
  @value.Value::new_builtin("format", fn(_ctx, pos_args, kw_args) {
    if pos_args.length() != 1 || kw_args.length() != 0 {
      return Err("format: got \{pos_args.length()} arguments, want 1")
    }
    let layout = match pos_args[0] {
      @value.Value::String(s) => s.raw()
      _ => return Err("format: argument must be a string")
    }
    let zone = if tz_offset == 0 {
      @x_time.utc_zone
    } else {
      @x_time.fixed_zone(tz_name, tz_offset) catch {
        _ => @x_time.utc_zone
      }
    }
    let dt = @x_time.ZonedDateTime::from_unix_second(
      sec,
      nanosecond=nsec,
      zone~,
    ) catch {
      _ => return Err("format: invalid time")
    }
    let result = fmt_go_layout(
      dt.year(),
      dt.month(),
      dt.day(),
      dt.hour(),
      dt.minute(),
      dt.second(),
      dt.nanosecond(),
      tz_offset,
      tz_name,
      layout,
    )
    Ok(@value.Value::String(@value.StarlarkString::new(result)))
  })
}

///|
fn parse_2digits(chars : Array[Char], i : Int) -> (Int, Int)? {
  if i + 1 >= chars.length() {
    return None
  }
  let c0 = chars[i].to_int() - '0'.to_int()
  let c1 = chars[i + 1].to_int() - '0'.to_int()
  if c0 < 0 || c0 > 9 || c1 < 0 || c1 > 9 {
    return None
  }
  Some((c0 * 10 + c1, i + 2))
}

///|
fn parse_rfc3339(s : String) -> Result[(Int64, Int), String] {
  let chars = s.to_array()
  let len = chars.length()
  if len < 10 {
    return Err("time: invalid RFC3339 time \"\{s}\"")
  }
  let (year_i, _) = parse_digits_at(chars, 0)
  let year = match parse_int64_str(year_i) {
    Some(y) => y.to_int()
    None => return Err("time: invalid year in \"\{s}\"")
  }
  let year_end = year_i.length()
  if year_end >= len || chars[year_end] != '-' {
    return Err("time: invalid RFC3339 time \"\{s}\"")
  }
  let i = year_end + 1
  let (month, i) = match parse_2digits(chars, i) {
    Some(v) => v
    None => return Err("time: invalid month in \"\{s}\"")
  }
  if i >= len || chars[i] != '-' {
    return Err("time: invalid RFC3339 time \"\{s}\"")
  }
  let i = i + 1
  let (day, i) = match parse_2digits(chars, i) {
    Some(v) => v
    None => return Err("time: invalid day in \"\{s}\"")
  }
  if i >= len || (chars[i] != 'T' && chars[i] != 't' && chars[i] != ' ') {
    return Err("time: invalid RFC3339 time \"\{s}\"")
  }
  let i = i + 1
  let (hour, i) = match parse_2digits(chars, i) {
    Some(v) => v
    None => return Err("time: invalid hour in \"\{s}\"")
  }
  if i >= len || chars[i] != ':' {
    return Err("time: invalid RFC3339 time \"\{s}\"")
  }
  let i = i + 1
  let (minute, i) = match parse_2digits(chars, i) {
    Some(v) => v
    None => return Err("time: invalid minute in \"\{s}\"")
  }
  if i >= len || chars[i] != ':' {
    return Err("time: invalid RFC3339 time \"\{s}\"")
  }
  let i = i + 1
  let (second, i) = match parse_2digits(chars, i) {
    Some(v) => v
    None => return Err("time: invalid second in \"\{s}\"")
  }
  let (nsec, i) = if i < len && chars[i] == '.' {
    let j = i + 1
    let (frac_str, end) = parse_digits_at(chars, j)
    let frac_len = frac_str.length()
    if frac_len == 0 {
      return Err("time: invalid fractional seconds in \"\{s}\"")
    }
    let frac_val = match parse_int64_str(frac_str) {
      Some(v) => v
      None => return Err("time: invalid fractional seconds in \"\{s}\"")
    }
    // Normalize the fractional digits to nanoseconds (9 digits): drop excess
    // precision when more than 9 were given, pad with trailing zeros otherwise.
    let ns = if frac_len >= 9 {
      frac_val / pow10_int64(frac_len - 9)
    } else {
      frac_val * pow10_int64(9 - frac_len)
    }
    (ns.to_int(), end)
  } else {
    (0, i)
  }
  let tz_offset_sec = if i >= len || chars[i] == 'Z' || chars[i] == 'z' {
    0
  } else if chars[i] == '+' || chars[i] == '-' {
    let sign = if chars[i] == '+' { 1 } else { -1 }
    let j = i + 1
    let (tz_hour, j) = match parse_2digits(chars, j) {
      Some(v) => v
      None => return Err("time: invalid timezone in \"\{s}\"")
    }
    if j >= len || chars[j] != ':' {
      return Err("time: invalid timezone in \"\{s}\"")
    }
    let j = j + 1
    let (tz_minute, _j) = match parse_2digits(chars, j) {
      Some(v) => v
      None => return Err("time: invalid timezone in \"\{s}\"")
    }
    sign * (tz_hour * secs_per_hour + tz_minute * secs_per_minute)
  } else {
    return Err("time: invalid timezone in \"\{s}\"")
  }
  let dt = @x_time.ZonedDateTime::of(
    year,
    month,
    day,
    hour~,
    minute~,
    second~,
    nanosecond=nsec,
    zone=@x_time.utc_zone,
  ) catch {
    _ => return Err("time: invalid time \"\{s}\"")
  }
  let unix_sec = dt.to_unix_second() - tz_offset_sec.to_int64()
  Ok((unix_sec, nsec))
}

///|
// Read exactly `n` digits at `chars[i]`, returning the value and next index.
fn read_fixed_digits(chars : Array[Char], i : Int, n : Int) -> (Int, Int)? {
  let len = chars.length()
  if i + n > len {
    return None
  }
  let mut value = 0
  for k in 0..<n {
    let c = chars[i + k]
    if c < '0' || c > '9' {
      return None
    }
    value = value * 10 + (c.to_int() - '0'.to_int())
  }
  Some((value, i + n))
}

///|
// Read 1 or 2 digits at `chars[i]` (used for the non-padded Go verbs 1/2/3/4/5).
fn read_flex_digits(chars : Array[Char], i : Int) -> (Int, Int)? {
  let len = chars.length()
  if i >= len || chars[i] < '0' || chars[i] > '9' {
    return None
  }
  let mut value = chars[i].to_int() - '0'.to_int()
  let mut j = i + 1
  if j < len && chars[j] >= '0' && chars[j] <= '9' {
    value = value * 10 + (chars[j].to_int() - '0'.to_int())
    j += 1
  }
  Some((value, j))
}

///|
// Match one of `names[1..=count]` (1-indexed) as a prefix of `chars` at `i`.
// Returns the matched index and the next value position.
fn match_name(
  chars : Array[Char],
  i : Int,
  names : FixedArray[String],
  start : Int,
  count : Int,
) -> (Int, Int)? {
  for idx in start..<(start + count) {
    let name = names[idx]
    let nchars = name.to_array()
    let nlen = nchars.length()
    if i + nlen <= chars.length() {
      let mut ok = true
      for k in 0..<nlen {
        if chars[i + k] != nchars[k] {
          ok = false
          break
        }
      }
      if ok {
        return Some((idx, i + nlen))
      }
    }
  }
  None
}

///|
// Parse `value` against a Go reference-time layout (the same token set that
// fmt_go_layout produces). Mirrors Go's time.Parse for the common verbs.
// Returns (year, month, day, hour, minute, second, nsec, tz_offset) where
// tz_offset is Some when the value carried an explicit zone (a `Z` literal
// means offset 0).
fn parse_go_layout(
  value : String,
  layout : String,
) -> Result[(Int, Int, Int, Int, Int, Int, Int, Int?), String] {
  let lc = layout.to_array()
  let vc = value.to_array()
  let ln = lc.length()
  let vn = vc.length()
  let mut li = 0
  let mut vi = 0
  let mut year = 1
  let mut month = 1
  let mut day = 1
  let mut hour = 0
  let mut minute = 0
  let mut second = 0
  let mut nsec = 0
  let mut tz_offset : Int? = None
  let mut pm : Bool? = None
  let mut hour_is_12 = false
  let err = fn() -> Result[(Int, Int, Int, Int, Int, Int, Int, Int?), String] {
    Err("time: parsing time \"\{value}\" as \"\{layout}\": cannot parse")
  }
  fn starts(tok : String) -> Bool {
    let tc = tok.to_array()
    let tl = tc.length()
    if li + tl > ln {
      return false
    }
    for k in 0..<tl {
      if lc[li + k] != tc[k] {
        return false
      }
    }
    true
  }

  // Parse a numeric/sign timezone of the forms ±hh:mm / ±hhmm; `allow_z`
  // accepts a literal `Z` meaning offset 0.
  fn parse_zone(colon : Bool, allow_z : Bool) -> Bool {
    if allow_z && vi < vn && (vc[vi] == 'Z' || vc[vi] == 'z') {
      tz_offset = Some(0)
      vi += 1
      return true
    }
    if vi >= vn || (vc[vi] != '+' && vc[vi] != '-') {
      return false
    }
    let sign = if vc[vi] == '+' { 1 } else { -1 }
    let after_sign = vi + 1
    match read_fixed_digits(vc, after_sign, 2) {
      None => false
      Some((hh, j)) => {
        let mut j2 = j
        if colon {
          if j2 >= vn || vc[j2] != ':' {
            return false
          }
          j2 += 1
        }
        match read_fixed_digits(vc, j2, 2) {
          None => false
          Some((mm, k)) => {
            tz_offset = Some(sign * (hh * secs_per_hour + mm * secs_per_minute))
            vi = k
            true
          }
        }
      }
    }
  }

  while li < ln {
    if starts("2006") {
      match read_fixed_digits(vc, vi, 4) {
        Some((v, j)) => {
          year = v
          vi = j
        }
        None => return err()
      }
      li += 4
    } else if starts("06") {
      match read_fixed_digits(vc, vi, 2) {
        Some((v, j)) => {
          year = if v >= 69 { 1900 + v } else { 2000 + v }
          vi = j
        }
        None => return err()
      }
      li += 2
    } else if starts("January") {
      match match_name(vc, vi, month_full_names, 1, 12) {
        Some((idx, j)) => {
          month = idx
          vi = j
        }
        None => return err()
      }
      li += 7
    } else if starts("Jan") {
      match match_name(vc, vi, month_abbrev_names, 1, 12) {
        Some((idx, j)) => {
          month = idx
          vi = j
        }
        None => return err()
      }
      li += 3
    } else if starts("Monday") {
      match match_name(vc, vi, weekday_full_names, 0, 7) {
        Some((_, j)) => vi = j
        None => return err()
      }
      li += 6
    } else if starts("Mon") {
      match match_name(vc, vi, weekday_abbrev_names, 0, 7) {
        Some((_, j)) => vi = j
        None => return err()
      }
      li += 3
    } else if starts("01") {
      match read_fixed_digits(vc, vi, 2) {
        Some((v, j)) => {
          month = v
          vi = j
        }
        None => return err()
      }
      li += 2
    } else if starts("02") {
      match read_fixed_digits(vc, vi, 2) {
        Some((v, j)) => {
          day = v
          vi = j
        }
        None => return err()
      }
      li += 2
    } else if starts("_2") {
      if vi < vn && vc[vi] == ' ' {
        vi += 1
      }
      match read_flex_digits(vc, vi) {
        Some((v, j)) => {
          day = v
          vi = j
        }
        None => return err()
      }
      li += 2
    } else if starts("15") {
      match read_fixed_digits(vc, vi, 2) {
        Some((v, j)) => {
          hour = v
          vi = j
        }
        None => return err()
      }
      li += 2
    } else if starts("03") {
      match read_fixed_digits(vc, vi, 2) {
        Some((v, j)) => {
          hour = v
          hour_is_12 = true
          vi = j
        }
        None => return err()
      }
      li += 2
    } else if starts("04") {
      match read_fixed_digits(vc, vi, 2) {
        Some((v, j)) => {
          minute = v
          vi = j
        }
        None => return err()
      }
      li += 2
    } else if starts("05") {
      match read_fixed_digits(vc, vi, 2) {
        Some((v, j)) => {
          second = v
          vi = j
        }
        None => return err()
      }
      li += 2
    } else if starts("PM") {
      match match_name(vc, vi, am_pm_upper, 0, 2) {
        Some((idx, j)) => {
          pm = Some(idx == 1)
          vi = j
        }
        None => return err()
      }
      li += 2
    } else if starts("pm") {
      match match_name(vc, vi, am_pm_lower, 0, 2) {
        Some((idx, j)) => {
          pm = Some(idx == 1)
          vi = j
        }
        None => return err()
      }
      li += 2
    } else if starts("Z07:00") {
      if !parse_zone(true, true) {
        return err()
      }
      li += 6
    } else if starts("Z0700") {
      if !parse_zone(false, true) {
        return err()
      }
      li += 5
    } else if starts("-07:00") {
      if !parse_zone(true, false) {
        return err()
      }
      li += 6
    } else if starts("-0700") {
      if !parse_zone(false, false) {
        return err()
      }
      li += 5
    } else if starts("MST") {
      // Timezone abbreviation: consume the alphabetic run but ignore it
      // (abbreviations cannot be resolved to a fixed offset).
      while vi < vn &&
            (
              (vc[vi] >= 'A' && vc[vi] <= 'Z') ||
              (vc[vi] >= 'a' && vc[vi] <= 'z')
            ) {
        vi += 1
      }
      li += 3
    } else if lc[li] == '3' {
      match read_flex_digits(vc, vi) {
        Some((v, j)) => {
          hour = v
          hour_is_12 = true
          vi = j
        }
        None => return err()
      }
      li += 1
    } else if lc[li] == '1' {
      match read_flex_digits(vc, vi) {
        Some((v, j)) => {
          month = v
          vi = j
        }
        None => return err()
      }
      li += 1
    } else if lc[li] == '2' {
      match read_flex_digits(vc, vi) {
        Some((v, j)) => {
          day = v
          vi = j
        }
        None => return err()
      }
      li += 1
    } else if lc[li] == '4' {
      match read_flex_digits(vc, vi) {
        Some((v, j)) => {
          minute = v
          vi = j
        }
        None => return err()
      }
      li += 1
    } else if lc[li] == '5' {
      match read_flex_digits(vc, vi) {
        Some((v, j)) => {
          second = v
          vi = j
        }
        None => return err()
      }
      li += 1
    } else if lc[li] == '.' &&
      li + 1 < ln &&
      (lc[li + 1] == '0' || lc[li + 1] == '9') {
      let is_trimmed = lc[li + 1] == '9'
      let mut lj = li + 1
      while lj < ln && (lc[lj] == '0' || lc[lj] == '9') {
        lj += 1
      }
      let max_digits = lj - li - 1
      // Consume the fractional seconds from the value if present.
      if vi < vn && vc[vi] == '.' {
        let (frac_str, end) = parse_digits_at(vc, vi + 1)
        let flen = frac_str.length()
        if flen > 0 {
          let frac_val = match parse_int64_str(frac_str) {
            Some(v) => v
            None => return err()
          }
          nsec = if flen >= 9 {
            (frac_val / pow10_int64(flen - 9)).to_int()
          } else {
            (frac_val * pow10_int64(9 - flen)).to_int()
          }
          vi = end
        } else if !is_trimmed {
          return err()
        }
      } else if !is_trimmed {
        return err()
      }
      let _ = max_digits
      li = lj
    } else {
      // Literal character: must match the value verbatim.
      if vi >= vn || vc[vi] != lc[li] {
        return err()
      }
      vi += 1
      li += 1
    }
  }
  if vi != vn {
    return err()
  }
  if hour_is_12 {
    match pm {
      Some(true) => if hour < 12 { hour += 12 }
      Some(false) => if hour == 12 { hour = 0 }
      None => ()
    }
  }
  Ok((year, month, day, hour, minute, second, nsec, tz_offset))
}

///|
let am_pm_upper : FixedArray[String] = ["AM", "PM"]

///|
let am_pm_lower : FixedArray[String] = ["am", "pm"]

///|
fn parse_time_has_tz_suffix(s : String) -> Bool {
  let n = s.length()
  if n == 0 {
    return false
  }
  let chars = s.to_array()
  let last = chars[n - 1]
  if last == 'Z' || last == 'z' {
    return true
  }
  // Look for +HH:MM or -HH:MM after YYYY-MM-DDTHH:MM:SS[.fff...]
  // Minimum base length without timezone: 19 (YYYY-MM-DDTHH:MM:SS)
  if n < 19 {
    return false
  }
  let mut i = 19
  // Skip fractional seconds
  if i < n && chars[i] == '.' {
    i += 1
    while i < n && chars[i] >= '0' && chars[i] <= '9' {
      i += 1
    }
  }
  i < n && (chars[i] == '+' || chars[i] == '-')
}

///|
fn pow10_int64(n : Int) -> Int64 {
  let mut result = 1L
  for _ in 0..<n {
    result = result * 10L
  }
  result
}

///|
/// Thread-local storage key for overriding the `time.now()` clock in tests.
/// Store a fixed `time.time` value via
/// `thread.set_local(now_override_key, time_value(sec, nsec))`; when unset,
/// `time.now()` reads the real system clock.
pub let now_override_key : String = "time.now"

///|
/// Creates a `time.time` Starlark value from a Unix second/nanosecond pair.
/// Primarily used to construct clock-override values for `now_override_key`.
///
/// Parameters:
///
/// * `sec` : Unix timestamp in whole seconds (seconds since the Unix epoch).
/// * `nsec` : Nanoseconds offset within the second (0..999_999_999).
///
/// Returns a `time.time` Starlark value representing the given instant.
pub fn time_value(sec : Int64, nsec : Int) -> @value.Value {
  make_time(sec, nsec)
}

///|
fn make_now_fn() -> @value.Value {
  @value.Value::new_builtin("now", fn(ctx, pos_args, kw_args) {
    if pos_args.length() != 0 || kw_args.length() != 0 {
      return Err("time.now: unexpected arguments")
    }
    match ctx.get_local(now_override_key) {
      Some(v) => Ok(v)
      None => {
        let (sec, nsec) = get_unix_time_now()
        Ok(make_time(sec, nsec))
      }
    }
  })
}

///|
fn make_from_timestamp_fn() -> @value.Value {
  @value.Value::new_builtin("from_timestamp", fn(_ctx, pos_args, kw_args) {
    if pos_args.length() < 1 {
      return Err("time.from_timestamp: missing required argument 'sec'")
    }
    if kw_args.length() != 0 {
      return Err("time.from_timestamp: unexpected keyword arguments")
    }
    let sec = match pos_args[0] {
      @value.Value::Int(n) => n.to_int64()
      _ => return Err("time.from_timestamp: sec must be an integer")
    }
    let nsec = if pos_args.length() >= 2 {
      match pos_args[1] {
        @value.Value::Int(n) => n.to_int()
        _ => return Err("time.from_timestamp: nsec must be an integer")
      }
    } else {
      0
    }
    Ok(make_time(sec, nsec))
  })
}

///|
fn make_parse_time_fn() -> @value.Value {
  @value.Value::new_builtin("parse_time", fn(_ctx, pos_args, kw_args) {
    if pos_args.length() < 1 {
      return Err("time.parse_time: missing required argument 'x'")
    }
    let x = match pos_args[0] {
      @value.Value::String(s) => s.raw()
      _ => return Err("time.parse_time: x must be a string")
    }
    let mut fmt = "2006-01-02T15:04:05Z07:00"
    let mut location = "UTC"
    for kw in kw_args {
      let (k, v) = kw
      match k {
        "format" =>
          match v {
            @value.Value::String(s) => fmt = s.raw()
            _ => return Err("time.parse_time: format must be a string")
          }
        "location" =>
          match v {
            @value.Value::String(s) => location = s.raw()
            _ => return Err("time.parse_time: location must be a string")
          }
        _ => return Err("time.parse_time: unexpected keyword argument \{k}")
      }
    }
    if pos_args.length() >= 2 {
      match pos_args[1] {
        @value.Value::String(s) => fmt = s.raw()
        _ => return Err("time.parse_time: format must be a string")
      }
    }
    if pos_args.length() >= 3 {
      match pos_args[2] {
        @value.Value::String(s) => location = s.raw()
        _ => return Err("time.parse_time: location must be a string")
      }
    }
    // The default layout is parsed by the lenient RFC3339 reader; any other
    // layout is parsed with the Go reference-time interpreter.
    // Both yield (parsed_sec, nsec, has_explicit_tz) where parsed_sec is the
    // wall-clock instant treated as UTC (already offset-adjusted when the
    // value carried an explicit zone).
    let (parsed_sec, nsec, has_tz) : (Int64, Int, Bool) = if fmt ==
      default_parse_time_layout {
      match parse_rfc3339(x) {
        Ok((sec, ns)) => (sec, ns, parse_time_has_tz_suffix(x))
        Err(e) => return Err(e)
      }
    } else {
      match parse_go_layout(x, fmt) {
        Err(e) => return Err(e)
        Ok((py, pmo, pd, ph, pmi, ps, pns, ptz)) => {
          let dt = @x_time.ZonedDateTime::of(
            py,
            pmo,
            pd,
            hour=ph,
            minute=pmi,
            second=ps,
            nanosecond=pns,
            zone=@x_time.utc_zone,
          ) catch {
            _ => return Err("time: invalid time \"\{x}\"")
          }
          let base = dt.to_unix_second()
          match ptz {
            Some(off) => (base - off.to_int64(), pns, true)
            None => (base, pns, false)
          }
        }
      }
    }
    if location == "UTC" || location == "" {
      Ok(make_time(parsed_sec, nsec))
    } else {
      if !is_valid_timezone_impl(location) {
        return Err("time.parse_time: unsupported timezone \"\{location}\"")
      }
      if has_tz {
        // Value carried an explicit timezone → parsed_sec is already UTC.
        Ok(make_time(parsed_sec, nsec))
      } else {
        // parsed_sec is "local time treated as UTC" → adjust for location.
        let offset = match get_tz_offset_at_impl(location, parsed_sec) {
          Some(o) => o
          None =>
            return Err(
              "time.parse_time: cannot determine offset for \"\{location}\"",
            )
        }
        let utc_sec = parsed_sec - offset.to_int64()
        let final_offset = match get_tz_offset_at_impl(location, utc_sec) {
          Some(o) => o
          None => offset
        }
        let final_sec = parsed_sec - final_offset.to_int64()
        Ok(make_time_at_zone(final_sec, nsec, final_offset, location))
      }
    }
  })
}

///|
let default_parse_time_layout : String = "2006-01-02T15:04:05Z07:00"

///|
fn make_parse_duration_fn() -> @value.Value {
  @value.Value::new_builtin("parse_duration", fn(_ctx, pos_args, kw_args) {
    if pos_args.length() != 1 || kw_args.length() != 0 {
      return Err("parse_duration: got \{pos_args.length()} arguments, want 1")
    }
    match pos_args[0] {
      @value.Value::ExtVal(_) as v =>
        match extract_duration_ns(v) {
          Some(_) => Ok(v)
          None =>
            Err(
              "parse_duration: for parameter 1: got \{@value.type_name(v)}, want a duration, string, or int",
            )
        }
      @value.Value::String(s) =>
        match parse_duration_str(s.raw()) {
          Ok(ns) => Ok(make_duration(ns))
          Err(e) => Err(e)
        }
      v =>
        Err(
          "parse_duration: for parameter 1: got \{@value.type_name(v)}, want a duration, string, or int",
        )
    }
  })
}

///|
fn make_time_constructor_fn() -> @value.Value {
  @value.Value::new_builtin("time", fn(_ctx, pos_args, kw_args) {
    if pos_args.length() > 0 {
      return Err("time: unexpected positional arguments")
    }
    let mut year = 0
    let mut month = 1
    let mut day = 1
    let mut hour = 0
    let mut minute = 0
    let mut second = 0
    let mut nanosecond = 0
    let mut location = "UTC"
    for kw in kw_args {
      let (k, v) = kw
      match k {
        "year" =>
          match v {
            @value.Value::Int(n) => year = n.to_int()
            _ => return Err("time.time: year must be an integer")
          }
        "month" =>
          match v {
            @value.Value::Int(n) => month = n.to_int()
            _ => return Err("time.time: month must be an integer")
          }
        "day" =>
          match v {
            @value.Value::Int(n) => day = n.to_int()
            _ => return Err("time.time: day must be an integer")
          }
        "hour" =>
          match v {
            @value.Value::Int(n) => hour = n.to_int()
            _ => return Err("time.time: hour must be an integer")
          }
        "minute" =>
          match v {
            @value.Value::Int(n) => minute = n.to_int()
            _ => return Err("time.time: minute must be an integer")
          }
        "second" =>
          match v {
            @value.Value::Int(n) => second = n.to_int()
            _ => return Err("time.time: second must be an integer")
          }
        "nanosecond" =>
          match v {
            @value.Value::Int(n) => nanosecond = n.to_int()
            _ => return Err("time.time: nanosecond must be an integer")
          }
        "location" =>
          match v {
            @value.Value::String(s) => location = s.raw()
            _ => return Err("time.time: location must be a string")
          }
        _ => return Err("time.time: unexpected keyword argument \{k}")
      }
    }
    if location == "UTC" || location == "" {
      let dt = @x_time.ZonedDateTime::of(
        year,
        month,
        day,
        hour~,
        minute~,
        second~,
        nanosecond~,
        zone=@x_time.utc_zone,
      ) catch {
        _ => return Err("time.time: invalid date/time parameters")
      }
      Ok(make_time(dt.to_unix_second(), nanosecond))
    } else {
      if !is_valid_timezone_impl(location) {
        return Err("time.time: unsupported timezone \"\{location}\"")
      }
      // Compute "local time as UTC" unix timestamp
      let dt_as_utc = @x_time.ZonedDateTime::of(
        year,
        month,
        day,
        hour~,
        minute~,
        second~,
        nanosecond~,
        zone=@x_time.utc_zone,
      ) catch {
        _ => return Err("time.time: invalid date/time parameters")
      }
      let local_sec = dt_as_utc.to_unix_second()
      // Get timezone offset at local_sec (as an estimate)
      let offset = match get_tz_offset_at_impl(location, local_sec) {
        Some(o) => o
        None =>
          return Err("time.time: cannot determine offset for \"\{location}\"")
      }
      // UTC = local_time - offset (since local = UTC + offset)
      let utc_sec = local_sec - offset.to_int64()
      // Re-check offset at the computed UTC time
      let final_offset = match get_tz_offset_at_impl(location, utc_sec) {
        Some(o) => o
        None => offset
      }
      let final_sec = local_sec - final_offset.to_int64()
      Ok(make_time_at_zone(final_sec, nanosecond, final_offset, location))
    }
  })
}

///|
fn make_is_valid_timezone_fn() -> @value.Value {
  @value.Value::new_builtin("is_valid_timezone", fn(_ctx, pos_args, kw_args) {
    if pos_args.length() != 1 || kw_args.length() != 0 {
      return Err(
        "time.is_valid_timezone: got \{pos_args.length()} arguments, want 1",
      )
    }
    let s = match pos_args[0] {
      @value.Value::String(s) => s.raw()
      _ => return Err("time.is_valid_timezone: argument must be a string")
    }
    Ok(@value.Value::Bool(is_valid_timezone_impl(s)))
  })
}

///|
/// Returns the `time` Starlark module value, providing `now`,
/// `from_timestamp`, `parse_time`, `parse_duration`, and the
/// `duration` constructor as attributes.
///
/// Returns the constructed `time` module as a `@value.Value::Module`.
pub fn time_module() -> @value.Value {
  let attrs : Map[String, @value.Value] = {}
  attrs["now"] = make_now_fn()
  attrs["from_timestamp"] = make_from_timestamp_fn()
  attrs["parse_time"] = make_parse_time_fn()
  attrs["parse_duration"] = make_parse_duration_fn()
  attrs["time"] = make_time_constructor_fn()
  attrs["is_valid_timezone"] = make_is_valid_timezone_fn()
  attrs["nanosecond"] = make_duration(1L)
  attrs["microsecond"] = make_duration(ns_per_microsecond)
  attrs["millisecond"] = make_duration(ns_per_millisecond)
  attrs["second"] = make_duration(ns_per_second)
  attrs["minute"] = make_duration(ns_per_minute)
  attrs["hour"] = make_duration(ns_per_hour)
  @value.Value::Module(@value.StarlarkModule::new("time", attrs))
}
