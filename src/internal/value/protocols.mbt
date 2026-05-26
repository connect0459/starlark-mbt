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
