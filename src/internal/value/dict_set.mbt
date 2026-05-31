///|
/// An insertion-ordered mapping from Starlark hashable keys to values.
/// Wraps `Hashtable[Value, Value]`; mutation is rejected when frozen or
/// under active iteration.
pub struct StarlarkDict {
  priv ht : @hashtable.Hashtable[Value, Value]
}

///|
/// Creates an empty `StarlarkDict`.
pub fn StarlarkDict::new() -> StarlarkDict {
  {
    ht: @hashtable.Hashtable::new(
      starlark_hash,
      starlark_equals,
      Value::None,
      Value::None,
    ),
  }
}

///|
/// Returns `true` if `self` and `other` share the same underlying hash table
/// (i.e. are the same dict object).
pub fn StarlarkDict::is_same_storage(
  self : StarlarkDict,
  other : StarlarkDict,
) -> Bool {
  physical_equal(self.ht, other.ht)
}

///|
/// Returns the number of key-value entries.
pub fn StarlarkDict::length(self : StarlarkDict) -> Int {
  self.ht.length()
}

///|
/// Returns `true` if the dict has been frozen and can no longer be mutated.
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
pub fn StarlarkDict::delete(
  self : StarlarkDict,
  key : Value,
) -> Result[Bool, String] {
  self.ht.delete(key)
}

///|
/// Iterates over all key-value pairs in insertion order, calling `f` for each.
pub fn StarlarkDict::each(
  self : StarlarkDict,
  f : (Value, Value) -> Unit,
) -> Unit {
  self.ht.each(f)
}

///|
/// Marks the start of a Starlark `for`-loop iteration; increments the
/// iterator count, which prevents mutation until `iter_end` is called.
pub fn StarlarkDict::iter_begin(self : StarlarkDict) -> Unit {
  self.ht.iter_begin()
}

///|
/// Marks the end of a Starlark `for`-loop iteration; decrements the iterator
/// count, restoring mutability when it reaches zero.
pub fn StarlarkDict::iter_end(self : StarlarkDict) -> Unit {
  self.ht.iter_end()
}

///|
/// Returns a snapshot of all keys in insertion order.
pub fn StarlarkDict::keys(self : StarlarkDict) -> Array[Value] {
  let arr : Array[Value] = []
  self.ht.each_key(fn(k) { arr.push(k) })
  arr
}

///|
/// Returns an `Iter` over all key-value pairs in insertion order.
pub fn StarlarkDict::to_entries(self : StarlarkDict) -> Iter[(Value, Value)] {
  let arr : Array[(Value, Value)] = []
  self.ht.each(fn(k, v) { arr.push((k, v)) })
  arr.iter()
}

///|
/// Returns an `Iter` over all keys in insertion order.
pub fn StarlarkDict::to_keys(self : StarlarkDict) -> Iter[Value] {
  self.keys().iter()
}

///|
/// Removes all entries. Returns `Err` if the dict is frozen or under active
/// iteration.
pub fn StarlarkDict::clear(self : StarlarkDict) -> Result[Unit, String] {
  self.ht.clear()
}

///|
/// Removes and returns the first inserted key-value pair, or `None` if empty.
/// Returns `Err` if frozen or under active iteration.
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
pub fn StarlarkSet::new() -> StarlarkSet {
  {
    ht: @hashtable.Hashtable::new(
      starlark_hash,
      starlark_equals,
      Value::None,
      Value::None,
    ),
  }
}

///|
/// Returns the number of elements.
pub fn StarlarkSet::length(self : StarlarkSet) -> Int {
  self.ht.length()
}

///|
/// Returns `true` if the set has been frozen and can no longer be mutated.
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
pub fn StarlarkSet::add(
  self : StarlarkSet,
  key : Value,
) -> Result[Unit, String] {
  self.ht.insert(key, Value::None)
}

///|
/// Returns `true` if `key` is in the set. Returns `Err` if `key` is
/// unhashable.
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
pub fn StarlarkSet::remove(
  self : StarlarkSet,
  key : Value,
) -> Result[Bool, String] {
  self.ht.delete(key)
}

///|
/// Iterates over all keys in insertion order, calling `f` for each.
pub fn StarlarkSet::each(self : StarlarkSet, f : (Value) -> Unit) -> Unit {
  self.ht.each_key(f)
}

///|
/// Marks the start of a Starlark `for`-loop iteration; increments the
/// iterator count, which prevents mutation until `iter_end` is called.
pub fn StarlarkSet::iter_begin(self : StarlarkSet) -> Unit {
  self.ht.iter_begin()
}

///|
/// Marks the end of a Starlark `for`-loop iteration; decrements the iterator
/// count, restoring mutability when it reaches zero.
pub fn StarlarkSet::iter_end(self : StarlarkSet) -> Unit {
  self.ht.iter_end()
}

///|
/// Returns an `Iter` over all keys in insertion order.
pub fn StarlarkSet::to_iter(self : StarlarkSet) -> Iter[Value] {
  let arr : Array[Value] = []
  self.ht.each_key(fn(k) { arr.push(k) })
  arr.iter()
}

///|
/// Removes all elements. Returns `Err` if the set is frozen or under active
/// iteration.
pub fn StarlarkSet::clear(self : StarlarkSet) -> Result[Unit, String] {
  self.ht.clear()
}

///|
/// Removes and returns the first inserted key, or `None` if empty.
/// Returns `Err` if the set is frozen or under active iteration.
pub fn StarlarkSet::pop_first(self : StarlarkSet) -> Result[Value?, String] {
  match self.ht.pop_first() {
    Err(e) => Err(e)
    Ok(None) => Ok(None)
    Ok(Some((k, _))) => Ok(Some(k))
  }
}
