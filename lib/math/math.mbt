///|
fn to_float_param(
  name : String,
  param_idx : Int,
  v : @value.Value,
) -> Result[Double, String] {
  match v {
    @value.Value::Float(f) => Ok(f)
    @value.Value::Int(i) => Ok(@numeric.bigint_to_double(i))
    _ =>
      Err(
        "\{name}: for parameter \{param_idx}: got \{v.type_name()}, want float or int",
      )
  }
}

///|
fn make_unary(name : String, f : (Double) -> Double) -> @value.Value {
  @value.Value::new_builtin(name, fn(_ctx, pos_args, kw_args) {
    if kw_args.length() != 0 {
      return Err("\{name}: unexpected keyword arguments")
    }
    if pos_args.length() != 1 {
      return Err("\{name}: got \{pos_args.length()} arguments, want 1")
    }
    to_float_param(name, 1, pos_args[0]).map(fn(x) { @value.Value::Float(f(x)) })
  })
}

///|
fn make_binary(name : String, f : (Double, Double) -> Double) -> @value.Value {
  @value.Value::new_builtin(name, fn(_ctx, pos_args, kw_args) {
    if kw_args.length() != 0 {
      return Err("\{name}: unexpected keyword arguments")
    }
    if pos_args.length() != 2 {
      return Err("\{name}: got \{pos_args.length()} arguments, want 2")
    }
    match
      (
        to_float_param(name, 1, pos_args[0]),
        to_float_param(name, 2, pos_args[1]),
      ) {
      (Ok(x), Ok(y)) => Ok(@value.Value::Float(f(x, y)))
      (Err(e), _) | (_, Err(e)) => Err(e)
    }
  })
}

///|
fn float_abs(x : Double) -> Double {
  // `1.0 / x < 0.0` detects -0.0: dividing by -0.0 yields -inf.
  if x < 0.0 || (x == 0.0 && 1.0 / x < 0.0) {
    -x
  } else {
    x
  }
}

///|
fn float_copysign(x : Double, y : Double) -> Double {
  let abs_x = float_abs(x)
  // `1.0 / y < 0.0` distinguishes -0.0 from +0.0: dividing by -0.0 yields
  // -inf, by +0.0 yields +inf, so the sign bit is recovered when y == 0.0.
  if y < 0.0 || (y == 0.0 && 1.0 / y < 0.0) {
    -abs_x
  } else {
    abs_x
  }
}

///|
fn float_mod(x : Double, y : Double) -> Double {
  let n = @std_math.trunc(x / y)
  if n == 0.0 {
    x
  } else {
    x - n * y
  }
}

///|
fn precise_fmod(x : Double, y : Double) -> Double {
  let xb = x.reinterpret_as_uint64()
  let yb = y.reinterpret_as_uint64()
  let sx = xb & 0x8000000000000000_UL
  let ax = xb ^ sx
  let ay = yb & 0x7FFFFFFFFFFFFFFF_UL
  if ay == 0_UL || ax >= 0x7FF0000000000000_UL || ay > 0x7FF0000000000000_UL {
    return x * y / (x * y)
  }
  if ax < ay {
    return x
  }
  if ax == ay {
    return if sx != 0_UL { -0.0 } else { 0.0 }
  }
  let ix_e = ((ax >> 52) & 0x7FF_UL).to_int()
  let mut ix = 0
  let mut mx = 0_UL
  if ix_e != 0 {
    ix = ix_e - 1023
    mx = 0x0010000000000000_UL | (ax & 0x000FFFFFFFFFFFFF_UL)
  } else {
    let mut m = ax & 0x000FFFFFFFFFFFFF_UL
    ix = -1022
    while m < 0x0010000000000000_UL {
      m = m << 1
      ix -= 1
    }
    mx = m
  }
  let iy_e = ((ay >> 52) & 0x7FF_UL).to_int()
  let mut iy = 0
  let mut my = 0_UL
  if iy_e != 0 {
    iy = iy_e - 1023
    my = 0x0010000000000000_UL | (ay & 0x000FFFFFFFFFFFFF_UL)
  } else {
    let mut m = ay & 0x000FFFFFFFFFFFFF_UL
    iy = -1022
    while m < 0x0010000000000000_UL {
      m = m << 1
      iy -= 1
    }
    my = m
  }
  let mut n = ix - iy
  while n > 0 {
    if mx >= my {
      let hz = mx - my
      if hz == 0_UL {
        return if sx != 0_UL { -0.0 } else { 0.0 }
      }
      mx = hz << 1
    } else {
      mx = mx << 1
    }
    n -= 1
  }
  if mx >= my {
    mx = mx - my
  }
  if mx == 0_UL {
    return if sx != 0_UL { -0.0 } else { 0.0 }
  }
  let mut cur_iy = iy
  while mx < 0x0010000000000000_UL {
    mx = mx << 1
    cur_iy -= 1
  }
  let result_bits = if cur_iy >= -1022 {
    let exp_bits = (cur_iy + 1023).to_int64().reinterpret_as_uint64()
    sx | (exp_bits << 52) | (mx & 0x000FFFFFFFFFFFFF_UL)
  } else {
    let shift = -1022 - cur_iy
    if shift >= 53 {
      sx
    } else {
      sx | (mx >> shift)
    }
  }
  result_bits.reinterpret_as_double()
}

