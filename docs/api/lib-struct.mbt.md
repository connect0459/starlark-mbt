# `lib/struct` package

Provides `struct`, `module`, and `gensym` as Starlark extensions (analogous to
`starlark-go/lib/starlarkstruct`). Import and inject the callables you need as
predeclared bindings.

```moonbit nocheck
import {
  "connect0459/starlark/eval",
  "connect0459/starlark/value",
  "connect0459/starlark/lib/struct",
}
```

## MoonBit-level API

| Symbol | Signature | Description |
| :--- | :--- | :--- |
| `struct_builtin()` | `() -> @value.Value` | Returns the `struct(…)` Starlark callable |
| `module_builtin()` | `() -> @value.Value` | Returns the `module(name, …)` Starlark callable |
| `gensym_builtin()` | `() -> @value.Value` | Returns the `gensym(name=…)` Starlark callable |
| `make_struct(ctor, entries)` | `(@value.Value, Array[(String, @value.Value)]) -> @value.Value` | Construct a struct value directly from MoonBit code |
| `make_module(name, members)` | `(String, Array[(String, @value.Value)]) -> @value.Value` | Construct a module value directly from MoonBit code |
| `default_ctor` | `@value.Value` | The default constructor string `"struct"` |

## Starlark-level usage (inside scripts)

After injecting `struct_builtin()` as `"struct"` in predeclared:

| Expression | Description |
| :--- | :--- |
| `struct(x=1, y=2)` | Create a struct with fields `x` and `y` |
| `s.x` | Attribute access |
| `s + struct(z=3)` | Merge two structs with the same constructor |
| `module("mymod", f=fn)` | Create a module value (with `module_builtin`) |
| `gensym(name="tag")` | Create a unique symbol callable (with `gensym_builtin`) |

```mbt check
///|
test {
  let predeclared = @eval.Predeclared::from_map({
    "struct": @struct.struct_builtin(),
    "module": @struct.module_builtin(),
  })
  let thread = @eval.Thread::new("main")
  let src = "p = struct(x=1, y=2)\nm = module('geo', dist=p)"
  match
    @eval.exec_file_with_predeclared(
      thread,
      "s.star",
      src,
      @eval.Options::default(),
      predeclared,
    ) {
    Ok(m) => {
      assert_true(m.get("p") is Some(@value.Value::ExtVal(_)))
      assert_true(m.get("m") is Some(@value.Value::ExtVal(_)))
    }
    Err(e) => fail(e.to_string())
  }
}
```
