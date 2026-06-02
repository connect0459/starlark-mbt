///|
/// An insertion-ordered mapping from Starlark hashable keys to values.
/// Wraps `Hashtable[Value, Value]`; mutation is rejected when frozen or
/// under active iteration.
pub struct StarlarkDict {
  priv ht : @hashtable.Hashtable[Value, Value]
}

///|
/// Creates an empty `StarlarkDict`.
///
/// Returns a new, unfrozen, empty dict with no entries.
pub fn StarlarkDict::new() -> StarlarkDict {
  {
    ht: @hashtable.Hashtable::new(
      starlark_hash,
      fn(a, b) { a.starlark_equals(b) },
      Value::None,
      Value::None,
    ),
  }
}

///|
fn StarlarkDict::is_same_storage(
  self : StarlarkDict,
  other : StarlarkDict,
) -> Bool {
  physical_equal(self.ht, other.ht)
}

///|
/// Returns the number of key-value entries.
///
/// Returns the count of entries currently stored in the dict.
pub fn StarlarkDict::length(self : StarlarkDict) -> Int {
  self.ht.length()
}

///|
/// Returns `true` if the dict has been frozen and can no longer be mutated.
///
/// Returns `true` when the dict is frozen, `false` otherwise.
pub fn StarlarkDict::is_frozen(self : StarlarkDict) -> Bool {
  self.ht.is_frozen()
}

///|
/// Freezes the dict, making it immutable. Subsequent mutations raise an error.
pub fn StarlarkDict::freeze(self : StarlarkDict) -> Unit {
  self.ht.freeze()
}

///|
/// Inserts or updates the entry for `key`. Returns `Err` if the dict is frozen,
/// has active iterators, or if `key` is unhashable.
///
/// Parameters:
///
/// - `self` : The dict to update.
/// - `key` : The key to insert or update; must be hashable.
/// - `value` : The value to associate with `key`.
///
/// Returns `Ok(())` on success, or `Err` with an error message on failure.
pub fn StarlarkDict::set(
  self : StarlarkDict,
  key : Value,
  value : Value,
) -> Result[Unit, String] {
  self.ht.insert(key, value)
}

///|
/// Returns the value for `key`, or `None` if absent. Returns `Err` if `key`
/// is unhashable.
///
/// Parameters:
///
/// - `self` : The dict to look up in.
/// - `key` : The key to search for; must be hashable.
///
/// Returns `Ok(Some(v))` if the key is present, `Ok(None)` if absent, or
/// `Err` if the key is unhashable.
pub fn StarlarkDict::get(
  self : StarlarkDict,
  key : Value,
) -> Result[Value?, String] {
  self.ht.lookup(key)
}

///|
/// Removes the entry for `key`. Returns `true` if the key was present,
/// `false` if absent. Returns `Err` if frozen, under active iteration,
/// or if `key` is unhashable.
///
/// Parameters:
///
/// - `self` : The dict to remove from.
/// - `key` : The key to remove; must be hashable.
///
/// Returns `Ok(true)` if the key was present and removed, `Ok(false)` if the
/// key was absent, or `Err` if the dict is frozen, under active iteration, or
/// the key is unhashable.
pub fn StarlarkDict::delete(
  self : StarlarkDict,
  key : Value,
) -> Result[Bool, String] {
  self.ht.delete(key)
}

///|
/// Iterates over all key-value pairs in insertion order, calling `f` for each.
///
/// Parameters:
///
/// - `self` : The dict to iterate over.
/// - `f` : The callback invoked with each key-value pair.
pub fn StarlarkDict::each(
  self : StarlarkDict,
  f : (Value, Value) -> Unit,
) -> Unit {
  self.ht.each(f)
}

///|
fn StarlarkDict::iter_begin(self : StarlarkDict) -> Unit {
  self.ht.iter_begin()
}

///|
fn StarlarkDict::iter_end(self : StarlarkDict) -> Unit {
  self.ht.iter_end()
}

///|
/// Returns a snapshot of all keys in insertion order.
///
/// Returns an array containing every key in the dict, in insertion order.
pub fn StarlarkDict::keys(self : StarlarkDict) -> Array[Value] {
  let arr : Array[Value] = []
  self.ht.each_key(fn(k) { arr.push(k) })
  arr
}

///|
/// Returns an `Iter` over all key-value pairs in insertion order.
///
/// Returns a lazy iterator over `(key, value)` pairs in insertion order.
pub fn StarlarkDict::to_entries(self : StarlarkDict) -> Iter[(Value, Value)] {
  let arr : Array[(Value, Value)] = []
  self.ht.each(fn(k, v) { arr.push((k, v)) })
  arr.iter()
}

///|
/// Removes all entries. Returns `Err` if the dict is frozen or under active
/// iteration.
///
/// Returns `Ok(())` on success, or `Err` with an error message if the dict is
/// frozen or under active iteration.
pub fn StarlarkDict::clear(self : StarlarkDict) -> Result[Unit, String] {
  self.ht.clear()
}

