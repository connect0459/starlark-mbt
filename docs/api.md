# API Reference

## Packages

| Package | Import alias | Description |
| :--- | :--- | :--- |
| `connect0459/starlark` | `@starlark` | Core interpreter façade |
| `connect0459/starlark/lib/json` | `@json` | JSON encode / decode extension |
| `connect0459/starlark/lib/math` | `@math` | Math functions extension |

All `src/internal/*` packages are implementation details and are not importable by consumers.

---

## `starlark` package

### Top-level functions

| Function | Signature | Description |
| :--- | :--- | :--- |
| `exec_file` | `(Thread, String, String, Options) -> Result[Module, EvalError]` | Execute a Starlark source file |
| `eval_expr` | `(Thread, String, String, StarlarkDict) -> Result[Value, EvalError]` | Evaluate a single Starlark expression |
| `exec_file_with_predeclared` | `(Thread, String, String, Options, Predeclared) -> Result[Module, EvalError]` | Execute with extra host bindings visible to the script |
| `module_get` | `(Module, String) -> Value?` | Look up a global by name in an executed module |
| `repr` | `(Value) -> String` | Starlark `repr()` of a value (quoted strings, recursive containers) |
| `to_str` | `(Value) -> String` | Starlark `str()` of a value (unquoted strings) |
| `type_name` | `(Value) -> String` | Starlark `type()` string for a value |
| `truth` | `(Value) -> Bool` | Starlark truthiness (`if` / `and` / `or` semantics) |
| `starlark_equals` | `(Value, Value) -> Bool` | Structural equality (`==` semantics; `NaN == NaN`) |

#### `exec_file`

Parses, resolves, and evaluates `src` as a complete Starlark file. `filename` is used only
in error messages. Returns the frozen `Module` containing all top-level globals on success.

```moonbit
let thread = @starlark.Thread::new("main")
let _ = @starlark.exec_file(
  thread, "build.star",
  "greeting = 'hello ' + 'world'",
  @starlark.Options::default(),
)
```

#### `eval_expr`

Evaluates a single expression `src` in the given environment `env`. Unlike `exec_file`,
this does not run statements and does not produce a `Module`; it returns the expression value.
`env` may be empty (`StarlarkDict::new()`) or pre-populated with bindings.

```moonbit
let thread = @starlark.Thread::new("expr")
let env = @starlark.StarlarkDict::new()
let _ = @starlark.eval_expr(thread, "<expr>", "len([1, 2, 3])", env)
```

#### `exec_file_with_predeclared`

Like `exec_file` but injects `predeclared` bindings before execution. These bindings are
visible to the script as predeclared names (higher precedence than universe built-ins,
lower than locals and globals).

```moonbit
let thread = @starlark.Thread::new("main")
let predeclared = @starlark.Predeclared::from_map({
  "MY_FLAG": @starlark.Value::Bool(true),
})
let _ = @starlark.exec_file_with_predeclared(
  thread, "script.star",
  "enabled = MY_FLAG",
  @starlark.Options::default(),
  predeclared,
)
```

---

### `Thread`

Holds execution context: print callback, load callback, call stack, and step budget.

```moonbit
pub struct Thread { /* private fields */ }
```

#### Constructors

| Constructor | Signature | Description |
| :--- | :--- | :--- |
| `Thread::new` | `(String) -> Thread` | Thread with default print (stdout) and no loader |
| `Thread::with_print` | `(String, (String) -> Unit) -> Thread` | Thread with a custom print callback |
| `Thread::with_loader` | `(String, (Thread, String) -> Result[Module, EvalError]) -> Thread` | Thread with a module loader |
| `Thread::with_step_budget` | `(String, Int) -> Thread` | Thread that halts after `n` evaluation steps |

The first argument to every constructor is the thread name (used in error messages).
Thread constructors are non-composable: each creates a fresh thread with exactly one
customization. Build a thread with a loader and print callback via `exec_file_with_predeclared`
if both are needed simultaneously, or create the Thread and set both at construction time.

To combine a print callback _and_ a loader, use `Thread::with_loader` — the loader
closure can capture a custom print buffer. See the "Loading modules" example in the README.

#### Accessors

