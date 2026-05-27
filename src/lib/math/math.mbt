///|
fn to_float(name : String, v : @value.Value) -> Result[Double, String] {
  match v {
    @value.Value::FloatVal(f) => Ok(f)
    @value.Value::IntVal(i) => Ok(i.to_double())
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
    to_float(name, pos_args[0]).map(fn(x) { @value.Value::FloatVal(f(x)) })
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
      (Ok(x), Ok(y)) => Ok(@value.Value::FloatVal(f(x, y)))
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
  x - @math.trunc(x / y) * y
}

///|
fn float_remainder(x : Double, y : Double) -> Double {
  x - @math.round(x / y) * y
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
fn float_gamma(x : Double) -> Double {
  if x < 0.5 {
    @math.PI / (@math.sin(@math.PI * x) * float_gamma(1.0 - x))
  } else {
    let z = x - 1.0
    let mut a = lanczos_c[0]
    for i in 1..<9 {
      a += lanczos_c[i] / (z + i.to_double())
    }
    let t = z + 7.5
    sqrt_2pi * @math.pow(t, z + 0.5) * @math.exp(-t) * a
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
          Ok(@value.Value::FloatVal(@math.ln(x)))
        } else {
          match to_float("math.log", pos_args[1]) {
            Err(e) => Err(e)
            Ok(base) =>
              if base == 0.0 {
                Err("math.log: division by zero")
              } else {
                Ok(@value.Value::FloatVal(@math.ln(x) / @math.ln(base)))
              }
          }
        }
    }
  })
}

///|
pub fn math_module() -> @value.Value {
  let attrs : Map[String, @value.Value] = {}
  attrs["e"] = @value.Value::FloatVal(2.718281828459045)
  attrs["pi"] = @value.Value::FloatVal(@math.PI)
  attrs["ceil"] = make_unary("math.ceil", @math.ceil)
  attrs["floor"] = make_unary("math.floor", @math.floor)
  attrs["round"] = make_unary("math.round", @math.round)
  attrs["fabs"] = make_unary("math.fabs", float_abs)
  attrs["exp"] = make_unary("math.exp", @math.exp)
  attrs["sqrt"] = make_unary("math.sqrt", fn(x) { @math.pow(x, 0.5) })
  attrs["acos"] = make_unary("math.acos", @math.acos)
  attrs["asin"] = make_unary("math.asin", @math.asin)
  attrs["atan"] = make_unary("math.atan", @math.atan)
  attrs["cos"] = make_unary("math.cos", @math.cos)
  attrs["sin"] = make_unary("math.sin", @math.sin)
  attrs["tan"] = make_unary("math.tan", @math.tan)
  attrs["acosh"] = make_unary("math.acosh", @math.acosh)
  attrs["asinh"] = make_unary("math.asinh", @math.asinh)
  attrs["atanh"] = make_unary("math.atanh", @math.atanh)
  attrs["cosh"] = make_unary("math.cosh", @math.cosh)
  attrs["sinh"] = make_unary("math.sinh", @math.sinh)
  attrs["tanh"] = make_unary("math.tanh", @math.tanh)
  attrs["degrees"] = make_unary("math.degrees", fn(x) { x * 180.0 / @math.PI })
  attrs["radians"] = make_unary("math.radians", fn(x) { x * @math.PI / 180.0 })
  attrs["gamma"] = make_unary("math.gamma", float_gamma)
  attrs["copysign"] = make_binary("math.copysign", float_copysign)
  attrs["mod"] = make_binary("math.mod", float_mod)
  attrs["pow"] = make_binary("math.pow", @math.pow)
  attrs["remainder"] = make_binary("math.remainder", float_remainder)
  attrs["atan2"] = make_binary("math.atan2", @math.atan2)
  attrs["hypot"] = make_binary("math.hypot", @math.hypot)
  attrs["log"] = make_log_fn()
  @value.Value::ModuleVal(@value.StarlarkModule::new("math", attrs))
}
