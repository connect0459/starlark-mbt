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