| Method | Returns | Description |
| :--- | :--- | :--- |
| `name()` | `String` | Thread name |
| `max_recursion_depth()` | `Int` | Call depth limit (default 100) |
| `max_steps()` | `Int?` | Step budget; `None` if uncapped |
| `execution_steps()` | `Int` | Steps consumed so far |
| `call_stack_depth()` | `Int` | Current call depth |
| `call_frames()` | `Array[CallFrame]` | Current call stack frames |

#### Cancellation

| Method | Description |
| :--- | :--- |
| `cancel(String)` | Signal the thread to halt; raises `EvalError` at the next step check |
| `uncancel()` | Clear a previous cancel signal |

```moonbit
test {
  let thread = @starlark.Thread::new("main")
  thread.cancel("timeout")
  match @starlark.exec_file(thread, "x.star", "x = 1", @starlark.Options::default()) {
    Err(e) => assert_true(e.msg().contains("timeout"))
    Ok(_) => fail!("expected cancellation")
  }
}
```

---

### `Options`

Feature flags that control Starlark dialect. All flags default to `true` except
`load_binds_globally` (default `false`).

```moonbit
pub struct Options { /* private fields */ }
```

| Accessor | Default | Description |
| :--- | :--- | :--- |
| `allow_set()` | `true` | Enable `set` literals and the `set()` built-in |
| `allow_recursion()` | `true` | Allow recursive function calls |
| `allow_lambda()` | `true` | Enable `lambda` expressions |
| `allow_while()` | `true` | Enable `while` loops |
| `allow_bytes()` | `true` | Enable `bytes` literals (`b"..."`) |
| `allow_float()` | `true` | Enable float literals and float arithmetic |
| `allow_global_reassign()` | `true` | Allow re-assigning module-level names |
| `allow_top_level_control()` | `true` | Allow `if` / `for` / `while` at module scope |
| `load_binds_globally()` | `false` | `load` imports are visible module-wide (legacy compatibility flag) |

```moonbit
test {
  let opts = @starlark.Options::default()
  assert_eq(opts.allow_set(), true)
  assert_eq(opts.load_binds_globally(), false)
}
```

Use `with_load_binds_globally(Bool)` to obtain a modified copy:

```moonbit
test {
  let opts = @starlark.Options::default().with_load_binds_globally(true)
  assert_eq(opts.load_binds_globally(), true)
}
```

---

### `Module`

The result of a successful `exec_file` call. Its globals dict is frozen on return.

```moonbit
pub struct Module { /* private fields */ }
```

| Method | Signature | Description |
| :--- | :--- | :--- |
| `get` | `(String) -> Value?` | Look up a global by name |
| `globals_count` | `() -> Int` | Number of defined globals |
| `is_frozen` | `() -> Bool` | Always `true` after `exec_file` returns |
| `freeze` | `() -> Unit` | Freeze the module manually (rarely needed) |
| `new` | `() -> Module` | Empty unfrozen module |
| `from_map` | `(Map[String, Value]) -> Module` | Construct a module from a map (for testing) |

---

### `Predeclared`

Extra bindings injected before user globals. Scripts can read but not reassign them.

```moonbit
pub struct Predeclared { /* private fields */ }
```

| Constructor / Method | Description |
| :--- | :--- |
| `Predeclared::new()` | Empty predeclared set |
| `Predeclared::from_map(Map[String, Value])` | Construct from a literal map |
| `get(String) -> Value?` | Look up a name |
| `set(String, Value)` | Add or replace a binding |

---

### `Universe`

The predeclared built-in environment shared across all threads.

```moonbit
pub struct Universe { /* private fields */ }
```

| Constructor | Description |
| :--- | :--- |
| `Universe::standard()` | Full Starlark built-in set (`print`, `range`, `len`, …) |
| `Universe::empty()` | No built-ins (useful for sandboxed evaluation) |

---

### `Value`

All Starlark values share this enum type.

```moonbit
pub enum Value {
  None
  Bool(Bool)
  Int(Int64)
  Float(Double)
  String(StarlarkString)
  Bytes(Bytes)
  List(StarlarkList)
  Tuple(Array[Value])
  Dict(StarlarkDict)
  Set(StarlarkSet)
  Range(StarlarkRange)
  Function(StarlarkFunction)
  Builtin(StarlarkBuiltinFunc)
  BoundMethod(StarlarkBoundMethod)
  Module(StarlarkModule)
}
```

