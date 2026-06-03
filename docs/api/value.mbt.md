# `value` package

Import `connect0459/starlark/value` for the `Value` type, every concrete value type, the
host-side `StringDict`, the embedder-extension `CustomValue`, value-inspection helpers, and the
embedder protocol traits.

## `@value.Value`

All Starlark values share this enum type.

```moonbit nocheck
///|
pub enum Value {
  None
  Bool(Bool)
  Int(BigInt) // arbitrary-precision integer
  Float(Double)
  String(StarlarkString)
  Bytes(Bytes)
  List(StarlarkList)
  Tuple(Array[Value])
  Dict(StarlarkDict)
  Set(StarlarkSet)
  Range(StarlarkRange)
  Function(StarlarkFunction)
  Builtin(StarlarkBuiltinFunc)
  BoundMethod(StarlarkBoundMethod)
  Module(StarlarkModule)
  StringElems(StarlarkStringElems) // returned by str.elems()
  StringCodepoints(StarlarkStringCodepoints) // returned by str.codepoints()
  BytesElems(StarlarkBytesElems) // returned by bytes.elems()
  ExtVal(CustomValue) // embedder-defined custom type
}
```

The three iterator variants (`StringElems`, `StringCodepoints`, `BytesElems`) are lazy iterables
returned by the respective string/bytes methods. They report their own `type()` strings
(`"string.elems"`, `"string.codepoints"`, `"bytes.elems"`) and support `len()`.

> **Note:** `Int` holds a `BigInt` (arbitrary precision). Use the `N` suffix for integer
> literals in patterns: `@value.Value::Int(42N)`.

Pattern matching is the primary way to inspect a `Value`:

```mbt check
///|
test {
  let thread = @eval.Thread::new("main")
  match
    @eval.exec_file(thread, "s.star", "x = 'hello'", @eval.Options::default()) {
    Ok(m) =>
      match m.get("x") {
        Some(@value.Value::String(s)) => assert_eq(s.raw(), "hello")
        _ => fail("expected string")
      }
    Err(e) => fail(e.to_string())
  }
}
```

### Constructors and value-level methods

| Method | Signature | Description |
| :--- | :--- | :--- |
| `Value::new_int(Int64)` | `-> Value` | Construct an `Int` value |
| `Value::new_float(Double)` | `-> Value` | Construct a `Float` value |
| `Value::new_string(String)` | `-> Value` | Construct a `String` value |
| `Value::new_list(Array[Value])` | `-> Value` | Construct a `List` value |
| `Value::new_dict()` | `-> Value` | Construct an empty `Dict` value |
| `Value::new_set()` | `-> Value` | Construct an empty `Set` value |
| `Value::new_builtin(String, (BuiltinCallCtx, Array[Value], Array[(String, Value)]) -> Result[Value, String])` | `-> Value` | Construct a host-provided callable built-in |
| `repr()` | `-> String` | `repr()` form (the Starlark literal) |
| `to_str()` | `-> String` | `str()` form (unquoted for strings) |
| `type_name()` | `-> String` | `type()` name |
| `truth()` | `-> Bool` | Truthiness for `if`/`while`/`and`/`or` |
| `starlark_equals(Value)` | `-> Bool` | Structural equality |
| `hash()` | `-> Result[UInt, String]` | Hash; `Err` for unhashable values |
| `freeze()` | `-> Unit` | Freeze this value (and, transitively, its contents) |

`Value` also implements `Eq`.

## Value-inspection helpers

Mirrors of starlark-go's package-level helpers. These return `String` errors (value-level
operations carry no source position).

| Function | Signature | Description |
| :--- | :--- | :--- |
| `equal` | `(Value, Value) -> Result[Bool, String]` | Structural equality (depth-capped by `compare_limit`) |
| `len_of` | `(Value) -> Int` | Sequence length; returns `-1` for non-sequences |
| `length_of` | `(Value) -> Result[Int, String]` | Sequence length; `Err` for non-sequences |
| `iterate` | `(Value) -> Result[StarlarkIterator, String]` | Obtain an iterator over a Starlark iterable |
| `number_to_int` | `(Value) -> Int64?` | Convert `Int` or `Float` to `Int64`; `None` otherwise |
| `as_float` | `(Value) -> (Double, Bool)` | Extract `Float` or convert `Int` to `Double`; second element is `true` on success |
| `as_string` | `(Value) -> (String, Bool)` | Extract raw string from `String` value; second element is `true` on success |

