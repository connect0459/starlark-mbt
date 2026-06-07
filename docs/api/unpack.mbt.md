# `unpack` package

Helpers for binding positional and keyword arguments inside host-defined built-ins. Call them as
`@unpack.unpack_args` etc.

| Function | Signature | Description |
| :--- | :--- | :--- |
| `unpack_args` | `(String, Array[Value], Array[(String, Value)], Array[String]) -> Result[Array[Value?], String]` | Bind positional + keyword args to a name spec (`"name"`, `"name?"`, `"name??"`) |
| `unpack_positional` | `(String, Array[Value], Array[(String, Value)], Int, Int) -> Result[Array[Value?], String]` | Bind positional-only args, requiring between `min` and `max` |
| `unpack_args_with` | `(String, Array[Value], Array[(String, Value)], Array[(String, &@value.Unpacker)]) -> Result[Unit, String]` | Like `unpack_args` but dispatches each matched value to a custom `@value.Unpacker` target |

Implement the `@value.Unpacker` trait (`unpack(Self, Value) -> Result[Unit, String]`)
on a host type to define custom per-argument validation/coercion, mirroring
starlark-go's `Unpacker` interface.

## `unpack_args`

Bind positional and keyword arguments using a name-spec array. Required names (`"name"`),
optional names (`"name?"`), and star-optional names (`"name??"`) are supported.

```mbt check
///|
test {
  let args = [@value.Value::Int(42N)]
  let kw : Array[(String, @value.Value)] = []
  match @unpack.unpack_args("my_func", args, kw, ["x"]) {
    Ok(bound) => assert_true(bound[0] is Some(@value.Value::Int(_)))
    Err(e) => fail(e)
  }
}
```

Missing a required argument returns an error that names both the function and the missing
parameter:

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

## `unpack_positional`

Bind positional-only arguments requiring between `min` and `max` values. Keyword arguments are
rejected.

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
