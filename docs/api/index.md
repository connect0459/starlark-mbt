# API Reference

This reference is split into one document per public package. Each page is a
verified doc test (`.mbt.md`): the `mbt check` examples are compiled and run by
`moon test`.

## Packages

| Package | Import alias | Reference | Description |
| :--- | :--- | :--- | :--- |
| `connect0459/starlark/eval` | `@eval` | [eval.mbt.md](./eval.mbt.md) | Entry functions (`exec_file`, `eval_expr`, `call`, `source_program`, `parse_file`, …) plus `Thread`, `Module`, `Options`, `Program`, `Predeclared`, `Universe`, `DebugFrame` |
| `connect0459/starlark/value` | `@value` | [value.mbt.md](./value.mbt.md) | `Value` and all concrete value types (`StarlarkString`, `StarlarkList`, `StarlarkDict`, `StarlarkSet`, …); `StringDict`; `CustomValue`; value helpers (`equal`, `len_of`, `as_float`, …); embedder protocol traits |
| `connect0459/starlark/errors` | `@errors` | [errors.mbt.md](./errors.mbt.md) | `EvalError`, `SyntaxError`, `ResolveError`, `Position`, `Span`, `Halt`, `Binding`, `CallFrame`, `CallStack` |
| `connect0459/starlark/syntax` | `@syntax` | [syntax.md](./syntax.md) | `File`, `Expr`, `Stmt`, and the rest of the AST node types; AST walkers (`walk_file`, `walk_expr`, `walk_stmt`) |
| `connect0459/starlark/unpack` | `@unpack` | [unpack.md](./unpack.md) | `unpack_args`, `unpack_positional`, `unpack_args_with` for host-defined built-ins |
| `connect0459/starlark/lib/json` | `@json` | [lib-json.mbt.md](./lib-json.mbt.md) | JSON encode / decode extension |
| `connect0459/starlark/lib/math` | `@math` | [lib-math.mbt.md](./lib-math.mbt.md) | Math functions extension |
| `connect0459/starlark/lib/struct` | `@struct` | [lib-struct.mbt.md](./lib-struct.mbt.md) | `struct`, `module`, and `gensym` extension (starlarkstruct) |
| `connect0459/starlark/lib/time` | `@time` | [lib-time.mbt.md](./lib-time.mbt.md) | Time and duration extension (starlarktime) |

All `internal/*` packages are implementation details and are not importable by consumers.
The packages `eval`, `value`, `errors`, `syntax`, and `unpack` are public sub-packages; import
them directly. The root `connect0459/starlark` package adds zero-ceremony helpers (`exec`, `eval`)
on top of these — full-control entry functions live in `@eval`, value types and inspection helpers
in `@value`, error types in `@errors`, AST types in `@syntax`, and argument unpacking in `@unpack`.
