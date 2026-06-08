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

| Target | Source | Precision |
| :--- | :--- | :--- |
| `native` / `llvm` | OS clock via C FFI | Nanosecond |
| `js` | `Date.now()` | Millisecond |
| `wasm-gc` / `wasm` | Stub (returns epoch) | — |

## Starlark-level API (inside scripts)

`time.now()`, `time.from_timestamp(sec, nsec=0)`, `time.parse_time(x)`,
`time.parse_duration(x)`, `time.time(year=, month=, …)`, `time.is_valid_timezone(tz)`

Duration constants: `time.nanosecond`, `time.microsecond`, `time.millisecond`,
`time.second`, `time.minute`, `time.hour`

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

```moonbit nocheck
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
