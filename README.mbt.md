# starlark-mbt

[![CI](https://github.com/connect0459/starlark-mbt/actions/workflows/ci.yml/badge.svg)](https://github.com/connect0459/starlark-mbt/actions/workflows/ci.yml)
[![License: Apache-2.0](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

A MoonBit implementation of the [Starlark](https://github.com/bazelbuild/starlark/blob/master/spec.md)
scripting language interpreter.

All optional features (`set`, `lambda`, `while`, `bytes`, `float`, recursion) are **enabled by default**.

## Packages

| Package | Import alias | Description |
| :--- | :--- | :--- |
| `connect0459/starlark/eval` | `@eval` | Entry functions (`exec_file`, `eval_expr`, `call`, `source_program`, `parse_file`, …) plus `Thread`, `Module`, `Options`, `Program`, `Predeclared`, `Universe` |
| `connect0459/starlark/value` | `@value` | `Value`, `StringDict`, `StarlarkDict`, `StarlarkList`, `StarlarkString`, `CustomValue`; value helpers (`equal`, `len_of`, `as_float`, …) |
| `connect0459/starlark/unpack` | `@unpack` | `unpack_args`, `unpack_positional`, `unpack_args_with` for host-defined built-ins |
| `connect0459/starlark/errors` | `@errors` | `EvalError`, `SyntaxError`, `ResolveError`, `Position`, `CallStack`, … |
| `connect0459/starlark/syntax` | `@syntax` | `File`, `Expr` — AST types for `parse_file`/`parse_expr` |
| `connect0459/starlark/lib/json` | `@json` | JSON encode / decode extension |
| `connect0459/starlark/lib/math` | `@math` | Math functions extension (mirrors Python's `math` module) |
| `connect0459/starlark/lib/struct` | `@struct` | `struct`, `module`, and `gensym` extension (starlarkstruct) |
| `connect0459/starlark/lib/time` | `@time` | Time and duration extension (starlarktime) |

## Installation

```sh
moon add connect0459/starlark
```

Then declare the packages you need in your `moon.pkg` (add extension packages as needed):

```text
import {
  "connect0459/starlark/eval",          // exec_file, eval_expr, call, parse_file, Thread, Module, Options, …
  "connect0459/starlark/value",         // Value, StringDict, StarlarkDict, value helpers (equal, len_of, …)
  // "connect0459/starlark/errors",     // EvalError, Position, CallStack, …
  // "connect0459/starlark/syntax",     // File, Expr (parse_file / parse_expr)
  // "connect0459/starlark/unpack",     // unpack_args* for host-defined built-ins
  // optional extensions:
  // "connect0459/starlark/lib/json",
  // "connect0459/starlark/lib/math",
  // "connect0459/starlark/lib/struct",
  // "connect0459/starlark/lib/time",
}
```

## Usage

```mbt check
///|
test {
  let thread = @eval.Thread::new("main")
  let src = "result = max([i * i for i in range(5)])"
  match @eval.exec_file(thread, "example.star", src, @eval.Options::default()) {
    Ok(m) => assert_true(m.get("result") is Some(@value.Value::Int(16N)))
    Err(e) => fail(e.to_string())
  }
}
```

For full usage examples — print capture, expression evaluation, host bindings, module
loading, error handling, extensions, and calling Starlark functions from host code — see
the [API Reference](https://github.com/connect0459/starlark-mbt/blob/main/src/docs/api/index.md).

## Documentation

- [API Reference](https://github.com/connect0459/starlark-mbt/blob/main/src/docs/api/index.md) — Per-package API reference for all packages

## Contributing

See [CONTRIBUTING.md](https://github.com/connect0459/starlark-mbt/blob/main/CONTRIBUTING.md).

## License

Apache-2.0
