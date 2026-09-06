// A module is a named collection of values, typically a suite of functions
// imported by a load statement. It differs from a struct primarily in that
// its string representation does not enumerate its fields.

///|
/// Returns the canonical string representation of a module with the given
/// `name`, formatted as `<module 'name'>`.
fn module_repr(name : String) -> String {
  "<module \{(@value.Value::String(@value.StarlarkString::new(name))).repr()}>"
}

///|
/// Looks up `name` in a list of module members and returns the first
/// matching value, or `None` if no entry matches.
///
/// Parameters:
///
/// - `members` : Attribute name/value pairs to search through linearly.
/// - `name` : The attribute name to look up.
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
///
/// Parameters:
///
/// - `name` : The display name of the module, shown in its string
///   representation.
/// - `members` : The attribute name/value pairs exported by the module.
///
/// Returns a `@value.Value::ExtVal` representing the constructed module.
pub fn make_module(
  name : String,
  members : Array[(String, @value.Value)],
) -> @value.Value {
  let sorted = members.copy()
  sorted.sort_by(fn(a, b) { str_lex_cmp(a.0, b.0) })
  let frozen_ref : Ref[Bool] = { val: false, }
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
          e.1.freeze()
        }
      }
    }),
  )
}

///|
/// Returns the `module()` Starlark builtin function. Takes exactly one
/// positional string argument (the module name) and keyword arguments
/// that become the module's member attributes.
///
/// Returns the `module` builtin as a callable `@value.Value`.
pub fn module_builtin() -> @value.Value {
  @value.Value::new_builtin("module", fn(_ctx, pos_args, kw_args) {
    if pos_args.length() != 1 {
      return Err("module: got \{pos_args.length()} arguments, want 1")
    }
    let name = match pos_args[0] {
      @value.Value::String(s) => s.raw()
      v =>
        return Err("module: for parameter 1: got \{v.type_name()}, want string")
    }
    Ok(make_module(name, kw_args))
  })
}
