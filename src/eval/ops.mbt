///|
/// Translates a Starlark index `i` for a sequence of `length` elements into a
/// non-negative offset. Negative indices count from the end. Returns `Err` when
/// `i` falls outside Go's int32 range (matching starlark-go's `AsInt32` check)
/// or the adjusted offset is out of bounds.
fn adjust_index(
  i : BigInt,
  length : Int64,
  type_name : String,
) -> Result[Int64, String] {
  // Go's AsInt32: fail if value doesn't fit int32 range.
  // Produces "<type> index: N out of range" (no range bounds).
  if i > max_int32 || i < min_int32 {
    return Err("\{type_name} index: \{i} out of range")
  }
  let len = BigInt::from_int64(length)
  let j = if i < 0N { i + len } else { i }
  if j < 0N || j >= len {
    if length == 0L {
      Err("index \{i} out of range: empty \{type_name}")
    } else {
      Err("\{type_name} index \{i} out of range [\{-length}:\{length - 1L}]")
    }
  } else {
    Ok(j.to_int64())
  }
}

///|
/// Returns the source spelling of a unary operator, used in
/// "unknown unary op" error messages.
fn unary_op_to_str(op : @syntax.UnaryOp) -> String {
  match op {
    @syntax.UnaryOp::OpPlus => "+"
    @syntax.UnaryOp::OpMinus => "-"
    @syntax.UnaryOp::OpBitNot => "~"
    @syntax.UnaryOp::OpNot => "not"
  }
}

///|
/// Returns the source spelling of a binary arithmetic/bitwise operator, used
/// in "unknown binary op" error messages.
fn op_to_str(op : @syntax.BinaryOp) -> String {
  match op {
    @syntax.BinaryOp::OpAdd => "+"
    @syntax.BinaryOp::OpSub => "-"
    @syntax.BinaryOp::OpMul => "*"
    @syntax.BinaryOp::OpDiv => "/"
    @syntax.BinaryOp::OpFloorDiv => "//"
    @syntax.BinaryOp::OpMod => "%"
    @syntax.BinaryOp::OpBitAnd => "&"
    @syntax.BinaryOp::OpBitOr => "|"
    @syntax.BinaryOp::OpBitXor => "^"
    @syntax.BinaryOp::OpLShift => "<<"
    @syntax.BinaryOp::OpRShift => ">>"
    _ => "?"
  }
}

///|
/// Applies a unary operator to `v`. Custom values are given first refusal via
/// their `get_unary` hook; all built-in types are handled inline.
fn eval_unary(
  ctx : EvalContext,
  op : @syntax.UnaryOp,
  v : @value.Value,
  _pos : @errors.Position,
) -> @value.Value raise EvalErr {
  if v is @value.Value::ExtVal(c) {
    match c.get_unary(unary_op_to_str(op)) {
      Some(Ok(r)) => return r
      Some(Err(e)) => raise EvalErr(make_eval_error(ctx, e))
      None => ()
    }
  }
  match op {
    @syntax.UnaryOp::OpPlus =>
      match v {
        @value.Value::Int(_) | @value.Value::Float(_) => v
        _ =>
          raise EvalErr(
            make_eval_error(ctx, "unknown unary op: + \{v.type_name()}"),
          )
      }
    @syntax.UnaryOp::OpMinus =>
      match v {
        @value.Value::Int(n) => @value.Value::Int(-n)
        @value.Value::Float(f) => @value.Value::Float(-f)
        _ =>
          raise EvalErr(
            make_eval_error(ctx, "unknown unary op: - \{v.type_name()}"),
          )
      }
    @syntax.UnaryOp::OpBitNot =>
      match v {
        @value.Value::Int(n) => @value.Value::Int(-n - 1N)
        _ =>
          raise EvalErr(
            make_eval_error(ctx, "unknown unary op: ~ \{v.type_name()}"),
          )
      }
    @syntax.UnaryOp::OpNot => @value.Value::Bool(!v.truth())
  }
}

///|
/// Applies a binary operator to `lv` and `rv`. Left-hand `ExtVal`s are given
/// first refusal, then right-hand; both non-`ExtVal` pairs dispatch to the
/// operator-specific sub-functions below. `and`/`or` short-circuit before
/// reaching this function and must not be passed here.
fn eval_binary(
  ctx : EvalContext,
  lv : @value.Value,
  op : @syntax.BinaryOp,
  rv : @value.Value,
  pos : @errors.Position,
) -> @value.Value raise EvalErr {
  if lv is @value.Value::ExtVal(lc) {
    match lc.get_binary(op_to_str(op), rv, true) {
      Some(Ok(v)) => return v
      Some(Err(e)) => raise EvalErr(make_eval_error(ctx, e))
      None => ()
    }
  }
  if rv is @value.Value::ExtVal(rc) {
    match rc.get_binary(op_to_str(op), lv, false) {
      Some(Ok(v)) => return v
      Some(Err(e)) => raise EvalErr(make_eval_error(ctx, e))
      None => ()
    }
  }
  match op {
    @syntax.BinaryOp::OpAdd => eval_add(ctx, lv, rv, pos)
    @syntax.BinaryOp::OpSub => eval_arith_sub(ctx, lv, rv, pos)
    @syntax.BinaryOp::OpMul => eval_mul(ctx, lv, rv, pos)
    @syntax.BinaryOp::OpDiv => eval_div(ctx, lv, rv, pos)
    @syntax.BinaryOp::OpFloorDiv => eval_floor_div(ctx, lv, rv, pos)
    @syntax.BinaryOp::OpMod => eval_mod(ctx, lv, rv, pos)
    @syntax.BinaryOp::OpBitAnd => eval_bitwise(ctx, lv, rv, pos, "land")
    @syntax.BinaryOp::OpBitOr => eval_bitwise(ctx, lv, rv, pos, "lor")
    @syntax.BinaryOp::OpBitXor => eval_bitwise(ctx, lv, rv, pos, "lxor")
    @syntax.BinaryOp::OpLShift => eval_shift(ctx, lv, rv, pos, "lshift")
    @syntax.BinaryOp::OpRShift => eval_shift(ctx, lv, rv, pos, "rshift")
    @syntax.BinaryOp::OpEq =>
      match @value.starlark_equals_depth(lv, rv, @value.compare_limit) {
        Ok(b) => @value.Value::Bool(b)
        Err(e) => raise EvalErr(make_eval_error(ctx, e))
      }
    @syntax.BinaryOp::OpNe =>
      match @value.starlark_equals_depth(lv, rv, @value.compare_limit) {
        Ok(b) => @value.Value::Bool(!b)
        Err(e) => raise EvalErr(make_eval_error(ctx, e))
      }
    @syntax.BinaryOp::OpLt => eval_cmp(ctx, lv, rv, pos, -1, true)
    @syntax.BinaryOp::OpLe => eval_cmp(ctx, lv, rv, pos, -1, false)
    @syntax.BinaryOp::OpGt => eval_cmp(ctx, lv, rv, pos, 1, true)
    @syntax.BinaryOp::OpGe => eval_cmp(ctx, lv, rv, pos, 1, false)
    @syntax.BinaryOp::OpIn => in_op(ctx, lv, rv, pos)
    @syntax.BinaryOp::OpNotIn => {
      let r = in_op(ctx, lv, rv, pos)
      match r {
        @value.Value::Bool(b) => @value.Value::Bool(!b)
        _ => @value.Value::Bool(false)
      }
    }
    @syntax.BinaryOp::OpAnd | @syntax.BinaryOp::OpOr =>
      raise EvalErr(
        make_eval_error(ctx, "and/or must be handled before eval_binary"),
      )
  }
}

