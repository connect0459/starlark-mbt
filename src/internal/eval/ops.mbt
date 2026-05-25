///|
fn adjust_index(i : Int64, length : Int) -> Result[Int, String] {
  let len = length.to_int64()
  let j = if i < 0L { i + len } else { i }
  if j < 0L || j >= len {
    Err("index \{i} out of range for sequence of length \{length}")
  } else {
    Ok(j.to_int())
  }
}

///|
fn int_pow(base : Int64, exp : Int64) -> Result[Int64, String] {
  if exp < 0L {
    return Err("integer power with negative exponent is not allowed")
  }
  if exp == 0L {
    return Ok(1L)
  }
  let mut result = 1L
  let mut b = base
  let mut e = exp
  while e > 0L {
    if e.land(1L) != 0L {
      result = result * b
    }
    b = b * b
    e = e >> 1
  }
  Ok(result)
}

///|
fn eval_unary(
  ctx : EvalContext,
  op : @syntax.UnaryOp,
  v : @value.Value,
  _pos : @errors.Position,
) -> @value.Value raise EvalErr {
  match op {
    @syntax.UnaryOp::OpPlus =>
      match v {
        @value.Value::IntVal(_) | @value.Value::FloatVal(_) => v
        _ =>
          raise EvalErr(
            make_eval_error(
              ctx,
              "unary + not supported for '\{@value.type_name(v)}'",
            ),
          )
      }
    @syntax.UnaryOp::OpMinus =>
      match v {
        @value.Value::IntVal(n) => @value.Value::IntVal(-n)
        @value.Value::FloatVal(f) => @value.Value::FloatVal(-f)
        _ =>
          raise EvalErr(
            make_eval_error(
              ctx,
              "unary - not supported for '\{@value.type_name(v)}'",
            ),
          )
      }
    @syntax.UnaryOp::OpBitNot =>
      match v {
        @value.Value::IntVal(n) => @value.Value::IntVal(n.lnot())
        _ =>
          raise EvalErr(
            make_eval_error(
              ctx,
              "unary ~ not supported for '\{@value.type_name(v)}'",
            ),
          )
      }
    @syntax.UnaryOp::OpNot => @value.Value::BoolVal(!@value.truth(v))
  }
}

///|
fn eval_binary(
  ctx : EvalContext,
  lv : @value.Value,
  op : @syntax.BinaryOp,
  rv : @value.Value,
  pos : @errors.Position,
) -> @value.Value raise EvalErr {
  match op {
    @syntax.BinaryOp::OpAdd => eval_add(ctx, lv, rv, pos)
    @syntax.BinaryOp::OpSub => eval_arith_sub(ctx, lv, rv, pos)
    @syntax.BinaryOp::OpMul => eval_mul(ctx, lv, rv, pos)
    @syntax.BinaryOp::OpDiv => eval_div(ctx, lv, rv, pos)
    @syntax.BinaryOp::OpFloorDiv => eval_floor_div(ctx, lv, rv, pos)
    @syntax.BinaryOp::OpMod => eval_mod(ctx, lv, rv, pos)
    @syntax.BinaryOp::OpPow => eval_pow(ctx, lv, rv, pos)
    @syntax.BinaryOp::OpBitAnd => eval_bitwise(ctx, lv, rv, pos, "land")
    @syntax.BinaryOp::OpBitOr => eval_bitwise(ctx, lv, rv, pos, "lor")
    @syntax.BinaryOp::OpBitXor => eval_bitwise(ctx, lv, rv, pos, "lxor")
    @syntax.BinaryOp::OpLShift => eval_shift(ctx, lv, rv, pos, "lshift")
    @syntax.BinaryOp::OpRShift => eval_shift(ctx, lv, rv, pos, "rshift")
    @syntax.BinaryOp::OpEq =>
      @value.Value::BoolVal(@value.starlark_equals(lv, rv))
    @syntax.BinaryOp::OpNe =>
      @value.Value::BoolVal(!@value.starlark_equals(lv, rv))
    @syntax.BinaryOp::OpLt => eval_cmp(ctx, lv, rv, pos, -1, true, false)
    @syntax.BinaryOp::OpLe => eval_cmp(ctx, lv, rv, pos, -1, false, false)
    @syntax.BinaryOp::OpGt => eval_cmp(ctx, lv, rv, pos, 1, true, false)
    @syntax.BinaryOp::OpGe => eval_cmp(ctx, lv, rv, pos, 1, false, false)
    @syntax.BinaryOp::OpIn => in_op(ctx, lv, rv, pos)
    @syntax.BinaryOp::OpNotIn => {
      let r = in_op(ctx, lv, rv, pos)
      match r {
        @value.Value::BoolVal(b) => @value.Value::BoolVal(!b)
        _ => @value.Value::BoolVal(false)
      }
    }
    @syntax.BinaryOp::OpAnd | @syntax.BinaryOp::OpOr =>
      raise EvalErr(
        make_eval_error(ctx, "and/or must be handled before eval_binary"),
      )
  }
}

