///|
fn str_lex_cmp(a : String, b : String) -> Int {
  let la = a.length()
  let lb = b.length()
  let mut ia = 0
  let mut ib = 0
  while ia < la && ib < lb {
    let (cp_a, step_a) = @utf8util.utf16_decode_cp(a, ia, la)
    let (cp_b, step_b) = @utf8util.utf16_decode_cp(b, ib, lb)
    if cp_a < cp_b {
      return -1
    }
    if cp_a > cp_b {
      return 1
    }
    ia += step_a
    ib += step_b
  }
  if ia < la {
    1
  } else if ib < lb {
    -1
  } else {
    0
  }
}

///|
fn parse_uint_str(s : String) -> Int? {
  if s.is_empty() {
    return None
  }
  let mut result = 0
  for c in s.to_array() {
    if c < '0' || c > '9' {
      return None
    }
    result = result * 10 + (c.to_int() - '0'.to_int())
  }
  Some(result)
}

///|
fn ctor_display(ctor : @value.Value) -> String {
  match ctor {
    @value.Value::String(s) => s.raw()
    _ => ctor.to_str()
  }
}

///|
fn struct_repr(
  ctor : @value.Value,
  entries : Array[(String, @value.Value)],
) -> String {
  match struct_repr_depth(ctor, entries, @value.repr_limit) {
    Ok(s) => s
    Err(e) => abort(e)
  }
}

///|
fn struct_repr_depth(
  ctor : @value.Value,
  entries : Array[(String, @value.Value)],
  depth : Int,
) -> Result[String, String] {
  let buf = StringBuilder::new()
  buf.write_string(ctor_display(ctor))
  buf.write_char('(')
  for i, e in entries {
    if i > 0 {
      buf.write_string(", ")
    }
    buf.write_string(e.0)
    buf.write_string(" = ")
    match @value.Value::repr_at_depth(e.1, depth) {
      Err(e) => return Err(e)
      Ok(s) => buf.write_string(s)
    }
  }
  buf.write_char(')')
  Ok(buf.to_string())
}

// Hash algorithm for starlark structs, ported from starlark-go's
// starlarkstruct package. The three constants and the `3 * name_hash` mixing
// factor are the original Go literals; they were chosen for good avalanche
// behaviour and are not derived from a published hash family.

///|
let struct_hash_seed : UInt = 8731U

///|
let struct_hash_mult_init : UInt = 9839U

///|
let struct_hash_mult_step : UInt = 7349U

///|
fn struct_hash(entries : Array[(String, @value.Value)]) -> Result[UInt, String] {
  let mut x : UInt = struct_hash_seed
  let mut m : UInt = struct_hash_mult_init
  for e in entries {
    match
      @value.Value::hash(@value.Value::String(@value.StarlarkString::new(e.0))) {
      Err(msg) => return Err(msg)
      Ok(nh) => {
        x = x ^ (3U * nh)
        match @value.Value::hash(e.1) {
          Err(msg) => return Err(msg)
          Ok(vh) => {
            x = x ^ (vh * m)
            m = m + struct_hash_mult_step
          }
        }
      }
    }
  }
  Ok(x)
}

///|
fn struct_get_attr(
  ctor : @value.Value,
  entries : Array[(String, @value.Value)],
  name : String,
) -> Result[@value.Value?, String] {
  if name == "__ctor" {
    return Ok(Some(ctor))
  }
  if name == "__n" {
    return Ok(Some(@value.Value::Int(BigInt::from_int(entries.length()))))
  }
  let nlen = name.length()
  if nlen > 7 && name[0:7] == "__name_" {
    match parse_uint_str(name[7:nlen].to_owned()) {
      Some(i) if i < entries.length() =>
        return Ok(
          Some(@value.Value::String(@value.StarlarkString::new(entries[i].0))),
        )
      _ => return Ok(None)
    }
  }
  if nlen > 6 && name[0:6] == "__val_" {
    match parse_uint_str(name[6:nlen].to_owned()) {
      Some(i) if i < entries.length() => return Ok(Some(entries[i].1))
      _ => return Ok(None)
    }
  }
  let n = entries.length()
  let mut lo = 0
  let mut hi = n
  while lo < hi {
    let mid = (lo + hi) / 2
    if str_lex_cmp(entries[mid].0, name) < 0 {
      lo = mid + 1
    } else {
      hi = mid
    }
  }
  if lo < n && entries[lo].0 == name {
    Ok(Some(entries[lo].1))
  } else {
    let cname = ctor_display(ctor)
    let prefix = if cname == "struct" { "" } else { "\{cname} " }
    Err("\{prefix}struct has no .\{name} attribute")
  }
}