///|
/// Converts `n` to a finite `Double`, raising when the magnitude overflows
/// IEEE-754 double range.
fn finite_double(ctx : EvalContext, n : BigInt) -> Double raise EvalErr {
  match @numeric.bigint_to_finite_double(n) {
    Ok(f) => f
    Err(msg) => raise EvalErr(make_eval_error(ctx, msg))
  }
}

///|
/// Implements `+`: numeric addition for int/float pairs; concatenation for
/// string, bytes, list, and tuple.
fn eval_add(
  ctx : EvalContext,
  lv : @value.Value,
  rv : @value.Value,
  _pos : @errors.Position,
) -> @value.Value raise EvalErr {
  match (lv, rv) {
    (@value.Value::Int(a), @value.Value::Int(b)) => @value.Value::Int(a + b)
    (@value.Value::Float(a), @value.Value::Float(b)) =>
      @value.Value::Float(a + b)
    (@value.Value::Int(a), @value.Value::Float(b)) =>
      @value.Value::Float(finite_double(ctx, a) + b)
    (@value.Value::Float(a), @value.Value::Int(b)) =>
      @value.Value::Float(a + finite_double(ctx, b))
    (@value.Value::String(a), @value.Value::String(b)) => {
      let new_bytes : Array[Byte] = []
      let ab = a.to_bytes()
      for i in 0..<ab.length() {
        new_bytes.push(ab[i])
      }
      let bb = b.to_bytes()
      for i in 0..<bb.length() {
        new_bytes.push(bb[i])
      }
      @value.Value::String(
        @value.StarlarkString::from_bytes(Bytes::from_array(new_bytes)),
      )
    }
    (@value.Value::List(a), @value.Value::List(b)) => {
      let items : Array[@value.Value] = []
      for v in a.iter() {
        items.push(v)
      }
      for v in b.iter() {
        items.push(v)
      }
      @value.Value::List(@value.StarlarkList::new(items))
    }
    (@value.Value::Tuple(a), @value.Value::Tuple(b)) => {
      let items : Array[@value.Value] = []
      for v in a {
        items.push(v)
      }
      for v in b {
        items.push(v)
      }
      @value.Value::Tuple(items)
    }
    (@value.Value::Bytes(a), @value.Value::Bytes(b)) => {
      let items : Array[Byte] = []
      for i in 0..<a.length() {
        items.push(a[i])
      }
      for i in 0..<b.length() {
        items.push(b[i])
      }
      @value.Value::Bytes(Bytes::from_array(items))
    }
    _ =>
      raise EvalErr(
        make_eval_error(
          ctx,
          "unknown binary op: \{lv.type_name()} + \{rv.type_name()}",
        ),
      )
  }
}

///|
/// Implements `-`: numeric subtraction for int/float pairs; set difference for
/// set × set (elements in `lv` not in `rv`).
fn eval_arith_sub(
  ctx : EvalContext,
  lv : @value.Value,
  rv : @value.Value,
  _pos : @errors.Position,
) -> @value.Value raise EvalErr {
  match (lv, rv) {
    (@value.Value::Int(a), @value.Value::Int(b)) => @value.Value::Int(a - b)
    (@value.Value::Float(a), @value.Value::Float(b)) =>
      @value.Value::Float(a - b)
    (@value.Value::Int(a), @value.Value::Float(b)) =>
      @value.Value::Float(finite_double(ctx, a) - b)
    (@value.Value::Float(a), @value.Value::Int(b)) =>
      @value.Value::Float(a - finite_double(ctx, b))
    (@value.Value::Set(ls), @value.Value::Set(rs)) => {
      let result = @value.StarlarkSet::new()
      ls.each(fn(v) {
        match rs.contains(v) {
          Ok(false) => ignore(result.add(v))
          _ => ()
        }
      })
      @value.Value::Set(result)
    }
    _ =>
      raise EvalErr(
        make_eval_error(
          ctx,
          "unknown binary op: \{lv.type_name()} - \{rv.type_name()}",
        ),
      )
  }
}

///|
/// Implements `*`: numeric multiplication for int/float pairs; sequence
/// repetition (`seq * n` or `n * seq`) for string, bytes, list, and tuple.
fn eval_mul(
  ctx : EvalContext,
  lv : @value.Value,
  rv : @value.Value,
  _pos : @errors.Position,
) -> @value.Value raise EvalErr {
  match (lv, rv) {
    (@value.Value::Int(a), @value.Value::Int(b)) => @value.Value::Int(a * b)
    (@value.Value::Float(a), @value.Value::Float(b)) =>
      @value.Value::Float(a * b)
    (@value.Value::Int(a), @value.Value::Float(b)) =>
      @value.Value::Float(finite_double(ctx, a) * b)
    (@value.Value::Float(a), @value.Value::Int(b)) =>
      @value.Value::Float(a * finite_double(ctx, b))
    (@value.Value::String(s), @value.Value::Int(n)) =>
      @value.Value::String(check(ctx, repeat_string(s, n)))
    (@value.Value::Int(n), @value.Value::String(s)) =>
      @value.Value::String(check(ctx, repeat_string(s, n)))
    (@value.Value::List(l), @value.Value::Int(n)) =>
      @value.Value::List(check(ctx, repeat_list(l, n)))
    (@value.Value::Int(n), @value.Value::List(l)) =>
      @value.Value::List(check(ctx, repeat_list(l, n)))
    (@value.Value::Tuple(t), @value.Value::Int(n)) =>
      @value.Value::Tuple(check(ctx, repeat_tuple(t, n)))
    (@value.Value::Int(n), @value.Value::Tuple(t)) =>
      @value.Value::Tuple(check(ctx, repeat_tuple(t, n)))
    (@value.Value::Bytes(b), @value.Value::Int(n)) =>
      @value.Value::Bytes(check(ctx, repeat_bytes(b, n)))
    (@value.Value::Int(n), @value.Value::Bytes(b)) =>
      @value.Value::Bytes(check(ctx, repeat_bytes(b, n)))
    _ =>
      raise EvalErr(
        make_eval_error(
          ctx,
          "unknown binary op: \{lv.type_name()} * \{rv.type_name()}",
        ),
      )
  }
}

///|
/// Upper bound of Go's `AsInt32` range; slice/index values exceeding this are
/// out of range.
let max_int32 : BigInt = 2147483647N

///|
/// Lower bound of Go's `AsInt32` range; slice/index values below this are out
/// of range.
let min_int32 : BigInt = -2147483648N

///|
/// Maximum valid byte value (255); used to range-check `in bytes` with an int
/// needle.
let max_byte_val : BigInt = 255N