///|
fn eval_add(
  ctx : EvalContext,
  lv : @value.Value,
  rv : @value.Value,
  _pos : @errors.Position,
) -> @value.Value raise EvalErr {
  match (lv, rv) {
    (@value.Value::IntVal(a), @value.Value::IntVal(b)) =>
      @value.Value::IntVal(a + b)
    (@value.Value::FloatVal(a), @value.Value::FloatVal(b)) =>
      @value.Value::FloatVal(a + b)
    (@value.Value::IntVal(a), @value.Value::FloatVal(b)) =>
      @value.Value::FloatVal(a.to_double() + b)
    (@value.Value::FloatVal(a), @value.Value::IntVal(b)) =>
      @value.Value::FloatVal(a + b.to_double())
    (@value.Value::StrVal(a), @value.Value::StrVal(b)) =>
      @value.Value::StrVal(@value.StarlarkString::new(a.raw + b.raw))
    (@value.Value::ListVal(a), @value.Value::ListVal(b)) => {
      let items : Array[@value.Value] = []
      for v in a.items {
        items.push(v)
      }
      for v in b.items {
        items.push(v)
      }
      @value.Value::ListVal(@value.StarlarkList::new(items))
    }
    (@value.Value::TupleVal(a), @value.Value::TupleVal(b)) => {
      let items : Array[@value.Value] = []
      for v in a {
        items.push(v)
      }
      for v in b {
        items.push(v)
      }
      @value.Value::TupleVal(items)
    }
    (@value.Value::BytesVal(a), @value.Value::BytesVal(b)) => {
      let items : Array[Byte] = []
      for i in 0..<a.length() {
        items.push(a[i])
      }
      for i in 0..<b.length() {
        items.push(b[i])
      }
      @value.Value::BytesVal(Bytes::from_array(items))
    }
    _ =>
      raise EvalErr(
        make_eval_error(
          ctx,
          "unsupported operand types for +: '\{@value.type_name(lv)}' and '\{@value.type_name(rv)}'",
        ),
      )
  }
}

///|
fn eval_arith_sub(
  ctx : EvalContext,
  lv : @value.Value,
  rv : @value.Value,
  _pos : @errors.Position,
) -> @value.Value raise EvalErr {
  match (lv, rv) {
    (@value.Value::IntVal(a), @value.Value::IntVal(b)) =>
      @value.Value::IntVal(a - b)
    (@value.Value::FloatVal(a), @value.Value::FloatVal(b)) =>
      @value.Value::FloatVal(a - b)
    (@value.Value::IntVal(a), @value.Value::FloatVal(b)) =>
      @value.Value::FloatVal(a.to_double() - b)
    (@value.Value::FloatVal(a), @value.Value::IntVal(b)) =>
      @value.Value::FloatVal(a - b.to_double())
    _ =>
      raise EvalErr(
        make_eval_error(
          ctx,
          "unsupported operand types for -: '\{@value.type_name(lv)}' and '\{@value.type_name(rv)}'",
        ),
      )
  }
}

