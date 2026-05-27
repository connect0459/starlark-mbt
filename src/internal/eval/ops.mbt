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
    @syntax.BinaryOp::OpLt => eval_cmp(ctx, lv, rv, pos, -1, true)
    @syntax.BinaryOp::OpLe => eval_cmp(ctx, lv, rv, pos, -1, false)
    @syntax.BinaryOp::OpGt => eval_cmp(ctx, lv, rv, pos, 1, true)
    @syntax.BinaryOp::OpGe => eval_cmp(ctx, lv, rv, pos, 1, false)
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
      for v in a.iter() {
        items.push(v)
      }
      for v in b.iter() {
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
          "unknown binary op: \{@value.type_name(lv)} + \{@value.type_name(rv)}",
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
    (@value.Value::SetVal(ls), @value.Value::SetVal(rs)) => {
      let result = @value.StarlarkSet::new()
      ls.each(fn(v) {
        match rs.contains(v) {
          Ok(false) => ignore(result.add(v))
          _ => ()
        }
      })
      @value.Value::SetVal(result)
    }
    _ =>
      raise EvalErr(
        make_eval_error(
          ctx,
          "unknown binary op: \{@value.type_name(lv)} - \{@value.type_name(rv)}",
        ),
      )
  }
}

///|
fn eval_mul(
  ctx : EvalContext,
  lv : @value.Value,
  rv : @value.Value,
  _pos : @errors.Position,
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
      @value.Value::StrVal(check(ctx, repeat_string(s, n)))
    (@value.Value::IntVal(n), @value.Value::StrVal(s)) =>
      @value.Value::StrVal(check(ctx, repeat_string(s, n)))
    (@value.Value::ListVal(l), @value.Value::IntVal(n)) =>
      @value.Value::ListVal(check(ctx, repeat_list(l, n)))
    (@value.Value::IntVal(n), @value.Value::ListVal(l)) =>
      @value.Value::ListVal(check(ctx, repeat_list(l, n)))
    (@value.Value::TupleVal(t), @value.Value::IntVal(n)) =>
      @value.Value::TupleVal(check(ctx, repeat_tuple(t, n)))
    (@value.Value::IntVal(n), @value.Value::TupleVal(t)) =>
      @value.Value::TupleVal(check(ctx, repeat_tuple(t, n)))
    (@value.Value::BytesVal(b), @value.Value::IntVal(n)) =>
      @value.Value::BytesVal(check(ctx, repeat_bytes(b, n)))
    (@value.Value::IntVal(n), @value.Value::BytesVal(b)) =>
      @value.Value::BytesVal(check(ctx, repeat_bytes(b, n)))
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
let max_int32 : Int64 = 2147483647L

///|
let max_alloc : Int = 1073741824

///|
let max_int64_shift : Int64 = 63L

///|
let max_byte_val : Int64 = 255L

///|
fn repeat_string(
  s : @value.StarlarkString,
  n : Int64,
) -> Result[@value.StarlarkString, String] {
  if n <= 0L {
    return Ok(@value.StarlarkString::new(""))
  }
  if n > max_int32 {
    return Err("repeat count \{n} too large")
  }
  let count = n.to_int()
  let byte_len = s.byte_len()
  if byte_len > 0 && count > max_alloc / byte_len {
    return Err("excessive repeat (\{byte_len} * \{count} elements)")
  }
  let buf = StringBuilder::new()
  for _ in 0..<count {
    buf.write_string(s.raw)
  }
  Ok(@value.StarlarkString::new(buf.to_string()))
}

///|
fn repeat_list(
  l : @value.StarlarkList,
  n : Int64,
) -> Result[@value.StarlarkList, String] {
  if n <= 0L {
    return Ok(@value.StarlarkList::new([]))
  }
  if n > max_int32 {
    return Err("repeat count \{n} too large")
  }
  let count = n.to_int()
  let elem_len = l.length()
  if elem_len > 0 && count > max_alloc / elem_len {
    return Err("excessive repeat (\{elem_len} * \{count} elements)")
  }
  let items : Array[@value.Value] = []
  for _ in 0..<count {
    for v in l.iter() {
      items.push(v)
    }
  }
  Ok(@value.StarlarkList::new(items))
}

///|
fn repeat_tuple(
  t : Array[@value.Value],
  n : Int64,
) -> Result[Array[@value.Value], String] {
  if n <= 0L {
    return Ok([])
  }
  if n > max_int32 {
    return Err("repeat count \{n} too large")
  }
  let count = n.to_int()
  let elem_len = t.length()
  if elem_len > 0 && count > max_alloc / elem_len {
    return Err("excessive repeat (\{elem_len} * \{count} elements)")
  }
  let items : Array[@value.Value] = []
  for _ in 0..<count {
    for v in t {
      items.push(v)
    }
  }
  Ok(items)
}

///|
fn repeat_bytes(b : Bytes, n : Int64) -> Result[Bytes, String] {
  if n <= 0L {
    return Ok(Bytes::from_array([]))
  }
  if n > max_int32 {
    return Err("repeat count \{n} too large")
  }
  let count = n.to_int()
  let byte_len = b.length()
  if byte_len > 0 && count > max_alloc / byte_len {
    return Err("excessive repeat (\{byte_len} * \{count} elements)")
  }
  let items : Array[Byte] = []
  for _ in 0..<count {
    for i in 0..<byte_len {
      items.push(b[i])
    }
  }
  Ok(Bytes::from_array(items))
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
fn float_floor_mod(a : Double, b : Double) -> Double {
  let r = a % b
  if r != 0.0 && (r < 0.0) != (b < 0.0) {
    r + b
  } else {
    r
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
      @value.Value::FloatVal(float_floor_mod(a, b))
    }
    (@value.Value::IntVal(a), @value.Value::FloatVal(b)) => {
      if b == 0.0 {
        raise EvalErr(make_eval_error(ctx, "float modulo by zero"))
      }
      @value.Value::FloatVal(float_floor_mod(a.to_double(), b))
    }
    (@value.Value::FloatVal(a), @value.Value::IntVal(b)) => {
      if b == 0L {
        raise EvalErr(make_eval_error(ctx, "float modulo by zero"))
      }
      @value.Value::FloatVal(float_floor_mod(a, b.to_double()))
    }
    (@value.Value::StrVal(s), _) => check(ctx, percent_format(s.raw, rv))
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
fn percent_format(
  fmt : String,
  args : @value.Value,
) -> Result[@value.Value, String] {
  let arg_list : Array[@value.Value] = match args {
    @value.Value::TupleVal(t) => t
    v => [v]
  }
  let buf = StringBuilder::new()
  let chars = fmt.to_array()
  let n = chars.length()
  let mut i = 0
  let mut arg_idx = 0
  while i < n {
    let c = chars[i]
    if c != '%' {
      buf.write_char(c)
      i += 1
      continue
    }
    i += 1
    if i >= n {
      return Err("incomplete format specifier")
    }
    let spec = chars[i]
    i += 1
    if spec == '%' {
      buf.write_char('%')
      continue
    }
    if arg_idx >= arg_list.length() {
      return Err("not enough arguments for format string")
    }
    let arg = arg_list[arg_idx]
    arg_idx += 1
    match spec {
      's' => buf.write_string(@value.to_str(arg))
      'r' => buf.write_string(@value.repr(arg))
      'd' | 'i' =>
        match arg {
          @value.Value::IntVal(n2) => buf.write_string(n2.to_string())
          @value.Value::FloatVal(f) =>
            buf.write_string(f.to_int64().to_string())
          @value.Value::BoolVal(_) => return Err("cannot convert bool to int")
          _ => return Err("cannot convert \{@value.type_name(arg)} to int")
        }
      'o' =>
        match arg {
          @value.Value::IntVal(n2) =>
            if n2 < 0L {
              buf.write_char('-')
              buf.write_string(int64_to_octal(n2.abs()))
            } else {
              buf.write_string(int64_to_octal(n2))
            }
          @value.Value::FloatVal(f) => {
            let n2 = f.to_int64()
            if n2 < 0L {
              buf.write_char('-')
              buf.write_string(int64_to_octal(n2.abs()))
            } else {
              buf.write_string(int64_to_octal(n2))
            }
          }
          @value.Value::BoolVal(_) => return Err("cannot convert bool to int")
          _ => return Err("cannot convert \{@value.type_name(arg)} to int")
        }
      'x' =>
        match arg {
          @value.Value::IntVal(n2) =>
            if n2 < 0L {
              buf.write_char('-')
              buf.write_string(int64_to_hex(n2.abs(), false))
            } else {
              buf.write_string(int64_to_hex(n2, false))
            }
          @value.Value::FloatVal(f) => {
            let n2 = f.to_int64()
            if n2 < 0L {
              buf.write_char('-')
              buf.write_string(int64_to_hex(n2.abs(), false))
            } else {
              buf.write_string(int64_to_hex(n2, false))
            }
          }
          @value.Value::BoolVal(_) => return Err("cannot convert bool to int")
          _ => return Err("cannot convert \{@value.type_name(arg)} to int")
        }
      'X' =>
        match arg {
          @value.Value::IntVal(n2) =>
            if n2 < 0L {
              buf.write_char('-')
              buf.write_string(int64_to_hex(n2.abs(), true))
            } else {
              buf.write_string(int64_to_hex(n2, true))
            }
          @value.Value::FloatVal(f) => {
            let n2 = f.to_int64()
            if n2 < 0L {
              buf.write_char('-')
              buf.write_string(int64_to_hex(n2.abs(), true))
            } else {
              buf.write_string(int64_to_hex(n2, true))
            }
          }
          @value.Value::BoolVal(_) => return Err("cannot convert bool to int")
          _ => return Err("cannot convert \{@value.type_name(arg)} to int")
        }
      'e' | 'E' | 'f' | 'g' | 'G' => {
        let f = match arg {
          @value.Value::FloatVal(f) => f
          @value.Value::IntVal(n2) => n2.to_double()
          _ => return Err("cannot convert \{@value.type_name(arg)} to float")
        }
        let s2 = match spec {
          'e' => format_float_e(f, false)
          'E' => format_float_e(f, true)
          'f' => format_float_fg(f)
          'g' | 'G' => {
            let s3 = format_float_fg(f)
            if spec == 'G' && !f.is_nan() && !f.is_inf() {
              s3.to_upper()
            } else {
              s3
            }
          }
          _ => ""
        }
        buf.write_string(s2)
      }
      'c' =>
        match arg {
          @value.Value::IntVal(n2) => {
            let cp = n2.to_int()
            if cp < 0 || cp > 0x10FFFF {
              return Err("%c requires a valid Unicode code point")
            }
            buf.write_char(cp.unsafe_to_char())
          }
          @value.Value::StrVal(s2) =>
            if s2.raw.length() == 1 {
              buf.write_string(s2.raw)
            } else {
              return Err("%c requires a single-character string")
            }
          _ => return Err("%c requires a single-character string")
        }
      _ => return Err("unknown format specifier '%\{spec}'")
    }
  }
  if arg_idx < arg_list.length() {
    return Err("too many arguments for format string")
  }
  Ok(@value.Value::StrVal(@value.StarlarkString::new(buf.to_string())))
}

///|
fn int64_to_octal(n : Int64) -> String {
  if n == 0L {
    return "0"
  }
  let buf = StringBuilder::new()
  let mut v = n
  let digits : Array[Int] = []
  while v > 0L {
    digits.push((v % 8L).to_int())
    v = v / 8L
  }
  let mut j = digits.length() - 1
  while j >= 0 {
    buf.write_char(('0'.to_int() + digits[j]).unsafe_to_char())
    j -= 1
  }
  buf.to_string()
}

///|
fn int64_to_hex(n : Int64, upper : Bool) -> String {
  if n == 0L {
    return "0"
  }
  let buf = StringBuilder::new()
  let mut v = n
  let digits : Array[Int] = []
  while v > 0L {
    digits.push((v % 16L).to_int())
    v = v / 16L
  }
  let base_char = if upper { 'A'.to_int() } else { 'a'.to_int() }
  let mut j = digits.length() - 1
  while j >= 0 {
    let d = digits[j]
    if d < 10 {
      buf.write_char(('0'.to_int() + d).unsafe_to_char())
    } else {
      buf.write_char((base_char + d - 10).unsafe_to_char())
    }
    j -= 1
  }
  buf.to_string()
}

///|
fn format_special_float(f : Double) -> String? {
  if f.is_nan() {
    Some("nan")
  } else if f == @double.infinity {
    Some("+inf")
  } else if f == @double.neg_infinity {
    Some("-inf")
  } else {
    None
  }
}

///|
fn format_float_e(f : Double, upper : Bool) -> String {
  match format_special_float(f) {
    Some(s) => s
    None => {
      let s = f.to_string()
      if upper {
        s.to_upper()
      } else {
        s
      }
    }
  }
}

///|
fn format_float_fg(f : Double) -> String {
  match format_special_float(f) {
    Some(s) => s
    None => f.to_string()
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
  if n.to_double() == exp && n >= -max_int64_shift && n <= max_int64_shift {
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
  let op_char = match op {
    "land" => "&"
    "lor" => "|"
    _ => "^"
  }
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
    (@value.Value::DictVal(ld), @value.Value::DictVal(rd)) if op == "lor" => {
      let result = @value.StarlarkDict::new()
      ld.each(fn(k, v) { ignore(result.set(k, v)) })
      rd.each(fn(k, v) { ignore(result.set(k, v)) })
      @value.Value::DictVal(result)
    }
    (@value.Value::DictVal(_), _) if op == "lor" =>
      raise EvalErr(
        make_eval_error(
          ctx,
          "unknown binary op: dict | \{@value.type_name(rv)}",
        ),
      )
    (@value.Value::SetVal(ls), @value.Value::SetVal(rs)) => {
      let result = @value.StarlarkSet::new()
      match op {
        "lor" => {
          ls.each(fn(v) { ignore(result.add(v)) })
          rs.each(fn(v) { ignore(result.add(v)) })
        }
        "land" =>
          ls.each(fn(v) {
            match rs.contains(v) {
              Ok(true) => ignore(result.add(v))
              _ => ()
            }
          })
        _ => {
          ls.each(fn(v) {
            match rs.contains(v) {
              Ok(false) => ignore(result.add(v))
              _ => ()
            }
          })
          rs.each(fn(v) {
            match ls.contains(v) {
              Ok(false) => ignore(result.add(v))
              _ => ()
            }
          })
        }
      }
      @value.Value::SetVal(result)
    }
    (@value.Value::SetVal(_), _) =>
      raise EvalErr(
        make_eval_error(
          ctx,
          "unknown binary op: set \{op_char} \{@value.type_name(rv)}",
        ),
      )
    (_, @value.Value::SetVal(_)) =>
      raise EvalErr(
        make_eval_error(
          ctx,
          "unknown binary op: \{@value.type_name(lv)} \{op_char} set",
        ),
      )
    _ =>
      raise EvalErr(
        make_eval_error(
          ctx,
          "unknown binary op: \{@value.type_name(lv)} \{op_char} \{@value.type_name(rv)}",
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
        raise EvalErr(make_eval_error(ctx, "negative shift count"))
      }
      if b > max_int64_shift {
        raise EvalErr(make_eval_error(ctx, "shift count too large"))
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
fn set_is_subset(s1 : @value.StarlarkSet, s2 : @value.StarlarkSet) -> Bool {
  let mut all_in = true
  s1.each(fn(v) {
    if all_in {
      match s2.contains(v) {
        Ok(true) => ()
        _ => all_in = false
      }
    }
  })
  all_in
}

///|
fn eval_cmp(
  ctx : EvalContext,
  lv : @value.Value,
  rv : @value.Value,
  _pos : @errors.Position,
  strict_sign : Int,
  strict : Bool,
) -> @value.Value raise EvalErr {
  match (lv, rv) {
    (@value.Value::SetVal(ls), @value.Value::SetVal(rs)) => {
      let result = if strict_sign > 0 {
        let is_sup = set_is_subset(rs, ls)
        if strict {
          is_sup && ls.length() > rs.length()
        } else {
          is_sup
        }
      } else {
        let is_sub = set_is_subset(ls, rs)
        if strict {
          is_sub && ls.length() < rs.length()
        } else {
          is_sub
        }
      }
      @value.Value::BoolVal(result)
    }
    _ => {
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
  }
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
      for item in l.iter() {
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
      match d.get(needle) {
        Ok(Some(_)) => @value.Value::BoolVal(true)
        _ => @value.Value::BoolVal(false)
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
        @value.Value::FloatVal(f) =>
          if f.is_nan() || f.is_inf() {
            @value.Value::BoolVal(false)
          } else {
            let n = f.to_int64()
            if n.to_double() != f {
              @value.Value::BoolVal(false)
            } else {
              @value.Value::BoolVal(r.contains(n))
            }
          }
        _ =>
          raise EvalErr(
            make_eval_error(
              ctx,
              "'in <range>' requires integer as left operand, not \{@value.type_name(needle)}",
            ),
          )
      }
    @value.Value::BytesVal(haystack_b) =>
      match needle {
        @value.Value::BytesVal(needle_b) => {
          let hlen = haystack_b.length()
          let nlen = needle_b.length()
          if nlen == 0 {
            return @value.Value::BoolVal(true)
          }
          if nlen > hlen {
            return @value.Value::BoolVal(false)
          }
          let mut found = false
          for i in 0..<=(hlen - nlen) {
            let mut match_ = true
            for j in 0..<nlen {
              if haystack_b[i + j] != needle_b[j] {
                match_ = false
                break
              }
            }
            if match_ {
              found = true
              break
            }
          }
          @value.Value::BoolVal(found)
        }
        @value.Value::IntVal(n) => {
          if n < 0L || n > max_byte_val {
            raise EvalErr(
              make_eval_error(ctx, "int in bytes: \{n} out of range"),
            )
          }
          let b = n.to_int().to_byte()
          let mut found = false
          for i in 0..<haystack_b.length() {
            if haystack_b[i] == b {
              found = true
              break
            }
          }
          @value.Value::BoolVal(found)
        }
        _ =>
          raise EvalErr(
            make_eval_error(
              ctx,
              "'in <bytes>' requires bytes or int as left operand, not \{@value.type_name(needle)}",
            ),
          )
      }
    _ =>
      raise EvalErr(
        make_eval_error(
          ctx,
          "unknown binary op: \{@value.type_name(needle)} in \{@value.type_name(haystack)}",
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
          let j = check(ctx, adjust_index(i, l.length()))
          l.get(j)
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
          @value.Value::BytesVal(Bytes::from_array([b[j]]))
        }
        _ =>
          raise EvalErr(make_eval_error(ctx, "bytes indices must be integers"))
      }
    @value.Value::DictVal(d) =>
      match check(ctx, d.get(idx)) {
        None =>
          raise EvalErr(
            make_eval_error(ctx, "key \{@value.repr(idx)} not in dict"),
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
          "unhandled index operation: \{@value.type_name(obj)}",
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
    @value.Value::ListVal(l) =>
      match idx {
        @value.Value::IntVal(i) => {
          let j = check(ctx, adjust_index(i, l.length()))
          check(ctx, l.set(j, val))
        }
        _ =>
          raise EvalErr(make_eval_error(ctx, "list indices must be integers"))
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
      let len = l.length()
      let (start, stop) = normalize_slice(lo_opt, hi_opt, len, step)
      let items : Array[@value.Value] = []
      if step > 0 {
        let mut i = start
        while i < stop {
          items.push(l.get(i))
          i += step
        }
      } else {
        let mut i = start
        while i > stop {
          items.push(l.get(i))
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
    @value.Value::RangeVal(r) => {
      let len = r.length()
      let (start, end_idx) = normalize_slice(lo_opt, hi_opt, len, step)
      let new_start = r.start() + r.step() * start.to_int64()
      let new_stop = r.start() + r.step() * end_idx.to_int64()
      let new_step = r.step() * step.to_int64()
      @value.Value::RangeVal(
        @value.StarlarkRange::new(new_start, new_stop, new_step),
      )
    }
    @value.Value::BytesVal(b) => {
      let len = b.length()
      let (start, stop) = normalize_slice(lo_opt, hi_opt, len, step)
      let bytes_arr : Array[Byte] = []
      if step > 0 {
        let mut i = start
        while i < stop {
          bytes_arr.push(b[i])
          i += step
        }
      } else {
        let mut i = start
        while i > stop {
          bytes_arr.push(b[i])
          i += step
        }
      }
      @value.Value::BytesVal(Bytes::from_array(bytes_arr))
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
