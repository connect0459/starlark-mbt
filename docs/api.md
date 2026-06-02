# API Reference

## Packages

| Package | Import alias | Description |
| :--- | :--- | :--- |
| `connect0459/starlark/eval` | `@eval` | Entry functions (`exec_file`, `eval_expr`, `call`, `source_program`, `parse_file`, …) plus `Thread`, `Module`, `Options`, `Program`, `Predeclared`, `Universe`, `DebugFrame` |
| `connect0459/starlark/value` | `@value` | `Value`, `StringDict`, `StarlarkDict`, `StarlarkList`, `StarlarkString`, `CustomValue`, `StarlarkBuiltinFunc`, `StarlarkIterator`; value helpers (`equal`, `len_of`, `as_float`, …) |
| `connect0459/starlark/errors` | `@errors` | `EvalError`, `SyntaxError`, `ResolveError`, `Position`, `Span`, `Halt`, `Binding`, `CallFrame`, `CallStack` |
| `connect0459/starlark/syntax` | `@syntax` | `File`, `Expr` — AST types returned by `parse_file`/`parse_expr` |
| `connect0459/starlark/unpack` | `@unpack` | `unpack_args`, `unpack_positional`, `unpack_args_with` for host-defined built-ins |
| `connect0459/starlark/lib/json` | `@json` | JSON encode / decode extension |
| `connect0459/starlark/lib/math` | `@math` | Math functions extension |
| `connect0459/starlark/lib/struct` | `@struct` | `struct`, `module`, and `gensym` extension (starlarkstruct) |
| `connect0459/starlark/lib/time` | `@time` | Time and duration extension (starlarktime) |

All `src/internal/*` packages are implementation details and are not importable by consumers.
The packages `eval`, `value`, `errors`, `syntax`, and `unpack` are public sub-packages; import
them directly. There is **no** top-level `connect0459/starlark` facade — entry functions live in
`@eval`, value-inspection helpers in `@value`, and argument unpacking in `@unpack`.

---

## `eval` package

The main entry point. Import `connect0459/starlark/eval` to parse, resolve, and execute
Starlark, and for the `Thread`/`Module`/`Options`/`Program` types.

### Top-level functions

#### Execution

| Function | Signature | Description |
| :--- | :--- | :--- |
| `exec_file` | `(@eval.Thread, String, String, @eval.Options) -> Result[@eval.Module, @errors.EvalError]` | Execute a Starlark source file |
| `exec_file_with_predeclared` | `(@eval.Thread, String, String, @eval.Options, @eval.Predeclared) -> Result[@eval.Module, @errors.EvalError]` | Execute with extra host bindings visible to the script |
| `exec_file_with_universe` | `(@eval.Thread, String, String, @eval.Options, @eval.Universe) -> Result[@eval.Module, @errors.EvalError]` | Execute with a custom built-in universe instead of the standard one |
| `exec_repl_chunk` | `(@eval.Thread, String, String, @value.StringDict, @eval.Options) -> Result[Unit, @errors.EvalError]` | Execute one REPL chunk; updates the persistent `globals` dict in place |
| `eval_expr` | `(@eval.Thread, String, String, @value.StringDict) -> Result[@value.Value, @errors.EvalError]` | Evaluate a single Starlark expression with default options |
| `eval_expr_with_opts` | `(@eval.Thread, String, String, @eval.Options, @value.StringDict) -> Result[@value.Value, @errors.EvalError]` | Like `eval_expr` but with explicit options |
| `eval_parsed_expr` | `(@eval.Thread, @syntax.Expr, @eval.Options, @value.StringDict) -> Result[@value.Value, @errors.EvalError]` | Evaluate a pre-parsed expression node |
| `call` | `(@eval.Thread, @value.Value, Array[@value.Value], Array[(String, @value.Value)]) -> Result[@value.Value, @errors.EvalError]` | Call any Starlark callable from host code |

#### Parsing and compilation

| Function | Signature | Description |
| :--- | :--- | :--- |
| `parse_file` | `(String, String) -> Result[@syntax.File, @errors.EvalError]` | Parse Starlark source to an AST |
| `parse_expr` | `(String, String) -> Result[@syntax.Expr, @errors.EvalError]` | Parse a single Starlark expression to an AST node |
| `source_program` | `(String, String, @eval.Options, (String)->Bool) -> Result[@eval.Program, @errors.EvalError]` | Parse and resolve without executing; returns a reusable `Program` |
| `source_program_with_file` | `(String, String, @eval.Options, (String)->Bool) -> Result[(@syntax.File, @eval.Program), @errors.EvalError]` | Like `source_program` but also returns the parsed AST |
| `file_program` | `(@syntax.File, @eval.Options, (String)->Bool) -> Result[@eval.Program, @errors.EvalError]` | Resolve an already-parsed `@syntax.File` into a `Program` |
| `compiled_program` | `(Bytes) -> Result[@eval.Program, @errors.EvalError]` | Reload a `Program` from bytes produced by `Program::write`, skipping parse + resolve |

