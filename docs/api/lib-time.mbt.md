# `lib/time` package

Time and duration types analogous to `starlark-go/lib/starlarktime`. Inject
`time_module()` as a predeclared binding to expose the `time` namespace.

```moonbit nocheck
import {
  "connect0459/starlark/eval",
  "connect0459/starlark/value",
  "connect0459/starlark/lib/time",
}
```

## MoonBit-level API

| Symbol | Signature | Description |
| :--- | :--- | :--- |
| `time_module()` | `() -> @value.Value` | Returns the `time` module value to inject |
| `time_value(sec, nsec)` | `(Int64, Int) -> @value.Value` | Create a `time.time` value from Unix seconds + nanoseconds |
| `now_override_key` | `String` | Thread-local key for overriding `time.now()` in tests |
| `get_unix_time_now()` | `() -> (Int64, Int)` | Read the real system clock (seconds, nanoseconds) |

## Starlark-level API (inside scripts)

### Module-level functions and constants

| Name | Description |
| :--- | :--- |
| `time.now()` | Current time as `time.time`; overridable via `now_override_key` |
| `time.from_timestamp(sec, nsec=0)` | Construct a `time.time` from Unix timestamp |
| `time.parse_time(x, format=…, location=…)` | Parse an RFC 3339 (or Go layout) string |
| `time.parse_duration(x)` | Parse a duration string (`"1h30m"`, `"500ms"`, etc.) |
| `time.time(year=, month=, …, location=)` | Construct a `time.time` from date/time components |
| `time.is_valid_timezone(tz)` | Test whether a timezone string is supported |
| `time.nanosecond` … `time.hour` | Duration constants |

### `time.time` attributes

| Attribute | Type | Description |
| :--- | :--- | :--- |
| `t.unix` | `int` | Unix timestamp in whole seconds |
| `t.unix_nano` | `int` | Unix timestamp in nanoseconds |
| `t.year` / `.month` / `.day` | `int` | Calendar fields in the time's timezone |
| `t.hour` / `.minute` / `.second` / `.nanosecond` | `int` | Time-of-day fields |
| `t.in_location(tz)` | `time.time` | Re-express the time in the given timezone |
| `t.format(layout)` | `string` | Format using a Go reference-time layout string |

### `time.duration` attributes and arithmetic

| Expression | Type | Description |
| :--- | :--- | :--- |
| `d.hours` / `.minutes` / `.seconds` | `float` | Duration as fractional units |
| `d.milliseconds` / `.microseconds` / `.nanoseconds` | `int` | Duration in integer units |
| `d1 + d2` | `time.duration` | Add durations |
| `d - d2` | `time.duration` | Subtract durations |
| `d * n` | `time.duration` | Scale by integer |
| `d / n` | `time.duration` | Divide by integer or float |
| `d // d2` | `int` | Integer floor-division of two durations |

```mbt check
///|
test {
  let predeclared = @eval.Predeclared::from_map({ "time": @time.time_module() })
  let thread = @eval.Thread::new("main")
  // Fix the clock so the test is deterministic.
  thread.set_local(@time.now_override_key, @time.time_value(1_000_000L, 0))
  let src =
    #|t = time.now()
    #|stamp = t.unix
    #|d = time.parse_duration("1h30m")
    #|total_ns = d.nanoseconds
  match
    @eval.exec_file_with_predeclared(
      thread,
      "t.star",
      src,
      @eval.Options::default(),
      predeclared,
    ) {
    Ok(m) => {
      assert_true(m.get("stamp") is Some(@value.Value::Int(1_000_000N)))
      // 1.5 hours = 5_400_000_000_000 nanoseconds
      assert_true(
        m.get("total_ns") is Some(@value.Value::Int(5_400_000_000_000N)),
      )
    }
    Err(e) => fail(e.to_string())
  }
}
```
