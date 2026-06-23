// Extension protocols for custom Starlark value types.
// Built-in types (List, Dict, Set, String, etc.) implement these capabilities
// internally via the Value enum match expressions in traits.mbt and iter.mbt.
// These traits allow embedders to create custom extension types that participate
// in attribute access, comparison, and the iterator protocol.
//
// Usage: implement these traits on a custom struct, then wrap it in a future
// ExtVal(obj) variant of the Value enum to integrate with the evaluator.

///|
/// Attribute-access protocol for custom Starlark value types.
/// Implement this trait to support `getattr`, `hasattr`, and `dir` on a
/// custom type registered as a `Value::ExtVal`.
pub trait HasAttrs {
  fn get_attr(Self, String) -> Result[Value?, String]
  fn attr_names(Self) -> Array[String]
}

///|
/// Field-assignment protocol for custom Starlark value types.
/// Implement this trait to support `x.name = v` field assignment on a
/// custom type registered as a `Value::ExtVal`.
pub trait HasSetField {
  fn set_field(Self, String, Value) -> Result[Unit, String]
}

///|
/// Total-order comparison protocol for custom Starlark value types.
/// Implement this trait to define `<`, `<=`, `>`, `>=` on a custom type
/// registered as a `Value::ExtVal`. By convention, `compare_same_type` is
/// intended to be called only when both operands have the same Starlark type
/// name, though this is not yet enforced by the evaluator. Return a negative
/// int, zero, or positive int to indicate ordering.
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
/// Custom argument-unpacking protocol. A type implementing `Unpacker` defines
/// how a single Starlark `Value` is validated and absorbed into the target,
/// mirroring starlark-go's `Unpacker` interface. Pass implementors to
/// `unpack_args_with` (in the `unpack` package) to give built-in functions
/// custom per-argument coercion beyond the plain value extraction performed
/// by `unpack_args`.
pub(open) trait Unpacker {
  fn unpack(Self, Value) -> Result[Unit, String]
}

