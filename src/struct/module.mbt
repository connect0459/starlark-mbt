// A module is a named collection of values, typically a suite of functions
// imported by a load statement. It differs from a struct primarily in that
// its string representation does not enumerate its fields.

///|
fn module_repr(name : String) -> String {
  "<module \{@value.repr(@value.Value::String(@value.StarlarkString::new(name)))}>"
}

///|
fn module_get_attr(
  members : Array[(String, @value.Value)],
  name : String,
) -> Result[@value.Value?, String] {
  for entry in members {
    if entry.0 == name {
      return Ok(Some(entry.1))
    }
  }
  Ok(None)
}

///|
/// Creates a module-typed `ExtVal` with the given `name` and `members`.
/// Members are stored sorted by name. Supports attribute access and
/// `dir()`; does not support hashing or `+` merge. Freeze propagates
/// transitively.
pub fn make_module(
  name : String,
  members : Array[(String, @value.Value)],
) -> @value.Value {
  let sorted = members.copy()
  sorted.sort_by(fn(a, b) { a.0.compare(b.0) })
  let frozen_ref : Ref[Bool] = { val: false }
  @value.Value::ExtVal(
    @value.CustomValue::new(fn() { "module" }, fn() { true }, fn() {
      module_repr(name)
    })
    .with_hash(fn() { Err("unhashable: module") })
    .with_attrs(fn(attr) { module_get_attr(sorted, attr) }, fn() {
      sorted.map(fn(e) { e.0 })
    })
    .with_freeze(fn() {
      if !frozen_ref.val {
        frozen_ref.val = true
        for e in sorted {
          @value.freeze_value(e.1)
        }
      }
    }),
  )
}

///|
/// Returns the `module()` Starlark builtin function. Takes exactly one
/// positional string argument (the module name) and keyword arguments
/// that become the module's member attributes.
pub fn module_builtin() -> @value.Value {
  @value.Value::new_builtin("module", fn(_ctx, pos_args, kw_args) {
    if pos_args.length() != 1 {
      return Err("module: got \{pos_args.length()} arguments, want 1")
    }
    let name = match pos_args[0] {
      @value.Value::String(s) => s.raw()
      v =>
        return Err(
          "module: for parameter 1: got \{@value.type_name(v)}, want string",
        )
    }
    Ok(make_module(name, kw_args))
  })
}
