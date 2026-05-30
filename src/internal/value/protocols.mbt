// Extension protocols for custom Starlark value types.
// Built-in types (List, Dict, Set, String, etc.) implement these capabilities
// internally via the Value enum match expressions in traits.mbt and iter.mbt.
// These traits allow embedders to create custom extension types that participate
// in attribute access, comparison, and the iterator protocol.
//
// Usage: implement these traits on a custom struct, then wrap it in a future
// ExtVal(obj) variant of the Value enum to integrate with the evaluator.

///|
pub trait HasAttrs {
  fn get_attr(Self, String) -> Result[Value?, String]
  fn attr_names(Self) -> Array[String]
}

///|
pub trait HasSetField {
  fn set_field(Self, String, Value) -> Result[Unit, String]
}

///|
pub trait StarlarkComparable {
  fn compare_same_type(Self, Value) -> Result[Int, String]
}

///|
/// Mapping protocol for Dict-like types. Allows embedders to expose custom
/// key-value stores that participate in subscript read, `in` membership, and
/// iteration via the standard evaluator paths.
pub trait Mapping {
  /// Return the value bound to `key`, or `None` if absent.
  fn mapping_get(Self, Value) -> Result[Value?, String]
  /// Return all keys as an ordered array.
  fn mapping_keys(Self) -> Result[Array[Value], String]
  /// Return the number of entries.
  fn mapping_len(Self) -> Int
}

///|
/// Indexable protocol for sequence types that support `a[i]` subscript.
/// Allows embedders to expose custom sequences that participate in the
/// evaluator's subscript and slice paths.
pub trait Indexable {
  /// Return the element at position `i`. `i` is already bounds-checked
  /// (non-negative, less than `indexable_len`); implementations may panic on
  /// out-of-range access.
  fn indexable_get(Self, Int) -> Result[Value, String]
  /// Return the number of elements.
  fn indexable_len(Self) -> Int
}

///|
/// Container protocol for the `in` operator. Embedders implement `has` on
/// custom types to define membership semantics.
pub trait Container {
  fn has(Self, Value) -> Result[Bool, String]
}

///|
/// HasBinary protocol for custom types that define binary operators
/// (+, -, *, /, //, %, &, |, ^, <<, >>, in, not in).
/// Return `Some(Ok(v))` to provide a result, `Some(Err(msg))` to signal an
/// error, or `None` to decline (let the evaluator try the other operand or
/// raise a TypeError).
pub trait HasBinary {
  fn binary_op(Self, op : String, other : Value, is_left : Bool) -> Result[
    Value,
    String,
  ]?
}

///|
/// HasUnary protocol for custom types that define unary operators (+, -, ~).
/// Return `Some(Ok(v))` to provide a result, `Some(Err(msg))` to signal an
/// error, or `None` to decline.
pub trait HasUnary {
  fn unary_op(Self, op : String) -> Result[Value, String]?
}

///|
/// HasSetIndex protocol for indexed sequence types that support element update
/// (`a[i] = v`). The index `i` is already bounds-checked and adjusted for
/// negative values before this method is called.
pub trait HasSetIndex: Indexable {
  fn set_index(Self, Int, Value) -> Result[Unit, String]
}

///|
/// TotallyOrdered protocol for types that define a complete ordering.
/// `cmp` returns a negative Int if `self < other`, zero if equal, or a
/// positive Int if `self > other`. Return `None` if the two values are not
/// comparable (e.g., different types).
pub trait TotallyOrdered {
  fn cmp(Self, Value) -> Int?
}

///|
/// Sliceable protocol for sequence types that support the slice operator
/// (`a[start:end:step]`). `start`, `end`, and `step` are already normalised
/// by the evaluator (non-zero step, adjusted for sequence length).
pub trait Sliceable: Indexable {
  fn slice(Self, Int, Int, Int) -> Result[Value, String]
}

///|
/// IterableMapping protocol for mapping types that support key enumeration
/// and bulk key/value retrieval. Combines `Mapping` with an `items()` method
/// that returns all key/value pairs.
pub trait IterableMapping: Mapping {
  fn items(Self) -> Result[Array[(Value, Value)], String]
}

///|
/// Vtable-based wrapper for embedding custom Starlark value types.
/// Construct with `CustomValue::new`, then call `with_*` builder methods to add
/// optional protocol support. Wrap in `Value::ExtVal(cv)` to produce a Value.
pub struct CustomValue {
  priv type_name_fn : () -> String
  priv truth_fn : () -> Bool
  priv repr_fn : () -> String
  priv hash_fn : (() -> Result[UInt, String])?
  priv equals_fn : ((Value) -> Bool)?
  priv get_attr_fn : ((String) -> Result[Value?, String])?
  priv attr_names_fn : (() -> Array[String])?
  priv set_field_fn : ((String, Value) -> Result[Unit, String])?
  priv contains_fn : ((Value) -> Result[Bool, String])?
  priv iterate_fn : (() -> Result[StarlarkIterator, String])?
  priv length_fn : (() -> Int)?
  priv freeze_fn : (() -> Unit)?
  priv binary_fn : ((String, Value, Bool) -> Result[Value, String]?)?
  priv unary_fn : ((String) -> Result[Value, String]?)?
  priv compare_fn : ((Value) -> Int?)?
  priv get_index_fn : ((Int) -> Result[Value, String])?
  priv set_index_fn : ((Int, Value) -> Result[Unit, String])?
  priv set_key_fn : ((Value, Value) -> Result[Unit, String])?
  priv slice_fn : ((Int, Int, Int) -> Result[Value, String])?
  priv items_fn : (() -> Result[Array[(Value, Value)], String])?
  priv call_fn : ((Array[Value], Array[(String, Value)]) -> Result[
    Value,
    String,
  ])?
}

