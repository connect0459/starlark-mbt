# `value` package

The Starlark value system. Import `connect0459/starlark/value` for the `Value` enum,
every concrete value type (`StarlarkList`, `StarlarkDict`, `StarlarkSet`, …),
the host-side `StringDict`, embedder-extension helpers, and the embedder protocol traits.

## Key types

| Type | Description |
| :--- | :--- |
| `Value` | Union of all Starlark values (`None`, `Bool`, `Int`, `Float`, `String`, `Bytes`, `List`, `Tuple`, `Dict`, `Set`, `Range`, `Function`, `Builtin`, `ExtVal`, …) |
| `StarlarkString` | Immutable UTF-8 string |
| `StarlarkList` | Mutable, freezable sequence |
| `StarlarkDict` | Insertion-ordered mutable mapping |
| `StarlarkSet` | Insertion-ordered mutable hash set |
| `StarlarkRange` | Lazy integer range |
| `StringDict` | Host-side `Map[String, Value]` wrapper (used as `eval_expr` env) |
| `CustomValue` | Embedder-defined custom type for `Value::ExtVal` |

## Quick start

Constructing and inspecting values:

```mbt check
///|
test {
  let n = @value.Value::new_int(42L)
  let s = @value.Value::new_string("hello")
  let lst = @value.Value::new_list([@value.Value::Bool(true), n])
  assert_eq(n.type_name(), "int")
  assert_eq(s.type_name(), "string")
  assert_eq(lst.type_name(), "list")
  assert_eq(n.truth(), true)
  assert_eq(@value.Value::None.truth(), false)
}
```

Working with `StarlarkList`:

```mbt check
///|
test {
  let lst = @value.StarlarkList::new([@value.Value::new_int(1L)])
  let _ = lst.push(@value.Value::new_int(2L))
  assert_eq(lst.length(), 2)
  assert_true(lst.get(0) is Some(@value.Value::Int(_)))
  lst.freeze()
  assert_true(lst.is_frozen())
}
```

Using `StringDict` as an eval environment:

```mbt check
///|
test {
  let env = @value.StringDict::new()
  env.set("x", @value.Value::new_int(10L))
  assert_true(env.get("x") is Some(@value.Value::Int(_)))
  assert_eq(env.has("y"), false)
}
```

Defining a host built-in callable:

```mbt check
///|
test {
  let add = @value.Value::new_builtin("add", fn(_ctx, args, _kw) {
    match (args[0], args[1]) {
      (@value.Value::Int(a), @value.Value::Int(b)) =>
        Ok(@value.Value::Int(a + b))
      _ => Err("expected two ints")
    }
  })
  assert_eq(add.type_name(), "builtin_function_or_method")
}
```

## API reference

### `Value` enum

```moonbit nocheck
///|
pub enum Value {
  None
  Bool(Bool)
  Int(BigInt) // arbitrary-precision integer; use `N` suffix in patterns: `42N`
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
  StringElems(StarlarkStringElems) // str.elems()
  StringCodepoints(StarlarkStringCodepoints) // str.codepoints()
  BytesElems(StarlarkBytesElems) // bytes.elems()
  ExtVal(CustomValue) // embedder-defined custom type
}
```

### `Value` constructors and methods

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

### Value-inspection helpers

Mirrors of starlark-go's package-level helpers; errors are plain `String`
(value-level operations carry no source position).

| Function | Signature | Description |
| :--- | :--- | :--- |
| `equal` | `(Value, Value) -> Result[Bool, String]` | Structural equality (depth-capped) |
| `len_of` | `(Value) -> Int` | Sequence length; returns `-1` for non-sequences |
| `length_of` | `(Value) -> Result[Int, String]` | Sequence length; `Err` for non-sequences |
| `iterate` | `(Value) -> Result[StarlarkIterator, String]` | Obtain an iterator over a Starlark iterable |
| `number_to_int` | `(Value) -> Int64?` | Convert `Int` or `Float` to `Int64` |
| `as_float` | `(Value) -> (Double, Bool)` | Extract `Float` or convert `Int`; second is `true` on success |
| `as_string` | `(Value) -> (String, Bool)` | Extract raw string from `String` value; second is `true` on success |

### Depth-limited comparison

These guard against infinite recursion on cyclic data structures.

| Symbol | Signature | Description |
| :--- | :--- | :--- |
| `compare_limit` | `Int` | Default recursion depth (value: `10`) |
| `equal_depth` | `(Value, Value, Int) -> Result[Bool, String]` | Equality with explicit depth limit |
| `compare_depth` | `(String, Value, Value, Int) -> Result[Bool, String]` | Comparison operator (`"=="`, `"<"`, …) with explicit depth limit |
| `compare_values` | `(Value, Value, op? : String) -> Result[Int, String]` | Three-way comparison (`-1`/`0`/`1`); primarily used for same-type ordering (e.g. `sorted`) |
| `compare_values_depth` | `(Value, Value, Int, op? : String) -> Result[Int, String]` | Three-way comparison with explicit depth limit |

