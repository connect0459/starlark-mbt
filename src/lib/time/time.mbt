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
let u_ns_per_microsecond : UInt64 = 1_000UL

///|
let u_ns_per_millisecond : UInt64 = 1_000_000UL

///|
let u_ns_per_second : UInt64 = 1_000_000_000UL

///|
let u_ns_per_minute : UInt64 = 60_000_000_000UL

///|
let u_ns_per_hour : UInt64 = 3_600_000_000_000UL

///|
let secs_per_hour : Int = 3600

///|
let secs_per_minute : Int = 60

///|
let secs_per_day : Int64 = 86400L

///|
let int64_digits_cutoff : Int64 = 922337203685477580L

///|
let uint64_max : UInt64 = 18446744073709551615UL

///|
let uint64_digits_cutoff : UInt64 = 1844674407370955161UL

///|
let max_int64 : Int64 = 9223372036854775807L

///|
let min_int64 : Int64 = -9223372036854775808L

///|
/// Extracts the nanosecond count from a `time.duration` Starlark value.
///
/// Returns `None` if `v` is not a `time.duration` custom value or if the
/// internal `__ns` attribute is missing or has an unexpected type.
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
/// Extracts the Unix second and nanosecond components from a `time.time` value.
///
/// Returns `None` if `v` is not a `time.time` custom value or if required
/// internal attributes are missing or have unexpected types.
fn extract_time_parts(v : @value.Value) -> (Int64, Int)? {
  match extract_time_all(v) {
    Some((s, n, _, _)) => Some((s, n))
    None => None
  }
}

///|
/// Extracts all internal fields from a `time.time` Starlark value.
///
/// Returns `Some((sec, nsec, tz_offset, tz_name))` where:
///
/// - `sec` : Unix timestamp in whole seconds.
/// - `nsec` : Nanosecond offset within the second.
/// - `tz_offset` : Timezone offset in seconds east of UTC.
/// - `tz_name` : Display name for the timezone.
///
/// Returns `None` if `v` is not a `time.time` custom value or if any required
/// attribute is absent or has an unexpected type.
fn extract_time_all(v : @value.Value) -> (Int64, Int, Int, String)? {
  match v {
    @value.Value::ExtVal(c) =>
      if c.get_type_name() == "time.time" {
        match
          (
            c.get_attr("__sec"),
            c.get_attr("__nsec"),
            c.get_attr("__tz_offset"),
            c.get_attr("__tz_name"),
          ) {
          (
            Ok(Some(@value.Value::Int(s))),
            Ok(Some(@value.Value::Int(n))),
            Ok(Some(@value.Value::Int(off))),
            Ok(Some(@value.Value::String(name))),
          ) => Some((s.to_int64(), n.to_int(), off.to_int(), name.raw()))
          _ => None
        }
      } else {
        None
      }
    _ => None
  }
}

///|
/// Adjusts a (seconds, nanoseconds) pair so that `nsec` falls in `[0, 1e9)`.
///
/// When `raw_nsec` overflows or underflows the nanosecond range, the excess is
/// carried into `sec`.
fn normalize_time_parts(sec : Int64, raw_nsec : Int) -> (Int64, Int) {
  let nps = ns_per_second.to_int()
  if raw_nsec >= nps {
    (sec + 1L, raw_nsec - nps)
  } else if raw_nsec < 0 {
    (sec - 1L, raw_nsec + nps)
  } else {
    (sec, raw_nsec)
  }
}

///|
/// Computes the floor-division of `a` by `b` for signed 64-bit integers.
///
/// Unlike the built-in truncating division, when `b` is positive the result
/// is rounded toward negative infinity and the remainder `a - result * b`
/// is always non-negative. Behavior is unspecified for a negative divisor.
fn floor_div_int64(a : Int64, b : Int64) -> Int64 {
  let q = a / b
  let r = a - q * b
  if r < 0L {
    q - 1L
  } else {
    q
  }
}

///|
// Howard Hinnant's civil calendar algorithm (2014).

///|
/// Converts a Unix day number to a proleptic Gregorian (year, month, day) triple.
///
/// Parameters:
///
/// - `unix_day` : Days since the Unix epoch (1970-01-01 = 0); may be negative.
///
/// Returns `(year, month, day)` where `month` is in `1..=12` and `day` is
/// in `1..=31`.
fn unix_day_to_ymd_i64(unix_day : Int64) -> (Int64, Int, Int) {
  let z = unix_day + 719468L
  let era = floor_div_int64(z, 146097L)
  let doe = (z - era * 146097L).to_int()
  let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365
  let y = yoe.to_int64() + era * 400L
  let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
  let mp = (5 * doy + 2) / 153
  let d = doy - (153 * mp + 2) / 5 + 1
  let m = if mp < 10 { mp + 3 } else { mp - 9 }
  let year = if m <= 2 { y + 1L } else { y }
  (year, m, d)
}

///|
/// Converts a proleptic Gregorian (year, month, day) triple to a Unix day number.
///
/// Parameters:
///
/// - `year` : Proleptic Gregorian year (may be negative or zero).
/// - `month` : Month in `1..=12`.
/// - `day` : Day-of-month in `1..=31`.
///
/// Returns the number of days since the Unix epoch (1970-01-01 = 0).
fn ymd_to_unix_day_i64(year : Int64, month : Int, day : Int) -> Int64 {
  let y = if month <= 2 { year - 1L } else { year }
  let era = floor_div_int64(y, 400L)
  let yoe = (y - era * 400L).to_int()
  let doy = (153 * (if month > 2 { month - 3 } else { month + 9 }) + 2) / 5 +
    day -
    1
  let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
  era * 146097L + doe.to_int64() - 719468L
}

///|
/// Decomposes a Unix second and timezone offset into calendar fields.
///
/// Parameters:
///
/// - `sec` : Unix timestamp in whole seconds.
/// - `tz_offset` : Timezone offset in seconds east of UTC.
///
/// Returns `(year, month, day, hour, minute, second)` in the given timezone.
fn decompose_unix_sec(
  sec : Int64,
  tz_offset : Int,
) -> (Int64, Int, Int, Int, Int, Int) {
  let local_sec = sec + tz_offset.to_int64()
  let unix_to_abs = 9223372028741760000L
  let (unix_day, sec_of_day) = if local_sec >= -unix_to_abs {
    let d = floor_div_int64(local_sec, secs_per_day)
    (d, (local_sec - d * secs_per_day).to_int())
  } else {
    let c_rem = local_sec % secs_per_day
    let pow2_64_mod = 25216L
    let pow2_64_div = 213503982334601L
    let carry = if c_rem + pow2_64_mod < 0L { 1L } else { 0L }
    (
      local_sec / secs_per_day + pow2_64_div - carry,
      (c_rem + pow2_64_mod + carry * secs_per_day).to_int(),
    )
  }
  let (year, month, day) = unix_day_to_ymd_i64(unix_day)
  let hour = sec_of_day / secs_per_hour
  let minute = sec_of_day % secs_per_hour / secs_per_minute
  let second = sec_of_day % secs_per_minute
  (year, month, day, hour, minute, second)
}

///|
// Unix day 0 (1970-01-01) is Thursday = 4.
fn weekday_from_unix_day(unix_day : Int64) -> Int {
  ((unix_day % 7L + 4L + 7L) % 7L).to_int()
}

///|
fn is_leap_year(year : Int64) -> Bool {
  year % 4L == 0L && (year % 100L != 0L || year % 400L == 0L)
}

///|
fn days_in_month(year : Int64, month : Int) -> Int {
  match month {
    1 | 3 | 5 | 7 | 8 | 10 | 12 => 31
    4 | 6 | 9 | 11 => 30
    2 => if is_leap_year(year) { 29 } else { 28 }
    _ => 0
  }
}

///|
fn day_of_year(year : Int64, month : Int, day : Int) -> Int {
  let mut yday = day
  for m in 1..<month {
    yday += days_in_month(year, m)
  }
  yday
}

///|
fn yday_to_month_day(year : Int64, yday : Int) -> (Int, Int) {
  let mut remaining = yday
  let mut month = 1
  while month < 12 {
    let dim = days_in_month(year, month)
    if remaining <= dim {
      break
    }
    remaining -= dim
    month += 1
  }
  (month, remaining)
}