///|
fn eval_mul(
  ctx : EvalContext,
  lv : @value.Value,
  rv : @value.Value,
  pos : @errors.Position,
) -> @value.Value raise EvalErr {
  match (lv, rv) {
    (@value.Value::IntVal(a), @value.Value::IntVal(b)) =>
      @value.Value::IntVal(a * b)
    (@value.Value::FloatVal(a), @value.Value::FloatVal(b)) =>
      @value.Value::FloatVal(a * b)
    (@value.Value::IntVal(a), @value.Value::FloatVal(b)) =>
      @value.Value::FloatVal(a.to_double() * b)
    (@value.Value::FloatVal(a), @value.Value::IntVal(b)) =>
      @value.Value::FloatVal(a * b.to_double())
    (@value.Value::StrVal(s), @value.Value::IntVal(n)) =>
      @value.Value::StrVal(repeat_string(s, n, ctx, pos))
    (@value.Value::IntVal(n), @value.Value::StrVal(s)) =>
      @value.Value::StrVal(repeat_string(s, n, ctx, pos))
    (@value.Value::ListVal(l), @value.Value::IntVal(n)) =>
      @value.Value::ListVal(repeat_list(l, n))
    (@value.Value::IntVal(n), @value.Value::ListVal(l)) =>
      @value.Value::ListVal(repeat_list(l, n))
    _ =>
      raise EvalErr(
        make_eval_error(
          ctx,
          "unsupported operand types for *: '\{@value.type_name(lv)}' and '\{@value.type_name(rv)}'",
        ),
      )
  }
}

///|
fn repeat_string(
  s : @value.StarlarkString,
  n : Int64,
  _ctx : EvalContext,
  _pos : @errors.Position,
) -> @value.StarlarkString {
  if n <= 0L {
    return @value.StarlarkString::new("")
  }
  let count = n.to_int()
  let buf = StringBuilder::new()
  for _ in 0..<count {
    buf.write_string(s.raw)
  }
  @value.StarlarkString::new(buf.to_string())
}

///|
fn repeat_list(l : @value.StarlarkList, n : Int64) -> @value.StarlarkList {
  if n <= 0L {
    return @value.StarlarkList::new([])
  }
  let count = n.to_int()
  let items : Array[@value.Value] = []
  for _ in 0..<count {
    for v in l.items {
      items.push(v)
    }
  }
  @value.StarlarkList::new(items)
}

///|
fn eval_div(
  ctx : EvalContext,
  lv : @value.Value,
  rv : @value.Value,
  _pos : @errors.Position,
) -> @value.Value raise EvalErr {
  if !ctx.opts.allow_float {
    raise EvalErr(make_eval_error(ctx, "real division is not allowed"))
  }
  match (lv, rv) {
    (@value.Value::IntVal(a), @value.Value::IntVal(b)) => {
      if b == 0L {
        raise EvalErr(make_eval_error(ctx, "integer division by zero"))
      }
      @value.Value::FloatVal(a.to_double() / b.to_double())
    }
    (@value.Value::FloatVal(a), @value.Value::FloatVal(b)) => {
      if b == 0.0 {
        raise EvalErr(make_eval_error(ctx, "float division by zero"))
      }
      @value.Value::FloatVal(a / b)
    }
    (@value.Value::IntVal(a), @value.Value::FloatVal(b)) => {
      if b == 0.0 {
        raise EvalErr(make_eval_error(ctx, "float division by zero"))
      }
      @value.Value::FloatVal(a.to_double() / b)
    }
    (@value.Value::FloatVal(a), @value.Value::IntVal(b)) => {
      if b == 0L {
        raise EvalErr(make_eval_error(ctx, "float division by zero"))
      }
      @value.Value::FloatVal(a / b.to_double())
    }
    _ =>
      raise EvalErr(
        make_eval_error(
          ctx,
          "unsupported operand types for /: '\{@value.type_name(lv)}' and '\{@value.type_name(rv)}'",
        ),
      )
  }
}