///|
/// Removes and returns the first inserted key-value pair, or `None` if empty.
/// Returns `Err` if frozen or under active iteration.
///
/// Returns `Ok(Some((key, value)))` if an entry was removed, `Ok(None)` if the
/// dict is empty, or `Err` if the dict is frozen or under active iteration.
pub fn StarlarkDict::popitem(
  self : StarlarkDict,
) -> Result[(Value, Value)?, String] {
  self.ht.pop_first()
}

///|
/// An insertion-ordered set of Starlark hashable values.
/// Wraps `Hashtable[Value, Value]` (values are `None`); mutation is rejected
/// when frozen or under active iteration.
pub struct StarlarkSet {
  priv ht : @hashtable.Hashtable[Value, Value]
}

///|
/// Creates an empty `StarlarkSet`.
///
/// Returns a new, unfrozen, empty set with no elements.
pub fn StarlarkSet::new() -> StarlarkSet {
  {
    ht: @hashtable.Hashtable::new(
      starlark_hash,
      fn(a, b) { a.starlark_equals(b) },
      Value::None,
      Value::None,
    ),
  }
}

///|
/// Returns the number of elements.
///
/// Returns the count of elements currently stored in the set.
pub fn StarlarkSet::length(self : StarlarkSet) -> Int {
  self.ht.length()
}

///|
/// Returns `true` if the set has been frozen and can no longer be mutated.
///
/// Returns `true` when the set is frozen, `false` otherwise.
pub fn StarlarkSet::is_frozen(self : StarlarkSet) -> Bool {
  self.ht.is_frozen()
}

///|
/// Freezes the set, making it immutable. Subsequent mutations raise an error.
pub fn StarlarkSet::freeze(self : StarlarkSet) -> Unit {
  self.ht.freeze()
}

///|
/// Inserts `key` into the set. Returns `Err` if the set is frozen, under
/// active iteration, or if `key` is unhashable.
///
/// Parameters:
///
/// - `self` : The set to insert into.
/// - `key` : The value to add; must be hashable.
///
/// Returns `Ok(())` on success, or `Err` with an error message on failure.
pub fn StarlarkSet::add(
  self : StarlarkSet,
  key : Value,
) -> Result[Unit, String] {
  self.ht.insert(key, Value::None)
}

///|
/// Returns `true` if `key` is in the set. Returns `Err` if `key` is
/// unhashable.
///
/// Parameters:
///
/// - `self` : The set to search.
/// - `key` : The value to look for; must be hashable.
///
/// Returns `Ok(true)` if the value is present, `Ok(false)` if absent, or
/// `Err` if the key is unhashable.
pub fn StarlarkSet::contains(
  self : StarlarkSet,
  key : Value,
) -> Result[Bool, String] {
  self.ht.contains(key)
}

///|
/// Removes `key` from the set. Returns `true` if the key was present,
/// `false` if absent. Returns `Err` if frozen, under active iteration,
/// or if `key` is unhashable.
///
/// Parameters:
///
/// - `self` : The set to remove from.
/// - `key` : The value to remove; must be hashable.
///
/// Returns `Ok(true)` if the value was present and removed, `Ok(false)` if
/// absent, or `Err` if the set is frozen, under active iteration, or the key
/// is unhashable.
pub fn StarlarkSet::remove(
  self : StarlarkSet,
  key : Value,
) -> Result[Bool, String] {
  self.ht.delete(key)
}

///|
/// Iterates over all keys in insertion order, calling `f` for each.
///
/// Parameters:
///
/// - `self` : The set to iterate over.
/// - `f` : The callback invoked with each element.
pub fn StarlarkSet::each(self : StarlarkSet, f : (Value) -> Unit) -> Unit {
  self.ht.each_key(f)
}

///|
fn StarlarkSet::iter_begin(self : StarlarkSet) -> Unit {
  self.ht.iter_begin()
}

///|
fn StarlarkSet::iter_end(self : StarlarkSet) -> Unit {
  self.ht.iter_end()
}

///|
/// Returns an `Iter` over all keys in insertion order.
///
/// Returns a lazy iterator over elements in insertion order.
pub fn StarlarkSet::to_iter(self : StarlarkSet) -> Iter[Value] {
  let arr : Array[Value] = []
  self.ht.each_key(fn(k) { arr.push(k) })
  arr.iter()
}

///|
/// Removes all elements. Returns `Err` if the set is frozen or under active
/// iteration.
///
/// Returns `Ok(())` on success, or `Err` with an error message if the set is
/// frozen or under active iteration.
pub fn StarlarkSet::clear(self : StarlarkSet) -> Result[Unit, String] {
  self.ht.clear()
}

///|
/// Removes and returns the first inserted key, or `None` if empty.
/// Returns `Err` if the set is frozen or under active iteration.
///
/// Returns `Ok(Some(v))` if an element was removed, `Ok(None)` if the set is
/// empty, or `Err` if the set is frozen or under active iteration.
pub fn StarlarkSet::pop_first(self : StarlarkSet) -> Result[Value?, String] {
  match self.ht.pop_first() {
    Err(e) => Err(e)
    Ok(None) => Ok(None)
    Ok(Some((k, _))) => Ok(Some(k))
  }
}