`Program::write() -> Bytes` serializes a resolved program so it can be persisted
and reloaded with `compiled_program`. The format holds the resolved AST plus the
program's options (a versioned, magic-tagged binary); it is specific to this
tree-walking implementation and **not** byte-compatible with starlark-go's
bytecode `Program.Write`.

#### Argument unpacking — `@unpack` package (for host-defined built-ins)

These live in `connect0459/starlark/unpack`; call them as `@unpack.unpack_args` etc.

| Function | Signature | Description |
| :--- | :--- | :--- |
| `unpack_args` | `(String, Array[Value], Array[(String, Value)], Array[String]) -> Result[Array[Value?], String]` | Bind positional + keyword args to a name spec (`"name"`, `"name?"`, `"name??"`) |
| `unpack_positional` | `(String, Array[Value], Array[(String, Value)], Int, Int) -> Result[Array[Value?], String]` | Bind positional-only args, requiring between `min` and `max` |
| `unpack_args_with` | `(String, Array[Value], Array[(String, Value)], Array[(String, &@value.Unpacker)]) -> Result[Unit, String]` | Like `unpack_args` but dispatches each matched value to a custom `@value.Unpacker` target |

Implement the `@value.Unpacker` trait (`unpack(Self, Value) -> Result[Unit, String]`)
on a host type to define custom per-argument validation/coercion, mirroring
starlark-go's `Unpacker` interface.

#### Value inspection — `@value` package

These live in `connect0459/starlark/value`; call them as `@value.equal` etc. They return
`String` errors (value-level operations carry no source position).

| Function | Signature | Description |
| :--- | :--- | :--- |
| `equal` | `(@value.Value, @value.Value) -> Result[Bool, String]` | Structural equality (depth-capped by `compare_limit`) |
| `len_of` | `(@value.Value) -> Int` | Sequence length; returns `-1` for non-sequences |
| `iterate` | `(@value.Value) -> Result[@value.StarlarkIterator, String]` | Obtain an iterator over a Starlark iterable |
| `number_to_int` | `(@value.Value) -> Int64?` | Convert `Int` or `Float` to `Int64`; `None` otherwise |
| `as_float` | `(@value.Value) -> (Double, Bool)` | Extract `Float` or convert `Int` to `Double`; second element is `true` on success |
| `as_string` | `(@value.Value) -> (String, Bool)` | Extract raw string from `String` value; second element is `true` on success |

#### Depth-limited comparison — `@value` package

`compare_limit`/`equal_depth`/`compare_depth` also live in `@value`. They guard against
infinite recursion on cyclic data structures.

| Symbol | Signature | Description |
| :--- | :--- | :--- |
| `compare_limit` | `Int` | Default recursion depth for comparisons (value: `10`) |
| `equal_depth` | `(@value.Value, @value.Value, Int) -> Result[Bool, String]` | Equality with explicit depth limit |
| `compare_depth` | `(String, @value.Value, @value.Value, Int) -> Result[Bool, String]` | Comparison operator (`"=="`, `"<"`, …) with explicit depth limit |

#### Operator dispatch — `@eval` package

| Function | Signature | Description |
| :--- | :--- | :--- |
| `binary` | `(String, @value.Value, @value.Value) -> Result[@value.Value, @errors.EvalError]` | Apply a binary operator by name (`"+"`, `"-"`, `"*"`, etc.) |
| `unary` | `(String, @value.Value) -> Result[@value.Value, @errors.EvalError]` | Apply a unary operator by name (`"-"`, `"~"`, `"not"`) |
| `compare` | `(String, @value.Value, @value.Value) -> Result[Bool, @errors.EvalError]` | Apply a comparison operator by name (`"=="`, `"<"`, etc.) |

#### `exec_file`

Parses, resolves, and evaluates `src` as a complete Starlark file. `filename` is used only
in error messages. Returns the frozen `Module` containing all top-level globals on success.

```moonbit
let thread = @eval.Thread::new("main")
let _ = @eval.exec_file(
  thread, "build.star",
  "greeting = 'hello ' + 'world'",
  @eval.Options::default(),
)
```

#### `eval_expr`

Evaluates a single expression `src` in the given environment `env` (a `@value.StringDict`,
the string-keyed binding map). Unlike `exec_file`, this does not run statements and does not
produce a `Module`; it returns the expression value. `env` may be empty
(`@value.StringDict::new()`) or pre-populated with bindings.

```moonbit
let thread = @eval.Thread::new("expr")
let env = @value.StringDict::new()
let _ = @eval.eval_expr(thread, "<expr>", "len([1, 2, 3])", env)
```