///|
fn float_remainder(x : Double, y : Double) -> Double {
  if x.is_nan() || y.is_nan() || x.is_inf() || y == 0.0 {
    return 0.0 / 0.0
  }
  if y.is_inf() {
    return x
  }
  let sign = x < 0.0
  let mut rx = if sign { -x } else { x }
  let ry = if y < 0.0 { -y } else { y }
  if rx == ry {
    return if sign { -0.0 } else { 0.0 }
  }
  if ry <= 8.98846567431158e+307 {
    rx = precise_fmod(rx, ry + ry)
  }
  if ry < 4.45014771701440276618e-308 {
    if rx + rx > ry {
      rx -= ry
      if rx + rx >= ry {
        rx -= ry
      }
    }
  } else {
    let ry_half = ry * 0.5
    if rx > ry_half {
      rx -= ry
      if rx >= ry_half {
        rx -= ry
      }
    }
  }
  if sign {
    -rx
  } else {
    rx
  }
}

///|
// Cephes rational approximation numerator coefficients for Gamma on [2, 3].
// Source: go/src/math/gamma.go (Cephes Math Library, Stephen L. Moshier).
let _gam_p : Array[Double] = [
  1.60119522476751861407e-04, 1.19135147006586384913e-03, 1.04213797561761569935e-02,
  4.76367800457137231464e-02, 2.07448227648435975150e-01, 4.94214826801497100753e-01,
  9.99999999999999996796e-01,
]

///|
// Cephes rational approximation denominator coefficients for Gamma on [2, 3].
let _gam_q : Array[Double] = [
  -2.31581873324120129819e-05, 5.39605580493303397842e-04, -4.45641913851797240494e-03,
  1.18139785222060435552e-02, 3.58236398605498653373e-02, -2.34591795718243348568e-01,
  7.14304917030273074085e-02, 1.00000000000000000320e+00,
]

///|
// Stirling series coefficients for Gamma (large x > 33).
let _gam_s : Array[Double] = [
  7.87311395793093628397e-04, -2.29549961613378126380e-04, -2.68132617805781232825e-03,
  3.47222221605458667310e-03, 8.33333333333482257126e-02,
]

///|
fn float_pow(x : Double, y : Double) -> Double {
  // IEEE 754-2008 §9.2 / C99 Annex F: pow(1, y) = 1 for any y including NaN.
  if x == 1.0 {
    return 1.0
  }
  // pow(-1, ±Inf) == 1 per IEEE 754 Annex F; naive implementation yields NaN.
  if x == -1.0 && y.is_inf() {
    return 1.0
  }
  @std_math.pow(x, y)
}

///|
fn float_round_starlark(x : Double) -> Double {
  let t = @std_math.trunc(x)
  let frac = x - t
  if frac >= 0.5 {
    t + 1.0
  } else if frac <= -0.5 {
    t - 1.0
  } else {
    t
  }
}

///|
// Returns (y1, y2) such that Gamma(x) ≈ y1 * y2 for x > 33.
// Splitting avoids premature overflow for 172 ≤ x ≤ 180.
fn float_gamma_stirling(x : Double) -> (Double, Double) {
  if x > 200.0 {
    return (@double.infinity, 1.0)
  }
  let sqrt_two_pi = 2.506628274631000502417
  let max_stirling = 143.01608
  let w0 = 1.0 / x
  let w = 1.0 +
    w0 *
    (
      (((_gam_s[0] * w0 + _gam_s[1]) * w0 + _gam_s[2]) * w0 + _gam_s[3]) * w0 +
      _gam_s[4]
    )
  let y1 = @std_math.exp(x)
  if x > max_stirling {
    let v = @std_math.pow(x, 0.5 * x - 0.25)
    (v, sqrt_two_pi * w * (v / y1))
  } else {
    (@std_math.pow(x, x - 0.5) / y1, sqrt_two_pi * w)
  }
}