///|
fn eval_floor_div(
  ctx : EvalContext,
  lv : @value.Value,
  rv : @value.Value,
  _pos : @errors.Position,
) -> @value.Value raise EvalErr {
  match (lv, rv) {
    (@value.Value::IntVal(a), @value.Value::IntVal(b)) =>
      @value.Value::IntVal(check(ctx, @value.floor_div(a, b)))
    (@value.Value::FloatVal(a), @value.Value::FloatVal(b)) => {
      if b == 0.0 {
        raise EvalErr(make_eval_error(ctx, "float floor division by zero"))
      }
      @value.Value::FloatVal((a / b).floor())
    }
    (@value.Value::IntVal(a), @value.Value::FloatVal(b)) => {
      if b == 0.0 {
        raise EvalErr(make_eval_error(ctx, "float floor division by zero"))
      }
      @value.Value::FloatVal((a.to_double() / b).floor())
    }
    (@value.Value::FloatVal(a), @value.Value::IntVal(b)) => {
      if b == 0L {
        raise EvalErr(make_eval_error(ctx, "float floor division by zero"))
      }
      @value.Value::FloatVal((a / b.to_double()).floor())
    }
    _ =>
      raise EvalErr(
        make_eval_error(
          ctx,
          "unsupported operand types for //: '\{@value.type_name(lv)}' and '\{@value.type_name(rv)}'",
        ),
      )
  }
}

///|
fn eval_mod(
  ctx : EvalContext,
  lv : @value.Value,
  rv : @value.Value,
  _pos : @errors.Position,
) -> @value.Value raise EvalErr {
  match (lv, rv) {
    (@value.Value::IntVal(a), @value.Value::IntVal(b)) =>
      @value.Value::IntVal(check(ctx, @value.starlark_mod(a, b)))
    (@value.Value::FloatVal(a), @value.Value::FloatVal(b)) => {
      if b == 0.0 {
        raise EvalErr(make_eval_error(ctx, "float modulo by zero"))
      }
      @value.Value::FloatVal(a % b)
    }
    (@value.Value::IntVal(a), @value.Value::FloatVal(b)) => {
      if b == 0.0 {
        raise EvalErr(make_eval_error(ctx, "float modulo by zero"))
      }
      @value.Value::FloatVal(a.to_double() % b)
    }
    (@value.Value::FloatVal(a), @value.Value::IntVal(b)) => {
      if b == 0L {
        raise EvalErr(make_eval_error(ctx, "float modulo by zero"))
      }
      @value.Value::FloatVal(a % b.to_double())
    }
    _ =>
      raise EvalErr(
        make_eval_error(
          ctx,
          "unsupported operand types for %: '\{@value.type_name(lv)}' and '\{@value.type_name(rv)}'",
        ),
      )
  }
}

///|
fn eval_pow(
  ctx : EvalContext,
  lv : @value.Value,
  rv : @value.Value,
  _pos : @errors.Position,
) -> @value.Value raise EvalErr {
  match (lv, rv) {
    (@value.Value::IntVal(a), @value.Value::IntVal(b)) =>
      @value.Value::IntVal(check(ctx, int_pow(a, b)))
    (@value.Value::FloatVal(a), @value.Value::FloatVal(b)) =>
      @value.Value::FloatVal(float_pow(a, b))
    (@value.Value::IntVal(a), @value.Value::FloatVal(b)) =>
      @value.Value::FloatVal(float_pow(a.to_double(), b))
    (@value.Value::FloatVal(a), @value.Value::IntVal(b)) =>
      @value.Value::FloatVal(float_pow(a, b.to_double()))
    _ =>
      raise EvalErr(
        make_eval_error(
          ctx,
          "unsupported operand types for **: '\{@value.type_name(lv)}' and '\{@value.type_name(rv)}'",
        ),
      )
  }
}

