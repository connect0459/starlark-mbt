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
