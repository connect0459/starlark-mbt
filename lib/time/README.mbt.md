# `lib/time` package

Time and duration types for Starlark (analogous to `starlark-go/lib/starlarktime`).
Import `connect0459/starlark/lib/time` and inject `time_module()` as a predeclared
binding to expose the `time` namespace in Starlark scripts.

## MoonBit-level API

| Symbol | Signature | Description |
| :--- | :--- | :--- |
| `time_module()` | `() -> @value.Value` | Returns the `time` module value to inject |
| `time_value(sec, nsec)` | `(Int64, Int) -> @value.Value` | Create a `time.time` value from Unix seconds + nanoseconds |
| `now_override_key` | `String` | Thread-local key for overriding `time.now()` in tests |
| `get_unix_time_now()` | `() -> (Int64, Int)` | Read the system clock (availability depends on build target) |

### Per-backend clock availability

| Target | Source | Precision | Notes |
| :--- | :--- | :--- | :--- |
| `native` / `llvm` | OS clock via C FFI | Nanosecond | Full real-time access |
| `js` | `Date.now()` | Millisecond | Nanosecond field derived from ms remainder |
| `wasm-gc` | Stub | — | `extern "js"` not supported for this target |
| `wasm` | Stub | — | Real-time requires WASI or a custom host import |

When the stub is active, `time.now()` always returns the Unix epoch. Override via
`now_override_key` in thread-local storage for deterministic tests.

## Starlark-level API (inside scripts)

### Module-level functions and constants

| Name | Description |
| :--- | :--- |
| `time.now()` | Current time as `time.time`; overridable via `now_override_key` |
| `time.from_timestamp(sec, nsec=0)` | Construct a `time.time` from a Unix timestamp |
| `time.parse_time(x, format=…, location=…)` | Parse an RFC 3339 (or Go layout) string |
| `time.parse_duration(x)` | Parse a duration string (`"1h30m"`, `"500ms"`, etc.) |
| `time.time(year=, month=, …, location=)` | Construct a `time.time` from date/time components |
| `time.is_valid_timezone(tz)` | Test whether a timezone string is supported |
| `time.nanosecond` … `time.hour` | Duration constants (nanosecond, microsecond, millisecond, second, minute, hour) |

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

`time + duration`, `time - duration`, and `duration + time` preserve the
operand's fixed UTC offset and abbreviation. The unix instant is computed
correctly, but the zone is transferred as-is: no DST recalculation is
performed. For named-location times obtained via `t.in_location("America/New_York")`,
adding a duration that crosses a DST boundary will keep the pre-addition
offset rather than re-deriving the correct post-addition offset, which
differs from Go's `Time.Add`. Fixed-offset times (e.g., `+05:30`) are
fully correct.

Note: `duration - time` raises `unsupported binary op`. The Starlark spec does not
define this operation; starlark-go silently computes `time - duration` instead, which
is a dialect difference.

## RFC 3339 parsing behavior

The default `parse_time` format follows RFC 3339 with one intentional extension
beyond the strict layout:

| Input form | Example | Behavior |
| :--- | :--- | :--- |
| Hour value 24 | `"2021-03-23T24:00:00Z"` | accepted, treated as midnight of next day |
| Lowercase `t` separator | `"2021-03-22t23:20:50Z"` | rejected (go parity) |
| Space separator | `"2021-03-22 23:20:50Z"` | rejected (go parity) |

Trailing text after the timezone is rejected:
`"2021-03-22T23:20:50Zgarbage"` → error `"... extra text: garbage"`.

## Quick start

Creating a fixed time value from MoonBit (useful for deterministic tests):

```mbt check
///|
test {
  let t = @time.time_value(1_000_000L, 0)
  assert_eq(t.type_name(), "time.time")
}
```

Injecting into Starlark scripts with a fixed clock for determinism:

```mbt nocheck
let predeclared = @eval.Predeclared::from_map({ "time": @time.time_module() })
let thread = @eval.Thread::new("main")
// Override the clock so the test is deterministic.
thread.set_local(@time.now_override_key, @time.time_value(1_000_000L, 0))
let src =
  #|t = time.now()
  #|stamp = t.unix
let _ = @eval.exec_file_with_predeclared(thread, "t.star", src,
  @eval.Options::default(), predeclared)
```