///|
fn get_other_entries(c : @value.CustomValue) -> Array[(String, @value.Value)]? {
  let n = match c.get_attr("__n") {
    Ok(Some(@value.Value::Int(n))) => n.to_int()
    _ => return None
  }
  let entries : Array[(String, @value.Value)] = Array::new(capacity=n)
  for i in 0..<n {
    let name = match c.get_attr("__name_\{i}") {
      Ok(Some(@value.Value::String(s))) => s.raw()
      _ => return None
    }
    let val = match c.get_attr("__val_\{i}") {
      Ok(Some(v)) => v
      _ => return None
    }
    entries.push((name, val))
  }
  Some(entries)
}

///|
fn merge_entries(
  left : Array[(String, @value.Value)],
  right : Array[(String, @value.Value)],
) -> Array[(String, @value.Value)] {
  // MoonBit's Map is a sorted tree map, so inserting left then right gives the
  // right operand priority on key collisions and yields the merged fields in
  // sorted-name order (matching how struct fields are otherwise enumerated).
  let m : Map[String, @value.Value] = {}
  for e in left {
    m[e.0] = e.1
  }
  for e in right {
    m[e.0] = e.1
  }
  let result : Array[(String, @value.Value)] = []
  for k, v in m {
    result.push((k, v))
  }
  result
}

///|
fn struct_equals(
  ctor : @value.Value,
  entries : Array[(String, @value.Value)],
  other : @value.Value,
  depth : Int,
) -> Result[Bool, String] {
  match other {
    @value.Value::ExtVal(c) if c.get_type_name() == "struct" => {
      let other_ctor = match c.get_attr("__ctor") {
        Ok(Some(v)) => v
        _ => return Ok(false)
      }
      match @value.starlark_equals_depth(ctor, other_ctor, depth) {
        Ok(false) => return Ok(false)
        Err(e) => return Err(e)
        Ok(true) => ()
      }
      let other_n = match c.get_attr("__n") {
        Ok(Some(@value.Value::Int(n))) => n.to_int()
        _ => return Ok(false)
      }
      if entries.length() != other_n {
        return Ok(false)
      }
      for i in 0..<entries.length() {
        let other_name = match c.get_attr("__name_\{i}") {
          Ok(Some(@value.Value::String(s))) => s.raw()
          _ => return Ok(false)
        }
        if entries[i].0 != other_name {
          return Ok(false)
        }
        let other_val = match c.get_attr("__val_\{i}") {
          Ok(Some(v)) => v
          _ => return Ok(false)
        }
        match @value.starlark_equals_depth(entries[i].1, other_val, depth) {
          Ok(false) => return Ok(false)
          Err(e) => return Err(e)
          Ok(true) => ()
        }
      }
      Ok(true)
    }
    _ => Ok(false)
  }
}

///|
fn struct_binary(
  ctor : @value.Value,
  entries : Array[(String, @value.Value)],
  op : String,
  other : @value.Value,
  is_left : Bool,
) -> Result[@value.Value, String]? {
  if op != "+" {
    return None
  }
  match other {
    @value.Value::ExtVal(c) if c.get_type_name() == "struct" => {
      let other_ctor = match c.get_attr("__ctor") {
        Ok(Some(v)) => v
        _ => return Some(Err("struct: cannot add, could not read constructor"))
      }
      let other_entries = match get_other_entries(c) {
        Some(es) => es
        None => return Some(Err("struct: cannot add, could not read entries"))
      }
      let ctors_equal = match
        @value.starlark_equals_depth(ctor, other_ctor, @value.compare_limit) {
        Ok(eq) => eq
        Err(_) => false
      }
      if !ctors_equal {
        let (lname, rname) = if is_left {
          (ctor_display(ctor), ctor_display(other_ctor))
        } else {
          (ctor_display(other_ctor), ctor_display(ctor))
        }
        return Some(
          Err(
            "cannot add structs of different constructors: \{lname} + \{rname}",
          ),
        )
      }
      if is_left {
        Some(Ok(make_struct(ctor, merge_entries(entries, other_entries))))
      } else {
        Some(Ok(make_struct(other_ctor, merge_entries(other_entries, entries))))
      }
    }
    // Non-struct operand is unhandled; returning None lets the evaluator
    // emit the standard "unknown binary op: ..." message.
    _ => None
  }
}

