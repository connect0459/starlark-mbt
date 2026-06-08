# `lib/math` package

Floating-point math extension for Starlark. Import `connect0459/starlark/lib/math`
and inject `math_module()` as a predeclared binding to expose math functions and
constants under the `math` namespace in Starlark scripts.

## MoonBit-level API

| Function | Signature | Description |
| :--- | :--- | :--- |
| `math_module()` | `() -> @value.Value` | Returns the `math` module value to inject |

## Starlark-level API (inside scripts)

### Constants

| Name | Value |
| :--- | :--- |
| `math.pi` | `3.141592653589793` |
| `math.e` | `2.718281828459045` |

### Unary functions

`math.ceil`, `math.floor`, `math.round`, `math.fabs`, `math.exp`, `math.sqrt`,
`math.log`, `math.acos`, `math.asin`, `math.atan`, `math.cos`, `math.sin`,
`math.tan`, `math.acosh`, `math.asinh`, `math.atanh`, `math.cosh`, `math.sinh`,
`math.tanh`, `math.degrees`, `math.radians`, `math.gamma`

### Binary functions

`math.atan2`, `math.copysign`, `math.hypot`, `math.mod`, `math.pow`, `math.remainder`

## Quick start

Obtaining the module value:

```mbt check
///|
test {
  let m = @math.math_module()
  assert_eq(m.type_name(), "module")
}
```

Injecting into Starlark scripts:

```moonbit nocheck
let thread = @eval.Thread::new("main")
let predeclared = @eval.Predeclared::from_map({ "math": @math.math_module() })
let _ = @eval.exec_file_with_predeclared(thread, "trig.star",
  "x = math.sqrt(2.0)", @eval.Options::default(), predeclared)
```