#### `exec_file_with_predeclared`

Like `exec_file` but injects `predeclared` bindings before execution. These bindings are
visible to the script as predeclared names (higher precedence than universe built-ins,
lower than locals and globals).

```moonbit
let thread = @eval.Thread::new("main")
let predeclared = @eval.Predeclared::from_map({
  "MY_FLAG": @value.Value::Bool(true),
})
let _ = @eval.exec_file_with_predeclared(
  thread, "script.star",
  "enabled = MY_FLAG",
  @eval.Options::default(),
  predeclared,
)
```

---

### `@eval.Thread`

Holds execution context: print callback, load callback, call stack, and step budget.

```moonbit
pub struct Thread { /* private fields */ }  // in "connect0459/starlark/eval"
```

#### Constructors

| Constructor | Signature | Description |
| :--- | :--- | :--- |
| `Thread::new` | `(String) -> Thread` | Thread with default print (stdout) and no loader |
| `Thread::with_print` | `(String, (Thread, String) -> Unit) -> Thread` | Thread with a custom print callback |
| `Thread::with_loader` | `(String, (Thread, String) -> Result[@eval.Module, @errors.EvalError]) -> Thread` | Thread with a module loader |
| `Thread::with_step_budget` | `(String, Int) -> Thread` | Thread that halts after `n` evaluation steps |

The first argument to every constructor is the thread name (used in error messages). Each
`with_*` constructor applies a single customization, but they are **composable** via the
setters: start from `Thread::new(name)` and call `set_print`, `set_loader`, `set_max_steps`,
and `set_on_max_steps` in any combination. For example, to combine a print callback and a
loader, `Thread::new(name)` then `.set_print(...)` and `.set_loader(...)`.

#### Accessors

| Method | Returns | Description |
| :--- | :--- | :--- |
| `name()` | `String` | Thread name |
| `max_recursion_depth()` | `Int` | Call depth limit (default 100) |
| `max_steps()` | `Int?` | Step budget; `None` if uncapped |
| `execution_steps()` | `Int` | Steps consumed so far |
| `call_stack_depth()` | `Int` | Current call depth |
| `call_frames()` | `Array[CallFrame]` | Current call stack frames |
| `call_stack()` | `CallStack` | Snapshot of the current call stack |
| `call_frame(Int)` | `CallFrame?` | Frame at depth `n` (0 = innermost); `None` if out of range |
| `debug_frame(Int)` | `DebugFrame?` | Snapshot of an active call frame (0 = innermost Starlark function); `None` if out of range |

#### Customization (mutators)

A `Thread` built with `Thread::new` can be customized after construction; these compose freely.

| Method | Description |
| :--- | :--- |
| `set_print((Thread, String) -> Unit)` | Set the print callback |
| `set_loader((Thread, String) -> Result[Module, EvalError])` | Set the module loader |

#### Step budget control

| Method | Description |
| :--- | :--- |
| `set_max_steps(Int)` | Set the step budget (does not reset the accumulated count) |
| `set_on_max_steps((Thread) -> Unit)` | Set a callback invoked when the step budget is reached instead of halting |
| `reset_steps()` | Reset the accumulated step counter to zero |

#### Thread-local storage

Embedders can store per-thread context (request IDs, counters, etc.) without subclassing.

| Method | Description |
| :--- | :--- |
| `set_local(String, Value)` | Store a value under a string key |
| `get_local(String) -> Value?` | Retrieve a stored value; `None` if not set |

#### Cancellation

| Method | Description |
| :--- | :--- |
| `cancel(String)` | Signal the thread to halt; raises `EvalError` at the next step check |
| `uncancel()` | Clear a previous cancel signal |

```moonbit
test {
  let thread = @eval.Thread::new("main")
  thread.cancel("timeout")
  match @eval.exec_file(thread, "x.star", "x = 1", @eval.Options::default()) {
    Err(e) => assert_true(e.msg().contains("timeout"))
    Ok(_) => fail!("expected cancellation")
  }
}
```

---

### `@eval.Options`

Feature flags that control Starlark dialect. All flags default to `true` except
`load_binds_globally` (default `false`).

```moonbit
pub struct Options { /* private fields */ }  // in "connect0459/starlark/eval"
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
  let opts = @eval.Options::default()
  assert_eq(opts.allow_set(), true)
  assert_eq(opts.load_binds_globally(), false)
}
```

Use `with_load_binds_globally(Bool)` to obtain a modified copy:

```moonbit
test {
  let opts = @eval.Options::default().with_load_binds_globally(true)
  assert_eq(opts.load_binds_globally(), true)
}
```

---

### `@eval.Module`

The result of a successful `exec_file` call. Its globals dict is frozen on return.

```moonbit
pub struct Module { /* private fields */ }  // in "connect0459/starlark/eval"
```