///|
fn write_year_pad4(buf : StringBuilder, year : Int64) -> Unit {
  if year < 0L {
    buf.write_char('-')
    let s = (0UL - year.reinterpret_as_uint64()).to_string()
    for _ in 0..<(4 - s.length()) {
      buf.write_char('0')
    }
    buf.write_string(s)
  } else {
    let s = year.to_string()
    for _ in 0..<(4 - s.length()) {
      buf.write_char('0')
    }
    buf.write_string(s)
  }
}

///|
/// Normalizes arbitrary calendar fields (including out-of-range values) to a
/// Unix (second, nanosecond) pair by carrying overflow between every unit.
///
/// Parameters:
///
/// - `year`, `month`, `day`, `hour`, `minute`, `second` : Calendar components;
///   any field may be outside its normal range and will be normalized.
/// - `nanosecond` : Nanosecond component; may be negative or exceed 1e9.
///
/// Returns `(unix_sec, normalized_nsec)` where `normalized_nsec` is in
/// `[0, 1_000_000_000)`.
fn normalize_to_unix_sec(
  year : Int64,
  month : Int64,
  day : Int64,
  hour : Int64,
  minute : Int64,
  second : Int64,
  nanosecond : Int64,
) -> (Int64, Int) {
  let carry_s = floor_div_int64(nanosecond, ns_per_second)
  let ns_norm = (nanosecond - carry_s * ns_per_second).to_int()
  let total_sec = hour * secs_per_hour.to_int64() +
    minute * secs_per_minute.to_int64() +
    second +
    carry_s
  let carry_d = floor_div_int64(total_sec, secs_per_day)
  let sec_of_day = total_sec - carry_d * secs_per_day
  let m0 = month - 1L
  let extra_years = floor_div_int64(m0, 12L)
  let month_norm = (m0 - extra_years * 12L + 1L).to_int()
  let year_norm_64 = year + extra_years
  let first_unix_day = ymd_to_unix_day_i64(year_norm_64, month_norm, 1)
  let unix_day = first_unix_day + (day - 1L) + carry_d
  let unix_sec = unix_day * secs_per_day + sec_of_day
  (unix_sec, ns_norm)
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
    _ => Err("unrecognized time.duration attribute \"\{name}\"")
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
          match extract_time_all(rhs) {
            Some((sec, nsec, tz_offset, tz_name)) => {
              let extra_sec = ns / ns_per_second
              let extra_nsec = (ns % ns_per_second).to_int()
              let (new_sec, new_nsec) = normalize_time_parts(
                sec + extra_sec,
                nsec + extra_nsec,
              )
              Some(Ok(make_time_at_zone(new_sec, new_nsec, tz_offset, tz_name)))
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
            } else if i.compare_int64(max_int64) > 0 ||
              i.compare_int64(min_int64) < 0 {
              Some(Err("int value out of range (want signed 64-bit value)"))
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
        @value.Value::Int(i) =>
          if i.compare_int64(max_int64) > 0 || i.compare_int64(min_int64) < 0 {
            Some(Err("int value out of range (want signed 64-bit value)"))
          } else {
            Some(Ok(make_duration(ns * i.to_int64())))
          }
        _ => None
      }
    _ => None
  }
}