---

### `StarlarkString`

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

### `StarlarkList`

| Method | Description |
| :--- | :--- |
| `StarlarkList::new(Array[Value])` | Construct from an array |
| `length() -> Int` | Number of elements |
| `is_empty() -> Bool` | Whether the list has no elements |
| `get(Int) -> Value?` | Element at index; `None` if out of range |
| `op_get(Int) -> Value` | Element at index (panics if out of range; backs `list[i]` syntax) |
| `set(Int, Value) -> Result[Unit, String]` | Replace the element at index |
| `push(Value) -> Result[Unit, String]` | Append (`Err` if frozen) |
| `insert(Int, Value) -> Result[Unit, String]` | Insert at index |
| `pop() -> Result[Value?, String]` | Remove and return the last element |
| `pop_at(Int, String) -> Result[Value, String]` | Remove and return the element at index |
| `clear() -> Result[Unit, String]` | Remove all elements |
| `reverse() -> Result[Unit, String]` | Reverse in place |
| `sort_by((Value, Value) -> Int) -> Result[Unit, String]` | Sort in place with a comparator |
| `each((Value) -> Unit)` | Iterate elements |
| `eachi((Int, Value) -> Unit)` | Iterate elements with index |
| `iter() -> Iter[Value]` | Lazy iterator |
| `is_frozen() -> Bool` | Whether the list is frozen |
| `freeze() -> Unit` | Freeze the list (and transitively its values) |
| `check_mutable(String) -> Result[Unit, String]` | `Err` if frozen or being iterated; `verb` names the operation |

---

### `StarlarkDict`

Insertion-ordered mutable mapping; keys are any hashable `Value`.

| Method | Description |
| :--- | :--- |
| `StarlarkDict::new()` | Empty dict |
| `set(Value, Value) -> Result[Unit, String]` | Insert or replace |
| `get(Value) -> Result[Value?, String]` | Look up by key (`Err` if unhashable) |
| `delete(Value) -> Result[Bool, String]` | Remove; returns whether present |
| `clear() -> Result[Unit, String]` | Remove all entries |
| `length() -> Int` | Number of entries |
| `keys() -> Array[Value]` | Keys in insertion order |
| `each((Value, Value) -> Unit)` | Iterate all key–value pairs |
| `iter() -> Iter[Value]` | Iterator over a snapshot of keys in insertion order |
| `entries() -> Iter[(Value, Value)]` | Iterator over key–value pairs in insertion order |
| `popitem() -> Result[(Value, Value)?, String]` | Remove and return the last inserted pair |
| `is_frozen() -> Bool` | Whether the dict is frozen |
| `freeze() -> Unit` | Freeze the dict and its contents |

---

### `StarlarkSet`

Insertion-ordered mutable hash set; members are any hashable `Value`.

| Method | Description |
| :--- | :--- |
| `StarlarkSet::new()` | Empty set |
| `add(Value) -> Result[Unit, String]` | Add a member |
| `contains(Value) -> Result[Bool, String]` | Membership test |
| `remove(Value) -> Result[Bool, String]` | Remove; returns whether present |
| `pop_first() -> Result[Value?, String]` | Remove and return the first inserted member |
| `clear() -> Result[Unit, String]` | Remove all members |
| `length() -> Int` | Number of members |
| `each((Value) -> Unit)` | Iterate members in insertion order |
| `iter() -> Iter[Value]` | Lazy iterator |
| `is_frozen() -> Bool` | Whether the set is frozen |
| `freeze() -> Unit` | Freeze the set and its members |

---

### `StarlarkRange`

The lazy integer sequence returned by `range()`; not a list.

| Method | Signature | Description |
| :--- | :--- | :--- |
| `StarlarkRange::new(Int64, Int64, Int64)` | `-> StarlarkRange` | Construct from `start`, `stop`, `step` |
| `start()` / `stop()` / `step()` | `-> Int64` | The three range parameters |
| `length()` | `-> Int` | Number of elements |
| `index_at(Int)` | `-> Int64` | The value at the i-th position |
| `contains(Int64)` | `-> Bool` | Membership test |

---

### `StringDict`

A `Map[String, Value]` wrapper for host-side string-keyed environments; the type
accepted by `eval_expr` and `exec_repl_chunk`.