///|
fn float_pow(base : Double, exp : Double) -> Double {
  if exp == 0.0 {
    return 1.0
  }
  if base == 0.0 {
    return 0.0
  }
  if exp == 1.0 {
    return base
  }
  let n = exp.to_int64()
  if n.to_double() == exp && n >= -63L && n <= 63L {
    if n >= 0L {
      let mut r = 1.0
      let mut b = base
      let mut e = n
      while e > 0L {
        if e.land(1L) != 0L {
          r = r * b
        }
        b = b * b
        e = e >> 1
      }
      r
    } else {
      1.0 / float_pow(base, -exp)
    }
  } else {
    let _ = base
    let _ = exp
    @double.not_a_number
  }
}

///|
fn eval_bitwise(
  ctx : EvalContext,
  lv : @value.Value,
  rv : @value.Value,
  _pos : @errors.Position,
  op : String,
) -> @value.Value raise EvalErr {
  match (lv, rv) {
    (@value.Value::IntVal(a), @value.Value::IntVal(b)) => {
      let r = match op {
        "land" => a.land(b)
        "lor" => a.lor(b)
        "lxor" => a.lxor(b)
        _ => a
      }
      @value.Value::IntVal(r)
    }
    _ =>
      raise EvalErr(
        make_eval_error(
          ctx,
          "bitwise op requires integers, got '\{@value.type_name(lv)}' and '\{@value.type_name(rv)}'",
        ),
      )
  }
}

///|
fn eval_shift(
  ctx : EvalContext,
  lv : @value.Value,
  rv : @value.Value,
  _pos : @errors.Position,
  dir : String,
) -> @value.Value raise EvalErr {
  match (lv, rv) {
    (@value.Value::IntVal(a), @value.Value::IntVal(b)) => {
      if b < 0L {
        raise EvalErr(make_eval_error(ctx, "shift count is negative"))
      }
      let shift = b.to_int()
      let r = match dir {
        "lshift" => a << shift
        _ => a >> shift
      }
      @value.Value::IntVal(r)
    }
    _ =>
      raise EvalErr(
        make_eval_error(
          ctx,
          "shift requires integers, got '\{@value.type_name(lv)}' and '\{@value.type_name(rv)}'",
        ),
      )
  }
}

///|
fn eval_cmp(
  ctx : EvalContext,
  lv : @value.Value,
  rv : @value.Value,
  _pos : @errors.Position,
  strict_sign : Int,
  strict : Bool,
  _unused : Bool,
) -> @value.Value raise EvalErr {
  let c = check(ctx, @value.compare_values(lv, rv))
  let result = if strict {
    if strict_sign > 0 {
      c > 0
    } else {
      c < 0
    }
  } else if strict_sign > 0 {
    c >= 0
  } else {
    c <= 0
  }
  @value.Value::BoolVal(result)
}

///|
fn in_op(
  ctx : EvalContext,
  needle : @value.Value,
  haystack : @value.Value,
  _pos : @errors.Position,
) -> @value.Value raise EvalErr {
  match haystack {
    @value.Value::ListVal(l) => {
      for item in l.items {
        if @value.starlark_equals(needle, item) {
          return @value.Value::BoolVal(true)
        }
      }
      @value.Value::BoolVal(false)
    }
    @value.Value::TupleVal(t) => {
      for item in t {
        if @value.starlark_equals(needle, item) {
          return @value.Value::BoolVal(true)
        }
      }
      @value.Value::BoolVal(false)
    }
    @value.Value::DictVal(d) =>
      match check(ctx, d.get(needle)) {
        None => @value.Value::BoolVal(false)
        Some(_) => @value.Value::BoolVal(true)
      }
    @value.Value::SetVal(s) =>
      @value.Value::BoolVal(check(ctx, s.contains(needle)))
    @value.Value::StrVal(s) =>
      match needle {
        @value.Value::StrVal(n) => @value.Value::BoolVal(s.raw.contains(n.raw))
        _ =>
          raise EvalErr(
            make_eval_error(
              ctx, "'in <string>' requires string as left operand",
            ),
          )
      }
    @value.Value::RangeVal(r) =>
      match needle {
        @value.Value::IntVal(n) => @value.Value::BoolVal(r.contains(n))
        _ => @value.Value::BoolVal(false)
      }
    _ =>
      raise EvalErr(
        make_eval_error(
          ctx,
          "argument of type '\{@value.type_name(haystack)}' is not iterable",
        ),
      )
  }
}