///|
pub fn CustomValue::new(
  type_name_fn : () -> String,
  truth_fn : () -> Bool,
  repr_fn : () -> String,
) -> CustomValue {
  {
    type_name_fn,
    truth_fn,
    repr_fn,
    hash_fn: None,
    equals_fn: None,
    get_attr_fn: None,
    attr_names_fn: None,
    set_field_fn: None,
    contains_fn: None,
    iterate_fn: None,
    length_fn: None,
    freeze_fn: None,
    binary_fn: None,
    unary_fn: None,
    compare_fn: None,
    get_index_fn: None,
    set_index_fn: None,
    set_key_fn: None,
    slice_fn: None,
    items_fn: None,
    call_fn: None,
  }
}

///|
pub fn CustomValue::with_hash(
  self : CustomValue,
  hash_fn : () -> Result[UInt, String],
) -> CustomValue {
  { ..self, hash_fn: Some(hash_fn) }
}

///|
pub fn CustomValue::with_equals(
  self : CustomValue,
  equals_fn : (Value) -> Bool,
) -> CustomValue {
  { ..self, equals_fn: Some(equals_fn) }
}

///|
pub fn CustomValue::with_attrs(
  self : CustomValue,
  get_attr_fn : (String) -> Result[Value?, String],
  attr_names_fn : () -> Array[String],
) -> CustomValue {
  { ..self, get_attr_fn: Some(get_attr_fn), attr_names_fn: Some(attr_names_fn) }
}

///|
pub fn CustomValue::with_set_field(
  self : CustomValue,
  set_field_fn : (String, Value) -> Result[Unit, String],
) -> CustomValue {
  { ..self, set_field_fn: Some(set_field_fn) }
}

///|
pub fn CustomValue::with_contains(
  self : CustomValue,
  contains_fn : (Value) -> Result[Bool, String],
) -> CustomValue {
  { ..self, contains_fn: Some(contains_fn) }
}

///|
pub fn CustomValue::with_iterate(
  self : CustomValue,
  iterate_fn : () -> Result[StarlarkIterator, String],
) -> CustomValue {
  { ..self, iterate_fn: Some(iterate_fn) }
}

///|
pub fn CustomValue::with_length(
  self : CustomValue,
  length_fn : () -> Int,
) -> CustomValue {
  { ..self, length_fn: Some(length_fn) }
}

///|
pub fn CustomValue::with_freeze(
  self : CustomValue,
  freeze_fn : () -> Unit,
) -> CustomValue {
  { ..self, freeze_fn: Some(freeze_fn) }
}

///|
pub fn CustomValue::with_binary(
  self : CustomValue,
  binary_fn : (String, Value, Bool) -> Result[Value, String]?,
) -> CustomValue {
  { ..self, binary_fn: Some(binary_fn) }
}

///|
pub fn CustomValue::with_unary(
  self : CustomValue,
  unary_fn : (String) -> Result[Value, String]?,
) -> CustomValue {
  { ..self, unary_fn: Some(unary_fn) }
}

///|
pub fn CustomValue::with_compare(
  self : CustomValue,
  compare_fn : (Value) -> Int?,
) -> CustomValue {
  { ..self, compare_fn: Some(compare_fn) }
}

///|
pub fn CustomValue::get_type_name(self : CustomValue) -> String {
  (self.type_name_fn)()
}

///|
pub fn CustomValue::get_truth(self : CustomValue) -> Bool {
  (self.truth_fn)()
}

///|
pub fn CustomValue::get_repr(self : CustomValue) -> String {
  (self.repr_fn)()
}

///|
pub fn CustomValue::get_hash(self : CustomValue) -> Result[UInt, String] {
  match self.hash_fn {
    Some(f) => f()
    None => Err("unhashable type: \{(self.type_name_fn)()}")
  }
}

///|
pub fn CustomValue::get_equals(self : CustomValue, other : Value) -> Bool {
  match self.equals_fn {
    Some(f) => f(other)
    None => false
  }
}

///|
pub fn CustomValue::get_attr(
  self : CustomValue,
  name : String,
) -> Result[Value?, String] {
  match self.get_attr_fn {
    Some(f) => f(name)
    None => Ok(None)
  }
}

