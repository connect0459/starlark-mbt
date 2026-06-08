# `errors` package

All error and source-location types used across the Starlark interpreter. Import
`connect0459/starlark/errors` for `EvalError`, `SyntaxError`, `ResolveError`,
`Position`, `Binding`, `CallStack`, and `CallFrame`.

`exec_file` wraps `SyntaxError` and `ResolveError` into `EvalError` before returning,
so most callers only need to handle `EvalError`.

## Key types

| Type | Description |
| :--- | :--- |
| `EvalError` | Runtime error with message, call stack, and optional cause |
| `SyntaxError` | Lexer / parser error |
| `ResolveError` | Name-resolution error |
| `Position` | Source location (filename, 1-based line, 1-based column) |
| `Binding` | Local variable name + definition position (debugger API) |
| `CallStack` | Snapshot of the call stack (ordered outermost → innermost) |
| `CallFrame` | Single frame: function name + call-site position |

## Quick start

Constructing error values directly:

```mbt check
///|
test {
  let pos = @errors.Position::new("build.star", 5, 3)
  assert_eq(pos.filename(), "build.star")
  assert_eq(pos.line(), 5)
  assert_eq(pos.col(), 3)
  assert_eq(pos.to_string(), "build.star:5:3")
}
```

```mbt check
///|
test {
  let err = @errors.EvalError::simple("something went wrong")
  assert_eq(err.msg(), "something went wrong")
  assert_true(err.cause() is None)
}
```

```mbt check
///|
test {
  let pos = @errors.Position::new("x.star", 1, 1)
  let frame = @errors.CallFrame::new("my_func", pos)
  let stack = @errors.CallStack::new([frame])
  assert_eq(stack.length(), 1)
  match stack.at(0) {
    Some(f) => assert_eq(f.name(), "my_func")
    None => fail("expected frame")
  }
}
```

Errors returned from `@eval.exec_file` always carry a position and call stack.
See `@eval` for usage in execution context.