///|
// Ported from go/src/math/gamma.go (Cephes Math Library, Stephen L. Moshier).
// Uses Stirling's formula for |x| > 33 and a Cephes rational P/Q approximation
// on [2, 3] with argument reduction elsewhere.
fn float_gamma(x : Double) -> Double {
  // Special cases.
  if x.is_nan() ||
    (x.is_inf() && x < 0.0) ||
    (x < 0.0 && x == @std_math.floor(x)) {
    return 0.0 / 0.0 // NaN
  }
  if x.is_inf() {
    return x // +Inf
  }
  if x == 0.0 {
    // Gamma(+0) = +Inf; Gamma(-0) = -Inf.
    if 1.0 / x < 0.0 {
      return -1.0 / 0.0
    }
    return 1.0 / 0.0
  }
  let euler = 0.57721566490153286060651209008240243104215933593992
  let q = x.abs()
  let p = @std_math.floor(q)
  if q > 33.0 {
    if x >= 0.0 {
      let (y1, y2) = float_gamma_stirling(x)
      return y1 * y2
    }
    // x < 0, non-integer: reflection formula via Stirling on |x|.
    let ip = p.to_int64()
    let signgam = if (ip & 1L) == 0L { -1.0 } else { 1.0 }
    let mut p2 = p
    let mut z = q - p2
    if z > 0.5 {
      p2 += 1.0
      z = q - p2
    }
    z = q * @std_math.sin(@std_math.PI * z)
    if z == 0.0 {
      return signgam * (1.0 / 0.0) // signgam * +Inf
    }
    let (sq1, sq2) = float_gamma_stirling(q)
    let absz = z.abs()
    let d = absz * sq1 * sq2
    let pi_over = if d.is_inf() {
      @std_math.PI / absz / sq1 / sq2
    } else {
      @std_math.PI / d
    }
    return signgam * pi_over
  }
  // Reduce argument to [2, 3].
  let mut z = 1.0
  let mut xm = x
  while xm >= 3.0 {
    xm -= 1.0
    z *= xm
  }
  // Handle negative x and small-near-zero x.
  let mut small = false
  while xm < 0.0 {
    if xm > -1.0e-9 {
      small = true
      break
    }
    z /= xm
    xm += 1.0
  }
  if !small {
    while xm < 2.0 {
      if xm < 1.0e-9 {
        small = true
        break
      }
      z /= xm
      xm += 1.0
    }
  }
  if small {
    if xm == 0.0 {
      return 1.0 / 0.0 // +Inf
    }
    return z / ((1.0 + euler * xm) * xm)
  }
  if xm == 2.0 {
    return z
  }
  xm -= 2.0
  let p_val = (
      (
        (((xm * _gam_p[0] + _gam_p[1]) * xm + _gam_p[2]) * xm + _gam_p[3]) * xm +
        _gam_p[4]
      ) *
      xm +
      _gam_p[5]
    ) *
    xm +
    _gam_p[6]
  let q_val = (
      (
        (
          (((xm * _gam_q[0] + _gam_q[1]) * xm + _gam_q[2]) * xm + _gam_q[3]) *
          xm +
          _gam_q[4]
        ) *
        xm +
        _gam_q[5]
      ) *
      xm +
      _gam_q[6]
    ) *
    xm +
    _gam_q[7]
  z * p_val / q_val
}

///|
fn float_hypot(x : Double, y : Double) -> Double {
  // IEEE 754: hypot(±inf, anything) = +inf, even when the other argument is NaN.
  if x.is_inf() || y.is_inf() {
    return @double.infinity
  }
  @std_math.hypot(x, y)
}

