# `unpack` package

Argument-binding helpers for host-defined built-in functions. Import
`connect0459/starlark/unpack` to bind positional and keyword arguments inside a
`Value::new_builtin` callback.

## Functions

| Function | Description |
| :--- | :--- |
| `unpack_args` | Bind positional + keyword args to a name spec (`"name"`, `"name?"`, `"name??"`); returns `Result[Array[@value.Value?], String]` |
| `unpack_positional` | Bind positional-only args, requiring between `min` and `max` values; returns `Result[Array[@value.Value?], String]` |
| `unpack_args_with` | Like `unpack_args` but dispatches each value to a custom `@value.Unpacker` target; returns `Result[Unit, String]` |

Implement `@value.Unpacker` (`unpack(Self, Value) -> Result[Unit, String]`) on a
host type for per-argument validation and coercion.

## Quick start

### Named argument binding

```mbt check
///|
test {
  let args = [@value.Value::Int(42N)]
  let kw : Array[(String, @value.Value)] = []
  match @unpack.unpack_args("my_func", args, kw, ["x", "y?"]) {
    Ok(bound) => {
      assert_true(bound[0] is Some(@value.Value::Int(_)))
      assert_true(bound[1] is None)
    }
    Err(e) => fail(e)
  }
}
```

Missing a required argument returns an error naming both the function and the parameter:

```mbt check
///|
test {
  let args : Array[@value.Value] = []
  let kw : Array[(String, @value.Value)] = []
  match @unpack.unpack_args("my_func", args, kw, ["x"]) {
    Err(e) => assert_true(e.contains("x"))
    Ok(_) => fail("expected error for missing required arg")
  }
}
```

### Positional-only binding

```mbt check
///|
test {
  let args = [@value.Value::Int(1N), @value.Value::Int(2N)]
  let kw : Array[(String, @value.Value)] = []
  match @unpack.unpack_positional("f", args, kw, 1, 3) {
    Ok(bound) => {
      assert_eq(bound.length(), 3)
      assert_true(bound[0] is Some(_))
      assert_true(bound[1] is Some(_))
      assert_true(bound[2] is None)
    }
    Err(e) => fail(e)
  }
}
```
