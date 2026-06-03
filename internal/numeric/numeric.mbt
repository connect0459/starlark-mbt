// Low-level numeric and conversion helpers shared by the evaluator, value
// hashing/comparison, and the json/math extensions. These are interpreter
// building blocks, not part of the public embedding API.

///|
/// Floor division toward −∞, matching Starlark's `//` operator.
///
/// Returns `Ok(q)` where `q` is the floor-division result, or
/// `Err("floored division by zero")` when `b` is zero.
pub fn floor_div(a : BigInt, b : BigInt) -> Result[BigInt, String] {
  if b.is_zero() {
    return Err("floored division by zero")
  }
  let q = a / b
  let r = a % b
  let zero = 0N
  // `/` truncates toward zero; when the remainder and divisor disagree in
  // sign the true floor is one less than the truncated quotient.
  if r != zero && (r < zero) != (b < zero) {
    Ok(q - 1N)
  } else {
    Ok(q)
  }
}

///|
/// Integer modulo whose sign matches the divisor, matching Starlark's `%`
/// operator.
///
/// Returns `Ok(r)` where `r` has the same sign as `b`, or
/// `Err("integer modulo by zero")` when `b` is zero.
pub fn starlark_mod(a : BigInt, b : BigInt) -> Result[BigInt, String] {
  if b.is_zero() {
    return Err("integer modulo by zero")
  }
  let r = a % b
  let zero = 0N
  // `%` truncates toward zero; add the divisor back when their signs disagree
  // so the result carries the divisor's sign (Starlark/Python modulo).
  if r != zero && (r < zero) != (b < zero) {
    Ok(r + b)
  } else {
    Ok(r)
  }
}

///|
fn is_neg_zero(f : Double) -> Bool {
  // -0.0 and +0.0 compare equal, so inspect the IEEE 754 sign bit directly:
  // -0.0 has the sign bit set, giving a negative integer bit pattern.
  f == 0.0 && f.reinterpret_as_int64() < 0L
}

///|
/// Formats a `Double` as a Starlark float literal, matching starlark-go's
/// `strconv.FormatFloat('g')` output: scientific notation for very large or
/// very small values, decimal otherwise. Handles ±inf, nan, and −0.0.
pub fn format_float(f : Double) -> String {
  if f.is_nan() {
    return "nan"
  }
  if f == @double.infinity {
    return "+inf"
  }
  if f == @double.neg_infinity {
    return "-inf"
  }
  if is_neg_zero(f) {
    return "-0.0"
  }
  let s = f.to_string()
  // Already in scientific notation: normalize to Go format (e+XX, 2-digit exponent).
  let e_idx = float_find_e(s)
  if e_idx >= 0 {
    return float_normalize_sci(s, e_idx)
  }
  let neg = s.has_prefix("-")
  let sign = if neg { "-" } else { "" }
  let abs_s = if neg { s[1:].to_owned() } else { s }
  if abs_s.contains(".") {
    // Decimal form.  Go's %g switches to scientific when the decimal exponent
    // is < -4 (small numbers below "0.0001") or >= 6 (magnitude >= 1e6).
    if abs_s.has_prefix("0.") {
      let frac = abs_s[2:].to_owned()
      let leading = float_count_leading_zeros(frac)
      // exponent = -(leading + 1); scientific when exp < -4 i.e. leading >= 4
      if leading >= 4 {
        let sig = frac[leading:].to_owned()
        return sign + float_small_to_sci(sig, leading + 1)
      }
    } else {
      let dot = float_find_dot(abs_s)
      let int_part = abs_s[0:dot].to_owned()
      // Integer-part length L means decimal exponent L-1; scientific when >= 6.
      if int_part.length() >= 7 {
        let frac_part = abs_s[dot + 1:].to_owned()
        return sign + float_large_frac_to_sci(int_part, frac_part)
      }
    }
    return s
  } else {
    // Integer form: check whether scientific notation is needed.
    return sign + float_int_to_str(abs_s)
  }
}

///|
fn float_find_e(s : String) -> Int {
  let n = s.length()
  let mut i = 0
  while i < n {
    let c = s[i:i + 1]
    if c == "e" || c == "E" {
      return i
    }
    i += 1
  }
  -1
}

///|
fn float_normalize_sci(s : String, e_idx : Int) -> String {
  let mantissa = s[0:e_idx].to_owned()
  let exp_part = s[e_idx + 1:].to_owned()
  let (exp_sign, exp_digits) = if exp_part.has_prefix("+") {
    ("+", exp_part[1:].to_owned())
  } else if exp_part.has_prefix("-") {
    ("-", exp_part[1:].to_owned())
  } else {
    ("+", exp_part)
  }
  let exp_str = if exp_digits.length() < 2 {
    "0" + exp_digits
  } else {
    exp_digits
  }
  // Scientific notation already satisfies the "has decimal or exponent" requirement;
  // do NOT append ".0" to the mantissa.
  mantissa + "e" + exp_sign + exp_str
}

///|
fn float_count_leading_zeros(frac : String) -> Int {
  let n = frac.length()
  let mut i = 0
  while i < n && frac[i:i + 1] == "0" {
    i += 1
  }
  i
}