| Method | Description |
| :--- | :--- |
| `StringDict::new()` | Empty map |
| `StringDict::from_map(Map[String, Value])` | Wrap an existing map |
| `set(String, Value)` | Add or replace a binding |
| `get(String) -> Value?` | Look up by key |
| `has(String) -> Bool` | Test for key presence |
| `delete(String) -> Bool` | Remove; returns whether present |
| `keys() -> Array[String]` | Sorted list of keys |
| `values() -> Array[Value]` | All contained values |
| `each((String, Value) -> Unit)` | Iterate all key-value pairs |
| `freeze()` | Transitively freeze all contained values |

---

### `StarlarkFunction`

A user-defined (Starlark-source) function. Obtain via `Value::Function(f)` pattern matching.

| Method | Returns | Description |
| :--- | :--- | :--- |
| `name()` | `String` | Function name; `"<lambda>"` for lambdas |
| `position()` | `@errors.Position` | Source position of the `def` keyword |
| `doc()` | `String` | Docstring (first string literal in body); `""` if absent |
| `num_params()` | `Int` | Total parameter count |
| `num_kwonly_params()` | `Int` | Number of keyword-only parameters (after `*args`) |
| `has_varargs()` | `Bool` | Whether the function has a `*args` parameter |
| `has_kwargs()` | `Bool` | Whether the function has a `**kwargs` parameter |
| `param(Int)` | `(String, @errors.Position)` | Name and position of the i-th parameter |
| `param_default(Int)` | `Value?` | Default value of the i-th parameter; `None` if required |
| `num_free_vars()` | `Int` | Number of captured (closure) variables |
| `free_var(Int)` | `(String, Value)?` | Name and current value of the i-th free variable |
| `defining_module()` | `StarlarkModule?` | Module that defined this function |

```moonbit nocheck
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
          match f.defining_module() {
            Some(mod_ref) => assert_true(mod_ref.get("CONST") is Some(_))
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

### String and bytes iterables

The lazy iterables returned by `str.elems()`, `str.codepoints()`, and `bytes.elems()`.
Each appears as a dedicated `Value` variant and reports its own `type()` string.

| Type | Constructor | Accessors | Description |
| :--- | :--- | :--- | :--- |
| `StarlarkStringElems` | `new(StarlarkString, Bool)` | `source_string()`, `is_ords()` | `str.elems()`; `is_ords=true` yields integer ordinals, `false` yields one-char substrings |
| `StarlarkStringCodepoints` | `new(StarlarkString, Bool)` | `source_string()`, `is_ords()` | `str.codepoints()`; `is_ords=true` yields codepoint integers, `false` yields substrings |
| `StarlarkBytesElems` | `new(Bytes)` | `raw_bytes()` | `bytes.elems()`; yields integer byte values |

---

### `StarlarkModule`, `StarlarkIterator`, `StarlarkBuiltinFunc`, `StarlarkBoundMethod`

| Type | Key methods | Description |
| :--- | :--- | :--- |
| `StarlarkModule` | `StarlarkModule::new(String, Map[String, Value])`, `name()`, `get(String)`, `attr_names()` | Loaded module value (e.g. from `load` or `StarlarkFunction::defining_module`) |
| `StarlarkIterator` | `next() -> Value?`, `done()`, `collect() -> Array[Value]` | Iterator returned by `@value.iterate`; **must** call `done()` even on early exit |
| `StarlarkBuiltinFunc` | `name()`, `receiver() -> Value?`, `bind_receiver(Value)` | Host-provided callable; build with `Value::new_builtin` |
| `StarlarkBoundMethod` | `StarlarkBoundMethod::new(Value, String)`, `recv()`, `method_name()` | Method bound to a receiver, e.g. `"abc".upper` |

---

### `CustomValue` and `BuiltinCallCtx`

`CustomValue` is an embedder-defined custom type that participates in the Starlark value
system as `Value::ExtVal(cv)`. Construct with `CustomValue::new(repr_fn, truth_fn,
type_name_fn)` and attach optional protocol implementations via fluent `.with_*` methods:
`with_attrs`, `with_call`, `with_binary`, `with_unary`, `with_compare`, `with_contains`,
`with_equals`, `with_hash`, `with_iterate`, `with_length`, `with_items`, `with_freeze`,
`with_get_index`, `with_set_index`, `with_set_key`, `with_set_field`, `with_slice`.

`BuiltinCallCtx` is passed to a built-in's body so it can call back into the evaluator:

| Method | Signature | Description |
| :--- | :--- | :--- |
| `BuiltinCallCtx::new((Value, Array[Value], Array[(String, Value)]) -> Result[Value, String], get_local? : (String) -> Value?)` | `-> BuiltinCallCtx` | Construct a call context with an invoke body and optional thread-local reader |
| `invoke(Value, Array[Value], Array[(String, Value)])` | `-> Result[Value, String]` | Call a Starlark callable from within the built-in |
| `get_local(String)` | `-> Value?` | Read thread-local state set on the active `Thread` |

---

### Embedder protocol traits

Implement these on a host type to make it interoperate with the evaluator.

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
