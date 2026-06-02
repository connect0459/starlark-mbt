# `lib/math` package

Math extension providing floating-point functions. Inject `math_module()` as a predeclared
binding to expose functions under the `math` namespace in Starlark scripts.

```text
import {
  "connect0459/starlark/eval",
  "connect0459/starlark/value",
  "connect0459/starlark/lib/math",
}
```

## MoonBit-level API

| Function | Signature | Description |
| :--- | :--- | :--- |
| `math_module()` | `() -> @value.Value` | Returns the `math` module value to inject |

## Starlark-level constants and functions (inside scripts)

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
| `math.round(x)` | Round to nearest integer |
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

```mbt check
///|
test {
  let thread = @eval.Thread::new("main")
  let predeclared = @eval.Predeclared::from_map({ "math": @math.math_module() })
  match
    @eval.exec_file_with_predeclared(
      thread,
      "trig.star",
      "approx_pi = math.atan2(0.0, -1.0)",
      @eval.Options::default(),
      predeclared,
    ) {
    Ok(m) =>
      match m.get("approx_pi") {
        Some(@value.Value::Float(f)) => assert_true(f > 3.14 && f < 3.15)
        _ => fail("expected float")
      }
    Err(e) => fail(e.to_string())
  }
}
```
