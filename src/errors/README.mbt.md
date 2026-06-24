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

Errors returned from `@eval.exec_file` include source location information.
Runtime errors carry a structured call stack; parse and resolve failures embed
the position in the error message string. See `@eval` for usage in execution
context.

## API reference

### `EvalError`

| Method | Returns | Description |
| :--- | :--- | :--- |
| `EvalError::simple(String)` | `EvalError` | Construct with no position (for host code) |
| `EvalError::with_stack(String, CallStack)` | `EvalError` | Construct with a call stack |
| `EvalError::with_cause(String, CallStack, EvalError)` | `EvalError` | Construct wrapping an inner cause |
| `msg()` | `String` | Error message |
| `to_string()` | `String` | Error message string (same as `msg()`) |
| `backtrace()` | `String` | Formatted call stack ending with `"Error: msg"` |
| `call_stack()` | `CallStack` | The captured call stack as structured frames |
| `cause()` | `EvalError?` | The wrapped inner error, if this error chains one |

`backtrace()` always ends the output with `Error: <msg>` (or `Error in <builtin>: <msg>`
when the innermost frame is a built-in). This format is intentional — the mbt CLI
uses `backtrace()` directly to display errors, so the `Error:` prefix appears in all
CLI output. starlark-go omits the prefix and prints the message directly; the
difference is a deliberate quality-of-life choice.

### `SyntaxError` and `ResolveError`

Both carry a `Position` and a message; `exec_file` wraps these into `EvalError`
before returning.

| Method | Returns | Description |
| :--- | :--- | :--- |
| `SyntaxError::new(Position, String)` | `SyntaxError` | Construct from a position and message (kind `Other`) |
| `SyntaxError::with_kind(Position, String, SyntaxErrorKind)` | `SyntaxError` | Construct with an explicit `kind` |
| `ResolveError::new(Position, String)` | `ResolveError` | Construct from a position and message |
| `msg()` | `String` | Error message |
| `pos()` | `Position` | Source position |
| `SyntaxError::kind()` | `SyntaxErrorKind` | Structural classification of the error |
| `to_string()` | `String` | `"<file>:<line>:<col>: <msg>"` |

`SyntaxErrorKind` classifies a `SyntaxError` by structural cause so consumers
(such as the REPL's continuation detector) can branch on the kind instead of
matching the English message text:

| Variant | Meaning |
| :--- | :--- |
| `UnexpectedEof` | Input ended while a construct was still open (e.g. a compound opener or unclosed bracket) — may complete with more input |
| `UnterminatedString` | A string literal was not closed before end of input — may complete with more input |
| `Other` | Any other syntax error — genuinely invalid input |

### `Position`

| Method | Returns | Description |
| :--- | :--- | :--- |
| `Position::new(String, Int, Int)` | `Position` | Construct from filename, line, column |
| `filename()` | `String` | Source file name |
| `line()` | `Int` | 1-based line number |
| `col()` | `Int` | 1-based column (0 = unknown) |
| `is_valid()` | `Bool` | `true` if line > 0 |
| `is_before(Position)` | `Bool` | Positional comparison |
| `to_string()` | `String` | `"<file>:<line>:<col>"` |

### `Binding`

A local variable name with its definition position; used by the debugger API.

| Method | Returns | Description |
| :--- | :--- | :--- |
| `Binding::new(String, Position)` | `Binding` | Construct from a name and position |
| `name()` | `String` | Variable name |
| `pos()` | `Position` | Declaration position in source |

### `CallStack` and `CallFrame`

| Method | Returns | Description |
| :--- | :--- | :--- |
| `CallStack::new(Array[CallFrame])` | `CallStack` | Construct from frames (0 = outermost) |
| `length()` | `Int` | Number of frames |
| `at(Int)` | `CallFrame?` | Frame at index; `None` if out of range |
| `pop()` | `CallFrame?` | Remove and return the innermost frame |
| `to_string()` | `String` | Human-readable backtrace |
| `CallFrame::new(String, Position)` | `CallFrame` | Construct from a name and call-site position |
| `name()` | `String` | Function name at this frame |
| `pos()` | `Position` | Call-site position |
