///|
pub(all) struct StarlarkDict {
  ht : @hashtable.Hashtable[Value, Value]
}

///|
pub fn StarlarkDict::new() -> StarlarkDict {
  {
    ht: @hashtable.Hashtable::new(
      starlark_hash,
      starlark_equals,
      Value::NoneVal,
      Value::NoneVal,
    ),
  }
}

///|
pub fn StarlarkDict::length(self : StarlarkDict) -> Int {
  self.ht.length()
}

///|
pub fn StarlarkDict::is_frozen(self : StarlarkDict) -> Bool {
  self.ht.is_frozen()
}

///|
pub fn StarlarkDict::freeze(self : StarlarkDict) -> Unit {
  self.ht.freeze()
}

///|
pub fn StarlarkDict::set(
  self : StarlarkDict,
  key : Value,
  value : Value,
) -> Result[Unit, String] {
  self.ht.insert(key, value)
}

///|
pub fn StarlarkDict::get(
  self : StarlarkDict,
  key : Value,
) -> Result[Value?, String] {
  self.ht.lookup(key)
}

///|
pub fn StarlarkDict::delete(
  self : StarlarkDict,
  key : Value,
) -> Result[Bool, String] {
  self.ht.delete(key)
}

///|
pub fn StarlarkDict::each(
  self : StarlarkDict,
  f : (Value, Value) -> Unit,
) -> Unit {
  self.ht.each(f)
}

///|
pub fn StarlarkDict::iter_begin(self : StarlarkDict) -> Unit {
  self.ht.iter_begin()
}

///|
pub fn StarlarkDict::iter_end(self : StarlarkDict) -> Unit {
  self.ht.iter_end()
}

///|
pub fn StarlarkDict::keys(self : StarlarkDict) -> Array[Value] {
  let arr : Array[Value] = []
  self.ht.each_key(fn(k) { arr.push(k) })
  arr
}

///|
pub fn StarlarkDict::clear(self : StarlarkDict) -> Result[Unit, String] {
  self.ht.clear()
}

///|
pub fn StarlarkDict::popitem(
  self : StarlarkDict,
) -> Result[(Value, Value)?, String] {
  self.ht.pop_first()
}

///|
pub(all) struct StarlarkSet {
  ht : @hashtable.Hashtable[Value, Value]
}

///|
pub fn StarlarkSet::new() -> StarlarkSet {
  {
    ht: @hashtable.Hashtable::new(
      starlark_hash,
      starlark_equals,
      Value::NoneVal,
      Value::NoneVal,
    ),
  }
}

///|
pub fn StarlarkSet::length(self : StarlarkSet) -> Int {
  self.ht.length()
}

///|
pub fn StarlarkSet::is_frozen(self : StarlarkSet) -> Bool {
  self.ht.is_frozen()
}

///|
pub fn StarlarkSet::freeze(self : StarlarkSet) -> Unit {
  self.ht.freeze()
}

///|
pub fn StarlarkSet::add(
  self : StarlarkSet,
  key : Value,
) -> Result[Unit, String] {
  self.ht.insert(key, Value::NoneVal)
}

///|
pub fn StarlarkSet::contains(
  self : StarlarkSet,
  key : Value,
) -> Result[Bool, String] {
  self.ht.contains(key)
}

///|
pub fn StarlarkSet::remove(
  self : StarlarkSet,
  key : Value,
) -> Result[Bool, String] {
  self.ht.delete(key)
}

///|
pub fn StarlarkSet::each(self : StarlarkSet, f : (Value) -> Unit) -> Unit {
  self.ht.each_key(f)
}

///|
pub fn StarlarkSet::iter_begin(self : StarlarkSet) -> Unit {
  self.ht.iter_begin()
}

///|
pub fn StarlarkSet::iter_end(self : StarlarkSet) -> Unit {
  self.ht.iter_end()
}

///|
pub fn StarlarkSet::clear(self : StarlarkSet) -> Result[Unit, String] {
  self.ht.clear()
}

///|
pub fn StarlarkSet::pop_first(self : StarlarkSet) -> Result[Value?, String] {
  match self.ht.pop_first() {
    Err(e) => Err(e)
    Ok(None) => Ok(None)
    Ok(Some((k, _))) => Ok(Some(k))
  }
}
