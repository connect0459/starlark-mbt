///|
fn to_float(name : String, v : @value.Value) -> Result[Double, String] {
  match v {
    @value.Value::Float(f) => Ok(f)
    @value.Value::Int(i) => Ok(i.to_double())
    _ => Err("\{name}: got \{@value.type_name(v)}, want float or int")
  }
}

///|
fn make_unary(name : String, f : (Double) -> Double) -> @value.Value {
  @value.Value::new_builtin(name, fn(_ctx, pos_args, kw_args) {
    if pos_args.length() != 1 || kw_args.length() != 0 {
      return Err(
        "\{name}: got \{pos_args.length()} positional arguments, want 1",
      )
    }
    to_float(name, pos_args[0]).map(fn(x) { @value.Value::Float(f(x)) })
  })
}

///|
fn make_binary(name : String, f : (Double, Double) -> Double) -> @value.Value {
  @value.Value::new_builtin(name, fn(_ctx, pos_args, kw_args) {
    if pos_args.length() != 2 || kw_args.length() != 0 {
      return Err(
        "\{name}: got \{pos_args.length()} positional arguments, want 2",
      )
    }
    match (to_float(name, pos_args[0]), to_float(name, pos_args[1])) {
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
let lanczos_c : Array[Double] = [
  0.99999999999980993, 676.5203681218851, -1259.1392167224028, 771.32342877765313,
  -176.61502916214059, 12.507343278686905, -0.13857109526572012, 9.9843695780195716e-6,
  1.5056327351493116e-7,
]

///|
fn float_round_starlark(x : Double) -> Double {
  if x >= 0.0 {
    @std_math.floor(x + 0.5)
  } else {
    @std_math.ceil(x - 0.5)
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
  if x > 0.0 && x == @std_math.floor(x) && x <= 21.0 {
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
    @std_math.PI / (@std_math.sin(@std_math.PI * x) * float_gamma(1.0 - x))
  } else {
    let z = x - 1.0
    let mut a = lanczos_c[0]
    for i in 1..<9 {
      a += lanczos_c[i] / (z + i.to_double())
    }
    let t = z + 7.5
    sqrt_2pi * @std_math.pow(t, z + 0.5) * @std_math.exp(-t) * a
  }
}

///|
fn make_log_fn() -> @value.Value {
  @value.Value::new_builtin("math.log", fn(_ctx, pos_args, kw_args) {
    if pos_args.length() < 1 || pos_args.length() > 2 || kw_args.length() != 0 {
      return Err("math.log: got \{pos_args.length()} arguments, want 1 or 2")
    }
    match to_float("math.log", pos_args[0]) {
      Err(e) => Err(e)
      Ok(x) =>
        if pos_args.length() == 1 {
          Ok(@value.Value::Float(@std_math.ln(x)))
        } else {
          match to_float("math.log", pos_args[1]) {
            Err(e) => Err(e)
            Ok(base) =>
              if base == 1.0 {
                Err("math.log: division by zero")
              } else {
                Ok(@value.Value::Float(@std_math.ln(x) / @std_math.ln(base)))
              }
          }
        }
    }
  })
}

///|
fn float_to_int(name : String, f : Double) -> Result[@value.Value, String] {
  if f.is_inf() {
    Err("\{name}: cannot convert float infinity to integer")
  } else if f.is_nan() {
    Err("\{name}: cannot convert float NaN to integer")
  } else {
    Ok(@value.Value::Int(f.to_int64()))
  }
}

///|
fn make_ceil() -> @value.Value {
  @value.Value::new_builtin("math.ceil", fn(_ctx, pos_args, kw_args) {
    if pos_args.length() != 1 || kw_args.length() != 0 {
      return Err(
        "math.ceil: got \{pos_args.length()} positional arguments, want 1",
      )
    }
    match pos_args[0] {
      @value.Value::Int(_) as v => Ok(v)
      @value.Value::Float(f) => float_to_int("math.ceil", @std_math.ceil(f))
      v => Err("math.ceil: got \{@value.type_name(v)}, want float or int")
    }
  })
}

///|
fn make_floor() -> @value.Value {
  @value.Value::new_builtin("math.floor", fn(_ctx, pos_args, kw_args) {
    if pos_args.length() != 1 || kw_args.length() != 0 {
      return Err(
        "math.floor: got \{pos_args.length()} positional arguments, want 1",
      )
    }
    match pos_args[0] {
      @value.Value::Int(_) as v => Ok(v)
      @value.Value::Float(f) => float_to_int("math.floor", @std_math.floor(f))
      v => Err("math.floor: got \{@value.type_name(v)}, want float or int")
    }
  })
}

///|
pub fn math_module() -> @value.Value {
  let attrs : Map[String, @value.Value] = {}
  attrs["e"] = @value.Value::Float(2.718281828459045)
  attrs["pi"] = @value.Value::Float(@std_math.PI)
  attrs["ceil"] = make_ceil()
  attrs["floor"] = make_floor()
  attrs["round"] = make_unary("math.round", float_round_starlark)
  attrs["fabs"] = make_unary("math.fabs", float_abs)
  attrs["exp"] = make_unary("math.exp", @std_math.exp)
  attrs["sqrt"] = make_unary("math.sqrt", fn(x) {
    if x < 0.0 {
      0.0 / 0.0
    } else {
      @std_math.pow(x, 0.5)
    }
  })
  attrs["acos"] = make_unary("math.acos", @std_math.acos)
  attrs["asin"] = make_unary("math.asin", @std_math.asin)
  attrs["atan"] = make_unary("math.atan", @std_math.atan)
  attrs["cos"] = make_unary("math.cos", @std_math.cos)
  attrs["sin"] = make_unary("math.sin", @std_math.sin)
  attrs["tan"] = make_unary("math.tan", @std_math.tan)
  attrs["acosh"] = make_unary("math.acosh", @std_math.acosh)
  attrs["asinh"] = make_unary("math.asinh", @std_math.asinh)
  attrs["atanh"] = make_unary("math.atanh", @std_math.atanh)
  attrs["cosh"] = make_unary("math.cosh", @std_math.cosh)
  attrs["sinh"] = make_unary("math.sinh", @std_math.sinh)
  attrs["tanh"] = make_unary("math.tanh", @std_math.tanh)
  attrs["degrees"] = make_unary("math.degrees", fn(x) {
    x * 180.0 / @std_math.PI
  })
  attrs["radians"] = make_unary("math.radians", fn(x) {
    x * @std_math.PI / 180.0
  })
  attrs["gamma"] = make_unary("math.gamma", float_gamma)
  attrs["copysign"] = make_binary("math.copysign", float_copysign)
  attrs["mod"] = make_binary("math.mod", float_mod)
  attrs["pow"] = make_binary("math.pow", @std_math.pow)
  attrs["remainder"] = make_binary("math.remainder", float_remainder)
  attrs["atan2"] = make_binary("math.atan2", @std_math.atan2)
  attrs["hypot"] = make_binary("math.hypot", @std_math.hypot)
  attrs["log"] = make_log_fn()
  @value.Value::Module(@value.StarlarkModule::new("math", attrs))
}