## Depth-limited comparison

These guard against infinite recursion on cyclic data structures.

| Symbol | Signature | Description |
| :--- | :--- | :--- |
| `compare_limit` | `Int` | Default recursion depth for comparisons (value: `10`) |
| `equal_depth` | `(Value, Value, Int) -> Result[Bool, String]` | Equality with explicit depth limit |
| `starlark_equals_depth` | `(Value, Value, Int) -> Result[Bool, String]` | Equality used by the evaluator, with explicit depth limit |
| `compare_depth` | `(String, Value, Value, Int) -> Result[Bool, String]` | Comparison operator (`"=="`, `"<"`, …) with explicit depth limit |
| `compare_values` | `(Value, Value, op? : String) -> Result[Int, String]` | Three-way comparison (`-1`/`0`/`1`); same-type only |
| `compare_values_depth` | `(Value, Value, Int, op? : String) -> Result[Int, String]` | Three-way comparison with explicit depth limit |

## `@value.StarlarkString`

The UTF-8-backed immutable string type behind Starlark `string` values.

```moonbit nocheck
pub struct StarlarkString { /* private fields */ }  // in "connect0459/starlark/value"
```

| Method | Signature | Description |
| :--- | :--- | :--- |
| `StarlarkString::new(String)` | `-> StarlarkString` | Construct from a MoonBit string |
| `StarlarkString::from_bytes(Bytes)` | `-> StarlarkString` | Construct from raw UTF-8 bytes |
| `raw()` | `-> String` | The underlying MoonBit string |
| `to_bytes()` | `-> Bytes` | UTF-8 byte representation |
| `byte_len()` | `-> Int` | Length in bytes |
| `byte_at(Int)` | `-> Byte` | The i-th byte |
| `equals(StarlarkString)` | `-> Bool` | Byte-wise equality |

---

## `@value.StarlarkList`

The mutable, freezable sequence backing Starlark `list` values.

```moonbit nocheck
pub struct StarlarkList { /* private fields */ }  // in "connect0459/starlark/value"
```

| Method | Signature | Description |
| :--- | :--- | :--- |
| `StarlarkList::new(Array[Value])` | `-> StarlarkList` | Construct from an array of values |
| `length()` | `-> Int` | Number of elements |
| `is_empty()` | `-> Bool` | Whether the list has no elements |
| `get(Int)` | `-> Value?` | Element at index; `None` if out of range |
| `op_get(Int)` | `-> Value` | Element at index (panics if out of range; for `list[i]`) |
| `set(Int, Value)` | `-> Result[Unit, String]` | Replace the element at index |
| `push(Value)` | `-> Result[Unit, String]` | Append an element (`Err` if frozen) |
| `insert(Int, Value)` | `-> Result[Unit, String]` | Insert at index |
| `pop()` | `-> Result[Value?, String]` | Remove and return the last element |
| `pop_at(Int, String)` | `-> Result[Value, String]` | Remove and return the element at index |
| `clear()` | `-> Result[Unit, String]` | Remove all elements |
| `reverse()` | `-> Result[Unit, String]` | Reverse in place |
| `sort_by((Value, Value) -> Int)` | `-> Result[Unit, String]` | Sort in place with a comparator |
| `copy_items()` | `-> Array[Value]` | A copy of the backing array |
| `each((Value) -> Unit)` | `-> Unit` | Iterate elements |
| `eachi((Int, Value) -> Unit)` | `-> Unit` | Iterate elements with index |
| `iter()` | `-> Iter[Value]` | Lazy iterator over elements |
| `is_frozen()` | `-> Bool` | Whether the list is frozen |
| `freeze()` | `-> Unit` | Freeze the list (and, transitively, its values) |
| `check_mutable(String)` | `-> Result[Unit, String]` | `Err` if frozen or being iterated; `verb` names the operation |

---

## `@value.StarlarkDict`

The insertion-ordered mutable mapping backing Starlark `dict` values. Keys are any hashable
`Value`. (For host-side string-keyed environments — e.g. the `eval_expr` env — use
`@value.StringDict` instead.)

```moonbit nocheck
pub struct StarlarkDict { /* private fields */ }  // in "connect0459/starlark/value"
```