Pattern matching is the primary way to inspect a `Value`:

```moonbit
test {
  let thread = @starlark.Thread::new("main")
  match @starlark.exec_file(thread, "s.star", "x = 'hello'", @starlark.Options::default()) {
    Ok(m) =>
      match @starlark.module_get(m, "x") {
        Some(@starlark.Value::String(s)) => assert_eq(s.raw(), "hello")
        _ => fail!("expected string")
      }
    Err(e) => fail!(e.to_string())
  }
}
```

> **Note:** `StarlarkString`, `StarlarkList`, `StarlarkDict`, and related types are defined in
> the internal package. Access them through the `Value` enum constructors or via methods returned
> from interpreter results.

---

### `StarlarkDict`

An insertion-ordered mutable mapping. Used as the environment for `eval_expr`.

```moonbit
pub struct StarlarkDict { /* private fields */ }
```

| Method | Description |
| :--- | :--- |
| `StarlarkDict::new()` | Empty dict |
| `insert(Value, Value) -> Result[Unit, String]` | Insert a key–value pair |
| `get_value(Value) -> Value?` | Look up by key |
| `delete(Value) -> Result[Bool, String]` | Remove a key |
| `clear() -> Result[Unit, String]` | Remove all entries |
| `length() -> Int` | Number of entries |

---

### Error types

All three error types share the pattern of carrying a `Position` (or call stack) and a
human-readable message. `exec_file` wraps `SyntaxError` and `ResolveError` into `EvalError`
before returning, so callers typically only need to handle `EvalError`.

#### `EvalError`

Runtime errors raised during evaluation.

| Method | Returns | Description |
| :--- | :--- | :--- |
| `msg()` | `String` | Error message |
| `to_string()` | `String` | `"<file>:<line>:<col>: <msg>"` |
| `backtrace()` | `String` | Formatted call stack |
| `EvalError::simple(String)` | `EvalError` | Construct with no position (for host code) |
| `EvalError::with_stack(String, CallStack)` | `EvalError` | Construct with a call stack |

#### `SyntaxError`

Lexer or parser errors.

| Method | Returns | Description |
| :--- | :--- | :--- |
| `msg()` | `String` | Error message |
| `pos()` | `Position` | Source position |
| `to_string()` | `String` | `"<file>:<line>:<col>: <msg>"` |

#### `ResolveError`

Name-resolution errors (undefined variables, invalid scoping, etc.).

| Method | Returns | Description |
| :--- | :--- | :--- |
| `msg()` | `String` | Error message |
| `pos()` | `Position` | Source position |
| `to_string()` | `String` | `"<file>:<line>:<col>: <msg>"` |

#### `Position`

A source location: filename, 1-based line, 1-based column. Column 0 means unknown.

| Method | Returns | Description |
| :--- | :--- | :--- |
| `filename()` | `String` | Source file name |
| `line()` | `Int` | 1-based line number |
| `col()` | `Int` | 1-based column (0 = unknown) |
| `is_valid()` | `Bool` | `true` if line > 0 |
| `is_before(Position)` | `Bool` | Positional comparison |
| `to_string()` | `String` | `"<file>:<line>:<col>"` |

---

## `starlark/lib/json` package

Inject `json_module()` as a predeclared binding to make all functions available in Starlark scripts.

```text
import {
  "connect0459/starlark",
  "connect0459/starlark/lib/json",
}
```

### MoonBit-level API

| Function | Signature | Description |
| :--- | :--- | :--- |
| `json_module()` | `() -> Value` | Returns the `json` module value to inject |
| `encode_to_json(Value)` | `-> Result[String, String]` | Encode a Starlark value to a JSON string |
| `decode_from_json(String, Value?)` | `-> Result[Value, String]` | Decode a JSON string; `default` returned on parse error when provided |
| `indent_json(String, String, String)` | `-> Result[String, String]` | Pretty-print JSON with `prefix` and `indent` |

### Starlark-level functions (inside scripts)

