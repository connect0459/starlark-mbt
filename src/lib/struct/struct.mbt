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
  let buf = StringBuilder::new()
  buf.write_string(ctor_display(ctor))
  buf.write_char('(')
  for i, e in entries {
    if i > 0 {
      buf.write_string(", ")
    }
    buf.write_string(e.0)
    buf.write_string(" = ")
    buf.write_string(e.1.repr())
  }
  buf.write_char(')')
  buf.to_string()
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
      @value.starlark_hash(
        @value.Value::String(@value.StarlarkString::new(e.0)),
      ) {
      Err(msg) => return Err(msg)
      Ok(nh) => {
        x = x ^ (3U * nh)
        match @value.starlark_hash(e.1) {
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
    if entries[mid].0 < name {
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
) -> Bool {
  match other {
    @value.Value::ExtVal(c) if c.get_type_name() == "struct" => {
      let other_ctor = match c.get_attr("__ctor") {
        Ok(Some(v)) => v
        _ => return false
      }
      if !ctor.starlark_equals(other_ctor) {
        return false
      }
      let other_n = match c.get_attr("__n") {
        Ok(Some(@value.Value::Int(n))) => n.to_int()
        _ => return false
      }
      if entries.length() != other_n {
        return false
      }
      for i in 0..<entries.length() {
        let other_name = match c.get_attr("__name_\{i}") {
          Ok(Some(@value.Value::String(s))) => s.raw()
          _ => return false
        }
        if entries[i].0 != other_name {
          return false
        }
        let other_val = match c.get_attr("__val_\{i}") {
          Ok(Some(v)) => v
          _ => return false
        }
        if !entries[i].1.starlark_equals(other_val) {
          return false
        }
      }
      true
    }
    _ => false
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
      if is_left {
        if !ctor.starlark_equals(other_ctor) {
          let lname = ctor_display(ctor)
          let rname = ctor_display(other_ctor)
          return Some(
            Err(
              "cannot add structs of different constructors: \{lname} + \{rname}",
            ),
          )
        }
        Some(Ok(make_struct(ctor, merge_entries(entries, other_entries))))
      } else {
        if !other_ctor.starlark_equals(ctor) {
          let lname = ctor_display(other_ctor)
          let rname = ctor_display(ctor)
          return Some(
            Err(
              "cannot add structs of different constructors: \{lname} + \{rname}",
            ),
          )
        }
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
  sorted.sort_by(fn(a, b) { a.0.compare(b.0) })
  let frozen_ref : Ref[Bool] = { val: false }
  @value.Value::ExtVal(
    @value.CustomValue::new(fn() { "struct" }, fn() { true }, fn() {
      struct_repr(ctor, sorted)
    })
    .with_hash(fn() { struct_hash(sorted) })
    .with_equals(fn(other) { struct_equals(ctor, sorted, other) })
    .with_attrs(fn(name) { struct_get_attr(ctor, sorted, name) }, fn() {
      sorted.map(fn(e) { e.0 })
    })
    .with_binary(fn(op, other, is_left) {
      struct_binary(ctor, sorted, op, other, is_left)
    })
    .with_freeze(fn() {
      if !frozen_ref.val {
        frozen_ref.val = true
        @value.freeze_value(ctor)
        for e in sorted {
          @value.freeze_value(e.1)
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
    .with_equals(fn(other) {
      match other {
        @value.Value::ExtVal(c) if c.get_type_name() == "symbol" =>
          match c.get_attr("__id") {
            Ok(Some(@value.Value::Int(oid))) =>
              oid == BigInt::from_int64(sym_id.to_int64())
            _ => false
          }
        _ => false
      }
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