| Method | Signature | Description |
| :--- | :--- | :--- |
| `get` | `(String) -> Value?` | Look up a global by name |
| `globals_count` | `() -> Int` | Number of defined globals |
| `is_frozen` | `() -> Bool` | Always `true` after `exec_file` returns |
| `freeze` | `() -> Unit` | Freeze the module manually (rarely needed) |
| `globals_map` | `() -> Map[String, Value]` | Copy of all global bindings as a MoonBit map |
| `predeclared_map` | `() -> Map[String, Value]` | Copy of predeclared bindings injected before execution |
| `new` | `() -> Module` | Empty unfrozen module |
| `from_map` | `(Map[String, Value]) -> Module` | Construct a module from a map (for testing) |

---

### `@eval.Predeclared`

Extra bindings injected before user globals. Scripts can read but not reassign them.

```moonbit
pub struct Predeclared { /* private fields */ }  // in "connect0459/starlark/eval"
```

| Constructor / Method | Description |
| :--- | :--- |
| `Predeclared::new()` | Empty predeclared set |
| `Predeclared::from_map(Map[String, Value])` | Construct from a literal map |
| `get(String) -> Value?` | Look up a name |
| `set(String, Value)` | Add or replace a binding |

---

### `@eval.Universe`

The predeclared built-in environment shared across all threads.

```moonbit
pub struct Universe { /* private fields */ }  // in "connect0459/starlark/eval"
```

| Constructor | Description |
| :--- | :--- |
| `Universe::standard()` | Full Starlark built-in set (`print`, `range`, `len`, …) |
| `Universe::new()` | No built-ins (useful for sandboxed evaluation) |
| `Universe::from_map(m)` | Wrap an existing `Map[String, Value]` of bindings |

---

### `@value.Value`

All Starlark values share this enum type. Defined in `"connect0459/starlark/value"`.

```moonbit
pub enum Value {
  None
  Bool(Bool)
  Int(BigInt)               // arbitrary-precision integer
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
  StringElems(StarlarkStringElems)           // returned by str.elems()
  StringCodepoints(StarlarkStringCodepoints) // returned by str.codepoints()
  BytesElems(StarlarkBytesElems)             // returned by bytes.elems()
  ExtVal(CustomValue)                        // embedder-defined custom type
}
```

The three iterator variants (`StringElems`, `StringCodepoints`, `BytesElems`) are lazy iterables
returned by the respective string/bytes methods. They report their own `type()` strings
(`"string.elems"`, `"string.codepoints"`, `"bytes.elems"`) and support `len()`.

> **Note:** `Int` holds a `BigInt` (arbitrary precision). Use the `N` suffix for integer
> literals in patterns: `@value.Value::Int(42N)`.

Pattern matching is the primary way to inspect a `Value`:

```moonbit
test {
  let thread = @eval.Thread::new("main")
  match @eval.exec_file(thread, "s.star", "x = 'hello'", @eval.Options::default()) {
    Ok(m) =>
      match m.get("x") {
        Some(@value.Value::String(s)) => assert_eq(s.raw(), "hello")
        _ => fail!("expected string")
      }
    Err(e) => fail!(e.to_string())
  }
}
```

---

### `@value.StarlarkDict`

The insertion-ordered mutable mapping backing Starlark `dict` values. Keys are any hashable
`Value`. (For host-side string-keyed environments — e.g. the `eval_expr` env — use
`@value.StringDict` instead.)

```moonbit
pub struct StarlarkDict { /* private fields */ }  // in "connect0459/starlark/value"
```

| Method | Description |
| :--- | :--- |
| `StarlarkDict::new()` | Empty dict |
| `set(Value, Value) -> Result[Unit, String]` | Insert or replace a key–value pair |
| `get(Value) -> Result[Value?, String]` | Look up by key (`Err` if the key is unhashable) |
| `delete(Value) -> Result[Bool, String]` | Remove a key; returns whether it was present |
| `clear() -> Result[Unit, String]` | Remove all entries |
| `length() -> Int` | Number of entries |
| `keys() -> Array[Value]` | Keys in insertion order |
| `each((Value, Value) -> Unit)` | Iterate all key–value pairs |
| `iter() -> Iter[Value]` | Lazy iterator over keys |
| `to_entries() -> Iter[(Value, Value)]` | Lazy iterator over key–value pairs |
| `popitem() -> Result[(Value, Value)?, String]` | Remove and return the last inserted pair |
| `is_frozen() -> Bool` | Whether the dict is frozen |
| `freeze() -> Unit` | Freeze the dict (and, transitively, its values) |

---

### `@value.StringDict`

A `Map[String, Value]` wrapper used for host-side string-keyed dictionaries, and the
environment type accepted by `eval_expr` and the persistent `globals` of
`exec_repl_chunk`. Analogous to `starlark.StringDict` in starlark-go.