///|
/// Creates a struct `ExtVal` from a constructor value and field key-value pairs.
/// Fields are stored sorted by name. The struct supports attribute access,
/// equality, hashing, and `+` merge. Freeze propagates transitively.
///
/// Parameters:
///
/// - `ctor` : The constructor value that names and identifies this struct type.
/// - `entries` : The field name/value pairs that make up the struct's attributes.
///
/// Returns a `@value.Value::ExtVal` representing the constructed struct.
pub fn make_struct(
  ctor : @value.Value,
  entries : Array[(String, @value.Value)],
) -> @value.Value {
  let sorted = entries.copy()
  sorted.sort_by(fn(a, b) { str_lex_cmp(a.0, b.0) })
  let frozen_ref : Ref[Bool] = { val: false }
  @value.Value::ExtVal(
    @value.CustomValue::new(fn() { "struct" }, fn() { true }, fn() {
      struct_repr(ctor, sorted)
    })
    .with_repr_depth(fn(depth) { struct_repr_depth(ctor, sorted, depth) })
    .with_hash(fn() { struct_hash(sorted) })
    .with_equals(fn(other, depth) { struct_equals(ctor, sorted, other, depth) })
    .with_attrs(fn(name) { struct_get_attr(ctor, sorted, name) }, fn() {
      sorted.map(fn(e) { e.0 })
    })
    .with_binary(fn(op, other, is_left) {
      struct_binary(ctor, sorted, op, other, is_left)
    })
    .with_freeze(fn() {
      if !frozen_ref.val {
        frozen_ref.val = true
        @value.Value::freeze(ctor)
        for e in sorted {
          @value.Value::freeze(e.1)
        }
      }
    }),
  )
}

///|
/// The default struct constructor string, `"struct"`, used when no explicit
/// constructor is specified.
pub let default_ctor : @value.Value = @value.Value::String(
  @value.StarlarkString::new("struct"),
)

///|
/// Returns the `struct()` Starlark builtin function. Accepts keyword arguments
/// only; each keyword becomes a field. Rejects positional arguments.
///
/// Returns the `struct` builtin as a callable `@value.Value`.
pub fn struct_builtin() -> @value.Value {
  @value.Value::new_builtin("struct", fn(_ctx, pos_args, kw_args) {
    if pos_args.length() > 0 {
      return Err("struct: unexpected positional arguments")
    }
    Ok(make_struct(default_ctor, kw_args))
  })
}

///|
/// Returns the `gensym()` Starlark builtin function, which creates a unique
/// callable symbol. An optional `name=` keyword argument sets its display name.
///
/// Returns the `gensym` builtin as a callable `@value.Value`.
pub fn gensym_builtin() -> @value.Value {
  @value.Value::new_builtin("gensym", fn(_ctx, pos_args, kw_args) {
    if pos_args.length() > 0 {
      return Err("gensym: unexpected positional arguments")
    }
    let mut name_val : @value.Value? = None
    for pair in kw_args {
      if pair.0 == "name" {
        name_val = Some(pair.1)
        break
      }
    }
    let name = match name_val {
      Some(@value.Value::String(s)) => s.raw()
      Some(_) => return Err("gensym: name must be a string")
      None => return Err("gensym: missing required keyword argument 'name'")
    }
    Ok(make_symbol(name))
  })
}

///|
fn make_symbol(name : String) -> @value.Value {
  let sym_id = next_symbol_id()
  make_symbol_with_id(name, sym_id)
}

///|
fn make_symbol_with_id(name : String, sym_id : Int) -> @value.Value {
  @value.Value::ExtVal(
    @value.CustomValue::new(fn() { "symbol" }, fn() { true }, fn() { name })
    .with_hash(fn() { Err("unhashable: symbol") })
    .with_equals(fn(other, _depth) {
      Ok(
        match other {
          @value.Value::ExtVal(c) if c.get_type_name() == "symbol" =>
            match c.get_attr("__id") {
              Ok(Some(@value.Value::Int(oid))) =>
                oid == BigInt::from_int64(sym_id.to_int64())
              _ => false
            }
          _ => false
        },
      )
    })
    .with_attrs(
      fn(attr) {
        if attr == "__id" {
          Ok(Some(@value.Value::Int(BigInt::from_int64(sym_id.to_int64()))))
        } else {
          Ok(None)
        }
      },
      fn() { [] },
    )
    .with_call(fn(pos_args, kw_args) {
      if pos_args.length() > 0 {
        return Err("\{name}: unexpected positional arguments")
      }
      Ok(make_struct(make_symbol_with_id(name, sym_id), kw_args))
    }),
  )
}

///|
let symbol_counter : Ref[Int] = { val: 0 }

///|
fn next_symbol_id() -> Int {
  symbol_counter.val += 1
  symbol_counter.val
}
