# `lib/math` package

Floating-point math extension for Starlark. Import `connect0459/starlark/lib/math` and inject `math_module()` as a predeclared binding to expose math functions and constants under the `math` namespace in Starlark scripts.

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

| Function | Description |
| :--- | :--- |
| `math.ceil(x)` | Smallest integer ≥ x |
| `math.floor(x)` | Largest integer ≤ x |
| `math.round(x)` | Round to nearest integer, returns `float` |
| `math.fabs(x)` | Absolute value |
| `math.exp(x)` | `e ** x` |
| `math.sqrt(x)` | Square root |
| `math.log(x)` / `math.log(x, base)` | Natural log or log base `base` |
| `math.acos(x)` | Arc cosine |
| `math.asin(x)` | Arc sine |
| `math.atan(x)` | Arc tangent |
| `math.cos(x)` | Cosine |
| `math.sin(x)` | Sine |
| `math.tan(x)` | Tangent |
| `math.acosh(x)` | Inverse hyperbolic cosine |
| `math.asinh(x)` | Inverse hyperbolic sine |
| `math.atanh(x)` | Inverse hyperbolic tangent |
| `math.cosh(x)` | Hyperbolic cosine |
| `math.sinh(x)` | Hyperbolic sine |
| `math.tanh(x)` | Hyperbolic tangent |
| `math.degrees(x)` | Radians → degrees |
| `math.radians(x)` | Degrees → radians |
| `math.gamma(x)` | Gamma function |

### Binary functions

| Function | Description |
| :--- | :--- |
| `math.atan2(y, x)` | Arc tangent of y/x |
| `math.copysign(x, y)` | Magnitude of x with sign of y |
| `math.hypot(x, y)` | `sqrt(x**2 + y**2)` |
| `math.mod(x, y)` | Floating-point modulo |
| `math.pow(x, y)` | `x ** y` (float) |
| `math.remainder(x, y)` | IEEE 754 remainder |

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

```mbt nocheck
let thread = @eval.Thread::new("main")
let predeclared = @eval.Predeclared::from_map({ "math": @math.math_module() })
let _ = @eval.exec_file_with_predeclared(thread, "trig.star",
  "x = math.sqrt(2.0)", @eval.Options::default(), predeclared)
```