///|
fn float_small_to_sci(sig : String, exp_abs : Int) -> String {
  if sig.length() == 0 {
    return "0.0"
  }
  let first = sig[0:1].to_owned()
  let rest = sig[1:].to_owned()
  let mantissa = if rest == "" { first } else { first + "." + rest }
  let exp_str = if exp_abs < 10 { "0\{exp_abs}" } else { exp_abs.to_string() }
  mantissa + "e-" + exp_str
}

///|
fn float_int_to_str(abs_s : String) -> String {
  let n = abs_s.length()
  if n < 7 {
    return abs_s + ".0"
  }
  // 7+ digits: convert to scientific notation by stripping trailing zeros.
  let exp = n - 1
  let mut sig_end = n
  while sig_end > 1 && abs_s[sig_end - 1:sig_end].to_owned() == "0" {
    sig_end -= 1
  }
  let first = abs_s[0:1].to_owned()
  let rest_sig = abs_s[1:sig_end].to_owned()
  let mantissa = if rest_sig == "" { first } else { first + "." + rest_sig }
  let exp_str = if exp < 10 { "0\{exp}" } else { exp.to_string() }
  mantissa + "e+" + exp_str
}

///|
fn float_find_dot(s : String) -> Int {
  let n = s.length()
  let mut i = 0
  while i < n {
    if s[i:i + 1] == "." {
      return i
    }
    i += 1
  }
  n
}

///|
fn float_large_frac_to_sci(int_part : String, frac_part : String) -> String {
  let exp = int_part.length() - 1
  let digits = int_part + frac_part
  let mut sig_end = digits.length()
  while sig_end > 1 && digits[sig_end - 1:sig_end] == "0" {
    sig_end -= 1
  }
  let first = digits[0:1].to_owned()
  let rest_sig = digits[1:sig_end].to_owned()
  let mantissa = if rest_sig == "" { first } else { first + "." + rest_sig }
  let exp_str = if exp < 10 { "0\{exp}" } else { exp.to_string() }
  mantissa + "e+" + exp_str
}

///|
// IEEE 754 double-precision bit-layout constants, used by `double_to_bigint`.
let ieee754_sign_shift : Int = 63

///|
let ieee754_mantissa_bits : Int = 52

///|
let ieee754_exponent_mask : UInt64 = 0x7FFUL

///|
let ieee754_exponent_bias : Int = 1023

///|
let ieee754_mantissa_mask : UInt64 = 0x000FFFFFFFFFFFFFUL

///|
let ieee754_implicit_bit : UInt64 = 0x0010000000000000UL

///|
/// Truncates a finite `Double` (with no fractional part) toward zero into the
/// exact integer value as a `BigInt`, via IEEE 754 bit extraction.
pub fn double_to_bigint(f : Double) -> BigInt {
  // f must be finite and satisfy f == f.trunc() (no fractional part).
  // Handles the full double range via IEEE 754 bit extraction.
  let bits = f.reinterpret_as_uint64()
  let negative = bits >> ieee754_sign_shift != 0UL
  let biased_exp = ((bits >> ieee754_mantissa_bits) & ieee754_exponent_mask).to_int()
  if biased_exp < ieee754_exponent_bias {
    return 0N
  }
  let mantissa = (bits & ieee754_mantissa_mask) | ieee754_implicit_bit
  let shift = biased_exp - ieee754_exponent_bias - ieee754_mantissa_bits
  let abs_val = if shift >= 0 {
    BigInt::from_uint64(mantissa) << shift
  } else {
    BigInt::from_uint64(mantissa) >> -shift
  }
  if negative {
    -abs_val
  } else {
    abs_val
  }
}

///|
/// Converts a `BigInt` to the nearest representable `Double`, returning
/// `+Infinity` on overflow.
pub fn bigint_to_double(n : BigInt) -> Double {
  @string.parse_double(n.to_string()) catch {
    _ => 0.0
  }
}

///|
/// Converts a `BigInt` to `Double`, returning `Err("int too large to convert
/// to float")` if the result would be infinite.
pub fn bigint_to_finite_double(n : BigInt) -> Result[Double, String] {
  let f = @string.parse_double(n.to_string()) catch { _ => @double.infinity }
  if f.is_inf() {
    Err("int too large to convert to float")
  } else {
    Ok(f)
  }
}

///|
// Java String.hashCode prime multiplier.
let java_hash_prime : Int = 31

///|
// Unicode replacement character substituted for invalid UTF-8 sequences.
let unicode_replacement_rune : Int = 0xFFFD

///|
/// Computes `java.lang.String.hashCode` over the UTF-8 byte sequence `b`,
/// decoding it as Unicode code points. Used by the `hash()` built-in for
/// string parity with starlark-go.
pub fn java_string_hash(b : Bytes) -> Int {
  let mut h : Int = 0
  let mut pos = 0
  while pos < b.length() {
    let (cp, n) = @utf8util.utf8_decode_rune(b, pos)
    pos += n
    h = java_hash_prime * h +
      (if cp < 0 { unicode_replacement_rune } else { cp })
  }
  h
}