```moonbit
pub struct StringDict { /* private fields */ }  // in "connect0459/starlark/value"
```

| Method | Description |
| :--- | :--- |
| `StringDict::new()` | Empty map |
| `StringDict::from_map(Map[String, Value])` | Wrap an existing map |
| `set(String, Value)` | Add or replace a binding |
| `get(String) -> Value?` | Look up by key |
| `has(String) -> Bool` | Test for key presence |
| `delete(String) -> Bool` | Remove a binding; returns whether it was present |
| `keys() -> Array[String]` | Sorted list of keys |
| `each((String, Value) -> Unit)` | Iterate all key-value pairs |
| `values() -> Array[Value]` | All contained values |
| `freeze()` | Transitively freeze all contained values |

---

### `@value.StarlarkBuiltinFunc`

A host-provided callable injected into the Starlark environment.

```moonbit
pub struct StarlarkBuiltinFunc { /* private fields */ }  // in "connect0459/starlark/value"
```

| Method | Description |
| :--- | :--- |
| `StarlarkBuiltinFunc::dispatch(String)` | Create a named built-in with no body (stub for forward references) |
| `name() -> String` | Built-in function name |
| `receiver() -> Value?` | Bound receiver value, if any |
| `bind_receiver(Value) -> StarlarkBuiltinFunc` | Return a copy bound to the given receiver |

---

### `@syntax.File` and `@syntax.Expr`

Parsed AST types from `"connect0459/starlark/syntax"`. Returned by `parse_file` and
`parse_expr`; consumed by `file_program` and `eval_parsed_expr`.

```moonbit
pub struct File { /* private fields */ }  // in "connect0459/starlark/syntax"
pub enum Expr { /* ... */ }               // in "connect0459/starlark/syntax"
```

---

### `@eval.Program`

A parsed-and-resolved Starlark program that can be executed multiple times without
re-parsing. Unlike `exec_file`, `Program::init` does **not** freeze the returned module.

```moonbit
pub struct Program { /* private fields */ }  // in "connect0459/starlark/eval"
```

| Method | Signature | Description |
| :--- | :--- | :--- |
| `filename()` | `() -> String` | Source file name used during compilation |
| `num_loads()` | `() -> Int` | Number of `load` statements in the file |
| `load(Int)` | `(Int) -> (String, @errors.Position)` | Path and position of the i-th `load` statement |
| `options()` | `() -> @eval.Options` | The file-level dialect options the program was resolved with |
| `init(@eval.Thread, @eval.Predeclared)` | `-> Result[@eval.Module, @errors.EvalError]` | Execute the program and return an **unfrozen** module |
| `write()` | `() -> Bytes` | Serialize the resolved program; reload with `compiled_program` |

```moonbit
test {
  let prog_result = @eval.source_program(
    "lib.star", "def square(n): return n * n",
    @eval.Options::default(),
    fn(_) { false },
  )
  match prog_result {
    Ok(prog) => {
      let thread = @eval.Thread::new("main")
      match prog.init(thread, @eval.Predeclared::new()) {
        Ok(m) => assert_true(m.get("square") is Some(@value.Value::Function(_)))
        Err(e) => fail!(e.to_string())
      }
    }
    Err(e) => fail!(e.to_string())
  }
}
```

---

### `@eval.DebugFrame`

A read-only snapshot of an active Starlark call frame. Obtain via `Thread.debug_frame(depth)`
(depth 0 = innermost Starlark function).

```moonbit
pub struct DebugFrame { /* private fields */ }  // in "connect0459/starlark/eval"
```

| Method | Returns | Description |
| :--- | :--- | :--- |
| `callable()` | `@value.Value` | The `Function` or `Builtin` value executing in this frame |
| `num_locals()` | `Int` | Total number of local variables (parameters + body locals) |
| `frame_local(Int)` | `(@errors.Binding, @value.Value?)` | Binding descriptor and current value of the i-th local; `None` if not yet assigned |
| `local_by_name(String)` | `@value.Value?` | Current value of the named local; `None` if absent or unassigned |
| `position()` | `@errors.Position` | Current execution position within the frame |

---

### `@errors.Binding`

A local variable name together with its definition position. Used by the debugger API.

```moonbit
pub struct Binding { /* private fields */ }  // in "connect0459/starlark/errors"
```

| Method | Returns | Description |
| :--- | :--- | :--- |
| `name()` | `String` | Variable name |
| `pos()` | `@errors.Position` | Declaration position in source |

---

### `@value.CustomValue`

Embedder-defined custom type that participates in the Starlark value system as
`@value.Value::ExtVal(cv)`. Defined in `"connect0459/starlark/value"`.
Construct with `CustomValue::new(...)` and attach optional protocol implementations
via fluent `.with_*` methods.

See the `src/struct/` and `src/time/` extensions for idiomatic usage examples.

