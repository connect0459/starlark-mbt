# starlark-mbt

[![CI](https://github.com/connect0459/starlark-mbt/actions/workflows/ci.yml/badge.svg)](https://github.com/connect0459/starlark-mbt/actions/workflows/ci.yml)
[![License: Apache-2.0](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

A MoonBit implementation of the [Starlark](https://github.com/bazelbuild/starlark/blob/master/spec.md)
scripting language interpreter.

All optional features (`set`, `lambda`, `while`, `bytes`, `float`, recursion) are **enabled by default**.

## Packages

| Package | Description |
| :--- | :--- |
| `connect0459/starlark` | Core interpreter: `Thread`, `exec_file`, `eval_expr` |
| `connect0459/starlark/json` | JSON encode / decode extension |
| `connect0459/starlark/math` | Math functions extension (mirrors Python's `math` module) |
| `connect0459/starlark/struct` | `struct`, `module`, and `gensym` extension (starlarkstruct) |
| `connect0459/starlark/time` | Time and duration extension (starlarktime) |

## Installation

```sh
moon add connect0459/starlark
```

Then declare the packages you need in your `moon.pkg` (add extension packages as needed):

```text
import {
  "connect0459/starlark",
  // optional extensions:
  // "connect0459/starlark/json",
  // "connect0459/starlark/math",
  // "connect0459/starlark/struct",
  // "connect0459/starlark/time",
}
```

## Usage

```moonbit
test {
  let thread = @starlark.Thread::new("main")
  let src = "result = sum([i * i for i in range(5)])"
  match @starlark.exec_file(thread, "example.star", src, @starlark.Options::default()) {
    Ok(m) =>
      assert_true(@starlark.module_get(m, "result") is Some(@starlark.Value::Int(30L)))
    Err(e) => fail!(e.to_string())
  }
}
```

For full usage examples — print capture, expression evaluation, host bindings, module
loading, error handling, extensions, and calling Starlark functions from host code — see
the [API Reference](https://github.com/connect0459/starlark-mbt/blob/main/docs/api.md).

## Documentation

- [API Reference](https://github.com/connect0459/starlark-mbt/blob/main/docs/api.md) — Full API reference for all packages

## License

Apache-2.0
