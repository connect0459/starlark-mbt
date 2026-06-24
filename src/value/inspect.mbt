// Embedder-facing value-inspection helpers. These mirror starlark-go's
// package-level Equal/Compare/Len/Iterate/AsFloat/AsString/NumberToInt and form
// the public value-level API. They return String errors because value-level
// operations carry no source position; richer EvalError context lives in @eval.

///|
/// Hashes `v` with an explicit recursion-depth cap. Pass the received `depth`
/// to `hash_value_depth` inside a `CustomValue::with_hash_depth` callback so
/// nested `Value` fields are hashed without restarting the counter.
///
/// Parameters:
///
/// - `v` : The value to hash.
/// - `depth` : Remaining recursion budget; use `hash_limit` as the initial
///   value.
///
/// Returns `Ok(hash)` on success, or `Err` for unhashable types or when
/// `depth` is exhausted.
pub fn hash_value_depth(v : Value, depth : Int) -> Result[UInt, String] {
  v.hash_depth(depth)
}

///|
/// Structural equality with the default recursion-depth cap (`compare_limit`)
/// to guard against cycles.
///
/// Parameters:
///
/// - `a` : The left-hand value.
/// - `b` : The right-hand value.
///
/// Returns `Ok(true)` if `a == b`, `Ok(false)` if not, or `Err` when the
/// recursion-depth cap is exceeded (cyclic structure).
pub fn equal(a : Value, b : Value) -> Result[Bool, String] {
  starlark_equals_depth(a, b, compare_limit)
}

///|
/// Structural equality with an explicit recursion-depth cap.
///
/// Parameters:
///
/// - `a` : The left-hand value.
/// - `b` : The right-hand value.
/// - `depth` : Remaining recursion budget; use `compare_limit` as the initial
///   value.
///
/// Returns `Ok(true)` if `a == b`, `Ok(false)` if not, or `Err` when `depth`
/// is exhausted (cyclic structure).
pub fn equal_depth(a : Value, b : Value, depth : Int) -> Result[Bool, String] {
  starlark_equals_depth(a, b, depth)
}

///|
/// Applies a comparison operator (`"=="`, `"!="`, `"<"`, `"<="`, `">"`,
/// `">="`) to `a` and `b` with an explicit recursion-depth cap.
///
/// Parameters:
///
/// - `op` : The comparison operator string.
/// - `a` : The left-hand value.
/// - `b` : The right-hand value.
/// - `depth` : Remaining recursion budget; use `compare_limit` as the initial
///   value.
///
/// Returns `Ok(result)` on success, or `Err` on type mismatch, depth
/// exhaustion, or unknown operator.
pub fn compare_depth(
  op : String,
  a : Value,
  b : Value,
  depth : Int,
) -> Result[Bool, String] {
  match op {
    "==" => starlark_equals_depth(a, b, depth)
    "!=" => starlark_equals_depth(a, b, depth).map(fn(v) { !v })
    "<" | "<=" | ">" | ">=" =>
      match compare_values_depth(a, b, depth) {
        Ok(c) =>
          Ok(
            match op {
              "<" => c < 0
              "<=" => c <= 0
              ">" => c > 0
              _ => c >= 0
            },
          )
        Err(e) => Err(e)
      }
    _ => Err("unknown comparison operator: \{op}")
  }
}

///|
/// Returns the sequence length of `v` (list, tuple, string, bytes, range), or
/// `-1` if `v` has no length.
///
/// Parameters:
///
/// - `v` : The value whose length to retrieve.
///
/// Returns the non-negative length, or `-1` if `v` does not support `len`.
pub fn len_of(v : Value) -> Int64 {
  match length_of(v) {
    Ok(n) => n
    Err(_) => -1L
  }
}

///|
/// Extracts a `Double` from an `Int` or `Float` value.
///
/// Parameters:
///
/// - `v` : The value to extract a float from.
///
/// Returns `(value, true)` on success, or `(0.0, false)` if `v` is neither a
/// numeric type.
pub fn as_float(v : Value) -> (Double, Bool) {
  match v {
    Float(f) => (f, true)
    Int(n) => (@numeric.bigint_to_double(n), true)
    _ => (0.0, false)
  }
}

///|
/// Extracts the raw `String` from a Starlark `String` value.
///
/// Parameters:
///
/// - `v` : The value to extract a string from.
///
/// Returns `(string, true)` on success, or `("", false)` if `v` is not a
/// string.
pub fn as_string(v : Value) -> (String, Bool) {
  match v {
    String(s) => (s.raw(), true)
    _ => ("", false)
  }
}

///|
/// Converts an `Int` or `Float` value to `Int64`.
///
/// Parameters:
///
/// - `v` : The numeric value to convert.
///
/// Returns `Some(n)` on success, or `None` if `v` is not numeric, is NaN or
/// infinite, or is outside the signed 64-bit range.
pub fn number_to_int(v : Value) -> Int64? {
  match v {
    Int(n) =>
      if n.compare_int64(@int64.MAX_VALUE) > 0 ||
        n.compare_int64(@int64.MIN_VALUE) < 0 {
        None
      } else {
        Some(n.to_int64())
      }
    Float(f) => if f.is_nan() || f.is_inf() { None } else { Some(f.to_int64()) }
    _ => None
  }
}