---

### `@value.StarlarkFunction`

A user-defined (Starlark-source) function. Obtain via `@value.Value::Function(f)` pattern matching.

```moonbit
pub struct StarlarkFunction { /* private fields */ }  // in "connect0459/starlark/value"
```

#### Identity

| Method | Returns | Description |
| :--- | :--- | :--- |
| `name()` | `String` | Function name; `"<lambda>"` for lambda expressions |
| `position()` | `Position` | Source position of the `def` keyword |
| `doc()` | `String` | Docstring (first string literal in body); `""` if absent |

#### Parameters

| Method | Returns | Description |
| :--- | :--- | :--- |
| `num_params()` | `Int` | Total parameter count |
| `num_kwonly_params()` | `Int` | Number of keyword-only parameters (after `*args`) |
| `has_varargs()` | `Bool` | Whether the function has a `*args` parameter |
| `has_kwargs()` | `Bool` | Whether the function has a `**kwargs` parameter |
| `param(Int)` | `(String, Position)` | Name and position of the i-th parameter |
| `param_default(Int)` | `Value?` | Default value of the i-th parameter; `None` if required |

#### Closure / module

| Method | Returns | Description |
| :--- | :--- | :--- |
| `num_free_vars()` | `Int` | Number of captured (closure) variables |
| `free_var(Int)` | `(String, @value.Value)?` | Name and current value of the i-th free variable |
| `globals()` | `Map[String, @value.Value]` | Module globals visible when the function was defined |
| `defining_module()` | `StarlarkModule?` | Module that defined this function; `None` for functions not created via `exec_file` |

```moonbit
test {
  let thread = @eval.Thread::new("main")
  match @eval.exec_file(
    thread, "lib.star",
    "CONST = 99\ndef greet(name):\n  \"\"\"Say hello.\"\"\"\n  return 'hi ' + name",
    @eval.Options::default(),
  ) {
    Ok(m) =>
      match m.get("greet") {
        Some(@value.Value::Function(f)) => {
          assert_eq(f.name(), "greet")
          assert_eq(f.num_params(), 1)
          assert_eq(f.doc(), "Say hello.")
          assert_true(f.globals().contains("CONST"))
          match f.defining_module() {
            Some(mod_ref) => assert_eq(mod_ref.name(), "lib.star")
            None => fail!("expected module")
          }
        }
        _ => fail!("expected function")
      }
    Err(e) => fail!(e.to_string())
  }
}
```

---

### `@errors.CallStack` and `@errors.CallFrame`

A snapshot of the call stack at a point in time. Both defined in `"connect0459/starlark/errors"`.

```moonbit
pub struct CallStack { /* private fields */ }
pub struct CallFrame { /* private fields */ }
```

#### `CallStack`

| Method | Returns | Description |
| :--- | :--- | :--- |
| `length()` | `Int` | Number of frames |
| `at(Int)` | `@errors.CallFrame?` | Frame at index (0 = outermost) |
| `pop()` | `@errors.CallFrame?` | Remove and return the innermost frame |
| `to_string()` | `String` | Human-readable backtrace |

#### `CallFrame`

| Method | Returns | Description |
| :--- | :--- | :--- |
| `name()` | `String` | Function name at this frame |
| `pos()` | `@errors.Position` | Call-site position |

```moonbit
test {
  let thread = @eval.Thread::new("main")
  let _ = @eval.exec_file(
    thread, "x.star",
    "def f(): pass\nf()",
    @eval.Options::default(),
  )
  let stack = thread.call_stack()
  assert_eq(stack.length(), 0) // stack is empty after execution
}
```

---

### Error types

All three error types share the pattern of carrying a `Position` (or call stack) and a
human-readable message. `exec_file` wraps `SyntaxError` and `ResolveError` into `EvalError`
before returning, so callers typically only need to handle `EvalError`. All are defined in
`"connect0459/starlark/errors"`.

#### `@errors.EvalError`

Runtime errors raised during evaluation.

| Method | Returns | Description |
| :--- | :--- | :--- |
| `msg()` | `String` | Error message |
| `to_string()` | `String` | `"<file>:<line>:<col>: <msg>"` |
| `backtrace()` | `String` | Formatted call stack |
| `EvalError::simple(String)` | `@errors.EvalError` | Construct with no position (for host code) |
| `EvalError::with_stack(String, @errors.CallStack)` | `@errors.EvalError` | Construct with a call stack |

#### `@errors.SyntaxError`

Lexer or parser errors.

| Method | Returns | Description |
| :--- | :--- | :--- |
| `msg()` | `String` | Error message |
| `pos()` | `@errors.Position` | Source position |
| `to_string()` | `String` | `"<file>:<line>:<col>: <msg>"` |

#### `@errors.ResolveError`

Name-resolution errors (undefined variables, invalid scoping, etc.).

