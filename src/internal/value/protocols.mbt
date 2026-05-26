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
