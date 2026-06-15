///|
pub const PI : Double = 3.141592653589793

///|
/// Returns the smallest integer value greater than or equal to x.
pub fn ceil(x : Double) -> Double {
  @math.ceil(x)
}

///|
/// Returns the largest integer value less than or equal to x.
pub fn floor(x : Double) -> Double {
  @math.floor(x)
}

///|
/// Returns the nearest integer to x, rounding half away from zero.
pub fn round(x : Double) -> Double {
  @math.round(x)
}

///|
/// Returns the integer part of x, truncating toward zero.
pub fn trunc(x : Double) -> Double {
  @math.trunc(x)
}

///|
/// Returns e raised to the power x.
pub fn exp(x : Double) -> Double {
  @math.exp(x)
}

///|
/// Returns x raised to the power y.
pub fn pow(x : Double, y : Double) -> Double {
  @math.pow(x, y)
}

///|
/// Returns the natural logarithm of x.
pub fn ln(x : Double) -> Double {
  @math.ln(x)
}

///|
/// Returns the sine of x (in radians).
pub fn sin(x : Double) -> Double {
  @math.sin(x)
}

///|
/// Returns the cosine of x (in radians).
pub fn cos(x : Double) -> Double {
  @math.cos(x)
}

///|
/// Returns the tangent of x (in radians).
pub fn tan(x : Double) -> Double {
  @math.tan(x)
}

///|
/// Returns the arc sine of x in radians.
pub fn asin(x : Double) -> Double {
  @math.asin(x)
}

///|
/// Returns the arc cosine of x in radians.
pub fn acos(x : Double) -> Double {
  @math.acos(x)
}

///|
/// Returns the arc tangent of x in radians.
pub fn atan(x : Double) -> Double {
  @math.atan(x)
}

///|
/// Returns the arc tangent of y/x using the signs to determine the quadrant.
pub fn atan2(y : Double, x : Double) -> Double {
  @math.atan2(y, x)
}

///|
/// Returns the hyperbolic sine of x.
pub fn sinh(x : Double) -> Double {
  @math.sinh(x)
}

///|
/// Returns the hyperbolic cosine of x.
pub fn cosh(x : Double) -> Double {
  let abs_x = x.abs()
  // Small x: @math.cosh is correct.
  if abs_x < 22.0 {
    return @math.cosh(x)
  }
  let t = @math.exp(abs_x)
  // Very large x: exp overflows, but cosh stays finite up to |x| ≈ 710.48.
  // @math.cosh uses a scaled exp(|x|/2)² formula here and is correct.
  if t.is_inf() {
    return @math.cosh(x)
  }
  // Workaround for the broken 22 ≤ |x| < ~709.78 branch: @math.cosh pipes
  // 0.5*|x| to exp instead of halving exp(|x|).
  // ref: <https://github.com/connect0459/starlark-mbt/issues/218>
  0.5 * t + 0.5 / t
}

///|
/// Returns the hyperbolic tangent of x.
pub fn tanh(x : Double) -> Double {
  @math.tanh(x)
}

///|
/// Returns the inverse hyperbolic sine of x.
pub fn asinh(x : Double) -> Double {
  @math.asinh(x)
}

///|
/// Returns the inverse hyperbolic cosine of x.
pub fn acosh(x : Double) -> Double {
  @math.acosh(x)
}

///|
/// Returns the inverse hyperbolic tangent of x.
pub fn atanh(x : Double) -> Double {
  @math.atanh(x)
}

///|
/// Returns the square root of x² + y².
pub fn hypot(x : Double, y : Double) -> Double {
  @math.hypot(x, y)
}