///|
fn fmt_frac_digits(frac : Int64, prec : Int) -> String {
  let s = frac.to_string()
  let pad_len = prec - s.length()
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
/// Formats a duration given in nanoseconds as a human-readable string.
///
/// Selects the largest unit (`ns`, `µs`, `ms`, or `s`) for which the
/// magnitude is at least one whole unit, expressing any sub-unit remainder as
/// a decimal fraction (with optional `h`/`m` prefix for durations of one
/// second or more). Negative durations are prefixed with `-`. Zero is always
/// `"0s"`.
///
/// Parameters:
///
/// - `ns` : Duration in nanoseconds (may be negative).
fn fmt_duration(ns : Int64) -> String {
  if ns == 0L {
    return "0s"
  }
  let u_secs_per_hour : UInt64 = 3600UL
  let u_secs_per_minute : UInt64 = 60UL
  let buf = StringBuilder::new()
  let abs_ns : UInt64 = if ns < 0L {
    0UL - ns.reinterpret_as_uint64()
  } else {
    ns.reinterpret_as_uint64()
  }
  if ns < 0L {
    buf.write_char('-')
  }
  if abs_ns < u_ns_per_second {
    if abs_ns < u_ns_per_microsecond {
      buf.write_string(abs_ns.to_string())
      buf.write_string("ns")
    } else if abs_ns < u_ns_per_millisecond {
      let us = abs_ns / u_ns_per_microsecond
      let frac_ns = abs_ns % u_ns_per_microsecond
      buf.write_string(us.to_string())
      if frac_ns != 0UL {
        buf.write_char('.')
        buf.write_string(fmt_frac_digits(frac_ns.reinterpret_as_int64(), 3))
      }
      buf.write_string("µs")
    } else {
      let ms = abs_ns / u_ns_per_millisecond
      let frac_ns = abs_ns % u_ns_per_millisecond
      buf.write_string(ms.to_string())
      if frac_ns != 0UL {
        buf.write_char('.')
        buf.write_string(fmt_frac_digits(frac_ns.reinterpret_as_int64(), 6))
      }
      buf.write_string("ms")
    }
  } else {
    let total_sec = abs_ns / u_ns_per_second
    let ns_frac = abs_ns % u_ns_per_second
    let hours = total_sec / u_secs_per_hour
    let minutes = total_sec % u_secs_per_hour / u_secs_per_minute
    let secs = total_sec % u_secs_per_minute
    if hours > 0UL {
      buf.write_string(hours.to_string())
      buf.write_char('h')
      buf.write_string(minutes.to_string())
      buf.write_char('m')
    } else if minutes > 0UL {
      buf.write_string(minutes.to_string())
      buf.write_char('m')
    }
    if ns_frac == 0UL {
      buf.write_string(secs.to_string())
      buf.write_char('s')
    } else {
      buf.write_string(secs.to_string())
      buf.write_char('.')
      buf.write_string(fmt_frac_digits(ns_frac.reinterpret_as_int64(), 9))
      buf.write_char('s')
    }
  }
  buf.to_string()
}

///|
/// Creates a `time.duration` Starlark value from a nanosecond count.
///
/// Parameters:
///
/// - `ns` : Duration magnitude in nanoseconds; may be negative.
fn make_duration(ns : Int64) -> @value.Value {
  @value.Value::ExtVal(
    @value.CustomValue::new(fn() { "time.duration" }, fn() { ns != 0L }, fn() {
      fmt_duration(ns)
    })
    .with_hash(fn() { duration_hash(ns) })
    .with_equals(fn(other, _depth) { Ok(duration_equals(ns, other)) })
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
    if result > int64_digits_cutoff {
      return None
    }
    result = result * 10L + (c.to_int() - '0'.to_int()).to_int64()
    if result < 0L {
      return None
    }
  }
  Some(result)
}

///|
fn parse_uint64_str(s : String) -> UInt64? {
  if s.is_empty() {
    return None
  }
  let chars = s.to_array()
  let mut result = 0UL
  for c in chars {
    if c < '0' || c > '9' {
      return None
    }
    if result > uint64_digits_cutoff {
      return None
    }
    let digit = (c.to_int() - '0'.to_int()).to_uint64()
    if result == uint64_digits_cutoff && digit > 5UL {
      return None
    }
    result = result * 10UL + digit
  }
  Some(result)
}

///|
fn parse_duration_number_u64(
  num_str : String,
  scale : UInt64,
  orig : String,
) -> Result[UInt64, String] {
  match num_str.find(".") {
    None =>
      match parse_uint64_str(num_str) {
        Some(n) => {
          if n != 0UL && scale > uint64_max / n {
            return Err("time: invalid duration \"\{orig}\"")
          }
          Ok(n * scale)
        }
        None => Err("time: invalid duration \"\{orig}\"")
      }
    Some(dot_pos) => {
      let int_part = num_str[0:dot_pos].to_owned()
      let frac_part = num_str[dot_pos + 1:].to_owned()
      let int_val = if int_part.is_empty() {
        0UL
      } else {
        match parse_uint64_str(int_part) {
          Some(n) => n
          None => return Err("time: invalid duration \"\{orig}\"")
        }
      }
      if int_val != 0UL && scale > uint64_max / int_val {
        return Err("time: invalid duration \"\{orig}\"")
      }
      let int_ns = int_val * scale
      let frac_ns = if frac_part.is_empty() {
        0UL
      } else {
        let chars = frac_part.to_array()
        let mut frac_val = 0UL
        let mut frac_scale = scale
        for c in chars {
          if c < '0' || c > '9' {
            return Err("time: invalid duration \"\{orig}\"")
          }
          frac_scale = frac_scale / 10UL
          if frac_scale > 0UL {
            frac_val = frac_val +
              (c.to_int() - '0'.to_int()).to_uint64() * frac_scale
          }
        }
        frac_val
      }
      if int_ns > uint64_max - frac_ns {
        return Err("time: invalid duration \"\{orig}\"")
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
/// Parses a Go-style duration string (e.g. `"1h30m"`, `"2.5s"`, `"-300ms"`)
/// into a nanosecond count.
///
/// Parameters:
///
/// - `s` : Duration string to parse; must consist of one or more
///   number-unit pairs where the unit is one of `ns`, `us`/`µs`/`μs`,
///   `ms`, `s`, `m`, or `h`. The special values `"0"`, `"+0"`, and `"-0"`
///   are also accepted.
///
/// Returns `Ok(nanoseconds)` on success, or `Err(message)` describing the
/// first parse failure.
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
  let mut total_ns : UInt64 = 0UL
  while !rest.is_empty() {
    match parse_duration_component(rest, orig) {
      Err(e) => return Err(e)
      Ok((num_str, unit_str, remaining)) => {
        let scale : UInt64 = match unit_str {
          "ns" => 1UL
          "us" | "µs" | "μs" => u_ns_per_microsecond
          "ms" => u_ns_per_millisecond
          "s" => u_ns_per_second
          "m" => u_ns_per_minute
          "h" => u_ns_per_hour
          _ =>
            return Err(
              "time: unknown unit \"\{unit_str}\" in duration \"\{orig}\"",
            )
        }
        match parse_duration_number_u64(num_str, scale, orig) {
          Err(e) => return Err(e)
          Ok(ns_val) => {
            if total_ns > uint64_max - ns_val {
              return Err("time: invalid duration \"\{orig}\"")
            }
            total_ns = total_ns + ns_val
            rest = remaining
          }
        }
      }
    }
  }
  let max_magnitude : UInt64 = 9223372036854775808UL
  if total_ns > max_magnitude {
    return Err("time: invalid duration \"\{orig}\"")
  }
  if neg {
    Ok((0UL - total_ns).reinterpret_as_int64())
  } else {
    if total_ns > max_magnitude - 1UL {
      return Err("time: invalid duration \"\{orig}\"")
    }
    Ok(total_ns.reinterpret_as_int64())
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
fn write_tz_offset(
  buf : StringBuilder,
  tz_offset : Int,
  colon? : Bool = false,
) -> Unit {
  let abs_off = if tz_offset < 0 { -tz_offset } else { tz_offset }
  if tz_offset >= 0 {
    buf.write_char('+')
  } else {
    buf.write_char('-')
  }
  write_pad2(buf, abs_off / secs_per_hour)
  if colon {
    buf.write_char(':')
  }
  write_pad2(buf, abs_off % secs_per_hour / secs_per_minute)
}

///|
fn write_tz_offset_hour_only(buf : StringBuilder, tz_offset : Int) -> Unit {
  let abs_off = if tz_offset < 0 { -tz_offset } else { tz_offset }
  if tz_offset >= 0 {
    buf.write_char('+')
  } else {
    buf.write_char('-')
  }
  write_pad2(buf, abs_off / secs_per_hour)
}

///|
fn fmt_time_at_zone(
  sec : Int64,
  nsec : Int,
  tz_offset : Int,
  tz_name : String,
) -> String {
  let (year, month, day, hour, minute, second) = decompose_unix_sec(
    sec, tz_offset,
  )
  let buf = StringBuilder::new()
  write_year_pad4(buf, year)
  buf.write_char('-')
  write_pad2(buf, month)
  buf.write_char('-')
  write_pad2(buf, day)
  buf.write_char(' ')
  write_pad2(buf, hour)
  buf.write_char(':')
  write_pad2(buf, minute)
  buf.write_char(':')
  write_pad2(buf, second)
  if nsec != 0 {
    buf.write_char('.')
    buf.write_string(fmt_frac_digits(nsec.to_int64(), 9))
  }
  buf.write_char(' ')
  if tz_offset >= 0 {
    buf.write_char('+')
    write_pad2(buf, tz_offset / secs_per_hour)
    write_pad2(buf, tz_offset % secs_per_hour / secs_per_minute)
  } else {
    let abs = -tz_offset
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
fn weekday_index(year : Int64, month : Int, day : Int) -> Int {
  weekday_from_unix_day(ymd_to_unix_day_i64(year, month, day))
}

///|
fn fmt_nsec_frac(nsec : Int, digits : Int, trimmed : Bool) -> String {
  let s = nsec.to_string()
  let padded = StringBuilder::new()
  let pad_len = 9 - s.length()
  for _ in 0..<pad_len {
    padded.write_char('0')
  }
  padded.write_string(s)
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

///|
/// Formats calendar fields using a Go reference-time layout string.
///
/// Parameters:
///
/// - `year`, `month`, `day` : Gregorian date components in the target timezone.
/// - `hour24` : Hour of day in 24-hour notation (0–23).
/// - `minute`, `second` : Minute and second within the hour/minute.
/// - `nsec` : Nanoseconds within the second (0–999_999_999).
/// - `tz_offset` : Timezone offset in seconds east of UTC.
/// - `tz_name` : Display name for the timezone (used for the `MST` verb).
/// - `layout` : Go reference-time layout string.
///
/// Returns the formatted time string.
fn fmt_go_layout(
  year : Int64,
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
      write_year_pad4(buf, year)
      i += 4
    } else if c == '0' &&
      i + 2 < n &&
      lchars[i + 1] == '0' &&
      lchars[i + 2] == '2' {
      let yday = day_of_year(year, month, day)
      if yday < 100 {
        buf.write_char('0')
      }
      if yday < 10 {
        buf.write_char('0')
      }
      buf.write_string(yday.to_string())
      i += 3
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
        let y2 = year % 100L
        if y2 < 0L {
          buf.write_char('-')
          write_pad2(buf, (-y2).to_int())
        } else {
          write_pad2(buf, y2.to_int())
        }
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
    } else if c == '_' && i + 1 < n && lchars[i + 1] == '2' {
      if day < 10 {
        buf.write_char(' ')
      }
      buf.write_string(day.to_string())
      i += 2
    } else if c == '1' {
      buf.write_string(month.to_string())
      i += 1
    } else if c == '2' {
      buf.write_string(day.to_string())
      i += 1
    } else if (c == '.' || c == ',') &&
      i + 1 < n &&
      (lchars[i + 1] == '9' || lchars[i + 1] == '0') {
      let is_trimmed = lchars[i + 1] == '9'
      let mut j = i + 1
      while j < n && (lchars[j] == '9' || lchars[j] == '0') {
        j += 1
      }
      let frac_digits = j - i - 1
      if nsec != 0 || !is_trimmed {
        buf.write_char(c)
        buf.write_string(fmt_nsec_frac(nsec, frac_digits, is_trimmed))
      }
      i = j
    } else if c == '-' &&
      i + 5 < n &&
      lchars[i + 1] == '0' &&
      lchars[i + 2] == '7' &&
      lchars[i + 3] == ':' &&
      lchars[i + 4] == '0' &&
      lchars[i + 5] == '0' {
      write_tz_offset(buf, tz_offset, colon=true)
      i += 6
    } else if c == 'Z' &&
      i + 5 < n &&
      lchars[i + 1] == '0' &&
      lchars[i + 2] == '7' &&
      lchars[i + 3] == ':' &&
      lchars[i + 4] == '0' &&
      lchars[i + 5] == '0' {
      if tz_offset == 0 {
        buf.write_char('Z')
      } else {
        write_tz_offset(buf, tz_offset, colon=true)
      }
      i += 6
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
    } else if c == '-' &&
      i + 2 < n &&
      lchars[i + 1] == '0' &&
      lchars[i + 2] == '7' {
      write_tz_offset_hour_only(buf, tz_offset)
      i += 3
    } else if c == 'Z' &&
      i + 2 < n &&
      lchars[i + 1] == '0' &&
      lchars[i + 2] == '7' {
      if tz_offset == 0 {
        buf.write_char('Z')
      } else {
        write_tz_offset_hour_only(buf, tz_offset)
      }
      i += 3
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
/// Returns the truth value of a `time.time` instant.
///
/// A `time.time` is falsy when it equals Go's zero `Time` (January 1, year 1,
/// 00:00:00 UTC, which corresponds to Unix second -62135596800), and truthy
/// for every other instant.
fn time_truth(sec : Int64, nsec : Int) -> Bool {
  // Go's zero Time is January 1, year 1, 00:00:00.000000000 UTC = unix second -62135596800.
  !(sec == -62135596800L && nsec == 0)
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
    "__tz_offset" => Ok(Some(@value.Value::Int(BigInt::from_int(tz_offset))))
    "__tz_name" =>
      Ok(Some(@value.Value::String(@value.StarlarkString::new(tz_name))))
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
      let (year, month, day, hour, minute, second) = decompose_unix_sec(
        sec, tz_offset,
      )
      let v = match name {
        "year" => @value.Value::Int(BigInt::from_int64(year))
        "month" => @value.Value::Int(BigInt::from_int(month))
        "day" => @value.Value::Int(BigInt::from_int(day))
        "hour" => @value.Value::Int(BigInt::from_int(hour))
        "minute" => @value.Value::Int(BigInt::from_int(minute))
        "second" => @value.Value::Int(BigInt::from_int(second))
        "nanosecond" => @value.Value::Int(BigInt::from_int(nsec))
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
  tz_offset : Int,
  tz_name : String,
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
          let extra_sec = dns / ns_per_second
          let extra_nsec = (dns % ns_per_second).to_int()
          let (new_sec, new_nsec) = normalize_time_parts(
            sec + extra_sec,
            nsec + extra_nsec,
          )
          Some(Ok(make_time_at_zone(new_sec, new_nsec, tz_offset, tz_name)))
        }
        None => None
      }
    "-" =>
      match extract_duration_ns(rhs) {
        Some(dns) => {
          let extra_sec = dns / ns_per_second
          let extra_nsec = (dns % ns_per_second).to_int()
          let (new_sec, new_nsec) = normalize_time_parts(
            sec - extra_sec,
            nsec - extra_nsec,
          )
          Some(Ok(make_time_at_zone(new_sec, new_nsec, tz_offset, tz_name)))
        }
        None =>
          match extract_time_parts(rhs) {
            Some((other_sec, other_nsec)) => {
              let d_ns = (sec - other_sec) * ns_per_second +
                (nsec.to_int64() - other_nsec.to_int64())
              let d_sec = d_ns / ns_per_second
              let d_nsec_part = (d_ns % ns_per_second).to_int()
              let (check_sec, check_nsec) = normalize_time_parts(
                other_sec + d_sec,
                other_nsec + d_nsec_part,
              )
              let result_ns = if check_sec == sec && check_nsec == nsec {
                d_ns
              } else if sec < other_sec ||
                (sec == other_sec && nsec < other_nsec) {
                min_int64
              } else {
                max_int64
              }
              Some(Ok(make_duration(result_ns)))
            }
            None => None
          }
      }
    _ => None
  }
}

///|
/// Creates a `time.time` Starlark value pinned to an explicit timezone.
///
/// Parameters:
///
/// - `sec` : Unix timestamp in whole seconds.
/// - `nsec` : Nanosecond offset within the second (0–999_999_999).
/// - `tz_offset` : Timezone offset in seconds east of UTC.
/// - `tz_name` : Display name for the timezone (e.g. `"UTC"`, `"+09:00"`).
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
    .with_equals(fn(other, _depth) { Ok(time_equals(sec, nsec, other)) })
    .with_compare(fn(other) { time_compare(sec, nsec, other) })
    .with_binary(fn(op, rhs, is_left) {
      time_binary(sec, nsec, tz_offset, tz_name, op, rhs, is_left)
    })
    .with_attrs(fn(name) { time_attr(sec, nsec, tz_offset, tz_name, name) }, fn() {
      time_attr_names()
    }),
  )
}

///|
/// Creates a UTC `time.time` Starlark value from a Unix second/nanosecond pair.
///
/// Parameters:
///
/// - `sec` : Unix timestamp in whole seconds.
/// - `nsec` : Nanosecond offset within the second (0–999_999_999).
fn make_time(sec : Int64, nsec : Int) -> @value.Value {
  make_time_at_zone(sec, nsec, 0, "UTC")
}

///|
fn make_in_location_method(sec : Int64, nsec : Int) -> @value.Value {
  @value.Value::new_builtin("in_location", fn(_ctx, pos_args, kw_args) {
    if kw_args.length() != 0 {
      return Err("in_location: unexpected keyword arguments")
    }
    if pos_args.length() != 1 {
      return Err("in_location: got \{pos_args.length()} arguments, want 1")
    }
    let loc = match pos_args[0] {
      @value.Value::String(s) => s.raw()
      v =>
        return Err(
          "in_location: for parameter 1: got \{v.type_name()}, want string",
        )
    }
    if !is_valid_timezone(loc) {
      return Err("unknown time zone \{loc}")
    }
    let (offset, abbr) = match get_tz_abbr_at(loc, sec) {
      Some(v) => v
      None => return Err("in_location: cannot determine offset for \"\{loc}\"")
    }
    Ok(make_time_at_zone(sec, nsec, offset, abbr))
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
    if kw_args.length() != 0 {
      return Err("format: unexpected keyword arguments")
    }
    if pos_args.length() != 1 {
      return Err("format: got \{pos_args.length()} arguments, want 1")
    }
    let layout = match pos_args[0] {
      @value.Value::String(s) => s.raw()
      v =>
        return Err("format: for parameter 1: got \{v.type_name()}, want string")
    }
    let (year, month, day, hour, minute, second) = decompose_unix_sec(
      sec, tz_offset,
    )
    let result = fmt_go_layout(
      year, month, day, hour, minute, second, nsec, tz_offset, tz_name, layout,
    )
    Ok(@value.Value::String(@value.StarlarkString::new(result)))
  })
}

///|
fn hex_lower_digit(n : Int) -> Char {
  if n < 10 {
    ('0'.to_int() + n).unsafe_to_char()
  } else {
    ('a'.to_int() + n - 10).unsafe_to_char()
  }
}

///|
fn write_hex_escape(buf : StringBuilder, b : Int) -> Unit {
  buf.write_char('\\')
  buf.write_char('x')
  buf.write_char(hex_lower_digit(b >> 4))
  buf.write_char(hex_lower_digit(b & 0xF))
}

///|
fn time_quote(s : String) -> String {
  let buf = StringBuilder::new()
  buf.write_char('"')
  for c in s {
    let cp = c.to_int()
    if cp == '"'.to_int() {
      buf.write_string("\\\"")
    } else if cp == '\\'.to_int() {
      buf.write_string("\\\\")
    } else if cp >= 32 && cp <= 127 {
      buf.write_char(c)
    } else if cp < 0x80 {
      write_hex_escape(buf, cp)
    } else if cp < 0x800 {
      write_hex_escape(buf, 0xC0 | (cp >> 6))
      write_hex_escape(buf, 0x80 | (cp & 0x3F))
    } else if cp < 0x10000 {
      write_hex_escape(buf, 0xE0 | (cp >> 12))
      write_hex_escape(buf, 0x80 | ((cp >> 6) & 0x3F))
      write_hex_escape(buf, 0x80 | (cp & 0x3F))
    } else {
      write_hex_escape(buf, 0xF0 | (cp >> 18))
      write_hex_escape(buf, 0x80 | ((cp >> 12) & 0x3F))
      write_hex_escape(buf, 0x80 | ((cp >> 6) & 0x3F))
      write_hex_escape(buf, 0x80 | (cp & 0x3F))
    }
  }
  buf.write_char('"')
  buf.to_string()
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
fn tz_name_from_offset(offset_sec : Int) -> String {
  if offset_sec == 0 {
    "UTC"
  } else {
    let buf = StringBuilder::new()
    write_tz_offset(buf, offset_sec)
    buf.to_string()
  }
}

///|
/// Parses an RFC 3339 timestamp string into its components.
///
/// Parameters:
///
/// - `s` : RFC 3339 timestamp string (e.g. `"2006-01-02T15:04:05Z"` or
///   `"2006-01-02T15:04:05.999999999+09:00"`).
///
/// Returns `Ok((unix_sec, nsec, tz_offset_sec, zone_name))` where `unix_sec`
/// is already adjusted to UTC, or `Err(message)` on any parse failure.
fn parse_rfc3339(s : String) -> Result[(Int64, Int, Int, String), String] {
  let chars = s.to_array()
  let len = chars.length()
  let rfc_layout = "2006-01-02T15:04:05Z07:00"
  fn cp_err(pos : Int, tok : String) -> String {
    let buf = StringBuilder::new()
    for k in pos..<chars.length() {
      buf.write_char(chars[k])
    }
    "parsing time \"\{s}\" as \"\{rfc_layout}\": cannot parse \"\{buf.to_string()}\" as \"\{tok}\""
  }

  if len < 10 {
    return Err(cp_err(0, "2006"))
  }
  let (year_i, _) = parse_digits_at(chars, 0)
  let year = match parse_int64_str(year_i) {
    Some(y) => y.to_int()
    None => return Err(cp_err(0, "2006"))
  }
  let year_end = year_i.length()
  if year_end != 4 {
    return Err(cp_err(0, "2006"))
  }
  if chars[year_end] != '-' {
    return Err(cp_err(year_end, "-"))
  }
  let i = year_end + 1
  let month_pos = i
  let (month, i) = match parse_2digits(chars, month_pos) {
    Some(v) => v
    None => return Err(cp_err(month_pos, "01"))
  }
  if month < 1 || month > 12 {
    return Err("parsing time \"\{s}\": month out of range")
  }
  if i >= len || chars[i] != '-' {
    return Err(cp_err(i, "-"))
  }
  let i = i + 1
  let day_pos = i
  let (day, i) = match parse_2digits(chars, day_pos) {
    Some(v) => v
    None => return Err(cp_err(day_pos, "02"))
  }
  if day < 1 || day > days_in_month(year.to_int64(), month) {
    return Err("parsing time \"\{s}\": day out of range")
  }
  if i >= len || chars[i] != 'T' {
    return Err(cp_err(i, "T"))
  }
  let i = i + 1
  let hour_pos = i
  let (hour, i) = match parse_2digits(chars, hour_pos) {
    Some(v) => v
    None => return Err(cp_err(hour_pos, "15"))
  }
  if hour > 23 {
    return Err("parsing time \"\{s}\": hour out of range")
  }
  if i >= len || chars[i] != ':' {
    return Err(cp_err(i, ":"))
  }
  let i = i + 1
  let minute_pos = i
  let (minute, i) = match parse_2digits(chars, minute_pos) {
    Some(v) => v
    None => return Err(cp_err(minute_pos, "04"))
  }
  if minute > 59 {
    return Err("parsing time \"\{s}\": minute out of range")
  }
  if i >= len || chars[i] != ':' {
    return Err(cp_err(i, ":"))
  }
  let i = i + 1
  let second_pos = i
  let (second, i) = match parse_2digits(chars, second_pos) {
    Some(v) => v
    None => return Err(cp_err(second_pos, "05"))
  }
  if second > 59 {
    return Err("parsing time \"\{s}\": second out of range")
  }
  let (nsec, i) = if i < len && chars[i] == '.' {
    let j = i + 1
    let (frac_str, end) = parse_digits_at(chars, j)
    let frac_len = frac_str.length()
    if frac_len == 0 {
      return Err(cp_err(i, ".999999999"))
    }
    let frac_val = match parse_int64_str(frac_str) {
      Some(v) => v
      None => return Err(cp_err(i, ".999999999"))
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
  let (tz_offset_sec, tz_end, zone_name) = if i < len && chars[i] == 'Z' {
    (0, i + 1, "UTC")
  } else if i < len && (chars[i] == '+' || chars[i] == '-') {
    let sign = if chars[i] == '+' { 1 } else { -1 }
    let j = i + 1
    let (tz_hour, j) = match parse_2digits(chars, j) {
      Some(v) => v
      None => return Err(cp_err(j, "07"))
    }
    if tz_hour > 23 {
      return Err("parsing time \"\{s}\": time zone offset hour out of range")
    }
    if j >= len || chars[j] != ':' {
      return Err(cp_err(j, ":"))
    }
    let j = j + 1
    let (tz_minute, j) = match parse_2digits(chars, j) {
      Some(v) => v
      None => return Err(cp_err(j, "00"))
    }
    if tz_minute > 59 {
      return Err("parsing time \"\{s}\": time zone offset minute out of range")
    }
    let offset = sign * (tz_hour * secs_per_hour + tz_minute * secs_per_minute)
    let name_buf = StringBuilder::new()
    write_tz_offset(name_buf, offset)
    (offset, j, name_buf.to_string())
  } else {
    return Err(cp_err(i, "Z07:00"))
  }
  if tz_end != len {
    let buf = StringBuilder::new()
    for k in tz_end..<chars.length() {
      buf.write_char(chars[k])
    }
    return Err(
      "parsing time \{time_quote(s)}: extra text: \{time_quote(buf.to_string())}",
    )
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
    _ => return Err("parsing time \"\{s}\" as \"\{rfc_layout}\": cannot parse")
  }
  let unix_sec = dt.to_unix_second() - tz_offset_sec.to_int64()
  Ok((unix_sec, nsec, tz_offset_sec, zone_name))
}

///|
// Read exactly `n` digits at `chars[i]`, returning the value and next index.

///|
/// Reads exactly `n` decimal digits starting at index `i` in `chars`.
///
/// Parameters:
///
/// - `chars` : Character array to read from.
/// - `i` : Starting index.
/// - `n` : Exact number of digits to consume.
///
/// Returns `Some((value, next_index))` on success, or `None` if fewer than
/// `n` digits are available or a non-digit character is encountered.
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

///|
/// Reads one or two decimal digits starting at index `i` in `chars`.
///
/// Consumes two digits when both are present and numeric; otherwise consumes
/// exactly one digit.
///
/// Parameters:
///
/// - `chars` : Character array to read from.
/// - `i` : Starting index.
///
/// Returns `Some((value, next_index))`, or `None` if no digit is present at `i`.
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
fn ascii_lower(c : Char) -> Char {
  if c >= 'A' && c <= 'Z' {
    (c.to_int() + 32).unsafe_to_char()
  } else {
    c
  }
}

///|
// Match one of `names[start..start+count]` as a prefix of `chars` at `i`.
// Returns the matched index and the next value position.

///|
/// Matches one name from `names[start..start+count]` as a prefix of `chars`
/// starting at index `i`.
///
/// Parameters:
///
/// - `chars` : Character array to match against.
/// - `i` : Starting position within `chars`.
/// - `names` : Array of candidate names.
/// - `start` : First index in `names` to consider.
/// - `count` : Number of names to try.
///
/// Returns `Some((matched_index, next_position))` for the first name that
/// matches exactly, or `None` if no candidate matches.
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
// Case-insensitive variant of match_name: compares each character after
// lowercasing so that e.g. "JANUARY" matches "January".

///|
/// Case-insensitive variant of `match_name`.
///
/// Matches one name from `names[start..start+count]` as a prefix of `chars`
/// at index `i`, comparing each character after ASCII-lowercasing both sides.
///
/// Parameters:
///
/// - `chars` : Character array to match against.
/// - `i` : Starting position within `chars`.
/// - `names` : Array of candidate names.
/// - `start` : First index in `names` to consider.
/// - `count` : Number of names to try.
///
/// Returns `Some((matched_index, next_position))` for the first name that
/// matches case-insensitively, or `None` if no candidate matches.
fn match_name_ci(
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
        if ascii_lower(chars[i + k]) != ascii_lower(nchars[k]) {
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

///|
/// Parses a time string against a Go reference-time layout.
///
/// Mirrors the token set that `fmt_go_layout` produces. When the value
/// contains an explicit timezone indicator (`Z`, `±hh:mm`, etc.) the returned
/// `tz_offset` tuple is `Some((offset_sec, name))`; otherwise it is `None`.
///
/// Parameters:
///
/// - `value` : The time string to parse.
/// - `layout` : Go reference-time layout string.
///
/// Returns `Ok((year, month, day, hour, minute, second, nsec, tz_offset))` on
/// success, or `Err(message)` describing the first mismatch.
fn parse_go_layout(
  value : String,
  layout : String,
) -> Result[(Int, Int, Int, Int, Int, Int, Int, (Int, String)?), String] {
  let lc = layout.to_array()
  let vc = value.to_array()
  let ln = lc.length()
  let vn = vc.length()
  let mut li = 0
  let mut vi = 0
  let mut year = 0
  let mut month = 1
  let mut day = 1
  let mut hour = 0
  let mut minute = 0
  let mut second = 0
  let mut nsec = 0
  let mut parsed_tz : (Int, String)? = None
  let mut pm : Bool? = None
  let mut yday = -1
  let err = fn(
    tok : String,
  ) -> Result[(Int, Int, Int, Int, Int, Int, Int, (Int, String)?), String] {
    let buf = StringBuilder::new()
    for k in vi..<vn {
      buf.write_char(vc[k])
    }
    Err(
      "parsing time \"\{value}\" as \"\{layout}\": cannot parse \"\{buf.to_string()}\" as \"\{tok}\"",
    )
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
      parsed_tz = Some((0, "UTC"))
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
            let offset = sign * (hh * secs_per_hour + mm * secs_per_minute)
            let name_buf = StringBuilder::new()
            write_tz_offset(name_buf, offset)
            parsed_tz = Some((offset, name_buf.to_string()))
            vi = k
            true
          }
        }
      }
    }
  }

  // Parse a numeric/sign timezone of the form ±hh (hour offset only);
  // `allow_z` accepts a literal `Z` meaning offset 0.
  fn parse_zone_hour_only(allow_z : Bool) -> Bool {
    if allow_z && vi < vn && (vc[vi] == 'Z' || vc[vi] == 'z') {
      parsed_tz = Some((0, "UTC"))
      vi += 1
      return true
    }
    if vi >= vn || (vc[vi] != '+' && vc[vi] != '-') {
      return false
    }
    let sign = if vc[vi] == '+' { 1 } else { -1 }
    match read_fixed_digits(vc, vi + 1, 2) {
      None => false
      Some((hh, j)) => {
        if hh > 23 {
          return false
        }
        let offset = sign * hh * secs_per_hour
        let name_buf = StringBuilder::new()
        write_tz_offset(name_buf, offset)
        parsed_tz = Some((offset, name_buf.to_string()))
        vi = j
        true
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
        None => return err("2006")
      }
      li += 4
    } else if starts("06") {
      match read_fixed_digits(vc, vi, 2) {
        Some((v, j)) => {
          year = if v >= 69 { 1900 + v } else { 2000 + v }
          vi = j
        }
        None => return err("06")
      }
      li += 2
    } else if starts("January") {
      match match_name_ci(vc, vi, month_full_names, 1, 12) {
        Some((idx, j)) => {
          month = idx
          vi = j
        }
        None => return err("January")
      }
      li += 7
    } else if starts("Jan") {
      match match_name_ci(vc, vi, month_abbrev_names, 1, 12) {
        Some((idx, j)) => {
          month = idx
          vi = j
        }
        None => return err("Jan")
      }
      li += 3
    } else if starts("Monday") {
      match match_name_ci(vc, vi, weekday_full_names, 0, 7) {
        Some((_, j)) => vi = j
        None => return err("Monday")
      }
      li += 6
    } else if starts("Mon") {
      match match_name_ci(vc, vi, weekday_abbrev_names, 0, 7) {
        Some((_, j)) => vi = j
        None => return err("Mon")
      }
      li += 3
    } else if starts("01") {
      match read_fixed_digits(vc, vi, 2) {
        Some((v, j)) => {
          month = v
          vi = j
        }
        None => return err("01")
      }
      li += 2
    } else if starts("002") {
      match read_fixed_digits(vc, vi, 3) {
        Some((v, j)) => {
          yday = v
          vi = j
        }
        None => return err("002")
      }
      li += 3
    } else if starts("02") {
      match read_fixed_digits(vc, vi, 2) {
        Some((v, j)) => {
          day = v
          vi = j
        }
        None => return err("02")
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
        None => return err("_2")
      }
      li += 2
    } else if starts("15") {
      match read_fixed_digits(vc, vi, 2) {
        Some((v, j)) => {
          hour = v
          vi = j
        }
        None => return err("15")
      }
      li += 2
    } else if starts("03") {
      match read_fixed_digits(vc, vi, 2) {
        Some((v, j)) => {
          hour = v
          vi = j
        }
        None => return err("03")
      }
      li += 2
    } else if starts("04") {
      match read_fixed_digits(vc, vi, 2) {
        Some((v, j)) => {
          minute = v
          vi = j
        }
        None => return err("04")
      }
      li += 2
    } else if starts("05") {
      match read_fixed_digits(vc, vi, 2) {
        Some((v, j)) => {
          second = v
          vi = j
        }
        None => return err("05")
      }
      li += 2
    } else if starts("PM") {
      match match_name(vc, vi, am_pm_upper, 0, 2) {
        Some((idx, j)) => {
          pm = Some(idx == 1)
          vi = j
        }
        None => return err("PM")
      }
      li += 2
    } else if starts("pm") {
      match match_name(vc, vi, am_pm_lower, 0, 2) {
        Some((idx, j)) => {
          pm = Some(idx == 1)
          vi = j
        }
        None => return err("pm")
      }
      li += 2
    } else if starts("Z07:00") {
      if !parse_zone(true, true) {
        return err("Z07:00")
      }
      li += 6
    } else if starts("Z0700") {
      if !parse_zone(false, true) {
        return err("Z0700")
      }
      li += 5
    } else if starts("-07:00") {
      if !parse_zone(true, false) {
        return err("-07:00")
      }
      li += 6
    } else if starts("-0700") {
      if !parse_zone(false, false) {
        return err("-0700")
      }
      li += 5
    } else if starts("Z07") {
      if !parse_zone_hour_only(true) {
        return err("Z07")
      }
      li += 3
    } else if starts("-07") {
      if !parse_zone_hour_only(false) {
        return err("-07")
      }
      li += 3
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
          vi = j
        }
        None => return err("3")
      }
      li += 1
    } else if lc[li] == '1' {
      match read_flex_digits(vc, vi) {
        Some((v, j)) => {
          month = v
          vi = j
        }
        None => return err("1")
      }
      li += 1
    } else if lc[li] == '2' {
      match read_flex_digits(vc, vi) {
        Some((v, j)) => {
          day = v
          vi = j
        }
        None => return err("2")
      }
      li += 1
    } else if lc[li] == '4' {
      match read_flex_digits(vc, vi) {
        Some((v, j)) => {
          minute = v
          vi = j
        }
        None => return err("4")
      }
      li += 1
    } else if lc[li] == '5' {
      match read_flex_digits(vc, vi) {
        Some((v, j)) => {
          second = v
          vi = j
        }
        None => return err("5")
      }
      li += 1
    } else if (lc[li] == '.' || lc[li] == ',') &&
      li + 1 < ln &&
      (lc[li + 1] == '0' || lc[li + 1] == '9') {
      let is_trimmed = lc[li + 1] == '9'
      let mut lj = li + 1
      while lj < ln && (lc[lj] == '0' || lc[lj] == '9') {
        lj += 1
      }
      let max_digits = lj - li - 1
      let frac_tok = {
        let b = StringBuilder::new()
        for k in li..<lj {
          b.write_char(lc[k])
        }
        b.to_string()
      }
      if vi < vn && (vc[vi] == '.' || vc[vi] == ',') {
        let (frac_str, end) = parse_digits_at(vc, vi + 1)
        let flen = frac_str.length()
        if flen > 0 {
          let frac_val = match parse_int64_str(frac_str) {
            Some(v) => v
            None => return err(frac_tok)
          }
          nsec = if flen >= 9 {
            (frac_val / pow10_int64(flen - 9)).to_int()
          } else {
            (frac_val * pow10_int64(9 - flen)).to_int()
          }
          vi = end
        } else if !is_trimmed {
          return err(frac_tok)
        }
      } else if !is_trimmed {
        return err(frac_tok)
      }
      let _ = max_digits
      li = lj
    } else {
      // Literal character: must match the value verbatim.
      if vi >= vn || vc[vi] != lc[li] {
        return err("\{lc[li]}")
      }
      vi += 1
      li += 1
    }
  }
  if vi != vn {
    let buf = StringBuilder::new()
    for k in vi..<vn {
      buf.write_char(vc[k])
    }
    return Err(
      "parsing time \{time_quote(value)}: extra text: \{time_quote(buf.to_string())}",
    )
  }
  if yday >= 0 {
    let max_yday = if is_leap_year(year.to_int64()) { 366 } else { 365 }
    if yday < 1 || yday > max_yday {
      return err("002")
    }
    let (m, d) = yday_to_month_day(year.to_int64(), yday)
    month = m
    day = d
  }
  match pm {
    Some(true) => if hour < 12 { hour += 12 }
    Some(false) => if hour == 12 { hour = 0 }
    None => ()
  }
  Ok((year, month, day, hour, minute, second, nsec, parsed_tz))
}

///|
let am_pm_upper : FixedArray[String] = ["AM", "PM"]

///|
let am_pm_lower : FixedArray[String] = ["am", "pm"]

///|
/// Returns `true` when the string `s` contains an explicit timezone suffix.
///
/// Recognises a trailing `Z`/`z`, or a `+`/`-` sign that immediately follows
/// the date-time base (after any optional fractional seconds) in an RFC
/// 3339-shaped string.  Used to distinguish "the value carried an explicit
/// zone" from "use the requested location as the default zone".
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
/// - `sec` : Unix timestamp in whole seconds (seconds since the Unix epoch).
/// - `nsec` : Nanoseconds offset within the second (0..999_999_999).
///
/// Returns a `time.time` Starlark value representing the given instant.
///
/// ```mbt check
/// test {
///   // The Unix epoch: 1970-01-01 00:00:00 UTC.
///   let v = time_value(0L, 0)
///   inspect(@value.Value::type_name(v), content="time.time")
/// }
/// ```
pub fn time_value(sec : Int64, nsec : Int) -> @value.Value {
  make_time(sec, nsec)
}

///|
fn make_now_fn() -> @value.Value {
  @value.Value::new_builtin("now", fn(ctx, pos_args, kw_args) {
    if kw_args.length() != 0 {
      return Err("now: unexpected keyword arguments")
    }
    if pos_args.length() != 0 {
      return Err("now: got \{pos_args.length()} arguments, want 0")
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
    if kw_args.length() != 0 {
      return Err("from_timestamp: unexpected keyword arguments")
    }
    if pos_args.length() < 1 {
      return Err("from_timestamp: got 0 arguments, want at least 1")
    }
    if pos_args.length() > 2 {
      return Err(
        "from_timestamp: got \{pos_args.length()} arguments, want at most 2",
      )
    }
    let sec = match pos_args[0] {
      @value.Value::Int(n) =>
        if n.compare_int64(max_int64) > 0 || n.compare_int64(min_int64) < 0 {
          return Err(
            "from_timestamp: for parameter 1: \{n.to_string()} out of range (want value in signed 64-bit range)",
          )
        } else {
          n.to_int64()
        }
      v =>
        return Err(
          "from_timestamp: for parameter 1: got \{v.type_name()}, want int",
        )
    }
    let nsec64 = if pos_args.length() >= 2 {
      match pos_args[1] {
        @value.Value::Int(n) =>
          if n.compare_int64(max_int64) > 0 || n.compare_int64(min_int64) < 0 {
            return Err(
              "from_timestamp: for parameter 2: \{n.to_string()} out of range (want value in signed 64-bit range)",
            )
          } else {
            n.to_int64()
          }
        v =>
          return Err(
            "from_timestamp: for parameter 2: got \{v.type_name()}, want int",
          )
      }
    } else {
      0L
    }
    let extra_sec = nsec64 / ns_per_second
    let norm_nsec = nsec64 % ns_per_second
    let (final_sec, final_nsec) = if norm_nsec < 0L {
      (sec + extra_sec - 1L, (norm_nsec + ns_per_second).to_int())
    } else {
      (sec + extra_sec, norm_nsec.to_int())
    }
    let (local_offset, local_abbr) = match get_local_tz_at(final_sec) {
      Some(v) => v
      None => (0, "UTC")
    }
    Ok(make_time_at_zone(final_sec, final_nsec, local_offset, local_abbr))
  })
}

///|
fn make_parse_time_fn() -> @value.Value {
  @value.Value::new_builtin("parse_time", fn(_ctx, pos_args, kw_args) {
    for kw in kw_args {
      let (k, _) = kw
      match k {
        "format" | "location" => ()
        _ => {
          let hint = @utf8util.spell_hint(k, ["format", "location"])
          return Err("parse_time: unexpected keyword argument \"\{k}\"\{hint}")
        }
      }
    }
    if pos_args.length() < 1 {
      return Err("parse_time: missing argument for x")
    }
    if pos_args.length() > 3 {
      return Err(
        "parse_time: got \{pos_args.length()} arguments, want at most 3",
      )
    }
    let x = match pos_args[0] {
      @value.Value::String(s) => s.raw()
      v =>
        return Err(
          "parse_time: for parameter x: got \{v.type_name()}, want string",
        )
    }
    let mut fmt = "2006-01-02T15:04:05Z07:00"
    let mut location = "UTC"
    for kw in kw_args {
      let (k, v) = kw
      match k {
        "format" =>
          match v {
            @value.Value::String(s) => fmt = s.raw()
            v =>
              return Err(
                "parse_time: for parameter \"format\": got \{v.type_name()}, want string",
              )
          }
        "location" =>
          match v {
            @value.Value::String(s) => location = s.raw()
            v =>
              return Err(
                "parse_time: for parameter \"location\": got \{v.type_name()}, want string",
              )
          }
        _ => {
          let hint = @utf8util.spell_hint(k, ["format", "location"])
          return Err("parse_time: unexpected keyword argument \"\{k}\"\{hint}")
        }
      }
    }
    if pos_args.length() >= 2 {
      match pos_args[1] {
        @value.Value::String(s) => fmt = s.raw()
        v =>
          return Err(
            "parse_time: for parameter format: got \{v.type_name()}, want string",
          )
      }
    }
    if pos_args.length() >= 3 {
      match pos_args[2] {
        @value.Value::String(s) => location = s.raw()
        v =>
          return Err(
            "parse_time: for parameter location: got \{v.type_name()}, want string",
          )
      }
    }
    // The default layout is parsed by the strict RFC3339 reader; any other
    // layout is parsed with the Go reference-time interpreter.
    // Both yield (parsed_sec, nsec, has_explicit_tz, tz_offset_sec, zone_name)
    // where parsed_sec is the UTC instant (already offset-adjusted when the
    // value carried an explicit zone), tz_offset_sec is the explicit zone offset
    // in seconds (0 for UTC or when no zone was present), and zone_name is the
    // display name for the zone ("UTC" for Z, "+0000" for numeric zero offset).
    let (parsed_sec, nsec, has_tz, tz_off, tz_name) : (
      Int64,
      Int,
      Bool,
      Int,
      String,
    ) = if fmt == default_parse_time_layout {
      match parse_rfc3339(x) {
        Ok((sec, ns, tz, zone_name)) =>
          (sec, ns, parse_time_has_tz_suffix(x), tz, zone_name)
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
            _ => return Err("parsing time \"\{x}\" as \"\{fmt}\": cannot parse")
          }
          let base = dt.to_unix_second()
          match ptz {
            Some((off, zone_name)) =>
              (base - off.to_int64(), pns, true, off, zone_name)
            None => (base, pns, false, 0, "UTC")
          }
        }
      }
    }
    if location == "UTC" || location == "" {
      Ok(make_time_at_zone(parsed_sec, nsec, tz_off, tz_name))
    } else {
      if !is_valid_timezone(location) {
        return Err("unknown time zone \{location}")
      }
      if has_tz {
        // Value carried an explicit timezone → parsed_sec is already UTC.
        Ok(make_time_at_zone(parsed_sec, nsec, tz_off, tz_name))
      } else {
        // parsed_sec is "local time treated as UTC" → adjust for location.
        let (offset, _) = match get_tz_abbr_at(location, parsed_sec) {
          Some(v) => v
          None =>
            return Err(
              "time.parse_time: cannot determine offset for \"\{location}\"",
            )
        }
        let utc_sec = parsed_sec - offset.to_int64()
        let (final_offset, final_abbr) = match
          get_tz_abbr_at(location, utc_sec) {
          Some(v) => v
          None => (offset, tz_name_from_offset(offset))
        }
        let final_sec = parsed_sec - final_offset.to_int64()
        Ok(make_time_at_zone(final_sec, nsec, final_offset, final_abbr))
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
              "parse_duration: for parameter 1: got \{v.type_name()}, want a duration, string, or int",
            )
        }
      @value.Value::String(s) =>
        match parse_duration_str(s.raw()) {
          Ok(ns) => Ok(make_duration(ns))
          Err(e) => Err("parse_duration: for parameter 1: \{e}")
        }
      v =>
        Err(
          "parse_duration: for parameter 1: got \{v.type_name()}, want a duration, string, or int",
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
    let mut year = 0L
    let mut month = 0L
    let mut day = 0L
    let mut hour = 0L
    let mut minute = 0L
    let mut second = 0L
    let mut nanosecond = 0L
    let mut location = "UTC"
    for kw in kw_args {
      let (k, v) = kw
      match k {
        "year" =>
          match v {
            @value.Value::Int(n) =>
              if n.compare_int64(max_int64) > 0 ||
                n.compare_int64(min_int64) < 0 {
                return Err(
                  "time: for parameter \"year\": \{n.to_string()} out of range (want value in signed 64-bit range)",
                )
              } else {
                year = n.to_int64()
              }
            v =>
              return Err(
                "time: for parameter \"year\": got \{v.type_name()}, want int",
              )
          }
        "month" =>
          match v {
            @value.Value::Int(n) =>
              if n.compare_int64(max_int64) > 0 ||
                n.compare_int64(min_int64) < 0 {
                return Err(
                  "time: for parameter \"month\": \{n.to_string()} out of range (want value in signed 64-bit range)",
                )
              } else {
                month = n.to_int64()
              }
            v =>
              return Err(
                "time: for parameter \"month\": got \{v.type_name()}, want int",
              )
          }
        "day" =>
          match v {
            @value.Value::Int(n) =>
              if n.compare_int64(max_int64) > 0 ||
                n.compare_int64(min_int64) < 0 {
                return Err(
                  "time: for parameter \"day\": \{n.to_string()} out of range (want value in signed 64-bit range)",
                )
              } else {
                day = n.to_int64()
              }
            v =>
              return Err(
                "time: for parameter \"day\": got \{v.type_name()}, want int",
              )
          }
        "hour" =>
          match v {
            @value.Value::Int(n) =>
              if n.compare_int64(max_int64) > 0 ||
                n.compare_int64(min_int64) < 0 {
                return Err(
                  "time: for parameter \"hour\": \{n.to_string()} out of range (want value in signed 64-bit range)",
                )
              } else {
                hour = n.to_int64()
              }
            v =>
              return Err(
                "time: for parameter \"hour\": got \{v.type_name()}, want int",
              )
          }
        "minute" =>
          match v {
            @value.Value::Int(n) =>
              if n.compare_int64(max_int64) > 0 ||
                n.compare_int64(min_int64) < 0 {
                return Err(
                  "time: for parameter \"minute\": \{n.to_string()} out of range (want value in signed 64-bit range)",
                )
              } else {
                minute = n.to_int64()
              }
            v =>
              return Err(
                "time: for parameter \"minute\": got \{v.type_name()}, want int",
              )
          }
        "second" =>
          match v {
            @value.Value::Int(n) =>
              if n.compare_int64(max_int64) > 0 ||
                n.compare_int64(min_int64) < 0 {
                return Err(
                  "time: for parameter \"second\": \{n.to_string()} out of range (want value in signed 64-bit range)",
                )
              } else {
                second = n.to_int64()
              }
            v =>
              return Err(
                "time: for parameter \"second\": got \{v.type_name()}, want int",
              )
          }
        "nanosecond" =>
          match v {
            @value.Value::Int(n) =>
              if n.compare_int64(max_int64) > 0 ||
                n.compare_int64(min_int64) < 0 {
                return Err(
                  "time: for parameter \"nanosecond\": \{n.to_string()} out of range (want value in signed 64-bit range)",
                )
              } else {
                nanosecond = n.to_int64()
              }
            v =>
              return Err(
                "time: for parameter \"nanosecond\": got \{v.type_name()}, want int",
              )
          }
        "location" =>
          match v {
            @value.Value::String(s) => location = s.raw()
            v =>
              return Err(
                "time: for parameter \"location\": got \{v.type_name()}, want string",
              )
          }
        _ => {
          let hint = @utf8util.spell_hint(k, [
            "year", "month", "day", "hour", "minute", "second", "nanosecond", "location",
          ])
          return Err("time: unexpected keyword argument \"\{k}\"\{hint}")
        }
      }
    }
    if location == "UTC" || location == "" {
      let (unix_sec, ns_norm) = normalize_to_unix_sec(
        year, month, day, hour, minute, second, nanosecond,
      )
      Ok(make_time(unix_sec, ns_norm))
    } else {
      if !is_valid_timezone(location) {
        return Err("unknown time zone \{location}")
      }
      let (local_sec, ns_norm) = normalize_to_unix_sec(
        year, month, day, hour, minute, second, nanosecond,
      )
      let (offset, _) = match get_tz_abbr_at(location, local_sec) {
        Some(v) => v
        None =>
          return Err("time.time: cannot determine offset for \"\{location}\"")
      }
      let utc_sec = local_sec - offset.to_int64()
      let (final_offset, final_abbr) = match get_tz_abbr_at(location, utc_sec) {
        Some(v) => v
        None => (offset, tz_name_from_offset(offset))
      }
      let final_sec = local_sec - final_offset.to_int64()
      Ok(make_time_at_zone(final_sec, ns_norm, final_offset, final_abbr))
    }
  })
}

///|
fn make_is_valid_timezone_fn() -> @value.Value {
  @value.Value::new_builtin("is_valid_timezone", fn(_ctx, pos_args, kw_args) {
    if kw_args.length() != 0 {
      return Err("is_valid_timezone: unexpected keyword arguments")
    }
    if pos_args.length() != 1 {
      return Err(
        "is_valid_timezone: got \{pos_args.length()} arguments, want 1",
      )
    }
    let s = match pos_args[0] {
      @value.Value::String(s) => s.raw()
      v =>
        return Err(
          "is_valid_timezone: for parameter 1: got \{v.type_name()}, want string",
        )
    }
    Ok(@value.Value::Bool(is_valid_timezone(s)))
  })
}

///|
/// Returns the `time` Starlark module value, providing `now`,
/// `from_timestamp`, `parse_time`, `parse_duration`, and the
/// `duration` constructor as attributes.
///
/// Returns the constructed `time` module as a `@value.Value::Module`.
///
/// ```mbt check
/// test {
///   let m = time_module()
///   guard m is @value.Value::Module(mod) else { fail("expected module") }
///   inspect(mod.name(), content="time")
///   // Parsing functions are present.
///   inspect(mod.attr_names().contains("parse_time"), content="true")
///   inspect(mod.attr_names().contains("parse_duration"), content="true")
///   // Duration constants are pre-built attributes.
///   inspect(mod.attr_names().contains("second"), content="true")
///   inspect(mod.attr_names().contains("hour"), content="true")
///   // Duration values carry the "time.duration" type name.
///   guard mod.get("second") is Some(sec) else { fail("second not found") }
///   inspect(@value.Value::type_name(sec), content="time.duration")
/// }
/// ```
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