///|
pub fn CustomValue::get_attr_names(self : CustomValue) -> Array[String]? {
  match self.attr_names_fn {
    Some(f) => Some(f())
    None => None
  }
}

///|
pub fn CustomValue::get_set_field(
  self : CustomValue,
  name : String,
  v : Value,
) -> Result[Unit, String] {
  match self.set_field_fn {
    Some(f) => f(name, v)
    None => Err("cannot set field on \{(self.type_name_fn)()}")
  }
}

///|
pub fn CustomValue::get_contains(
  self : CustomValue,
  v : Value,
) -> Result[Bool, String]? {
  match self.contains_fn {
    Some(f) => Some(f(v))
    None => None
  }
}

///|
pub fn CustomValue::get_iterate(
  self : CustomValue,
) -> Result[StarlarkIterator, String] {
  match self.iterate_fn {
    Some(f) => f()
    None => Err("'\{(self.type_name_fn)()}' object is not iterable")
  }
}

///|
pub fn CustomValue::get_length(self : CustomValue) -> Result[Int, String] {
  match self.length_fn {
    Some(f) => Ok(f())
    None => Err("object of type '\{(self.type_name_fn)()}' has no len()")
  }
}

///|
pub fn CustomValue::do_freeze(self : CustomValue) -> Unit {
  match self.freeze_fn {
    Some(f) => f()
    None => ()
  }
}

///|
pub fn CustomValue::get_binary(
  self : CustomValue,
  op : String,
  rhs : Value,
  is_left : Bool,
) -> Result[Value, String]? {
  match self.binary_fn {
    Some(f) => f(op, rhs, is_left)
    None => None
  }
}

///|
pub fn CustomValue::get_unary(
  self : CustomValue,
  op : String,
) -> Result[Value, String]? {
  match self.unary_fn {
    Some(f) => f(op)
    None => None
  }
}

///|
pub fn CustomValue::get_compare(self : CustomValue, other : Value) -> Int? {
  match self.compare_fn {
    Some(f) => f(other)
    None => None
  }
}

///|
pub fn CustomValue::with_get_index(
  self : CustomValue,
  get_index_fn : (Int) -> Result[Value, String],
) -> CustomValue {
  { ..self, get_index_fn: Some(get_index_fn) }
}

///|
pub fn CustomValue::get_index(
  self : CustomValue,
  i : Int,
) -> Result[Value, String] {
  match self.get_index_fn {
    Some(f) => f(i)
    None => Err("'\{(self.type_name_fn)()}' object does not support indexing")
  }
}

///|
pub fn CustomValue::with_set_index(
  self : CustomValue,
  set_index_fn : (Int, Value) -> Result[Unit, String],
) -> CustomValue {
  { ..self, set_index_fn: Some(set_index_fn) }
}

///|
pub fn CustomValue::do_set_index(
  self : CustomValue,
  i : Int,
  v : Value,
) -> Result[Unit, String]? {
  match self.set_index_fn {
    Some(f) => Some(f(i, v))
    None => None
  }
}

///|
// HasSetKey hook: `x[k] = v` for custom mapping values, where `k` is an
// arbitrary Starlark value (not restricted to an integer index).
pub fn CustomValue::with_set_key(
  self : CustomValue,
  set_key_fn : (Value, Value) -> Result[Unit, String],
) -> CustomValue {
  { ..self, set_key_fn: Some(set_key_fn) }
}

///|
pub fn CustomValue::do_set_key(
  self : CustomValue,
  k : Value,
  v : Value,
) -> Result[Unit, String]? {
  match self.set_key_fn {
    Some(f) => Some(f(k, v))
    None => None
  }
}

///|
pub fn CustomValue::with_slice(
  self : CustomValue,
  slice_fn : (Int, Int, Int) -> Result[Value, String],
) -> CustomValue {
  { ..self, slice_fn: Some(slice_fn) }
}

///|
pub fn CustomValue::do_slice(
  self : CustomValue,
  start : Int,
  stop : Int,
  step : Int,
) -> Result[Value, String]? {
  match self.slice_fn {
    Some(f) => Some(f(start, stop, step))
    None => None
  }
}

///|
pub fn CustomValue::with_items(
  self : CustomValue,
  items_fn : () -> Result[Array[(Value, Value)], String],
) -> CustomValue {
  { ..self, items_fn: Some(items_fn) }
}

///|
pub fn CustomValue::get_items(
  self : CustomValue,
) -> Result[Array[(Value, Value)], String]? {
  match self.items_fn {
    Some(f) => Some(f())
    None => None
  }
}

///|
pub fn CustomValue::with_call(
  self : CustomValue,
  call_fn : (Array[Value], Array[(String, Value)]) -> Result[Value, String],
) -> CustomValue {
  { ..self, call_fn: Some(call_fn) }
}

///|
pub fn CustomValue::do_call(
  self : CustomValue,
  pos_args : Array[Value],
  kw_args : Array[(String, Value)],
) -> Result[Value, String]? {
  match self.call_fn {
    Some(f) => Some(f(pos_args, kw_args))
    None => None
  }
}