| Method | Description |
| :--- | :--- |
| `StarlarkDict::new()` | Empty dict |
| `set(Value, Value) -> Result[Unit, String]` | Insert or replace a key–value pair |
| `get(Value) -> Result[Value?, String]` | Look up by key (`Err` if the key is unhashable) |
| `delete(Value) -> Result[Bool, String]` | Remove a key; returns whether it was present |
| `clear() -> Result[Unit, String]` | Remove all entries |
| `length() -> Int` | Number of entries |
| `keys() -> Array[Value]` | Keys in insertion order |
| `each((Value, Value) -> Unit)` | Iterate all key–value pairs |
| `iter() -> Iter[Value]` | Lazy iterator over keys |
| `to_entries() -> Iter[(Value, Value)]` | Lazy iterator over key–value pairs |
| `popitem() -> Result[(Value, Value)?, String]` | Remove and return the last inserted pair |
| `is_frozen() -> Bool` | Whether the dict is frozen |
| `freeze() -> Unit` | Freeze the dict (and, transitively, its values) |

---

## `@value.StarlarkSet`

The insertion-ordered mutable hash set backing Starlark `set` values. Members are any hashable
`Value`.

```moonbit nocheck
pub struct StarlarkSet { /* private fields */ }  // in "connect0459/starlark/value"
```

| Method | Description |
| :--- | :--- |
| `StarlarkSet::new()` | Empty set |
| `add(Value) -> Result[Unit, String]` | Add a member |
| `contains(Value) -> Result[Bool, String]` | Membership test |
| `remove(Value) -> Result[Bool, String]` | Remove a member; returns whether it was present |
| `pop_first() -> Result[Value?, String]` | Remove and return the first inserted member |
| `clear() -> Result[Unit, String]` | Remove all members |
| `length() -> Int` | Number of members |
| `each((Value) -> Unit)` | Iterate members in insertion order |
| `iter() -> Iter[Value]` | Lazy iterator over members |
| `is_frozen() -> Bool` | Whether the set is frozen |
| `freeze() -> Unit` | Freeze the set (and, transitively, its members) |

---

## `@value.StarlarkRange`

The lazy integer sequence returned by `range()`; not a list.

```moonbit nocheck
pub struct StarlarkRange { /* private fields */ }  // in "connect0459/starlark/value"
```

| Method | Signature | Description |
| :--- | :--- | :--- |
| `StarlarkRange::new(Int64, Int64, Int64)` | `-> StarlarkRange` | Construct from `start`, `stop`, `step` |
| `start()` / `stop()` / `step()` | `-> Int64` | The three range parameters |
| `length()` | `-> Int` | Number of elements |
| `index_at(Int)` | `-> Int64` | The value at the i-th position |
| `contains(Int64)` | `-> Bool` | Membership test |

---

## `@value.StringDict`

A `Map[String, Value]` wrapper used for host-side string-keyed dictionaries, and the
environment type accepted by `eval_expr` and the persistent `globals` of
`exec_repl_chunk`. Analogous to `starlark.StringDict` in starlark-go.

```moonbit nocheck
pub struct StringDict { /* private fields */ }  // in "connect0459/starlark/value"
```

| Method | Description |
| :--- | :--- |
| `StringDict::new()` | Empty map |
| `StringDict::from_map(Map[String, Value])` | Wrap an existing map |
| `set(String, Value)` | Add or replace a binding |
| `get(String) -> Value?` | Look up by key |
| `has(String) -> Bool` | Test for key presence |
| `delete(String) -> Bool` | Remove a binding; returns whether it was present |
| `keys() -> Array[String]` | Sorted list of keys |
| `each((String, Value) -> Unit)` | Iterate all key-value pairs |
| `values() -> Array[Value]` | All contained values |
| `freeze()` | Transitively freeze all contained values |

---

## `@value.StarlarkBuiltinFunc`

A host-provided callable injected into the Starlark environment.

```moonbit nocheck
pub struct StarlarkBuiltinFunc { /* private fields */ }  // in "connect0459/starlark/value"
```

| Method | Description |
| :--- | :--- |
| `StarlarkBuiltinFunc::dispatch(String)` | Create a named built-in with no body (stub for forward references) |
| `name() -> String` | Built-in function name |
| `receiver() -> Value?` | Bound receiver value, if any |
| `bind_receiver(Value) -> StarlarkBuiltinFunc` | Return a copy bound to the given receiver |
| `call_body(BuiltinCallCtx, Array[Value], Array[(String, Value)]) -> Result[Value, String]?` | Invoke the built-in's body (if any) |

