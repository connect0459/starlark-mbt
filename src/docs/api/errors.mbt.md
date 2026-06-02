# `errors` package

All error types carry a `Position` (or call stack) and a human-readable message. `exec_file`
wraps `SyntaxError` and `ResolveError` into `EvalError` before returning, so callers typically
only need to handle `EvalError`.

## `@errors.EvalError`

Runtime errors raised during evaluation.

| Method | Returns | Description |
| :--- | :--- | :--- |
| `msg()` | `String` | Error message |
| `to_string()` | `String` | `"<file>:<line>:<col>: <msg>"` |
| `backtrace()` | `String` | Formatted call stack |
| `cause()` | `EvalError?` | The wrapped inner error, if this error chains one |
| `EvalError::simple(String)` | `EvalError` | Construct with no position (for host code) |
| `EvalError::with_stack(String, CallStack)` | `EvalError` | Construct with a call stack |
| `EvalError::with_cause(String, CallStack, EvalError)` | `EvalError` | Construct wrapping an inner cause |

## `@errors.SyntaxError`

Lexer or parser errors.

| Method | Returns | Description |
| :--- | :--- | :--- |
| `SyntaxError::new(Position, String)` | `SyntaxError` | Construct from a position and message |
| `msg()` | `String` | Error message |
| `pos()` | `Position` | Source position |
| `to_string()` | `String` | `"<file>:<line>:<col>: <msg>"` |

## `@errors.ResolveError`

Name-resolution errors (undefined variables, invalid scoping, etc.).

| Method | Returns | Description |
| :--- | :--- | :--- |
| `ResolveError::new(Position, String)` | `ResolveError` | Construct from a position and message |
| `msg()` | `String` | Error message |
| `pos()` | `Position` | Source position |
| `to_string()` | `String` | `"<file>:<line>:<col>: <msg>"` |

## `@errors.Position`

A source location: filename, 1-based line, 1-based column. Column 0 means unknown.

| Method | Returns | Description |
| :--- | :--- | :--- |
| `Position::new(String, Int, Int)` | `Position` | Construct from filename, line, column |
| `filename()` | `String` | Source file name |
| `line()` | `Int` | 1-based line number |
| `col()` | `Int` | 1-based column (0 = unknown) |
| `is_valid()` | `Bool` | `true` if line > 0 |
| `is_before(Position)` | `Bool` | Positional comparison |
| `to_string()` | `String` | `"<file>:<line>:<col>"` |

## `@errors.Span`

A start–end pair of `Position`s for ranged diagnostics.

| Method | Returns | Description |
| :--- | :--- | :--- |
| `Span::new(Position, Position)` | `Span` | Construct from start and end positions |
| `start()` | `Position` | Start position |
| `end_pos()` | `Position` | End position |
| `to_string()` | `String` | `"<start>-<end>"` |

## `@errors.Halt`

A cancellation signal, distinct from `EvalError`, used to unwind execution when a thread is
cancelled or its step budget is exhausted.

| Method | Returns | Description |
| :--- | :--- | :--- |
| `Halt::new(String)` | `Halt` | Construct with a reason |
| `reason()` | `String` | Why execution was halted |

## `@errors.Binding`

A local variable name together with its definition position. Used by the debugger API.

| Method | Returns | Description |
| :--- | :--- | :--- |
| `Binding::new(String, Position)` | `Binding` | Construct from a name and position |
| `name()` | `String` | Variable name |
| `pos()` | `Position` | Declaration position in source |

## `@errors.CallStack` and `@errors.CallFrame`

A snapshot of the call stack at a point in time.

### `CallStack`

| Method | Returns | Description |
| :--- | :--- | :--- |
| `CallStack::new(Array[CallFrame])` | `CallStack` | Construct from frames |
| `length()` | `Int` | Number of frames |
| `at(Int)` | `CallFrame?` | Frame at index (0 = outermost) |
| `pop()` | `CallFrame?` | Remove and return the innermost frame |
| `to_string()` | `String` | Human-readable backtrace |

### `CallFrame`

| Method | Returns | Description |
| :--- | :--- | :--- |
| `CallFrame::new(String, Position)` | `CallFrame` | Construct from a name and call-site position |
| `name()` | `String` | Function name at this frame |
| `pos()` | `Position` | Call-site position |

```mbt check
///|
test {
  let thread = @eval.Thread::new("main")
  let _ = @eval.exec_file(
    thread,
    "x.star",
    "def f(): pass\nf()",
    @eval.Options::default(),
  )
  let stack = thread.call_stack()
  assert_eq(stack.length(), 0) // stack is empty after execution
}
```