///|
fn eval_index(
  ctx : EvalContext,
  obj : @value.Value,
  idx : @value.Value,
  _pos : @errors.Position,
) -> @value.Value raise EvalErr {
  match obj {
    @value.Value::ListVal(l) =>
      match idx {
        @value.Value::IntVal(i) => {
          let j = check(ctx, adjust_index(i, l.items.length()))
          l.items[j]
        }
        _ =>
          raise EvalErr(make_eval_error(ctx, "list indices must be integers"))
      }
    @value.Value::TupleVal(t) =>
      match idx {
        @value.Value::IntVal(i) => {
          let j = check(ctx, adjust_index(i, t.length()))
          t[j]
        }
        _ =>
          raise EvalErr(make_eval_error(ctx, "tuple indices must be integers"))
      }
    @value.Value::StrVal(s) =>
      match idx {
        @value.Value::IntVal(i) => {
          let j = check(ctx, adjust_index(i, s.byte_len()))
          let one_byte = Bytes::from_array([s.byte_at(j)])
          @value.Value::StrVal(@value.StarlarkString::from_bytes(one_byte))
        }
        _ =>
          raise EvalErr(make_eval_error(ctx, "string indices must be integers"))
      }
    @value.Value::BytesVal(b) =>
      match idx {
        @value.Value::IntVal(i) => {
          let j = check(ctx, adjust_index(i, b.length()))
          @value.Value::IntVal(b[j].to_int().to_int64())
        }
        _ =>
          raise EvalErr(make_eval_error(ctx, "bytes indices must be integers"))
      }
    @value.Value::DictVal(d) =>
      match check(ctx, d.get(idx)) {
        None =>
          raise EvalErr(
            make_eval_error(ctx, "key not found: \{@value.repr(idx)}"),
          )
        Some(v) => v
      }
    @value.Value::RangeVal(r) =>
      match idx {
        @value.Value::IntVal(i) => {
          let j = check(ctx, adjust_index(i, r.length()))
          @value.Value::IntVal(r.index_at(j))
        }
        _ =>
          raise EvalErr(make_eval_error(ctx, "range indices must be integers"))
      }
    _ =>
      raise EvalErr(
        make_eval_error(
          ctx,
          "'\{@value.type_name(obj)}' object is not subscriptable",
        ),
      )
  }
}

///|
fn set_index(
  ctx : EvalContext,
  obj : @value.Value,
  idx : @value.Value,
  val : @value.Value,
  _pos : @errors.Position,
) -> Unit raise EvalErr {
  match obj {
    @value.Value::ListVal(l) => {
      check(ctx, l.check_mutable("assign to"))
      match idx {
        @value.Value::IntVal(i) => {
          let j = check(ctx, adjust_index(i, l.items.length()))
          l.items[j] = val
        }
        _ =>
          raise EvalErr(make_eval_error(ctx, "list indices must be integers"))
      }
    }
    @value.Value::DictVal(d) => check(ctx, d.set(idx, val))
    _ =>
      raise EvalErr(
        make_eval_error(
          ctx,
          "'\{@value.type_name(obj)}' object does not support item assignment",
        ),
      )
  }
}