///|
/// Vtable-based wrapper for embedding custom Starlark value types.
/// Construct with `CustomValue::new`, then call `with_*` builder methods to add
/// optional protocol support. Wrap in `Value::ExtVal(cv)` to produce a Value.
pub struct CustomValue {
  priv type_name_fn : () -> String
  priv truth_fn : () -> Bool
  priv repr_fn : () -> String
  priv repr_depth_fn : ((Int) -> Result[String, String])?
  priv hash_fn : (() -> Result[UInt, String])?
  priv hash_depth_fn : ((Int) -> Result[UInt, String])?
  priv equals_fn : ((Value, Int) -> Result[Bool, String])?
  priv get_attr_fn : ((String) -> Result[Value?, String])?
  priv internal_get_attr_fn : ((String) -> Result[Value?, String])?
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
/// Creates a `CustomValue` with type-name, truthiness, and repr callbacks.
/// All optional protocols (hash, equals, attrs, iterate, …) default to absent
/// and can be added via `with_*` builder methods.
///
/// Parameters:
///
/// - `type_name_fn` : Callback that returns the Starlark type name string.
/// - `truth_fn` : Callback that returns the boolean truthiness of the value.
/// - `repr_fn` : Callback that returns the `repr()` string of the value.
///
/// Returns a new `CustomValue` with all optional protocol slots set to absent.
pub fn CustomValue::new(
  type_name_fn : () -> String,
  truth_fn : () -> Bool,
  repr_fn : () -> String,
) -> CustomValue {
  {
    type_name_fn,
    truth_fn,
    repr_fn,
    repr_depth_fn: None,
    hash_fn: None,
    hash_depth_fn: None,
    equals_fn: None,
    get_attr_fn: None,
    internal_get_attr_fn: None,
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
/// Attaches a custom hash function. Invoked by `starlark_hash` for
/// `Value::ExtVal`. Without this, the value is considered unhashable.
///
/// Parameters:
///
/// - `self` : The `CustomValue` to extend.
/// - `hash_fn` : Callback that computes and returns a hash code, or `Err`
///   if the value is unhashable at runtime.
///
/// Returns a new `CustomValue` with the hash callback registered.
pub fn CustomValue::with_hash(
  self : CustomValue,
  hash_fn : () -> Result[UInt, String],
) -> CustomValue {
  { ..self, hash_fn: Some(hash_fn) }
}

///|
/// Attaches a custom equality function. Invoked by `starlark_equals` and
/// `starlark_equals_depth` for `Value::ExtVal`. Without this, two `ExtVal`s
/// compare unequal by default.
///
/// Parameters:
///
/// - `self` : The `CustomValue` to extend.
/// - `equals_fn` : Callback that tests equality against another `Value` and
///   the remaining recursion budget. Returns `Ok(true)` if equal, `Ok(false)`
///   if not, or `Err(msg)` if the comparison fails (e.g., recursion depth
///   exceeded). Errors are propagated by `starlark_equals_depth` and squashed
///   to `false` by `starlark_equals`. Pass the received depth to any nested
///   `starlark_equals_depth` calls to compose the depth guard correctly.
///
/// Returns a new `CustomValue` with the equality callback registered.
pub fn CustomValue::with_equals(
  self : CustomValue,
  equals_fn : (Value, Int) -> Result[Bool, String],
) -> CustomValue {
  { ..self, equals_fn: Some(equals_fn) }
}

///|
/// Attaches attribute-access and attribute-listing callbacks, enabling
/// `getattr`, `hasattr`, and `dir` on this value.
///
/// Parameters:
///
/// - `self` : The `CustomValue` to extend.
/// - `get_attr_fn` : Callback that looks up an attribute by name.
/// - `attr_names_fn` : Callback that returns all attribute names.
///
/// Returns a new `CustomValue` with both attribute callbacks registered.
pub fn CustomValue::with_attrs(
  self : CustomValue,
  get_attr_fn : (String) -> Result[Value?, String],
  attr_names_fn : () -> Array[String],
) -> CustomValue {
  { ..self, get_attr_fn: Some(get_attr_fn), attr_names_fn: Some(attr_names_fn) }
}

///|
/// Attaches an internal-only attribute accessor that bypasses user-facing
/// access restrictions. Use this for cross-value protocols (e.g., struct
/// equality or merge) that need to read implementation-private fields
/// without exposing them to Starlark programs.
///
/// Parameters:
///
/// - `self` : The `CustomValue` to extend.
/// - `internal_get_attr_fn` : Callback that looks up an attribute by name,
///   including implementation-private names hidden from user code.
///
/// Returns a new `CustomValue` with the internal attribute callback
/// registered.
pub fn CustomValue::with_internal_get_attr(
  self : CustomValue,
  internal_get_attr_fn : (String) -> Result[Value?, String],
) -> CustomValue {
  { ..self, internal_get_attr_fn: Some(internal_get_attr_fn) }
}

///|
/// Attaches a field-assignment callback, enabling `x.name = v` on this value.
///
/// Parameters:
///
/// - `self` : The `CustomValue` to extend.
/// - `set_field_fn` : Callback that assigns a value to a named field.
///
/// Returns a new `CustomValue` with the field-assignment callback registered.
pub fn CustomValue::with_set_field(
  self : CustomValue,
  set_field_fn : (String, Value) -> Result[Unit, String],
) -> CustomValue {
  { ..self, set_field_fn: Some(set_field_fn) }
}

///|
/// Attaches a membership-test callback, enabling `v in x` on this value.
///
/// Parameters:
///
/// - `self` : The `CustomValue` to extend.
/// - `contains_fn` : Callback that tests whether a value is a member.
///
/// Returns a new `CustomValue` with the membership-test callback registered.
pub fn CustomValue::with_contains(
  self : CustomValue,
  contains_fn : (Value) -> Result[Bool, String],
) -> CustomValue {
  { ..self, contains_fn: Some(contains_fn) }
}

///|
/// Attaches an iteration callback, enabling `for v in x` and related
/// built-ins (`list`, `tuple`, `set`, `sorted`, …) on this value.
///
/// Parameters:
///
/// - `self` : The `CustomValue` to extend.
/// - `iterate_fn` : Callback that creates and returns a `StarlarkIterator`.
///
/// Returns a new `CustomValue` with the iteration callback registered.
pub fn CustomValue::with_iterate(
  self : CustomValue,
  iterate_fn : () -> Result[StarlarkIterator, String],
) -> CustomValue {
  { ..self, iterate_fn: Some(iterate_fn) }
}

///|
/// Attaches a length callback, enabling `len(x)` on this value.
///
/// Parameters:
///
/// - `self` : The `CustomValue` to extend.
/// - `length_fn` : Callback that returns the number of elements.
///
/// Returns a new `CustomValue` with the length callback registered.
pub fn CustomValue::with_length(
  self : CustomValue,
  length_fn : () -> Int,
) -> CustomValue {
  { ..self, length_fn: Some(length_fn) }
}

///|
/// Attaches a freeze callback invoked when this value is frozen transitively
/// (e.g. when a containing module or dict is frozen).
///
/// Parameters:
///
/// - `self` : The `CustomValue` to extend.
/// - `freeze_fn` : Callback invoked when the value is transitively frozen.
///
/// Returns a new `CustomValue` with the freeze callback registered.
pub fn CustomValue::with_freeze(
  self : CustomValue,
  freeze_fn : () -> Unit,
) -> CustomValue {
  { ..self, freeze_fn: Some(freeze_fn) }
}

///|
/// Attaches a binary operator callback for `x op y`. The callback receives
/// the operator string, the right-hand operand, and `is_left` (whether `x` is
/// on the left). Return `None` to fall back to the default type-error.
///
/// Parameters:
///
/// - `self` : The `CustomValue` to extend.
/// - `binary_fn` : Callback invoked with the operator string, the other
///   operand, and a flag indicating whether this value is the left operand.
///
/// Returns a new `CustomValue` with the binary operator callback registered.
pub fn CustomValue::with_binary(
  self : CustomValue,
  binary_fn : (String, Value, Bool) -> Result[Value, String]?,
) -> CustomValue {
  { ..self, binary_fn: Some(binary_fn) }
}

///|
/// Attaches a unary operator callback for `op x`. The callback receives the
/// operator string (`"-"`, `"+"`, `"~"`, `"not"`). Return `None` to fall back
/// to the default type-error.
///
/// Parameters:
///
/// - `self` : The `CustomValue` to extend.
/// - `unary_fn` : Callback invoked with the operator string.
///
/// Returns a new `CustomValue` with the unary operator callback registered.
pub fn CustomValue::with_unary(
  self : CustomValue,
  unary_fn : (String) -> Result[Value, String]?,
) -> CustomValue {
  { ..self, unary_fn: Some(unary_fn) }
}

///|
/// Attaches a total-order comparison callback for `<`, `<=`, `>`, `>=`.
/// The callback returns a negative int, 0, or positive int (like `compare`).
/// Return `None` to fall back to the default type-error.
///
/// Parameters:
///
/// - `self` : The `CustomValue` to extend.
/// - `compare_fn` : Callback that compares this value against another,
///   returning a negative int, zero, or positive int, or `None` if not
///   comparable.
///
/// Returns a new `CustomValue` with the comparison callback registered.
pub fn CustomValue::with_compare(
  self : CustomValue,
  compare_fn : (Value) -> Int?,
) -> CustomValue {
  { ..self, compare_fn: Some(compare_fn) }
}

///|
/// Invokes the type-name callback, returning the Starlark type name string.
///
/// Returns the Starlark type name of this value, as provided by
/// `type_name_fn`.
pub fn CustomValue::get_type_name(self : CustomValue) -> String {
  (self.type_name_fn)()
}

///|
/// Invokes the truth callback, returning the Starlark truthiness of this value.
///
/// Returns the boolean truthiness of this value, as provided by `truth_fn`.
pub fn CustomValue::get_truth(self : CustomValue) -> Bool {
  (self.truth_fn)()
}

///|
/// Invokes the repr callback, returning the `repr()` string of this value.
///
/// Returns the string representation of this value, as provided by
/// `repr_fn`.
pub fn CustomValue::get_repr(self : CustomValue) -> String {
  (self.repr_fn)()
}

///|
/// Invokes the depth-aware repr callback with `depth`, propagating the
/// remaining recursion budget. Falls back to `repr_fn()` when no
/// depth-aware callback was registered, but still returns `Err` when
/// `depth` is exhausted to prevent the fallback from calling
/// `Value::repr()` (which restarts at `repr_limit`) inside a deeply
/// nested traversal.
///
/// Parameters:
///
/// - `depth` : Remaining recursion depth passed down from the caller.
pub fn CustomValue::get_repr_depth(
  self : CustomValue,
  depth : Int,
) -> Result[String, String] {
  match self.repr_depth_fn {
    Some(f) => f(depth)
    None =>
      if depth < 1 {
        Err("repr exceeded maximum recursion depth")
      } else {
        Ok((self.repr_fn)())
      }
  }
}

///|
/// Attaches a depth-aware repr callback. When registered, `repr_inner`
/// calls this instead of `repr_fn`, passing the remaining depth budget so
/// field values can be repr'd without restarting the counter.
///
/// Parameters:
///
/// - `self` : The `CustomValue` to extend.
/// - `repr_depth_fn` : Callback `(depth: Int) -> Result[String, String]`
///   that renders the value with `depth` remaining levels.
///
/// Returns a new `CustomValue` with the depth-aware repr registered.
pub fn CustomValue::with_repr_depth(
  self : CustomValue,
  repr_depth_fn : (Int) -> Result[String, String],
) -> CustomValue {
  { ..self, repr_depth_fn: Some(repr_depth_fn) }
}

///|
/// Invokes the depth-aware hash callback if registered, or falls back to the
/// plain hash callback. Returns `Err` when the recursion budget (`depth`) is
/// exhausted and no depth-aware callback is registered, to prevent the fallback
/// from calling `Value::hash` (which restarts at `hash_limit`) inside a deeply
/// nested traversal.
///
/// Parameters:
///
/// - `depth` : Remaining recursion depth passed down from the caller.
pub fn CustomValue::get_hash_depth(
  self : CustomValue,
  depth : Int,
) -> Result[UInt, String] {
  match self.hash_depth_fn {
    Some(f) => f(depth)
    None =>
      match self.hash_fn {
        Some(f) =>
          if depth < 1 {
            Err("hash exceeded maximum recursion depth")
          } else {
            f()
          }
        None => Err("unhashable type: \{(self.type_name_fn)()}")
      }
  }
}

///|
/// Invokes the hash callback, or returns `Err("unhashable type: T")` if no
/// hash callback was registered.
///
/// Returns `Ok(hash)` if a hash callback was registered, or
/// `Err("unhashable type: T")` otherwise.
pub fn CustomValue::get_hash(self : CustomValue) -> Result[UInt, String] {
  self.get_hash_depth(hash_limit)
}

///|
/// Attaches a depth-aware hash callback. When registered, `Value::hash_depth`
/// calls this instead of `hash_fn`, passing the remaining depth budget so field
/// values can be hashed without restarting the counter. Use `hash_value_depth`
/// (from the `value` package's public API) to hash nested `Value`s while
/// propagating depth correctly.
///
/// Parameters:
///
/// - `self` : The `CustomValue` to extend.
/// - `hash_depth_fn` : Callback `(depth: Int) -> Result[UInt, String]` that
///   hashes the value with `depth` remaining levels.
///
/// Returns a new `CustomValue` with the depth-aware hash registered.
pub fn CustomValue::with_hash_depth(
  self : CustomValue,
  hash_depth_fn : (Int) -> Result[UInt, String],
) -> CustomValue {
  { ..self, hash_depth_fn: Some(hash_depth_fn) }
}

///|
/// Invokes the equality callback against `other` with the given recursion
/// budget, or returns `Ok(false)` if no callback was registered.
///
/// Parameters:
///
/// - `self` : The custom value to test equality for.
/// - `other` : The value to compare against.
/// - `depth` : Remaining recursion budget, threaded from the caller's
///   `starlark_equals_depth` invocation. Pass this value unchanged to any
///   nested `starlark_equals_depth` calls inside the callback.
///
/// Returns `Ok(true)` if equal, `Ok(false)` if not equal or no callback is
/// registered, or `Err(msg)` if the callback reports a comparison error.
pub fn CustomValue::get_equals(
  self : CustomValue,
  other : Value,
  depth : Int,
) -> Result[Bool, String] {
  match self.equals_fn {
    Some(f) => f(other, depth)
    None => Ok(false)
  }
}

///|
/// Invokes the attribute callback for `name`, or returns `Ok(None)` if no
/// callback was registered.
///
/// Parameters:
///
/// - `self` : The custom value to look up an attribute on.
/// - `name` : The attribute name to look up.
///
/// Returns `Ok(Some(v))` if the attribute exists, `Ok(None)` if not found or
/// no callback was registered, or `Err` if the callback signals an error.
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
/// Invokes the internal attribute accessor registered by
/// `with_internal_get_attr`, or falls back to `get_attr` if none was
/// registered. Intended for cross-value protocols that need to read
/// implementation-private fields hidden from user-facing `get_attr`.
///
/// Parameters:
///
/// - `self` : The custom value to look up an internal attribute on.
/// - `name` : The attribute name to look up.
///
/// Returns `Ok(Some(v))` if found, `Ok(None)` if absent, or `Err` on error.
pub fn CustomValue::get_internal_attr(
  self : CustomValue,
  name : String,
) -> Result[Value?, String] {
  match self.internal_get_attr_fn {
    Some(f) => f(name)
    None => self.get_attr(name)
  }
}

///|
/// Invokes the attribute-listing callback, or returns `None` if no callback
/// was registered. The result is used by `dir()`.
///
/// Returns `Some(names)` if an attribute-listing callback was registered, or
/// `None` otherwise.
pub fn CustomValue::get_attr_names(self : CustomValue) -> Array[String]? {
  match self.attr_names_fn {
    Some(f) => Some(f())
    None => None
  }
}

///|
/// Invokes the field-assignment callback for `name = v`, or returns `None`
/// if no callback was registered.
///
/// Parameters:
///
/// - `self` : The custom value to assign a field on.
/// - `name` : The name of the field to assign.
/// - `v` : The value to assign.
///
/// Returns `Some(Ok(()))` on success, `Some(Err(...))` if the callback
/// signals an error, or `None` if no field-assignment callback was registered.
pub fn CustomValue::get_set_field(
  self : CustomValue,
  name : String,
  v : Value,
) -> Result[Unit, String]? {
  match self.set_field_fn {
    Some(f) => Some(f(name, v))
    None => None
  }
}

///|
/// Invokes the membership-test callback for `v`, or returns `None` if no
/// callback was registered.
///
/// Parameters:
///
/// - `self` : The custom value to test membership on.
/// - `v` : The value to test for membership.
///
/// Returns `Some(Ok(true))` if `v` is a member, `Some(Ok(false))` if not,
/// `Some(Err(...))` if the callback signals an error, or `None` if no
/// callback was registered.
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
/// Invokes the iteration callback, or returns
/// `Err("'T' object is not iterable")` if no callback was registered.
///
/// Returns `Ok(iterator)` if an iteration callback was registered, or
/// `Err("'T' object is not iterable")` otherwise.
pub fn CustomValue::get_iterate(
  self : CustomValue,
) -> Result[StarlarkIterator, String] {
  match self.iterate_fn {
    Some(f) => f()
    None => Err("'\{(self.type_name_fn)()}' object is not iterable")
  }
}

///|
/// Invokes the length callback, or returns
/// `Err("len: value of type T has no len")` if no callback was registered.
///
/// Returns `Ok(n)` if a length callback was registered, or
/// `Err("len: value of type T has no len")` otherwise.
pub fn CustomValue::get_length(self : CustomValue) -> Result[Int, String] {
  match self.length_fn {
    Some(f) => Ok(f())
    None => Err("len: value of type \{(self.type_name_fn)()} has no len")
  }
}

///|
/// Invokes the freeze callback if one was registered, otherwise is a no-op.
pub fn CustomValue::do_freeze(self : CustomValue) -> Unit {
  match self.freeze_fn {
    Some(f) => f()
    None => ()
  }
}

///|
/// Invokes the binary operator callback, or returns `None` if no callback
/// was registered.
///
/// Parameters:
///
/// - `self` : The custom value on which the operator is applied.
/// - `op` : The operator string (e.g. `"+"`, `"-"`, `"*"`, `"in"`).
/// - `rhs` : The right-hand operand.
/// - `is_left` : `true` if this value is the left operand; `false` if right.
///
/// Returns `Some(Ok(v))` if the callback produces a result,
/// `Some(Err(msg))` if it signals an error, or `None` if no callback was
/// registered or the callback declines.
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
/// Invokes the unary operator callback, or returns `None` if no callback
/// was registered.
///
/// Parameters:
///
/// - `self` : The custom value on which the operator is applied.
/// - `op` : The operator string (e.g. `"-"`, `"+"`, `"~"`, `"not"`).
///
/// Returns `Some(Ok(v))` if the callback produces a result,
/// `Some(Err(msg))` if it signals an error, or `None` if no callback was
/// registered or the callback declines.
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
/// Invokes the comparison callback against `other`, or returns `None` if no
/// callback was registered.
///
/// Parameters:
///
/// - `self` : The custom value to compare.
/// - `other` : The value to compare against.
///
/// Returns `Some(n)` where `n` is negative, zero, or positive to indicate
/// ordering, or `None` if no callback was registered or the values are not
/// comparable.
pub fn CustomValue::get_compare(self : CustomValue, other : Value) -> Int? {
  match self.compare_fn {
    Some(f) => f(other)
    None => None
  }
}

///|
/// Attaches an integer-index read callback, enabling `x[i]` where `i` is an
/// integer. For arbitrary-key indexing, use `with_set_key`.
///
/// Parameters:
///
/// - `self` : The `CustomValue` to extend.
/// - `get_index_fn` : Callback that returns the element at a given integer
///   index.
///
/// Returns a new `CustomValue` with the integer-index read callback
/// registered.
pub fn CustomValue::with_get_index(
  self : CustomValue,
  get_index_fn : (Int) -> Result[Value, String],
) -> CustomValue {
  { ..self, get_index_fn: Some(get_index_fn) }
}

///|
/// Invokes the integer-index read callback for `i`, or returns `Err` if no
/// callback was registered.
///
/// Parameters:
///
/// - `self` : The custom value to index into.
/// - `i` : The integer index to read.
///
/// Returns `Ok(v)` if the callback returns a value, or `Err` if no callback
/// was registered or the callback signals an error.
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
/// Attaches an integer-index write callback, enabling `x[i] = v` where `i`
/// is an integer.
///
/// Parameters:
///
/// - `self` : The `CustomValue` to extend.
/// - `set_index_fn` : Callback that assigns a value at a given integer index.
///
/// Returns a new `CustomValue` with the integer-index write callback
/// registered.
pub fn CustomValue::with_set_index(
  self : CustomValue,
  set_index_fn : (Int, Value) -> Result[Unit, String],
) -> CustomValue {
  { ..self, set_index_fn: Some(set_index_fn) }
}

///|
/// Invokes the integer-index write callback for `x[i] = v`, or returns
/// `None` if no callback was registered.
///
/// Parameters:
///
/// - `self` : The custom value to write an index on.
/// - `i` : The integer index to assign.
/// - `v` : The value to assign at that index.
///
/// Returns `Some(Ok(()))` on success, `Some(Err(msg))` if the callback
/// signals an error, or `None` if no callback was registered.
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
/// Attaches a mapping-key write callback for `x[k] = v`, where `k` is any
/// hashable Starlark value (not restricted to an integer index).
///
/// Parameters:
///
/// - `self` : The `CustomValue` to extend.
/// - `set_key_fn` : Callback that assigns a value at an arbitrary hashable
///   key.
///
/// Returns a new `CustomValue` with the mapping-key write callback
/// registered.
pub fn CustomValue::with_set_key(
  self : CustomValue,
  set_key_fn : (Value, Value) -> Result[Unit, String],
) -> CustomValue {
  { ..self, set_key_fn: Some(set_key_fn) }
}

///|
/// Invokes the mapping-key write callback for `x[k] = v`, or returns `None`
/// if no callback was registered.
///
/// Parameters:
///
/// - `self` : The custom value to write a key on.
/// - `k` : The key to assign.
/// - `v` : The value to assign at that key.
///
/// Returns `Some(Ok(()))` on success, `Some(Err(msg))` if the callback
/// signals an error, or `None` if no callback was registered.
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
/// Attaches a slice callback, enabling `x[start:stop:step]` on this value.
///
/// Parameters:
///
/// - `self` : The `CustomValue` to extend.
/// - `slice_fn` : Callback that computes a slice given start, stop, and step
///   indices.
///
/// Returns a new `CustomValue` with the slice callback registered.
pub fn CustomValue::with_slice(
  self : CustomValue,
  slice_fn : (Int, Int, Int) -> Result[Value, String],
) -> CustomValue {
  { ..self, slice_fn: Some(slice_fn) }
}

///|
/// Invokes the slice callback for `x[start:stop:step]`, or returns `None`
/// if no callback was registered.
///
/// Parameters:
///
/// - `self` : The custom value to slice.
/// - `start` : The normalised start index of the slice.
/// - `stop` : The normalised stop index of the slice.
/// - `step` : The normalised step of the slice (non-zero).
///
/// Returns `Some(Ok(v))` with the sliced value, `Some(Err(msg))` if the
/// callback signals an error, or `None` if no callback was registered.
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
/// Attaches an items callback that yields `(key, value)` pairs, enabling
/// dict-like iteration over this mapping value.
///
/// Parameters:
///
/// - `self` : The `CustomValue` to extend.
/// - `items_fn` : Callback that returns all key-value pairs as an array.
///
/// Returns a new `CustomValue` with the items callback registered.
pub fn CustomValue::with_items(
  self : CustomValue,
  items_fn : () -> Result[Array[(Value, Value)], String],
) -> CustomValue {
  { ..self, items_fn: Some(items_fn) }
}

///|
/// Invokes the items callback, returning `(key, value)` pairs, or `None`
/// if no callback was registered.
///
/// Returns `Some(Ok(pairs))` with all key-value pairs, `Some(Err(msg))` if
/// the callback signals an error, or `None` if no callback was registered.
pub fn CustomValue::get_items(
  self : CustomValue,
) -> Result[Array[(Value, Value)], String]? {
  match self.items_fn {
    Some(f) => Some(f())
    None => None
  }
}

///|
/// Attaches a call callback, making this value callable from Starlark.
///
/// Parameters:
///
/// - `self` : The `CustomValue` to extend.
/// - `call_fn` : Callback invoked with positional arguments and keyword
///   arguments when the value is called.
///
/// Returns a new `CustomValue` with the call callback registered.
pub fn CustomValue::with_call(
  self : CustomValue,
  call_fn : (Array[Value], Array[(String, Value)]) -> Result[Value, String],
) -> CustomValue {
  { ..self, call_fn: Some(call_fn) }
}

///|
/// Invokes the call callback with `pos_args` and `kw_args`, or returns `None`
/// if no callback was registered (value is not callable).
///
/// Parameters:
///
/// - `self` : The custom value to call.
/// - `pos_args` : Positional arguments passed to the call.
/// - `kw_args` : Keyword arguments passed to the call, as name-value pairs.
///
/// Returns `Some(Ok(v))` with the call result, `Some(Err(msg))` if the
/// callback signals an error, or `None` if no call callback was registered.
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