///|
/// Maximum left-shift count. Beyond 512 bits the BigInt would grow without
/// bound; shifts at or above this limit raise an error.
let max_lshift_bits : BigInt = 512N

///|
/// Maximum right-shift count used as a safe clamp. Beyond 1 000 000 bits the
/// result is always 0 (positive) or −1 (negative), so clamping avoids
/// `BigInt.to_int()` overflow.
let max_rshift_bits : BigInt = 1_000_000N

///|
/// Maximum valid Unicode code point (U+10FFFF), used for `%c` format
/// validation and `chr`.
let unicode_max_cp_bigint : BigInt = 0x10FFFFN

///|
/// Inclusive lower bound of the Unicode surrogate block (U+D800..U+DFFF).
let unicode_surr_first : Int = 0xD800

///|
/// Inclusive upper bound of the Unicode surrogate block (U+D800..U+DFFF).
let unicode_surr_last : Int = 0xDFFF

///|
/// Decimal places for `%e`/`%f` printf format, matching C's
/// `printf("%.6e")`/`printf("%.6f")`.
let printf_float_precision : Int = 6

///|
/// Validates the count for a sequence repeat (`seq * n`). Returns the resolved
/// element count, treating a non-positive `n` as 0 (empty result); errors when
/// the count exceeds int32 range or `elem_len * count` would exceed the
/// allocation cap.
fn checked_repeat_count(n : BigInt, elem_len : Int) -> Result[Int, String] {
  if n <= 0N {
    return Ok(0)
  }
  if n > max_int32 {
    return Err("repeat count \{n} too large")
  }
  let count = n.to_int()
  if elem_len > 0 &&
    elem_len.to_int64() * count.to_int64() >= max_alloc_elems.to_int64() {
    return Err("excessive repeat (\{elem_len} * \{count} elements)")
  }
  Ok(count)
}

///|
/// Repeats the bytes of `s` exactly `n` times. Non-positive `n` yields an
/// empty string; out-of-int32 or allocation-cap violations return an `Err`.
fn repeat_string(
  s : @value.StarlarkString,
  n : BigInt,
) -> Result[@value.StarlarkString, String] {
  let byte_len = s.byte_len()
  let count = match checked_repeat_count(n, byte_len) {
    Ok(c) => c
    Err(e) => return Err(e)
  }
  let original_bytes = s.to_bytes()
  let all_bytes : Array[Byte] = []
  for _ in 0..<count {
    for i in 0..<byte_len {
      all_bytes.push(original_bytes[i])
    }
  }
  Ok(@value.StarlarkString::from_bytes(Bytes::from_array(all_bytes)))
}