| Function | Description |
| :--- | :--- |
| `json.encode(value)` | Serialize to JSON; dict keys sorted; non-ASCII as `\uXXXX` |
| `json.encode_indent(value, prefix=, indent=)` | Serialize with indentation |
| `json.decode(x, default=)` | Parse JSON; returns `default` on error if provided |
| `json.indent(x, prefix=, indent=)` | Pretty-print a JSON string |

Supported Starlark → JSON mappings:

| Starlark | JSON |
| :--- | :--- |
| `None` | `null` |
| `True` / `False` | `true` / `false` |
| `int` | number |
| `float` | number |
| `string` | string |
| `list` / `tuple` / `range` | array |
| `dict` | object (keys must be strings) |

```moonbit
test {
  let thread = @starlark.Thread::new("main")
  let predeclared = @starlark.Predeclared::from_map({ "json": @json.json_module() })
  let src = "payload = json.encode({\"key\": [1, 2, 3]})"
  match @starlark.exec_file_with_predeclared(
    thread, "data.star", src, @starlark.Options::default(), predeclared,
  ) {
    Ok(m) =>
      match @starlark.module_get(m, "payload") {
        Some(@starlark.Value::String(s)) =>
          assert_eq(s.raw(), "{\"key\": [1, 2, 3]}")
        _ => fail!("expected string")
      }
    Err(e) => fail!(e.to_string())
  }
}
```

---

## `starlark/lib/math` package

Math extension providing floating-point functions. Inject `math_module()` as a predeclared
binding to expose functions under the `math` namespace in Starlark scripts.

```text
import {
  "connect0459/starlark",
  "connect0459/starlark/lib/math",
}
```

### MoonBit-level API

| Function | Signature | Description |
| :--- | :--- | :--- |
| `math_module()` | `() -> Value` | Returns the `math` module value to inject |

### Starlark-level constants and functions (inside scripts)

#### Constants

| Name | Value |
| :--- | :--- |
| `math.pi` | `3.141592653589793` |
| `math.e` | `2.718281828459045` |

#### Unary functions

| Function | Description |
| :--- | :--- |
| `math.ceil(x)` | Smallest integer ≥ x |
| `math.floor(x)` | Largest integer ≤ x |
| `math.round(x)` | Round to nearest integer |
| `math.fabs(x)` | Absolute value |
| `math.exp(x)` | `e ** x` |
| `math.sqrt(x)` | Square root |
| `math.log(x)` / `math.log(x, base)` | Natural log or log base `base` |
| `math.acos(x)` | Arc cosine |
| `math.asin(x)` | Arc sine |
| `math.atan(x)` | Arc tangent |
| `math.cos(x)` | Cosine |
| `math.sin(x)` | Sine |
| `math.tan(x)` | Tangent |
| `math.acosh(x)` | Inverse hyperbolic cosine |
| `math.asinh(x)` | Inverse hyperbolic sine |
| `math.atanh(x)` | Inverse hyperbolic tangent |
| `math.cosh(x)` | Hyperbolic cosine |
| `math.sinh(x)` | Hyperbolic sine |
| `math.tanh(x)` | Hyperbolic tangent |
| `math.degrees(x)` | Radians → degrees |
| `math.radians(x)` | Degrees → radians |
| `math.gamma(x)` | Gamma function |

#### Binary functions

| Function | Description |
| :--- | :--- |
| `math.atan2(y, x)` | Arc tangent of y/x |
| `math.copysign(x, y)` | Magnitude of x with sign of y |
| `math.hypot(x, y)` | `sqrt(x**2 + y**2)` |
| `math.mod(x, y)` | Floating-point modulo |
| `math.pow(x, y)` | `x ** y` (float) |
| `math.remainder(x, y)` | IEEE 754 remainder |

```moonbit
test {
  let thread = @starlark.Thread::new("main")
  let predeclared = @starlark.Predeclared::from_map({ "math": @math.math_module() })
  match @starlark.exec_file_with_predeclared(
    thread, "trig.star",
    "approx_pi = math.atan2(0.0, -1.0)",
    @starlark.Options::default(),
    predeclared,
  ) {
    Ok(m) =>
      match @starlark.module_get(m, "approx_pi") {
        Some(@starlark.Value::Float(f)) => assert_true(f > 3.14 && f < 3.15)
        _ => fail!("expected float")
      }
    Err(e) => fail!(e.to_string())
  }
}
```