| Method | Returns | Description |
| :--- | :--- | :--- |
| `msg()` | `String` | Error message |
| `pos()` | `@errors.Position` | Source position |
| `to_string()` | `String` | `"<file>:<line>:<col>: <msg>"` |

#### `@errors.Position`

A source location: filename, 1-based line, 1-based column. Column 0 means unknown.

| Method | Returns | Description |
| :--- | :--- | :--- |
| `filename()` | `String` | Source file name |
| `line()` | `Int` | 1-based line number |
| `col()` | `Int` | 1-based column (0 = unknown) |
| `is_valid()` | `Bool` | `true` if line > 0 |
| `is_before(@errors.Position)` | `Bool` | Positional comparison |
| `to_string()` | `String` | `"<file>:<line>:<col>"` |

#### `@errors.Span`

A start–end pair of `Position`s for ranged diagnostics.

| Method | Returns | Description |
| :--- | :--- | :--- |
| `Span::new(Position, Position)` | `Span` | Construct from start and end positions |
| `start()` | `Position` | Start position |
| `end_pos()` | `Position` | End position |
| `to_string()` | `String` | `"<start>-<end>"` |

#### `@errors.Halt`

A cancellation signal, distinct from `EvalError`, used to unwind execution when a thread is
cancelled or its step budget is exhausted.

| Method | Returns | Description |
| :--- | :--- | :--- |
| `Halt::new(String)` | `Halt` | Construct with a reason |
| `reason()` | `String` | Why execution was halted |

---

## `starlark/lib/json` package

Inject `json_module()` as a predeclared binding to make all functions available in Starlark scripts.

```text
import {
  "connect0459/starlark/eval",
  "connect0459/starlark/value",
  "connect0459/starlark/lib/json",
}
```

### MoonBit-level API

