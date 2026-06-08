# `lib/struct` package

`struct`, `module`, and `gensym` extensions for Starlark (analogous to
`starlark-go/lib/starlarkstruct`). Import `connect0459/starlark/lib/struct` and
inject the callables you need as predeclared bindings.

## MoonBit-level API

| Symbol | Signature | Description |
| :--- | :--- | :--- |
| `struct_builtin()` | `() -> @value.Value` | Returns the `struct(…)` Starlark callable |
| `module_builtin()` | `() -> @value.Value` | Returns the `module(name, …)` Starlark callable |
| `gensym_builtin()` | `() -> @value.Value` | Returns the `gensym(name=…)` Starlark callable |
| `make_struct(ctor, entries)` | `(@value.Value, Array[(String, @value.Value)]) -> @value.Value` | Construct a struct value directly from MoonBit |
| `make_module(name, members)` | `(String, Array[(String, @value.Value)]) -> @value.Value` | Construct a module value directly from MoonBit |
| `default_ctor` | `@value.Value` | The default constructor string `"struct"` |

## Quick start

Constructing struct and module values from MoonBit:

```mbt check
///|
test {
  let s = @struct.make_struct(@struct.default_ctor, [
    ("x", @value.Value::new_int(1L)),
    ("y", @value.Value::new_int(2L)),
  ])
  assert_eq(s.type_name(), "struct")
  let m = @struct.make_module("geo", [("origin", s)])
  assert_eq(m.type_name(), "module")
}
```

Injecting into Starlark scripts:

```moonbit nocheck
let predeclared = @eval.Predeclared::from_map({
  "struct": @struct.struct_builtin(),
  "module": @struct.module_builtin(),
})
let thread = @eval.Thread::new("main")
let src = "p = struct(x=1, y=2)\nm = module('geo', dist=p)"
let _ = @eval.exec_file_with_predeclared(thread, "s.star", src,
  @eval.Options::default(), predeclared)
```

### Starlark-level operations (after injection)

| Expression | Description |
| :--- | :--- |
| `struct(x=1, y=2)` | Create a struct |
| `s.x` | Attribute access |
| `s + struct(z=3)` | Merge two structs with the same constructor |
| `module("mymod", f=fn)` | Create a module value |
| `gensym(name="tag")` | Create a unique symbol callable |