Use `Value::new_builtin(name, fn)` to build a callable with a body; the callback receives a
`BuiltinCallCtx` (below) that can call back into the evaluator.

---

## `@value.StarlarkBoundMethod`

A method bound to a receiver, e.g. `"abc".upper`.

```moonbit nocheck
pub struct StarlarkBoundMethod { /* private fields */ }  // in "connect0459/starlark/value"
```

| Method | Signature | Description |
| :--- | :--- | :--- |
| `StarlarkBoundMethod::new(Value, String)` | `-> StarlarkBoundMethod` | Bind `method_name` to `recv` |
| `recv()` | `-> Value` | The receiver value |
| `method_name()` | `-> String` | The method name |

---

## `@value.StarlarkFunction`

A user-defined (Starlark-source) function. Obtain via `@value.Value::Function(f)` pattern matching.

```moonbit nocheck
pub struct StarlarkFunction { /* private fields */ }  // in "connect0459/starlark/value"
```

### Identity

| Method | Returns | Description |
| :--- | :--- | :--- |
| `name()` | `String` | Function name; `"<lambda>"` for lambda expressions |
| `position()` | `@errors.Position` | Source position of the `def` keyword |
| `doc()` | `String` | Docstring (first string literal in body); `""` if absent |

### Parameters

| Method | Returns | Description |
| :--- | :--- | :--- |
| `num_params()` | `Int` | Total parameter count |
| `num_kwonly_params()` | `Int` | Number of keyword-only parameters (after `*args`) |
| `has_varargs()` | `Bool` | Whether the function has a `*args` parameter |
| `has_kwargs()` | `Bool` | Whether the function has a `**kwargs` parameter |
| `param(Int)` | `(String, @errors.Position)` | Name and position of the i-th parameter |
| `param_default(Int)` | `Value?` | Default value of the i-th parameter; `None` if required |

### Closure / module

| Method | Returns | Description |
| :--- | :--- | :--- |
| `num_free_vars()` | `Int` | Number of captured (closure) variables |
| `free_var(Int)` | `(String, Value)?` | Name and current value of the i-th free variable |
| `globals()` | `Map[String, Value]` | Module globals visible when the function was defined |
| `defining_module()` | `StarlarkModule?` | Module that defined this function; `None` for functions not created via `exec_file` |

```mbt check
///|
test {
  let thread = @eval.Thread::new("main")
  match
    @eval.exec_file(
      thread,
      "lib.star",
      "CONST = 99\ndef greet(name):\n  \"\"\"Say hello.\"\"\"\n  return 'hi ' + name",
      @eval.Options::default(),
    ) {
    Ok(m) =>
      match m.get("greet") {
        Some(@value.Value::Function(f)) => {
          assert_eq(f.name(), "greet")
          assert_eq(f.num_params(), 1)
          assert_eq(f.doc(), "Say hello.")
          assert_true(f.globals().contains("CONST"))
          match f.defining_module() {
            Some(mod_ref) => assert_eq(mod_ref.name(), "lib.star")
            None => fail("expected module")
          }
        }
        _ => fail("expected function")
      }
    Err(e) => fail(e.to_string())
  }
}
```

---

## `@value.StarlarkModule`

A loaded module value (e.g. obtained through `load`, or via `StarlarkFunction.defining_module`).

```moonbit nocheck
pub struct StarlarkModule { /* private fields */ }  // in "connect0459/starlark/value"
```

| Method | Signature | Description |
| :--- | :--- | :--- |
| `StarlarkModule::new(String, Map[String, Value])` | `-> StarlarkModule` | Construct from a name and attribute map |
| `name()` | `-> String` | Module name |
| `get(String)` | `-> Value?` | Look up an attribute |
| `attr_names()` | `-> Array[String]` | All attribute names |

---

## `@value.StarlarkIterator`

The iterator protocol returned by `@value.iterate`.

```moonbit nocheck
pub struct StarlarkIterator { /* private fields */ }  // in "connect0459/starlark/value"
```