///|
fn make_log_fn() -> @value.Value {
  @value.Value::new_builtin("log", fn(_ctx, pos_args, kw_args) {
    if kw_args.length() != 0 {
      return Err("log: unexpected keyword arguments")
    }
    if pos_args.length() < 1 {
      return Err("log: got 0 arguments, want at least 1")
    }
    if pos_args.length() > 2 {
      return Err("log: got \{pos_args.length()} arguments, want at most 2")
    }
    match to_float_param("log", 1, pos_args[0]) {
      Err(e) => Err(e)
      Ok(x) =>
        if pos_args.length() == 1 {
          Ok(@value.Value::Float(@std_math.ln(x)))
        } else {
          match to_float_param("log", 2, pos_args[1]) {
            Err(e) => Err(e)
            Ok(base) =>
              if base == 1.0 {
                Err("division by zero")
              } else {
                Ok(@value.Value::Float(@std_math.ln(x) / @std_math.ln(base)))
              }
          }
        }
    }
  })
}

///|
fn float_to_int(f : Double) -> Result[@value.Value, String] {
  if f.is_inf() {
    Err("cannot convert float infinity to integer")
  } else if f.is_nan() {
    Err("cannot convert float NaN to integer")
  } else {
    Ok(@value.Value::Int(@numeric.double_to_bigint(f)))
  }
}

///|
fn make_rounding(name : String, round : (Double) -> Double) -> @value.Value {
  @value.Value::new_builtin(name, fn(_ctx, pos_args, kw_args) {
    if kw_args.length() != 0 {
      return Err("\{name}: unexpected keyword arguments")
    }
    if pos_args.length() != 1 {
      return Err("\{name}: got \{pos_args.length()} arguments, want 1")
    }
    match pos_args[0] {
      @value.Value::Int(_) as v => Ok(v)
      @value.Value::Float(f) => float_to_int(round(f))
      v => Err("got \{v.type_name()}, want float or int")
    }
  })
}

///|
/// Returns the `math` Starlark module value, providing the constants `e` and
/// `pi`, and the functions `ceil`, `floor`, `round`, `fabs`, `exp`, `sqrt`,
/// `log`, `sin`, `cos`, `tan`, `asin`, `acos`, `atan`, `atan2`, `pow`, and
/// `trunc` as attributes.
///
/// Returns the constructed `math` module as a `@value.Value::Module`.
pub fn math_module() -> @value.Value {
  let attrs : Map[String, @value.Value] = {}
  attrs["e"] = @value.Value::Float(2.718281828459045)
  attrs["pi"] = @value.Value::Float(@std_math.PI)
  attrs["ceil"] = make_rounding("ceil", @std_math.ceil)
  attrs["floor"] = make_rounding("floor", @std_math.floor)
  attrs["round"] = make_unary("round", float_round_starlark)
  attrs["fabs"] = make_unary("fabs", float_abs)
  attrs["exp"] = make_unary("exp", @std_math.exp)
  attrs["sqrt"] = make_unary("sqrt", fn(x) {
    if x < 0.0 {
      0.0 / 0.0
    } else if x == 0.0 {
      // IEEE 754: sqrt(±0) = ±0; preserve the sign rather than going through pow.
      x
    } else {
      @std_math.pow(x, 0.5)
    }
  })
  attrs["acos"] = make_unary("acos", @std_math.acos)
  attrs["asin"] = make_unary("asin", @std_math.asin)
  attrs["atan"] = make_unary("atan", @std_math.atan)
  attrs["cos"] = make_unary("cos", @std_math.cos)
  attrs["sin"] = make_unary("sin", @std_math.sin)
  attrs["tan"] = make_unary("tan", @std_math.tan)
  attrs["acosh"] = make_unary("acosh", @std_math.acosh)
  attrs["asinh"] = make_unary("asinh", @std_math.asinh)
  attrs["atanh"] = make_unary("atanh", @std_math.atanh)
  attrs["cosh"] = make_unary("cosh", @std_math.cosh)
  attrs["sinh"] = make_unary("sinh", @std_math.sinh)
  attrs["tanh"] = make_unary("tanh", @std_math.tanh)
  attrs["degrees"] = make_unary("degrees", fn(x) { x * 180.0 / @std_math.PI })
  attrs["radians"] = make_unary("radians", fn(x) { x * @std_math.PI / 180.0 })
  attrs["gamma"] = make_unary("gamma", float_gamma)
  attrs["copysign"] = make_binary("copysign", float_copysign)
  attrs["mod"] = make_binary("mod", float_mod)
  attrs["pow"] = make_binary("pow", float_pow)
  attrs["remainder"] = make_binary("remainder", float_remainder)
  attrs["atan2"] = make_binary("atan2", @std_math.atan2)
  attrs["hypot"] = make_binary("hypot", float_hypot)
  attrs["log"] = make_log_fn()
  @value.Value::Module(@value.StarlarkModule::new("math", attrs))
}
