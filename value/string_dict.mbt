///|
/// A string-keyed dict of `Value`s; used by the embedding API to pass named
/// globals to `eval_expr` and to inspect module exports.
pub struct StringDict {
  priv data : Map[String, Value]
}

///|
/// Creates an empty `StringDict`.
///
/// Returns a new `StringDict` with no bindings.
pub fn StringDict::new() -> StringDict {
  { data: {} }
}

///|
/// Creates a `StringDict` wrapping an existing `Map[String, Value]`.
///
/// Parameters:
///
/// - `m` : The map to wrap; ownership is transferred.
///
/// Returns a `StringDict` backed by `m`.
pub fn StringDict::from_map(m : Map[String, Value]) -> StringDict {
  { data: m }
}

///|
/// Inserts or updates the binding for `key`.
///
/// Parameters:
///
/// - `self` : The dict to modify.
/// - `key` : The string key to bind.
/// - `v` : The value to associate with `key`.
pub fn StringDict::set(self : StringDict, key : String, v : Value) -> Unit {
  self.data[key] = v
}

///|
/// Returns the value bound to `key`, or `None`.
///
/// Parameters:
///
/// - `self` : The dict to look up in.
/// - `key` : The string key to retrieve.
///
/// Returns `Some(value)` if `key` is present, `None` otherwise.
pub fn StringDict::get(self : StringDict, key : String) -> Value? {
  self.data.get(key)
}

///|
/// Returns `true` if `key` is present.
///
/// Parameters:
///
/// - `self` : The dict to query.
/// - `key` : The string key to test for presence.
///
/// Returns `true` if `key` exists in the dict.
pub fn StringDict::has(self : StringDict, key : String) -> Bool {
  self.data.contains(key)
}

///|
/// Returns the keys in lexicographic order.
///
/// Parameters:
///
/// - `self` : The dict whose keys to retrieve.
///
/// Returns an array of all keys sorted lexicographically.
pub fn StringDict::keys(self : StringDict) -> Array[String] {
  let ks = self.data.keys().collect()
  ks.sort_by(fn(a, b) {
    let la = a.length()
    let lb = b.length()
    let min_len = if la < lb { la } else { lb }
    let mut result = 0
    let mut i = 0
    while i < min_len && result == 0 {
      let ca = a.get_char(i).unwrap()
      let cb = b.get_char(i).unwrap()
      result = ca.compare(cb)
      i = i + 1
    }
    if result != 0 {
      result
    } else {
      la.compare(lb)
    }
  })
  ks
}

///|
/// Removes the binding for `key`.
///
/// Parameters:
///
/// - `self` : The dict to modify.
/// - `key` : The string key to remove.
///
/// Returns `true` if `key` was present (and removed), `false` if absent.
pub fn StringDict::delete(self : StringDict, key : String) -> Bool {
  if self.data.contains(key) {
    self.data.remove(key)
    true
  } else {
    false
  }
}

///|
/// Calls `f(key, value)` for every entry in the dict.
///
/// Parameters:
///
/// - `self` : The dict to iterate.
/// - `f` : Callback receiving each key-value pair.
pub fn StringDict::each(self : StringDict, f : (String, Value) -> Unit) -> Unit {
  self.data.each(f)
}

///|
/// Returns all values in the dict.
///
/// Parameters:
///
/// - `self` : The dict whose values to retrieve.
///
/// Returns an array of all values.
pub fn StringDict::values(self : StringDict) -> Array[Value] {
  self.data.values().collect()
}

///|
/// Recursively deep-freezes all values in the dict.
///
/// Parameters:
///
/// - `self` : The dict whose values to freeze.
pub fn StringDict::freeze(self : StringDict) -> Unit {
  self.data.each(fn(_, v) { v.freeze() })
}

///|
/// Like `StringDict::freeze` but returns `Err` instead of aborting when the
/// nesting depth limit is exceeded.
pub fn StringDict::freeze_checked(self : StringDict) -> Result[Unit, String] {
  let mut err : String? = None
  self.data.each(fn(_, v) {
    if err is None {
      match v.freeze_checked() {
        Err(e) => err = Some(e)
        Ok(_) => ()
      }
    }
  })
  match err {
    Some(e) => Err(e)
    None => Ok(())
  }
}