| Method | Signature | Description |
| :--- | :--- | :--- |
| `next()` | `-> Value?` | Next value, or `None` when exhausted |
| `done()` | `-> Unit` | Release the iterator; must be called even on early exit (decrements the container's iteration count) |
| `collect()` | `-> Array[Value]` | Drain the iterator into an array |

---

## String and bytes iterables

The lazy iterables returned by `str.elems()`, `str.codepoints()`, and `bytes.elems()`. Each
appears as a dedicated `Value` variant and reports its own `type()` string.

```moonbit nocheck
pub struct StarlarkStringElems { /* private fields */ }       // str.elems()
pub struct StarlarkStringCodepoints { /* private fields */ }  // str.codepoints()
pub struct StarlarkBytesElems { /* private fields */ }        // bytes.elems()
```

| Type | Method | Description |
| :--- | :--- | :--- |
| `StarlarkStringElems` | `new(StarlarkString, Bool)` | Construct; `is_ords` selects int-ord vs substring elements |
| | `source_string()` / `is_ords()` | Backing string / whether it yields ordinals |
| `StarlarkStringCodepoints` | `new(StarlarkString, Bool)` | Construct; `is_ords` selects int-ord vs codepoint substrings |
| | `source_string()` / `is_ords()` | Backing string / whether it yields ordinals |
| `StarlarkBytesElems` | `new(Bytes)` | Construct from raw bytes |
| | `raw_bytes()` | The backing bytes |

---

## `@value.CustomValue` and `@value.BuiltinCallCtx`

`CustomValue` is an embedder-defined custom type that participates in the Starlark value system
as `@value.Value::ExtVal(cv)`. Construct with `CustomValue::new(repr_fn, truth_fn, type_name_fn)`
and attach optional protocol implementations via fluent `.with_*` methods
(`with_attrs`, `with_call`, `with_binary`, `with_unary`, `with_compare`, `with_contains`,
`with_equals`, `with_hash`, `with_iterate`, `with_length`, `with_items`, `with_freeze`,
`with_get_index`, `with_set_index`, `with_set_key`, `with_set_field`, `with_slice`). The matching
`get_*` / `do_*` accessors are used by the evaluator to dispatch operations.

```moonbit nocheck
pub struct CustomValue { /* private fields */ }     // in "connect0459/starlark/value"
pub struct BuiltinCallCtx { /* private fields */ }  // in "connect0459/starlark/value"
```

`BuiltinCallCtx` is passed to a built-in's body so it can call back into the evaluator:

| Method | Signature | Description |
| :--- | :--- | :--- |
| `BuiltinCallCtx::new((Value, Array[Value], Array[(String, Value)]) -> Result[Value, String], get_local? : (String) -> Value?)` | `-> BuiltinCallCtx` | Construct a call context |
| `invoke(Value, Array[Value], Array[(String, Value)])` | `-> Result[Value, String]` | Call a Starlark callable from within the built-in |
| `get_local(String)` | `-> Value?` | Read thread-local state set on the active `Thread` |

See the `lib/struct/` and `lib/time/` extensions for idiomatic `CustomValue` usage.

---

## Embedder protocol traits

Implement these on a host type to make it interoperate with the evaluator. They mirror
starlark-go's optional interfaces. Most embedders implement them indirectly through
`CustomValue`'s `.with_*` methods rather than directly.

| Trait | Method(s) | Purpose |
| :--- | :--- | :--- |
| `Container` | `has(Value) -> Result[Bool, String]` | `x in c` membership |
| `HasAttrs` | `get_attr(String)`, `attr_names()` | Attribute read (`x.attr`, `dir(x)`) |
| `HasSetField` | `set_field(String, Value)` | Attribute write (`x.attr = v`) |
| `Indexable` | `indexable_get(Int)`, `indexable_len()` | Index read (`x[i]`) |
| `HasSetIndex : Indexable` | `set_index(Int, Value)` | Index write (`x[i] = v`) |
| `Sliceable : Indexable` | `slice(Int, Int, Int)` | Slicing (`x[a:b:c]`) |
| `Mapping` | `mapping_get(Value)`, `mapping_keys()`, `mapping_len()` | Dict-like key access |
| `IterableMapping : Mapping` | `items()` | Key–value enumeration |
| `HasBinary` | `binary_op(String, Value, Bool)` | Custom binary operators |
| `HasUnary` | `unary_op(String)` | Custom unary operators |
| `StarlarkComparable` | `compare_same_type(Value)` | Same-type ordering for `sorted`/`min`/`max` |
| `TotallyOrdered` | `cmp(Value)` | Total ordering across comparisons |
| `Unpacker` (open) | `unpack(Value)` | Per-argument coercion for `@unpack.unpack_args_with` |
