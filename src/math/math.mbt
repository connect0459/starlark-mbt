///|
fn to_float_param(
  name : String,
  param_idx : Int,
  v : @value.Value,
) -> Result[Double, String] {
  match v {
    @value.Value::Float(f) => Ok(f)
    @value.Value::Int(i) => Ok(@value.bigint_to_double(i))
    _ =>
      Err(
        "\{name}: for parameter \{param_idx}: got \{@value.type_name(v)}, want float or int",
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
  if x < 0.0 {
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
fn float_remainder(x : Double, y : Double) -> Double {
  let n = @std_math.round(x / y)
  if n == 0.0 {
    x
  } else {
    x - n * y
  }
}

///|
let sqrt_2pi : Double = 2.5066282746310002

///|
// Lanczos approximation coefficients for the g=7, n=9 parameter set; paired
// with `lanczos_g` below. See float_gamma.
let lanczos_c : Array[Double] = [
  0.99999999999980993, 676.5203681218851, -1259.1392167224028, 771.32342877765313,
  -176.61502916214059, 12.507343278686905, -0.13857109526572012, 9.9843695780195716e-6,
  1.5056327351493116e-7,
]

///|
let lanczos_g : Double = 7.0

///|
// Largest positive integer argument handled by the exact factorial fast path
// (gamma(n) == (n-1)!); above this the Lanczos approximation is used.
let gamma_factorial_max : Double = 21.0

///|
fn float_pow(x : Double, y : Double) -> Double {
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
fn float_gamma(x : Double) -> Double {
  if x.is_inf() && x > 0.0 {
    return x
  }
  if x < 0.0 && x == @std_math.floor(x) {
    return 0.0 / 0.0
  }
  if x > 0.0 && x == @std_math.floor(x) && x <= gamma_factorial_max {
    let n = x.to_int64()
    let mut r = 1.0
    let mut k = 2L
    while k < n {
      r *= k.to_double()
      k += 1L
    }
    return r
  }
  if x < 0.5 {
    // Reflection formula: gamma(x) = pi / (sin(pi*x) * gamma(1-x)).
    @std_math.PI / (@std_math.sin(@std_math.PI * x) * float_gamma(1.0 - x))
  } else {
    let z = x - 1.0
    let mut a = lanczos_c[0]
    for i in 1..<lanczos_c.length() {
      a += lanczos_c[i] / (z + i.to_double())
    }
    // t = z + g + 0.5 per the Lanczos approximation.
    let t = z + lanczos_g + 0.5
    sqrt_2pi * @std_math.pow(t, z + 0.5) * @std_math.exp(-t) * a
  }
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
                Err("log: division by zero")
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
    Ok(@value.Value::Int(@value.double_to_bigint(f)))
  }
}

///|
fn make_ceil() -> @value.Value {
  @value.Value::new_builtin("ceil", fn(_ctx, pos_args, kw_args) {
    if kw_args.length() != 0 {
      return Err("ceil: unexpected keyword arguments")
    }
    if pos_args.length() != 1 {
      return Err("ceil: got \{pos_args.length()} arguments, want 1")
    }
    match pos_args[0] {
      @value.Value::Int(_) as v => Ok(v)
      @value.Value::Float(f) => float_to_int(@std_math.ceil(f))
      v => Err("got \{@value.type_name(v)}, want float or int")
    }
  })
}

///|
fn make_floor() -> @value.Value {
  @value.Value::new_builtin("floor", fn(_ctx, pos_args, kw_args) {
    if kw_args.length() != 0 {
      return Err("floor: unexpected keyword arguments")
    }
    if pos_args.length() != 1 {
      return Err("floor: got \{pos_args.length()} arguments, want 1")
    }
    match pos_args[0] {
      @value.Value::Int(_) as v => Ok(v)
      @value.Value::Float(f) => float_to_int(@std_math.floor(f))
      v => Err("got \{@value.type_name(v)}, want float or int")
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
  attrs["ceil"] = make_ceil()
  attrs["floor"] = make_floor()
  attrs["round"] = make_unary("round", float_round_starlark)
  attrs["fabs"] = make_unary("fabs", float_abs)
  attrs["exp"] = make_unary("exp", @std_math.exp)
  attrs["sqrt"] = make_unary("sqrt", fn(x) {
    if x < 0.0 {
      0.0 / 0.0
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
  attrs["hypot"] = make_binary("hypot", @std_math.hypot)
  attrs["log"] = make_log_fn()
  @value.Value::Module(@value.StarlarkModule::new("math", attrs))
}