| Function | Signature | Description |
| :--- | :--- | :--- |
| `json_module()` | `() -> @value.Value` | Returns the `json` module value to inject |
| `encode_to_json(@value.Value)` | `-> Result[String, String]` | Encode a Starlark value to a JSON string |
| `decode_from_json(String, @value.Value?)` | `-> Result[@value.Value, String]` | Decode a JSON string; `default` returned on parse error when provided |
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
  let thread = @eval.Thread::new("main")
  let predeclared = @eval.Predeclared::from_map({ "json": @json.json_module() })
  let src = "payload = json.encode({\"key\": [1, 2, 3]})"
  match @eval.exec_file_with_predeclared(
    thread, "data.star", src, @eval.Options::default(), predeclared,
  ) {
    Ok(m) =>
      match m.get("payload") {
        Some(@value.Value::String(s)) =>
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
  "connect0459/starlark/eval",
  "connect0459/starlark/value",
  "connect0459/starlark/lib/math",
}
```

### MoonBit-level API

| Function | Signature | Description |
| :--- | :--- | :--- |
| `math_module()` | `() -> @value.Value` | Returns the `math` module value to inject |

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
  let thread = @eval.Thread::new("main")
  let predeclared = @eval.Predeclared::from_map({ "math": @math.math_module() })
  match @eval.exec_file_with_predeclared(
    thread, "trig.star",
    "approx_pi = math.atan2(0.0, -1.0)",
    @eval.Options::default(),
    predeclared,
  ) {
    Ok(m) =>
      match m.get("approx_pi") {
        Some(@value.Value::Float(f)) => assert_true(f > 3.14 && f < 3.15)
        _ => fail!("expected float")
      }
    Err(e) => fail!(e.to_string())
  }
}
```

---

## `starlark/lib/struct` package

Provides `struct`, `module`, and `gensym` as Starlark extensions (analogous to
`starlark-go/lib/starlarkstruct`). Import and inject the callables you need as
predeclared bindings.

```text
import {
  "connect0459/starlark/eval",
  "connect0459/starlark/value",
  "connect0459/starlark/lib/struct",
}
```

### MoonBit-level API

| Symbol | Signature | Description |
| :--- | :--- | :--- |
| `struct_builtin()` | `() -> @value.Value` | Returns the `struct(…)` Starlark callable |
| `module_builtin()` | `() -> @value.Value` | Returns the `module(name, …)` Starlark callable |
| `gensym_builtin()` | `() -> @value.Value` | Returns the `gensym(name=…)` Starlark callable |
| `make_struct(ctor, entries)` | `(@value.Value, Array[(String, @value.Value)]) -> @value.Value` | Construct a struct value directly from MoonBit code |
| `make_module(name, members)` | `(String, Array[(String, @value.Value)]) -> @value.Value` | Construct a module value directly from MoonBit code |
| `default_ctor` | `@value.Value` | The default constructor string `"struct"` |

### Starlark-level usage (inside scripts)

After injecting `struct_builtin()` as `"struct"` in predeclared:

| Expression | Description |
| :--- | :--- |
| `struct(x=1, y=2)` | Create a struct with fields `x` and `y` |
| `s.x` | Attribute access |
| `s + struct(z=3)` | Merge two structs with the same constructor |
| `module("mymod", f=fn)` | Create a module value (with `module_builtin`) |
| `gensym(name="tag")` | Create a unique symbol callable (with `gensym_builtin`) |

```moonbit
test {
  let predeclared = @eval.Predeclared::from_map({
    "struct": @struct.struct_builtin(),
    "module": @struct.module_builtin(),
  })
  let thread = @eval.Thread::new("main")
  let src = "p = struct(x=1, y=2)\nm = module('geo', dist=p)"
  match @eval.exec_file_with_predeclared(
    thread, "s.star", src, @eval.Options::default(), predeclared,
  ) {
    Ok(m) => {
      assert_true(m.get("p") is Some(@value.Value::ExtVal(_)))
      assert_true(m.get("m") is Some(@value.Value::ExtVal(_)))
    }
    Err(e) => fail!(e.to_string())
  }
}
```

---

## `starlark/lib/time` package

Time and duration types analogous to `starlark-go/lib/starlarktime`. Inject
`time_module()` as a predeclared binding to expose the `time` namespace.

```text
import {
  "connect0459/starlark/eval",
  "connect0459/starlark/value",
  "connect0459/starlark/lib/time",
}
```

### MoonBit-level API

| Symbol | Signature | Description |
| :--- | :--- | :--- |
| `time_module()` | `() -> @value.Value` | Returns the `time` module value to inject |
| `time_value(sec, nsec)` | `(Int64, Int) -> @value.Value` | Create a `time.time` value from Unix seconds + nanoseconds |
| `now_override_key` | `String` | Thread-local key for overriding `time.now()` in tests |
| `get_unix_time_now()` | `() -> (Int64, Int)` | Read the real system clock (seconds, nanoseconds) |

### Starlark-level API (inside scripts)

#### Module-level functions and constants

| Name | Description |
| :--- | :--- |
| `time.now()` | Current time as `time.time`; overridable via `now_override_key` |
| `time.from_timestamp(sec, nsec=0)` | Construct a `time.time` from Unix timestamp |
| `time.parse_time(x, format=…, location=…)` | Parse an RFC 3339 (or Go layout) string |
| `time.parse_duration(x)` | Parse a duration string (`"1h30m"`, `"500ms"`, etc.) |
| `time.time(year=, month=, …, location=)` | Construct a `time.time` from date/time components |
| `time.is_valid_timezone(tz)` | Test whether a timezone string is supported |
| `time.nanosecond` … `time.hour` | Duration constants |

#### `time.time` attributes

| Attribute | Type | Description |
| :--- | :--- | :--- |
| `t.unix` | `int` | Unix timestamp in whole seconds |
| `t.unix_nano` | `int` | Unix timestamp in nanoseconds |
| `t.year` / `.month` / `.day` | `int` | Calendar fields in the time's timezone |
| `t.hour` / `.minute` / `.second` / `.nanosecond` | `int` | Time-of-day fields |
| `t.in_location(tz)` | `time.time` | Re-express the time in the given timezone |
| `t.format(layout)` | `string` | Format using a Go reference-time layout string |

#### `time.duration` attributes and arithmetic

| Expression | Type | Description |
| :--- | :--- | :--- |
| `d.hours` / `.minutes` / `.seconds` | `float` | Duration as fractional units |
| `d.milliseconds` / `.microseconds` / `.nanoseconds` | `int` | Duration in integer units |
| `d1 + d2` | `time.duration` | Add durations |
| `d - d2` | `time.duration` | Subtract durations |
| `d * n` | `time.duration` | Scale by integer |
| `d / n` | `time.duration` | Divide by integer or float |
| `d // d2` | `int` | Integer floor-division of two durations |

```moonbit
test {
  let predeclared = @eval.Predeclared::from_map({ "time": @time.time_module() })
  let thread = @eval.Thread::new("main")
  // Fix the clock so the test is deterministic.
  thread.set_local(@time.now_override_key, @time.time_value(1_000_000L, 0))
  let src =
    #|t = time.now()
    #|stamp = t.unix
    #|d = time.parse_duration("1h30m")
    #|total_ns = d.nanoseconds
  match @eval.exec_file_with_predeclared(
    thread, "t.star", src, @eval.Options::default(), predeclared,
  ) {
    Ok(m) => {
      assert_true(m.get("stamp") is Some(@value.Value::Int(1_000_000N)))
      // 1.5 hours = 5_400_000_000_000 nanoseconds
      assert_true(
        m.get("total_ns") is Some(@value.Value::Int(5_400_000_000_000N)),
      )
    }
    Err(e) => fail!(e.to_string())
  }
}
```