///|
/// Materializes `n` repetitions of `l`'s elements into a new list.
/// Non-positive `n` yields an empty list; violations of the count/allocation
/// cap return an `Err`.
fn repeat_list(
  l : @value.StarlarkList,
  n : BigInt,
) -> Result[@value.StarlarkList, String] {
  let count = match checked_repeat_count(n, l.length()) {
    Ok(c) => c
    Err(e) => return Err(e)
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
/// Materializes `n` repetitions of tuple `t` into a new element array.
/// Non-positive `n` yields an empty array; violations of the count/allocation
/// cap return an `Err`.
fn repeat_tuple(
  t : Array[@value.Value],
  n : BigInt,
) -> Result[Array[@value.Value], String] {
  let count = match checked_repeat_count(n, t.length()) {
    Ok(c) => c
    Err(e) => return Err(e)
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
/// Repeats the bytes of `b` exactly `n` times into a new `Bytes`.
/// Non-positive `n` yields empty bytes; violations of the count/allocation cap
/// return an `Err`.
fn repeat_bytes(b : Bytes, n : BigInt) -> Result[Bytes, String] {
  let byte_len = b.length()
  let count = match checked_repeat_count(n, byte_len) {
    Ok(c) => c
    Err(e) => return Err(e)
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
/// Implements real division (`/`). Raises when `allow_float` is off.
/// Division by zero is always an error regardless of the operand types.
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
    (@value.Value::Int(a), @value.Value::Int(b)) => {
      if b.is_zero() {
        raise EvalErr(make_eval_error(ctx, "floating-point division by zero"))
      }
      @value.Value::Float(finite_double(ctx, a) / finite_double(ctx, b))
    }
    (@value.Value::Float(a), @value.Value::Float(b)) => {
      if b == 0.0 {
        raise EvalErr(make_eval_error(ctx, "floating-point division by zero"))
      }
      @value.Value::Float(a / b)
    }
    (@value.Value::Int(a), @value.Value::Float(b)) => {
      if b == 0.0 {
        raise EvalErr(make_eval_error(ctx, "floating-point division by zero"))
      }
      @value.Value::Float(finite_double(ctx, a) / b)
    }
    (@value.Value::Float(a), @value.Value::Int(b)) => {
      if b.is_zero() {
        raise EvalErr(make_eval_error(ctx, "floating-point division by zero"))
      }
      @value.Value::Float(a / finite_double(ctx, b))
    }
    _ =>
      raise EvalErr(
        make_eval_error(
          ctx,
          "unknown binary op: \{lv.type_name()} / \{rv.type_name()}",
        ),
      )
  }
}

///|
/// Implements floor division (`//`). For int pairs, delegates to
/// `@numeric.floor_div` which produces Python's signed-floor semantics. For
/// float operands, divides then applies `floor`.
fn eval_floor_div(
  ctx : EvalContext,
  lv : @value.Value,
  rv : @value.Value,
  _pos : @errors.Position,
) -> @value.Value raise EvalErr {
  match (lv, rv) {
    (@value.Value::Int(a), @value.Value::Int(b)) =>
      @value.Value::Int(check(ctx, @numeric.floor_div(a, b)))
    (@value.Value::Float(a), @value.Value::Float(b)) => {
      if b == 0.0 {
        raise EvalErr(make_eval_error(ctx, "floored division by zero"))
      }
      @value.Value::Float((a / b).floor())
    }
    (@value.Value::Int(a), @value.Value::Float(b)) => {
      if b == 0.0 {
        raise EvalErr(make_eval_error(ctx, "floored division by zero"))
      }
      @value.Value::Float((finite_double(ctx, a) / b).floor())
    }
    (@value.Value::Float(a), @value.Value::Int(b)) => {
      if b.is_zero() {
        raise EvalErr(make_eval_error(ctx, "floored division by zero"))
      }
      @value.Value::Float((a / finite_double(ctx, b)).floor())
    }
    _ =>
      raise EvalErr(
        make_eval_error(
          ctx,
          "unknown binary op: \{lv.type_name()} // \{rv.type_name()}",
        ),
      )
  }
}

///|
/// Computes `a % b` with floor (not truncation) semantics: adjusts the
/// truncating remainder so the result carries the sign of the divisor `b`.
fn float_floor_mod(a : Double, b : Double) -> Double {
  let r = a % b
  // `%` truncates toward zero; floor-mod's result must carry the divisor's
  // sign, so when remainder and divisor disagree in sign add one divisor back.
  if r != 0.0 && (r < 0.0) != (b < 0.0) {
    r + b
  } else {
    r
  }
}

///|
/// Returns true when `f` is strictly negative or negative zero. Uses the
/// `1.0 / f` sign trick to distinguish `-0.0` from `+0.0`.
fn signbit(f : Double) -> Bool {
  // Distinguishes -0.0 from +0.0: 1.0 / -0.0 is -inf (< 0), 1.0 / +0.0 is +inf.
  f < 0.0 || (f == 0.0 && 1.0 / f < 0.0)
}

///|
/// Implements `%`: floor modulo for numeric pairs; percent format when the
/// left operand is a string (delegates to `percent_format`).
fn eval_mod(
  ctx : EvalContext,
  lv : @value.Value,
  rv : @value.Value,
  _pos : @errors.Position,
) -> @value.Value raise EvalErr {
  match (lv, rv) {
    (@value.Value::Int(a), @value.Value::Int(b)) =>
      @value.Value::Int(check(ctx, @numeric.starlark_mod(a, b)))
    (@value.Value::Float(a), @value.Value::Float(b)) => {
      if b == 0.0 {
        raise EvalErr(make_eval_error(ctx, "floating-point modulo by zero"))
      }
      @value.Value::Float(float_floor_mod(a, b))
    }
    (@value.Value::Int(a), @value.Value::Float(b)) => {
      if b == 0.0 {
        raise EvalErr(make_eval_error(ctx, "floating-point modulo by zero"))
      }
      @value.Value::Float(float_floor_mod(finite_double(ctx, a), b))
    }
    (@value.Value::Float(a), @value.Value::Int(b)) => {
      if b.is_zero() {
        raise EvalErr(make_eval_error(ctx, "floating-point modulo by zero"))
      }
      @value.Value::Float(float_floor_mod(a, finite_double(ctx, b)))
    }
    (@value.Value::String(s), _) => check(ctx, percent_format(s.raw(), rv))
    _ =>
      raise EvalErr(
        make_eval_error(
          ctx,
          "unknown binary op: \{lv.type_name()} % \{rv.type_name()}",
        ),
      )
  }
}

///|
/// Coerces `arg` to a `BigInt` for `%d`/`%o`/`%x`/`%X` format specs.
/// Floats are truncated toward zero; `NaN`/`Inf` and non-numeric types are
/// rejected.
fn percent_to_int(arg : @value.Value) -> Result[BigInt, String] {
  match arg {
    @value.Value::Int(n) => Ok(n)
    @value.Value::Float(f) =>
      if f.is_inf() {
        Err("cannot convert float infinity to integer")
      } else if f.is_nan() {
        Err("cannot convert float NaN to integer")
      } else {
        Ok(@numeric.double_to_bigint(f))
      }
    _ => Err("cannot convert \{arg.type_name()} to int")
  }
}

///|
/// Implements the `%` format operator for strings. Supports positional
/// arguments (via a tuple or single value) and named `%(key)spec` arguments
/// (via a dict). Mirrors Go's `fmt.Sprintf` sub-language as used by
/// starlark-go.
fn percent_format(
  fmt : String,
  args : @value.Value,
) -> Result[@value.Value, String] {
  let is_mapping = match args {
    @value.Value::Dict(_) => true
    _ => false
  }
  let arg_list : Array[@value.Value] = match args {
    @value.Value::Tuple(t) => t
    _ => [args]
  }
  let buf = @buffer.Buffer::Buffer()
  let chars = fmt.to_array()
  let n = chars.length()
  let mut i = 0
  let mut arg_idx = 0
  while i < n {
    let c = chars[i]
    if c != '%' {
      buf.write_char_utf8(c)
      i += 1
      continue
    }
    i += 1
    if i >= n {
      // Trailing '%': positional path. Argument availability is checked
      // before reporting the missing conversion verb.
      if arg_idx >= arg_list.length() && !is_mapping {
        return Err("not enough arguments for format string")
      }
      return Err("incomplete format")
    }
    if chars[i] == '%' {
      buf.write_char_utf8('%')
      i += 1
      continue
    }
    // Resolve (arg, spec): named %(key)spec or positional spec
    let mut arg_val : @value.Value = @value.Value::None
    let mut spec : Char = ' '
    if chars[i] == '(' {
      i += 1 // skip '('
      let key_buf = StringBuilder::new()
      while i < n && chars[i] != ')' {
        key_buf.write_char(chars[i])
        i += 1
      }
      if i >= n {
        return Err("incomplete format key")
      }
      i += 1 // skip ')'
      if i >= n {
        return Err("incomplete format")
      }
      let key = key_buf.to_string()
      spec = chars[i]
      i += 1
      match args {
        @value.Value::Dict(d) => {
          let kv = @value.Value::String(@value.StarlarkString::new(key))
          match d.get(kv) {
            Ok(Some(v)) => arg_val = v
            Ok(None) => return Err("key not found: \{key}")
            Err(e) => return Err(e)
          }
        }
        _ => return Err("format requires a mapping")
      }
    } else {
      if arg_idx >= arg_list.length() {
        return Err("not enough arguments for format string")
      }
      arg_val = arg_list[arg_idx]
      arg_idx += 1
      spec = chars[i]
      i += 1
    }
    let arg = arg_val
    match spec {
      's' =>
        match arg {
          @value.Value::String(sv) => buf.write_bytes(sv.to_bytes()[:])
          _ =>
            match arg.to_str_checked() {
              Err(e) => return Err(e)
              Ok(s) => buf.write_string_utf8(s)
            }
        }
      'r' =>
        match arg.repr_checked() {
          Err(e) => return Err(e)
          Ok(s) => buf.write_string_utf8(s)
        }
      'd' | 'i' =>
        match percent_to_int(arg) {
          Ok(n2) => buf.write_string_utf8(n2.to_string())
          Err(cause) => return Err("%\{spec} format requires integer: \{cause}")
        }
      'o' =>
        match percent_to_int(arg) {
          Ok(n2) =>
            if n2 < 0N {
              buf.write_char_utf8('-')
              buf.write_string_utf8(int64_to_octal(-n2))
            } else {
              buf.write_string_utf8(int64_to_octal(n2))
            }
          Err(cause) => return Err("%o format requires integer: \{cause}")
        }
      'x' =>
        match percent_to_int(arg) {
          Ok(n2) =>
            if n2 < 0N {
              buf.write_char_utf8('-')
              buf.write_string_utf8(int64_to_hex(-n2, false))
            } else {
              buf.write_string_utf8(int64_to_hex(n2, false))
            }
          Err(cause) => return Err("%x format requires integer: \{cause}")
        }
      'X' =>
        match percent_to_int(arg) {
          Ok(n2) =>
            if n2 < 0N {
              buf.write_char_utf8('-')
              buf.write_string_utf8(int64_to_hex(-n2, true))
            } else {
              buf.write_string_utf8(int64_to_hex(n2, true))
            }
          Err(cause) => return Err("%X format requires integer: \{cause}")
        }
      'e' | 'E' | 'f' | 'g' | 'G' => {
        let f = match arg {
          @value.Value::Float(f) => f
          @value.Value::Int(n2) => @numeric.bigint_to_double(n2)
          _ =>
            return Err("%\{spec} format requires float, not \{arg.type_name()}")
        }
        let s2 = match spec {
          'e' => format_float_e(f, false)
          'E' => format_float_e(f, true)
          'f' => format_float_f(f)
          'g' | 'G' => {
            let s3 = format_float_g(f)
            if spec == 'G' && !f.is_nan() && !f.is_inf() {
              s3.to_upper()
            } else {
              s3
            }
          }
          _ => ""
        }
        buf.write_string_utf8(s2)
      }
      'c' =>
        match arg {
          @value.Value::Int(n2) => {
            if n2 < 0N || n2 > unicode_max_cp_bigint {
              return Err(
                "%c format requires a valid Unicode code point, got \{n2}",
              )
            }
            let cp = n2.to_int()
            if cp >= unicode_surr_first && cp <= unicode_surr_last {
              buf.write_char_utf8('\u{FFFD}')
            } else {
              buf.write_char_utf8(cp.unsafe_to_char())
            }
          }
          @value.Value::String(s2) => {
            let bytes = s2.to_bytes()
            if bytes.length() == 0 {
              return Err("%c format requires a single-character string")
            }
            let (rune_val, size) = @utf8util.utf8_decode_rune(bytes, 0)
            if size != bytes.length() {
              return Err("%c format requires a single-character string")
            }
            // Mirror Go's WriteRune: invalid UTF-8 → U+FFFD, valid → the rune.
            let rune_char = if rune_val < 0 {
              '\u{FFFD}'
            } else {
              rune_val.unsafe_to_char()
            }
            buf.write_char_utf8(rune_char)
          }
          _ =>
            return Err(
              "%c format requires int or single-character string, not \{arg.type_name()}",
            )
        }
      _ => return Err("unknown conversion %\{spec}")
    }
  }
  if arg_idx < arg_list.length() && !is_mapping {
    return Err("too many arguments for format string")
  }
  Ok(@value.Value::String(@value.StarlarkString::from_bytes(buf.contents())))
}

///|
/// Formats a non-negative `BigInt` as an octal string without a leading `0o`
/// prefix, matching the `%o` conversion spec.
fn int64_to_octal(n : BigInt) -> String {
  if n.is_zero() {
    return "0"
  }
  let buf = StringBuilder::new()
  let mut v = n
  let digits : Array[Int] = []
  while v > 0N {
    digits.push((v % 8N).to_int())
    v = v / 8N
  }
  let mut j = digits.length() - 1
  while j >= 0 {
    buf.write_char(('0'.to_int() + digits[j]).unsafe_to_char())
    j -= 1
  }
  buf.to_string()
}

///|
/// Formats a non-negative `BigInt` as a hex string without a `0x` prefix.
/// `upper` selects uppercase A–F; lowercase otherwise. Used by `%x`/`%X`.
fn int64_to_hex(n : BigInt, upper : Bool) -> String {
  if n.is_zero() {
    return "0"
  }
  let buf = StringBuilder::new()
  let mut v = n
  let digits : Array[Int] = []
  while v > 0N {
    digits.push((v % 16N).to_int())
    v = v / 16N
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
/// Returns `10^n` as a `BigInt`, used in exact-arithmetic float formatting.
fn pow10_big(n : Int) -> BigInt {
  let mut r = 1N
  for _ in 0..<n {
    r = r * 10N
  }
  r
}

///|
/// Left-pads `n.to_string()` with zeros to at least `width` digits. Used to
/// produce the fixed-width fractional part in `%f` output.
fn pad_bigint(n : BigInt, width : Int) -> String {
  let s = n.to_string()
  let pad = width - s.length()
  if pad <= 0 {
    return s
  }
  let pbuf = StringBuilder::new()
  for _ in 0..<pad {
    pbuf.write_char('0')
  }
  pbuf.write_string(s)
  pbuf.to_string()
}

///|
/// Extracts the exact binary representation of a finite, strictly-positive
/// double as `(mantissa, exponent)` where `value = mantissa × 2^exponent`.
/// Used by `round_scaled` for lossless decimal conversion.
fn decompose_double(abs_f : Double) -> (BigInt, Int) {
  let bits = abs_f.reinterpret_as_uint64()
  // 52 = mantissa bits; 0x7FF = 11-bit biased-exponent mask (bits 52..62)
  let biased = ((bits >> 52) & 0x7FFUL).to_int()
  // 52-bit fractional mantissa (bits 0..51)
  let frac = bits & 0x000FFFFFFFFFFFFFUL
  if biased == 0 {
    // Subnormal: true exponent = 1 - 1023 - 52 = -1074
    (BigInt::from_uint64(frac), -1074)
  } else {
    // Normal: prepend implicit leading 1 (bit 52); true exponent = biased - 1023 - 52 = biased - 1075
    (BigInt::from_uint64(frac | 0x0010000000000000UL), biased - 1075)
  }
}

///|
/// Divides `num` by `den` (both non-negative, `den > 0`) rounding the
/// quotient to the nearest integer with ties broken toward even ("round half
/// to even"), matching Go's `strconv.FormatFloat` rounding.
fn round_half_even_div(num : BigInt, den : BigInt) -> BigInt {
  let q = num / den
  let r = num % den
  let twice = r * 2N
  if twice < den {
    q
  } else if twice > den {
    q + 1N
  } else if (q % 2N).is_zero() {
    q
  } else {
    q + 1N
  }
}

///|
/// Rounds `abs_f × 10^scale` to the nearest integer using exact big-integer
/// arithmetic on the true binary value of `abs_f`, avoiding the rounding error
/// of an intermediate floating-point multiply. `abs_f` must be finite and ≥ 0.
fn round_scaled(abs_f : Double, scale : Int) -> BigInt {
  let (mant, e) = decompose_double(abs_f)
  let mut num = mant
  let mut den = 1N
  if e >= 0 {
    num = num << e
  } else {
    den = den << -e
  }
  if scale >= 0 {
    num = num * pow10_big(scale)
  } else {
    den = den * pow10_big(-scale)
  }
  round_half_even_div(num, den)
}

///|
/// Formats `f` in scientific notation with 6 decimal places (`%e`/`%E`),
/// matching C's `printf("%.6e")` output exactly. `upper` selects `E` vs `e`.
fn format_float_e(f : Double, upper : Bool) -> String {
  if f.is_nan() {
    return "nan"
  }
  if f == @double.infinity {
    return "+inf"
  }
  if f == @double.neg_infinity {
    return "-inf"
  }
  let e_char = if upper { "E" } else { "e" }
  let is_neg = signbit(f)
  let sign_str = if is_neg { "-" } else { "" }
  let abs_f = if f < 0.0 { -f } else { f }
  if abs_f == 0.0 {
    return "\{sign_str}0.000000\{e_char}+00"
  }
  // Normalize to [10^p, 10^(p+1)) to produce exactly p+1 significant digits
  // (1 before the decimal point, p = printf_float_precision after it).
  let lo = pow10_big(printf_float_precision)
  let hi = pow10_big(printf_float_precision + 1)
  let mut exp = @math.log10(abs_f).floor().to_int()
  let mut n = round_scaled(abs_f, printf_float_precision - exp)
  while n < lo {
    exp = exp - 1
    n = round_scaled(abs_f, printf_float_precision - exp)
  }
  while n >= hi {
    exp = exp + 1
    n = round_scaled(abs_f, printf_float_precision - exp)
  }
  let digits = n.to_string()
  let int_digit = digits[0:1].to_owned()
  let frac_str = digits[1:printf_float_precision + 1].to_owned()
  let exp_sign = if exp >= 0 { "+" } else { "-" }
  let exp_abs = if exp >= 0 { exp } else { -exp }
  let exp_str = if exp_abs < 10 { "0\{exp_abs}" } else { exp_abs.to_string() }
  "\{sign_str}\{int_digit}.\{frac_str}\{e_char}\{exp_sign}\{exp_str}"
}

///|
/// Formats `f` in fixed-point notation with 6 decimal places (`%f`), matching
/// C's `printf("%.6f")` output exactly.
fn format_float_f(f : Double) -> String {
  if f.is_nan() {
    return "nan"
  }
  if f == @double.infinity {
    return "+inf"
  }
  if f == @double.neg_infinity {
    return "-inf"
  }
  let is_neg = signbit(f)
  let sign_str = if is_neg { "-" } else { "" }
  let abs_f = if f < 0.0 { -f } else { f }
  let n = round_scaled(abs_f, printf_float_precision)
  let scale = pow10_big(printf_float_precision)
  let int_str = (n / scale).to_string()
  let frac_str = pad_bigint(n % scale, printf_float_precision)
  "\{sign_str}\{int_str}.\{frac_str}"
}

///|
/// Formats `f` for `%g`/`%G`, delegating to `@numeric.format_float` (the
/// general-purpose shortest-representation formatter).
fn format_float_g(f : Double) -> String {
  @numeric.format_float(f)
}

///|
/// Implements `&`/`|`/`^` for integer pairs; `|` for dict pairs (union, right
/// takes precedence); and `&`/`|`/`^` for set pairs (intersection, union,
/// symmetric difference).
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
    (@value.Value::Int(a), @value.Value::Int(b)) => {
      let r = match op {
        "land" => a & b
        "lor" => a | b
        "lxor" => a ^ b
        _ => a
      }
      @value.Value::Int(r)
    }
    (@value.Value::Dict(ld), @value.Value::Dict(rd)) if op == "lor" => {
      let result = @value.StarlarkDict::new()
      ld.each(fn(k, v) { ignore(result.set(k, v)) })
      rd.each(fn(k, v) { ignore(result.set(k, v)) })
      @value.Value::Dict(result)
    }
    (@value.Value::Dict(_), _) if op == "lor" =>
      raise EvalErr(
        make_eval_error(ctx, "unknown binary op: dict | \{rv.type_name()}"),
      )
    (@value.Value::Set(ls), @value.Value::Set(rs)) => {
      let result = @value.StarlarkSet::new()
      match op {
        "lor" => {
          ls.each(fn(v) { ignore(result.add(v)) })
          rs.each(fn(v) { ignore(result.add(v)) })
        }
        "land" =>
          rs.each(fn(v) {
            match ls.contains(v) {
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
      @value.Value::Set(result)
    }
    (@value.Value::Set(_), _) =>
      raise EvalErr(
        make_eval_error(
          ctx,
          "unknown binary op: set \{op_char} \{rv.type_name()}",
        ),
      )
    (_, @value.Value::Set(_)) =>
      raise EvalErr(
        make_eval_error(
          ctx,
          "unknown binary op: \{lv.type_name()} \{op_char} set",
        ),
      )
    _ =>
      raise EvalErr(
        make_eval_error(
          ctx,
          "unknown binary op: \{lv.type_name()} \{op_char} \{rv.type_name()}",
        ),
      )
  }
}

///|
/// Implements `<<` and `>>` for integer pairs. Left shifts at or above
/// `max_lshift_bits` (512) raise an error; right shifts are clamped to
/// `max_rshift_bits` to avoid `to_int()` overflow while preserving sign.
fn eval_shift(
  ctx : EvalContext,
  lv : @value.Value,
  rv : @value.Value,
  _pos : @errors.Position,
  dir : String,
) -> @value.Value raise EvalErr {
  match (lv, rv) {
    (@value.Value::Int(a), @value.Value::Int(b)) => {
      if b < 0N {
        raise EvalErr(make_eval_error(ctx, "negative shift count: \{b}"))
      }
      match dir {
        "lshift" => {
          if b >= max_lshift_bits {
            raise EvalErr(make_eval_error(ctx, "shift count too large: \{b}"))
          }
          @value.Value::Int(a << b.to_int())
        }
        _ => {
          // Right shift: no upper cap; BigInt >> large_count = 0 (positive) or -1 (negative).
          // Clamp b to a safe int range to avoid to_int() overflow.
          let shift = if b > max_rshift_bits {
            max_rshift_bits.to_int()
          } else {
            b.to_int()
          }
          @value.Value::Int(a >> shift)
        }
      }
    }
    _ => {
      let op_sym = if dir == "lshift" { "<<" } else { ">>" }
      raise EvalErr(
        make_eval_error(
          ctx,
          "unknown binary op: \{lv.type_name()} \{op_sym} \{rv.type_name()}",
        ),
      )
    }
  }
}

///|
/// Returns true when every element of `s1` is contained in `s2`.
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
/// Implements ordered comparisons (`<`/`<=`/`>`/`>=`). Set pairs use the
/// subset/superset partial order; all other pairs delegate to
/// `@value.compare_values`. `strict_sign > 0` means `>` / `>=`; `strict`
/// distinguishes `<` from `<=`.
fn eval_cmp(
  ctx : EvalContext,
  lv : @value.Value,
  rv : @value.Value,
  _pos : @errors.Position,
  strict_sign : Int,
  strict : Bool,
) -> @value.Value raise EvalErr {
  match (lv, rv) {
    (@value.Value::Set(ls), @value.Value::Set(rs)) => {
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
      @value.Value::Bool(result)
    }
    _ => {
      let op = if strict_sign > 0 {
        if strict {
          ">"
        } else {
          ">="
        }
      } else if strict {
        "<"
      } else {
        "<="
      }
      let c = check(ctx, @value.compare_values(lv, rv, op~))
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
      @value.Value::Bool(result)
    }
  }
}

///|
/// Implements the `in` membership test for all collection types. Dict
/// containment silences hash errors (matching starlark-go's `Mapping.Get`
/// semantics); set containment propagates them. Bytes accepts both a bytes
/// needle and an int byte value.
fn in_op(
  ctx : EvalContext,
  needle : @value.Value,
  haystack : @value.Value,
  _pos : @errors.Position,
) -> @value.Value raise EvalErr {
  match haystack {
    @value.Value::List(l) => {
      for item in l.iter() {
        if check(
            ctx,
            @value.starlark_equals_depth(needle, item, @value.compare_limit),
          ) {
          return @value.Value::Bool(true)
        }
      }
      @value.Value::Bool(false)
    }
    @value.Value::Tuple(t) => {
      for item in t {
        if check(
            ctx,
            @value.starlark_equals_depth(needle, item, @value.compare_limit),
          ) {
          return @value.Value::Bool(true)
        }
      }
      @value.Value::Bool(false)
    }
    // Dict silences all hash errors (starlark-go Mapping.Get: "cannot
    // distinguish true errors from key not found"). Set propagates them
    // (starlark-go Set.Has returns the error from the hashtable lookup).
    @value.Value::Dict(d) =>
      match d.get(needle) {
        Ok(Some(_)) => @value.Value::Bool(true)
        _ => @value.Value::Bool(false)
      }
    @value.Value::Set(s) => @value.Value::Bool(check(ctx, s.contains(needle)))
    @value.Value::String(s) =>
      match needle {
        @value.Value::String(n) => @value.Value::Bool(s.raw().contains(n.raw()))
        _ =>
          raise EvalErr(
            make_eval_error(
              ctx,
              "'in <string>' requires string as left operand, not \{needle.type_name()}",
            ),
          )
      }
    @value.Value::Range(r) =>
      match needle {
        @value.Value::Int(n) =>
          if n.compare_int64(@int64.MAX_VALUE) > 0 ||
            n.compare_int64(@int64.MIN_VALUE) < 0 {
            @value.Value::Bool(false)
          } else {
            @value.Value::Bool(r.contains(n.to_int64()))
          }
        @value.Value::Float(f) => {
          if f.is_nan() || f.is_inf() {
            raise EvalErr(
              make_eval_error(
                ctx,
                "'in <range>' requires integer as left operand, not \{needle.type_name()}",
              ),
            )
          }
          if f >= @int64.MAX_VALUE.to_double() ||
            f < @int64.MIN_VALUE.to_double() {
            @value.Value::Bool(false)
          } else {
            @value.Value::Bool(r.contains(f.to_int64()))
          }
        }
        _ =>
          raise EvalErr(
            make_eval_error(
              ctx,
              "'in <range>' requires integer as left operand, not \{needle.type_name()}",
            ),
          )
      }
    @value.Value::Bytes(haystack_b) =>
      match needle {
        @value.Value::Bytes(needle_b) => {
          let hlen = haystack_b.length()
          let nlen = needle_b.length()
          if nlen == 0 {
            return @value.Value::Bool(true)
          }
          if nlen > hlen {
            return @value.Value::Bool(false)
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
          @value.Value::Bool(found)
        }
        @value.Value::Int(n) => {
          if n < 0N || n > max_byte_val {
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
          @value.Value::Bool(found)
        }
        _ =>
          raise EvalErr(
            make_eval_error(
              ctx,
              "'in bytes' requires bytes or int as left operand, not \{needle.type_name()}",
            ),
          )
      }
    @value.Value::ExtVal(c) =>
      match c.get_contains(needle) {
        Some(Ok(b)) => @value.Value::Bool(b)
        Some(Err(e)) => raise EvalErr(make_eval_error(ctx, e))
        None =>
          raise EvalErr(
            make_eval_error(
              ctx,
              "argument of type '\{haystack.type_name()}' is not iterable",
            ),
          )
      }
    _ =>
      raise EvalErr(
        make_eval_error(
          ctx,
          "unknown binary op: \{needle.type_name()} in \{haystack.type_name()}",
        ),
      )
  }
}

///|
/// Integer-indexed lookup for list, tuple, string, bytes, range, and
/// `StringElems`; dict lookup by arbitrary hashable key; `ExtVal` via the
/// length + index hooks. Negative integer indices count from the end.
fn eval_index(
  ctx : EvalContext,
  obj : @value.Value,
  idx : @value.Value,
  _pos : @errors.Position,
) -> @value.Value raise EvalErr {
  match obj {
    @value.Value::List(l) =>
      match idx {
        @value.Value::Int(i) => {
          let j = check(ctx, adjust_index(i, l.length().to_int64(), "list"))
          l[j.to_int()]
        }
        _ =>
          raise EvalErr(
            make_eval_error(ctx, "list index: got \{idx.type_name()}, want int"),
          )
      }
    @value.Value::Tuple(t) =>
      match idx {
        @value.Value::Int(i) => {
          let j = check(ctx, adjust_index(i, t.length().to_int64(), "tuple"))
          t[j.to_int()]
        }
        _ =>
          raise EvalErr(
            make_eval_error(
              ctx,
              "tuple index: got \{idx.type_name()}, want int",
            ),
          )
      }
    @value.Value::String(s) =>
      match idx {
        @value.Value::Int(i) => {
          let j = check(ctx, adjust_index(i, s.byte_len().to_int64(), "string"))
          let one_byte = Bytes::from_array([s.byte_at(j.to_int())])
          @value.Value::String(@value.StarlarkString::from_bytes(one_byte))
        }
        _ =>
          raise EvalErr(
            make_eval_error(
              ctx,
              "string index: got \{idx.type_name()}, want int",
            ),
          )
      }
    @value.Value::Bytes(b) =>
      match idx {
        @value.Value::Int(i) => {
          let j = check(ctx, adjust_index(i, b.length().to_int64(), "bytes"))
          @value.Value::Bytes(Bytes::from_array([b[j.to_int()]]))
        }
        _ =>
          raise EvalErr(
            make_eval_error(
              ctx,
              "bytes index: got \{idx.type_name()}, want int",
            ),
          )
      }
    @value.Value::Dict(d) =>
      match check(ctx, d.get(idx)) {
        None => {
          let key_str = match idx.repr_checked() {
            Ok(s) => s
            Err(_) => "<key>"
          }
          raise EvalErr(make_eval_error(ctx, "key \{key_str} not in dict"))
        }
        Some(v) => v
      }
    @value.Value::Range(r) =>
      match idx {
        @value.Value::Int(i) => {
          let len = r.length()
          if len < 0L {
            raise EvalErr(make_eval_error(ctx, "range has no len"))
          }
          let j = check(ctx, adjust_index(i, len, "range"))
          @value.Value::Int(BigInt::from_int64(r.index_at(j)))
        }
        _ =>
          raise EvalErr(
            make_eval_error(
              ctx,
              "range index: got \{idx.type_name()}, want int",
            ),
          )
      }
    @value.Value::StringElems(e) =>
      match idx {
        @value.Value::Int(i) => {
          let bytes = e.source_string().to_bytes()
          let j = check(
            ctx,
            adjust_index(i, bytes.length().to_int64(), "string.elems"),
          )
          if e.is_ords() {
            @value.Value::Int(BigInt::from_int(bytes[j.to_int()].to_int()))
          } else {
            let one = Bytes::from_array([bytes[j.to_int()]])
            @value.Value::String(@value.StarlarkString::from_bytes(one))
          }
        }
        _ =>
          raise EvalErr(
            make_eval_error(
              ctx,
              "string.elems index: got \{idx.type_name()}, want int",
            ),
          )
      }
    @value.Value::ExtVal(c) =>
      match idx {
        @value.Value::Int(i) => {
          let len = match c.get_length() {
            Ok(n) => n
            Err(e) => raise EvalErr(make_eval_error(ctx, e))
          }
          let j = check(ctx, adjust_index(i, len.to_int64(), obj.type_name()))
          match c.get_index(j.to_int()) {
            Ok(v) => v
            Err(e) => raise EvalErr(make_eval_error(ctx, e))
          }
        }
        _ =>
          raise EvalErr(
            make_eval_error(
              ctx,
              "\{obj.type_name()} index: got \{idx.type_name()}, want int",
            ),
          )
      }
    _ =>
      raise EvalErr(
        make_eval_error(
          ctx,
          "unhandled index operation \{obj.type_name()}[\{idx.type_name()}]",
        ),
      )
  }
}

///|
/// Item assignment for list (integer index) and dict (arbitrary hashable key),
/// and `ExtVal` (via `HasSetKey` or `HasSetIndex` hooks in that precedence
/// order). All other types raise.
fn set_index(
  ctx : EvalContext,
  obj : @value.Value,
  idx : @value.Value,
  val : @value.Value,
  _pos : @errors.Position,
) -> Unit raise EvalErr {
  match obj {
    @value.Value::List(l) =>
      match idx {
        @value.Value::Int(i) => {
          let j = check(ctx, adjust_index(i, l.length().to_int64(), "list"))
          check(ctx, l.set(j.to_int(), val))
        }
        _ =>
          raise EvalErr(
            make_eval_error(ctx, "got \{idx.type_name()}, want int"),
          )
      }
    @value.Value::Dict(d) => check(ctx, d.set(idx, val))
    @value.Value::ExtVal(c) =>
      // HasSetKey (arbitrary key) takes precedence; otherwise fall back to the
      // integer-indexed HasSetIndex hook.
      match c.do_set_key(idx, val) {
        Some(Ok(_)) => ()
        Some(Err(e)) => raise EvalErr(make_eval_error(ctx, e))
        None =>
          match idx {
            @value.Value::Int(i) => {
              let len = match c.get_length() {
                Ok(n) => n
                Err(e) => raise EvalErr(make_eval_error(ctx, e))
              }
              let j = check(
                ctx,
                adjust_index(i, len.to_int64(), obj.type_name()),
              )
              match c.do_set_index(j.to_int(), val) {
                Some(Ok(_)) => ()
                Some(Err(e)) => raise EvalErr(make_eval_error(ctx, e))
                None =>
                  raise EvalErr(
                    make_eval_error(
                      ctx,
                      "\{obj.type_name()} value does not support item assignment",
                    ),
                  )
              }
            }
            _ =>
              raise EvalErr(
                make_eval_error(ctx, "got \{idx.type_name()}, want int"),
              )
          }
      }
    _ =>
      raise EvalErr(
        make_eval_error(
          ctx,
          "\{obj.type_name()} value does not support item assignment",
        ),
      )
  }
}

///|
/// Slices list, tuple, string, bytes, range, and `ExtVal` by optional
/// `[lo:hi:step]` bounds. Omitted bounds and step default to natural
/// start/end/1; a zero step always raises.
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
    raise EvalErr(make_eval_error(ctx, "zero is not a valid slice step"))
  }
  match obj {
    @value.Value::List(l) => {
      let len = l.length()
      let (start, stop) = normalize_slice(lo_opt, hi_opt, len, step)
      let items : Array[@value.Value] = []
      if step > 0 {
        let mut i = start
        while i < stop {
          items.push(l[i])
          i += step
        }
      } else {
        let mut i = start
        while i > stop {
          items.push(l[i])
          i += step
        }
      }
      @value.Value::List(@value.StarlarkList::new(items))
    }
    @value.Value::Tuple(t) => {
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
      @value.Value::Tuple(items)
    }
    @value.Value::String(s) => {
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
      @value.Value::String(
        @value.StarlarkString::from_bytes(Bytes::from_array(bytes_arr)),
      )
    }
    @value.Value::Range(r) => {
      let len = r.length()
      if len < 0L {
        raise EvalErr(make_eval_error(ctx, "range has no len"))
      }
      let (start, end_idx_raw) = normalize_slice_64(lo_opt, hi_opt, len, step)
      let end_idx = if step > 0 && end_idx_raw < start {
        start
      } else if step < 0 && end_idx_raw > start {
        start
      } else {
        end_idx_raw
      }
      let new_start = r.start() + r.step() * start
      let new_stop = r.start() + r.step() * end_idx
      let new_step = r.step() * step.to_int64()
      @value.Value::Range(
        @value.StarlarkRange::new(new_start, new_stop, new_step),
      )
    }
    @value.Value::Bytes(b) => {
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
      @value.Value::Bytes(Bytes::from_array(bytes_arr))
    }
    @value.Value::ExtVal(c) => {
      let len = match c.get_length() {
        Ok(n) => n
        Err(e) => raise EvalErr(make_eval_error(ctx, e))
      }
      let (start, stop) = normalize_slice(lo_opt, hi_opt, len, step)
      match c.do_slice(start, stop, step) {
        Some(Ok(v)) => v
        Some(Err(e)) => raise EvalErr(make_eval_error(ctx, e))
        None =>
          raise EvalErr(
            make_eval_error(ctx, "invalid slice operand \{obj.type_name()}"),
          )
      }
    }
    _ =>
      raise EvalErr(
        make_eval_error(ctx, "invalid slice operand \{obj.type_name()}"),
      )
  }
}

///|
/// Clamps `[lo_opt, hi_opt]` slice bounds against an `Int` sequence length
/// for the given `step` direction. Omitted bounds default to the natural
/// start/end; out-of-range values are clamped into `[0, len]` (positive step)
/// or `[-1, len-1]` (negative step).
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
/// 64-bit variant of `normalize_slice`, used for `range` slices whose length
/// may exceed `Int` range.
fn normalize_slice_64(
  lo_opt : Int?,
  hi_opt : Int?,
  len : Int64,
  step : Int,
) -> (Int64, Int64) {
  if step > 0 {
    let start = match lo_opt {
      None => 0L
      Some(i) => {
        let j = if i < 0 { i.to_int64() + len } else { i.to_int64() }
        if j < 0L {
          0L
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
        let j = if i < 0 { i.to_int64() + len } else { i.to_int64() }
        if j < 0L {
          0L
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
      None => len - 1L
      Some(i) => {
        let j = if i < 0 { i.to_int64() + len } else { i.to_int64() }
        if j < 0L {
          -1L
        } else if j >= len {
          len - 1L
        } else {
          j
        }
      }
    }
    let stop = match hi_opt {
      None => -1L
      Some(i) => {
        let j = if i < 0 { i.to_int64() + len } else { i.to_int64() }
        if j < -1L {
          -1L
        } else if j >= len {
          len - 1L
        } else {
          j
        }
      }
    }
    (start, stop)
  }
}

///|
/// Converts an augmented-assignment operator (`+=`, `-=`, etc.) to its
/// corresponding binary operator, so `eval_aug_val` can delegate to
/// `eval_binary` for non-special-cased operators.
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