///|
fn eval_slice(
  ctx : EvalContext,
  obj : @value.Value,
  lo_opt : Int?,
  hi_opt : Int?,
  step_opt : Int?,
) -> @value.Value raise EvalErr {
  let step = match step_opt {
    None => 1
    Some(s) => s
  }
  if step == 0 {
    raise EvalErr(make_eval_error(ctx, "slice step cannot be zero"))
  }
  match obj {
    @value.Value::ListVal(l) => {
      let len = l.items.length()
      let (start, stop) = normalize_slice(lo_opt, hi_opt, len, step)
      let items : Array[@value.Value] = []
      if step > 0 {
        let mut i = start
        while i < stop {
          items.push(l.items[i])
          i += step
        }
      } else {
        let mut i = start
        while i > stop {
          items.push(l.items[i])
          i += step
        }
      }
      @value.Value::ListVal(@value.StarlarkList::new(items))
    }
    @value.Value::TupleVal(t) => {
      let len = t.length()
      let (start, stop) = normalize_slice(lo_opt, hi_opt, len, step)
      let items : Array[@value.Value] = []
      if step > 0 {
        let mut i = start
        while i < stop {
          items.push(t[i])
          i += step
        }
      } else {
        let mut i = start
        while i > stop {
          items.push(t[i])
          i += step
        }
      }
      @value.Value::TupleVal(items)
    }
    @value.Value::StrVal(s) => {
      let len = s.byte_len()
      let (start, stop) = normalize_slice(lo_opt, hi_opt, len, step)
      let bytes_arr : Array[Byte] = []
      if step > 0 {
        let mut i = start
        while i < stop {
          bytes_arr.push(s.byte_at(i))
          i += step
        }
      } else {
        let mut i = start
        while i > stop {
          bytes_arr.push(s.byte_at(i))
          i += step
        }
      }
      @value.Value::StrVal(
        @value.StarlarkString::from_bytes(Bytes::from_array(bytes_arr)),
      )
    }
    _ =>
      raise EvalErr(
        make_eval_error(
          ctx,
          "'\{@value.type_name(obj)}' object is not sliceable",
        ),
      )
  }
}

///|
fn normalize_slice(
  lo_opt : Int?,
  hi_opt : Int?,
  len : Int,
  step : Int,
) -> (Int, Int) {
  if step > 0 {
    let start = match lo_opt {
      None => 0
      Some(i) => {
        let j = if i < 0 { i + len } else { i }
        if j < 0 {
          0
        } else if j > len {
          len
        } else {
          j
        }
      }
    }
    let stop = match hi_opt {
      None => len
      Some(i) => {
        let j = if i < 0 { i + len } else { i }
        if j < 0 {
          0
        } else if j > len {
          len
        } else {
          j
        }
      }
    }
    (start, stop)
  } else {
    let start = match lo_opt {
      None => len - 1
      Some(i) => {
        let j = if i < 0 { i + len } else { i }
        if j < 0 {
          -1
        } else if j >= len {
          len - 1
        } else {
          j
        }
      }
    }
    let stop = match hi_opt {
      None => -1
      Some(i) => {
        let j = if i < 0 { i + len } else { i }
        if j < -1 {
          -1
        } else if j >= len {
          len - 1
        } else {
          j
        }
      }
    }
    (start, stop)
  }
}

///|
fn aug_to_bin_op(aug_op : @syntax.AugOp) -> @syntax.BinaryOp {
  match aug_op {
    @syntax.AugOp::AugAdd => @syntax.BinaryOp::OpAdd
    @syntax.AugOp::AugSub => @syntax.BinaryOp::OpSub
    @syntax.AugOp::AugMul => @syntax.BinaryOp::OpMul
    @syntax.AugOp::AugDiv => @syntax.BinaryOp::OpDiv
    @syntax.AugOp::AugFloorDiv => @syntax.BinaryOp::OpFloorDiv
    @syntax.AugOp::AugMod => @syntax.BinaryOp::OpMod
    @syntax.AugOp::AugBitAnd => @syntax.BinaryOp::OpBitAnd
    @syntax.AugOp::AugBitOr => @syntax.BinaryOp::OpBitOr
    @syntax.AugOp::AugBitXor => @syntax.BinaryOp::OpBitXor
    @syntax.AugOp::AugLShift => @syntax.BinaryOp::OpLShift
    @syntax.AugOp::AugRShift => @syntax.BinaryOp::OpRShift
  }
}
