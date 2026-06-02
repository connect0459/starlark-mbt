# API Reference

## Packages

| Package | Import alias | Description |
| :--- | :--- | :--- |
| `connect0459/starlark/eval` | `@eval` | Entry functions (`exec_file`, `eval_expr`, `call`, `source_program`, `parse_file`, …) plus `Thread`, `Module`, `Options`, `Program`, `Predeclared`, `Universe`, `DebugFrame` |
| `connect0459/starlark/value` | `@value` | `Value` and all concrete value types (`StarlarkString`, `StarlarkList`, `StarlarkDict`, `StarlarkSet`, …); `StringDict`; `CustomValue`; value helpers (`equal`, `len_of`, `as_float`, …); embedder protocol traits |
| `connect0459/starlark/errors` | `@errors` | `EvalError`, `SyntaxError`, `ResolveError`, `Position`, `Span`, `Halt`, `Binding`, `CallFrame`, `CallStack` |
| `connect0459/starlark/syntax` | `@syntax` | `File`, `Expr`, `Stmt`, and the rest of the AST node types; AST walkers (`walk_file`, `walk_expr`, `walk_stmt`) |
| `connect0459/starlark/unpack` | `@unpack` | `unpack_args`, `unpack_positional`, `unpack_args_with` for host-defined built-ins |
| `connect0459/starlark/lib/json` | `@json` | JSON encode / decode extension |
| `connect0459/starlark/lib/math` | `@math` | Math functions extension |
| `connect0459/starlark/lib/struct` | `@struct` | `struct`, `module`, and `gensym` extension (starlarkstruct) |
| `connect0459/starlark/lib/time` | `@time` | Time and duration extension (starlarktime) |

All `src/internal/*` packages are implementation details and are not importable by consumers.
The packages `eval`, `value`, `errors`, `syntax`, and `unpack` are public sub-packages; import
them directly. There is **no** top-level `connect0459/starlark` facade — entry functions live in
`@eval`, value types and inspection helpers in `@value`, error types in `@errors`, AST types in
`@syntax`, and argument unpacking in `@unpack`.

---

## `eval` package

The main entry point. Import `connect0459/starlark/eval` to parse, resolve, and execute
Starlark, and for the `Thread`/`Module`/`Options`/`Program` types.

### Execution functions

| Function | Signature | Description |
| :--- | :--- | :--- |
| `exec_file` | `(Thread, String, String, Options) -> Result[Module, @errors.EvalError]` | Execute a Starlark source file |
| `exec_file_with_predeclared` | `(Thread, String, String, Options, Predeclared) -> Result[Module, @errors.EvalError]` | Execute with extra host bindings visible to the script |
| `exec_file_with_universe` | `(Thread, String, String, Options, Universe) -> Result[Module, @errors.EvalError]` | Execute with a custom built-in universe instead of the standard one |
| `exec_repl_chunk` | `(Thread, String, String, @value.StringDict, Options) -> Result[Unit, @errors.EvalError]` | Execute one REPL chunk; updates the persistent `globals` dict in place |
| `eval_expr` | `(Thread, String, String, @value.StringDict) -> Result[@value.Value, @errors.EvalError]` | Evaluate a single Starlark expression with default options |
| `eval_expr_with_opts` | `(Thread, String, String, Options, @value.StringDict) -> Result[@value.Value, @errors.EvalError]` | Like `eval_expr` but with explicit options |
| `eval_parsed_expr` | `(Thread, @syntax.Expr, Options, @value.StringDict) -> Result[@value.Value, @errors.EvalError]` | Evaluate a pre-parsed expression node |
| `call` | `(Thread, @value.Value, Array[@value.Value], Array[(String, @value.Value)]) -> Result[@value.Value, @errors.EvalError]` | Call any Starlark callable from host code |

### Parsing and compilation

| Function | Signature | Description |
| :--- | :--- | :--- |
| `parse_file` | `(String, String) -> Result[@syntax.File, @errors.EvalError]` | Parse Starlark source to an AST |
| `parse_expr` | `(String, String) -> Result[@syntax.Expr, @errors.EvalError]` | Parse a single Starlark expression to an AST node |
| `source_program` | `(String, String, Options, (String)->Bool) -> Result[Program, @errors.EvalError]` | Parse and resolve without executing; returns a reusable `Program` |
| `source_program_with_file` | `(String, String, Options, (String)->Bool) -> Result[(@syntax.File, Program), @errors.EvalError]` | Like `source_program` but also returns the parsed AST |
| `file_program` | `(@syntax.File, Options, (String)->Bool) -> Result[Program, @errors.EvalError]` | Resolve an already-parsed `@syntax.File` into a `Program` |
| `compiled_program` | `(Bytes) -> Result[Program, @errors.EvalError]` | Reload a `Program` from bytes produced by `Program::write`, skipping parse + resolve |

`Program::write() -> Bytes` serializes a resolved program so it can be persisted
and reloaded with `compiled_program`. The format holds the resolved AST plus the
program's options (a versioned, magic-tagged binary); it is specific to this
tree-walking implementation and **not** byte-compatible with starlark-go's
bytecode `Program.Write`.

### Operator dispatch

Apply Starlark operators by name from host code. These return `@errors.EvalError`.

| Function | Signature | Description |
| :--- | :--- | :--- |
| `binary` | `(String, @value.Value, @value.Value) -> Result[@value.Value, @errors.EvalError]` | Apply a binary operator by name (`"+"`, `"-"`, `"*"`, etc.) |
| `unary` | `(String, @value.Value) -> Result[@value.Value, @errors.EvalError]` | Apply a unary operator by name (`"-"`, `"~"`, `"not"`) |
| `compare` | `(String, @value.Value, @value.Value) -> Result[Bool, @errors.EvalError]` | Apply a comparison operator by name (`"=="`, `"<"`, etc.) |

#### `exec_file`

Parses, resolves, and evaluates `src` as a complete Starlark file. `filename` is used only
in error messages. Returns the frozen `Module` containing all top-level globals on success.

```mbt check
///|
test {
  let thread = @eval.Thread::new("main")
  let _ = @eval.exec_file(
    thread,
    "build.star",
    "greeting = 'hello ' + 'world'",
    @eval.Options::default(),
  )
}
```

#### `eval_expr`

Evaluates a single expression `src` in the given environment `env` (a `@value.StringDict`,
the string-keyed binding map). Unlike `exec_file`, this does not run statements and does not
produce a `Module`; it returns the expression value. `env` may be empty
(`@value.StringDict::new()`) or pre-populated with bindings.

```mbt check
///|
test {
  let thread = @eval.Thread::new("expr")
  let env = @value.StringDict::new()
  let _ = @eval.eval_expr(thread, "<expr>", "len([1, 2, 3])", env)
}
```

#### `exec_file_with_predeclared`

Like `exec_file` but injects `predeclared` bindings before execution. These bindings are
visible to the script as predeclared names (higher precedence than universe built-ins,
lower than locals and globals).

```mbt check
///|
test {
  let thread = @eval.Thread::new("main")
  let predeclared = @eval.Predeclared::from_map({
    "MY_FLAG": @value.Value::Bool(true),
  })
  let _ = @eval.exec_file_with_predeclared(
    thread,
    "script.star",
    "enabled = MY_FLAG",
    @eval.Options::default(),
    predeclared,
  )
}
```

---

### `@eval.Thread`

Holds execution context: print callback, load callback, call stack, and step budget.

```moonbit nocheck
pub struct Thread { /* private fields */ }  // in "connect0459/starlark/eval"
```

#### Constructors

| Constructor | Signature | Description |
| :--- | :--- | :--- |
| `Thread::new` | `(String) -> Thread` | Thread with default print (stdout) and no loader |
| `Thread::with_print` | `(String, (Thread, String) -> Unit) -> Thread` | Thread with a custom print callback |
| `Thread::with_loader` | `(String, (Thread, String) -> Result[Module, @errors.EvalError]) -> Thread` | Thread with a module loader |
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
| `call_frames()` | `Array[@errors.CallFrame]` | Current call stack frames |
| `call_stack()` | `@errors.CallStack` | Snapshot of the current call stack |
| `call_frame(Int)` | `@errors.CallFrame?` | Frame at depth `n` (0 = innermost); `None` if out of range |
| `debug_frame(Int)` | `DebugFrame?` | Snapshot of an active call frame (0 = innermost Starlark function); `None` if out of range |

#### Customization (mutators)

A `Thread` built with `Thread::new` can be customized after construction; these compose freely.

| Method | Description |
| :--- | :--- |
| `set_print((Thread, String) -> Unit)` | Set the print callback |
| `set_loader((Thread, String) -> Result[Module, @errors.EvalError])` | Set the module loader |

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
| `set_local(String, @value.Value)` | Store a value under a string key |
| `get_local(String) -> @value.Value?` | Retrieve a stored value; `None` if not set |

#### Cancellation

| Method | Description |
| :--- | :--- |
| `cancel(String)` | Signal the thread to halt; raises `EvalError` at the next step check |
| `uncancel()` | Clear a previous cancel signal |

```mbt check
///|
test {
  let thread = @eval.Thread::new("main")
  thread.cancel("timeout")
  match @eval.exec_file(thread, "x.star", "x = 1", @eval.Options::default()) {
    Err(e) => assert_true(e.msg().contains("timeout"))
    Ok(_) => fail("expected cancellation")
  }
}
```

---

### `@eval.Options`

Feature flags that control Starlark dialect. All flags default to `true` except
`load_binds_globally` (default `false`).

```moonbit nocheck
pub struct Options { /* private fields */ }  // in "connect0459/starlark/eval"
```

| Accessor | Mutator | Default | Description |
| :--- | :--- | :--- | :--- |
| `allow_set()` | `with_allow_set(Bool)` | `true` | Enable `set` literals and the `set()` built-in |
| `allow_recursion()` | `with_allow_recursion(Bool)` | `true` | Allow recursive function calls |
| `allow_lambda()` | `with_allow_lambda(Bool)` | `true` | Enable `lambda` expressions |
| `allow_while()` | `with_allow_while(Bool)` | `true` | Enable `while` loops |
| `allow_bytes()` | `with_allow_bytes(Bool)` | `true` | Enable `bytes` literals (`b"..."`) |
| `allow_float()` | `with_allow_float(Bool)` | `true` | Enable float literals and float arithmetic |
| `allow_global_reassign()` | `with_allow_global_reassign(Bool)` | `true` | Allow re-assigning module-level names |
| `allow_top_level_control()` | `with_allow_top_level_control(Bool)` | `true` | Allow `if` / `for` / `while` at module scope |
| `load_binds_globally()` | `with_load_binds_globally(Bool)` | `false` | `load` imports are visible module-wide (legacy compatibility flag) |

`Options::default()` returns the all-enabled defaults. Each `with_*` mutator returns a modified
copy, so flags can be chained: `Options::default().with_allow_set(false).with_allow_while(false)`.

```mbt check
///|
test {
  let opts = @eval.Options::default()
  assert_eq(opts.allow_set(), true)
  assert_eq(opts.load_binds_globally(), false)
}
```

```mbt check
///|
test {
  let opts = @eval.Options::default().with_load_binds_globally(true)
  assert_eq(opts.load_binds_globally(), true)
}
```

---

### `@eval.Module`

The result of a successful `exec_file` call. Its globals dict is frozen on return.

```moonbit nocheck
pub struct Module { /* private fields */ }  // in "connect0459/starlark/eval"
```

| Method | Signature | Description |
| :--- | :--- | :--- |
| `get` | `(String) -> @value.Value?` | Look up a global by name |
| `global_names` | `() -> Array[String]` | Names of all defined globals |
| `globals_count` | `() -> Int` | Number of defined globals |
| `predeclared_names` | `() -> Array[String]` | Names of predeclared bindings injected before execution |
| `predeclared_count` | `() -> Int` | Number of predeclared bindings |
| `is_frozen` | `() -> Bool` | Always `true` after `exec_file` returns |
| `freeze` | `() -> Unit` | Freeze the module manually (rarely needed) |
| `new` | `() -> Module` | Empty unfrozen module |
| `from_map` | `(Map[String, @value.Value]) -> Module` | Construct a module from a map (for testing) |

---

### `@eval.Predeclared`

Extra bindings injected before user globals. Scripts can read but not reassign them.

```moonbit nocheck
pub struct Predeclared { /* private fields */ }  // in "connect0459/starlark/eval"
```

| Constructor / Method | Description |
| :--- | :--- |
| `Predeclared::new()` | Empty predeclared set |
| `Predeclared::from_map(Map[String, @value.Value])` | Construct from a literal map |
| `get(String) -> @value.Value?` | Look up a name |
| `set(String, @value.Value)` | Add or replace a binding |
| `has(String) -> Bool` | Test for name presence |
| `delete(String) -> Bool` | Remove a binding; returns whether it was present |
| `keys() -> Array[String]` | All bound names |
| `values() -> Array[@value.Value]` | All bound values |
| `each((String, @value.Value) -> Unit)` | Iterate all name–value pairs |

---

### `@eval.Universe`

The predeclared built-in environment shared across all threads.

```moonbit nocheck
pub struct Universe { /* private fields */ }  // in "connect0459/starlark/eval"
```

| Constructor / Method | Description |
| :--- | :--- |
| `Universe::standard()` | Full Starlark built-in set (`print`, `range`, `len`, …) |
| `Universe::new()` | No built-ins (useful for sandboxed evaluation) |
| `Universe::from_map(Map[String, @value.Value])` | Wrap an existing map of bindings |
| `get(String) -> @value.Value?` | Look up a built-in by name |
| `set(String, @value.Value)` | Add or replace a built-in |
| `has(String) -> Bool` | Test for name presence |
| `delete(String) -> Bool` | Remove a built-in; returns whether it was present |
| `keys() -> Array[String]` | All built-in names |
| `values() -> Array[@value.Value]` | All built-in values |
| `each((String, @value.Value) -> Unit)` | Iterate all name–value pairs |

---

### `@eval.Program`

A parsed-and-resolved Starlark program that can be executed multiple times without
re-parsing. Unlike `exec_file`, `Program::init` does **not** freeze the returned module.

```moonbit nocheck
pub struct Program { /* private fields */ }  // in "connect0459/starlark/eval"
```

| Method | Signature | Description |
| :--- | :--- | :--- |
| `filename()` | `() -> String` | Source file name used during compilation |
| `num_loads()` | `() -> Int` | Number of `load` statements in the file |
| `load(Int)` | `(Int) -> (String, @errors.Position)` | Path and position of the i-th `load` statement |
| `options()` | `() -> Options` | The file-level dialect options the program was resolved with |
| `init(Thread, Predeclared)` | `-> Result[Module, @errors.EvalError]` | Execute the program and return an **unfrozen** module |
| `write()` | `() -> Bytes` | Serialize the resolved program; reload with `compiled_program` |

```mbt check
///|
test {
  let prog_result = @eval.source_program(
    "lib.star",
    "def square(n): return n * n",
    @eval.Options::default(),
    fn(_) { false },
  )
  match prog_result {
    Ok(prog) => {
      let thread = @eval.Thread::new("main")
      match prog.init(thread, @eval.Predeclared::new()) {
        Ok(m) => assert_true(m.get("square") is Some(@value.Value::Function(_)))
        Err(e) => fail(e.to_string())
      }
    }
    Err(e) => fail(e.to_string())
  }
}
```

---

### `@eval.DebugFrame`

A read-only snapshot of an active Starlark call frame. Obtain via `Thread.debug_frame(depth)`
(depth 0 = innermost Starlark function).

```moonbit nocheck
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

## `value` package

Import `connect0459/starlark/value` for the `Value` type, every concrete value type, the
host-side `StringDict`, the embedder-extension `CustomValue`, value-inspection helpers, and the
embedder protocol traits.

### `@value.Value`

All Starlark values share this enum type.

```moonbit nocheck
///|
pub enum Value {
  None
  Bool(Bool)
  Int(BigInt) // arbitrary-precision integer
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
  StringElems(StarlarkStringElems) // returned by str.elems()
  StringCodepoints(StarlarkStringCodepoints) // returned by str.codepoints()
  BytesElems(StarlarkBytesElems) // returned by bytes.elems()
  ExtVal(CustomValue) // embedder-defined custom type
}
```

The three iterator variants (`StringElems`, `StringCodepoints`, `BytesElems`) are lazy iterables
returned by the respective string/bytes methods. They report their own `type()` strings
(`"string.elems"`, `"string.codepoints"`, `"bytes.elems"`) and support `len()`.

> **Note:** `Int` holds a `BigInt` (arbitrary precision). Use the `N` suffix for integer
> literals in patterns: `@value.Value::Int(42N)`.

Pattern matching is the primary way to inspect a `Value`:

```mbt check
///|
test {
  let thread = @eval.Thread::new("main")
  match
    @eval.exec_file(thread, "s.star", "x = 'hello'", @eval.Options::default()) {
    Ok(m) =>
      match m.get("x") {
        Some(@value.Value::String(s)) => assert_eq(s.raw(), "hello")
        _ => fail("expected string")
      }
    Err(e) => fail(e.to_string())
  }
}
```

#### Constructors and value-level methods

| Method | Signature | Description |
| :--- | :--- | :--- |
| `Value::new_int(Int64)` | `-> Value` | Construct an `Int` value |
| `Value::new_float(Double)` | `-> Value` | Construct a `Float` value |
| `Value::new_string(String)` | `-> Value` | Construct a `String` value |
| `Value::new_list(Array[Value])` | `-> Value` | Construct a `List` value |
| `Value::new_dict()` | `-> Value` | Construct an empty `Dict` value |
| `Value::new_set()` | `-> Value` | Construct an empty `Set` value |
| `Value::new_builtin(String, (BuiltinCallCtx, Array[Value], Array[(String, Value)]) -> Result[Value, String])` | `-> Value` | Construct a host-provided callable built-in |
| `repr()` | `-> String` | `repr()` form (the Starlark literal) |
| `to_str()` | `-> String` | `str()` form (unquoted for strings) |
| `type_name()` | `-> String` | `type()` name |
| `truth()` | `-> Bool` | Truthiness for `if`/`while`/`and`/`or` |
| `starlark_equals(Value)` | `-> Bool` | Structural equality |
| `hash()` | `-> Result[UInt, String]` | Hash; `Err` for unhashable values |
| `freeze()` | `-> Unit` | Freeze this value (and, transitively, its contents) |

`Value` also implements `Eq`.

### Value-inspection helpers

Mirrors of starlark-go's package-level helpers. These return `String` errors (value-level
operations carry no source position).

| Function | Signature | Description |
| :--- | :--- | :--- |
| `equal` | `(Value, Value) -> Result[Bool, String]` | Structural equality (depth-capped by `compare_limit`) |
| `len_of` | `(Value) -> Int` | Sequence length; returns `-1` for non-sequences |
| `length_of` | `(Value) -> Result[Int, String]` | Sequence length; `Err` for non-sequences |
| `iterate` | `(Value) -> Result[StarlarkIterator, String]` | Obtain an iterator over a Starlark iterable |
| `number_to_int` | `(Value) -> Int64?` | Convert `Int` or `Float` to `Int64`; `None` otherwise |
| `as_float` | `(Value) -> (Double, Bool)` | Extract `Float` or convert `Int` to `Double`; second element is `true` on success |
| `as_string` | `(Value) -> (String, Bool)` | Extract raw string from `String` value; second element is `true` on success |

### Depth-limited comparison

These guard against infinite recursion on cyclic data structures.

| Symbol | Signature | Description |
| :--- | :--- | :--- |
| `compare_limit` | `Int` | Default recursion depth for comparisons (value: `10`) |
| `equal_depth` | `(Value, Value, Int) -> Result[Bool, String]` | Equality with explicit depth limit |
| `starlark_equals_depth` | `(Value, Value, Int) -> Result[Bool, String]` | Equality used by the evaluator, with explicit depth limit |
| `compare_depth` | `(String, Value, Value, Int) -> Result[Bool, String]` | Comparison operator (`"=="`, `"<"`, …) with explicit depth limit |
| `compare_values` | `(Value, Value, op? : String) -> Result[Int, String]` | Three-way comparison (`-1`/`0`/`1`); same-type only |
| `compare_values_depth` | `(Value, Value, Int, op? : String) -> Result[Int, String]` | Three-way comparison with explicit depth limit |

### Low-level numeric and conversion helpers

Building blocks shared with the evaluator; embedders rarely need these directly.

| Function | Signature | Description |
| :--- | :--- | :--- |
| `floor_div` | `(@bigint.BigInt, @bigint.BigInt) -> Result[@bigint.BigInt, String]` | Floor division toward −∞ (Starlark `//`) |
| `starlark_mod` | `(@bigint.BigInt, @bigint.BigInt) -> Result[@bigint.BigInt, String]` | Modulo with the sign of the divisor (Starlark `%`) |
| `format_float` | `(Double) -> String` | Format a float the way `repr`/`str` does (handles inf/nan) |
| `bigint_to_double` | `(@bigint.BigInt) -> Double` | Convert a `BigInt` to the nearest `Double` |
| `bigint_to_finite_double` | `(@bigint.BigInt) -> Result[Double, String]` | Like `bigint_to_double` but errors on overflow to ±∞ |
| `double_to_bigint` | `(Double) -> @bigint.BigInt` | Truncate a `Double` toward zero to a `BigInt` |
| `java_string_hash` | `(StarlarkString) -> Int` | `java.lang.String.hashCode`-compatible hash used for string values |

---

### `@value.StarlarkString`

The UTF-8-backed immutable string type behind Starlark `string` values.

```moonbit nocheck
pub struct StarlarkString { /* private fields */ }  // in "connect0459/starlark/value"
```

| Method | Signature | Description |
| :--- | :--- | :--- |
| `StarlarkString::new(String)` | `-> StarlarkString` | Construct from a MoonBit string |
| `StarlarkString::from_bytes(Bytes)` | `-> StarlarkString` | Construct from raw UTF-8 bytes |
| `raw()` | `-> String` | The underlying MoonBit string |
| `to_bytes()` | `-> Bytes` | UTF-8 byte representation |
| `byte_len()` | `-> Int` | Length in bytes |
| `byte_at(Int)` | `-> Byte` | The i-th byte |
| `equals(StarlarkString)` | `-> Bool` | Byte-wise equality |

---

### `@value.StarlarkList`

The mutable, freezable sequence backing Starlark `list` values.

```moonbit nocheck
pub struct StarlarkList { /* private fields */ }  // in "connect0459/starlark/value"
```

| Method | Signature | Description |
| :--- | :--- | :--- |
| `StarlarkList::new(Array[Value])` | `-> StarlarkList` | Construct from an array of values |
| `length()` | `-> Int` | Number of elements |
| `is_empty()` | `-> Bool` | Whether the list has no elements |
| `get(Int)` | `-> Value?` | Element at index; `None` if out of range |
| `op_get(Int)` | `-> Value` | Element at index (panics if out of range; for `list[i]`) |
| `set(Int, Value)` | `-> Result[Unit, String]` | Replace the element at index |
| `push(Value)` | `-> Result[Unit, String]` | Append an element (`Err` if frozen) |
| `insert(Int, Value)` | `-> Result[Unit, String]` | Insert at index |
| `pop()` | `-> Result[Value?, String]` | Remove and return the last element |
| `pop_at(Int, String)` | `-> Result[Value, String]` | Remove and return the element at index |
| `clear()` | `-> Result[Unit, String]` | Remove all elements |
| `reverse()` | `-> Result[Unit, String]` | Reverse in place |
| `sort_by((Value, Value) -> Int)` | `-> Result[Unit, String]` | Sort in place with a comparator |
| `copy_items()` | `-> Array[Value]` | A copy of the backing array |
| `each((Value) -> Unit)` | `-> Unit` | Iterate elements |
| `eachi((Int, Value) -> Unit)` | `-> Unit` | Iterate elements with index |
| `iter()` | `-> Iter[Value]` | Lazy iterator over elements |
| `is_frozen()` | `-> Bool` | Whether the list is frozen |
| `freeze()` | `-> Unit` | Freeze the list (and, transitively, its values) |
| `check_mutable(String)` | `-> Result[Unit, String]` | `Err` if frozen or being iterated; `verb` names the operation |

---

### `@value.StarlarkDict`

The insertion-ordered mutable mapping backing Starlark `dict` values. Keys are any hashable
`Value`. (For host-side string-keyed environments — e.g. the `eval_expr` env — use
`@value.StringDict` instead.)

```moonbit nocheck
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

### `@value.StarlarkSet`

The insertion-ordered mutable hash set backing Starlark `set` values. Members are any hashable
`Value`.

```moonbit nocheck
pub struct StarlarkSet { /* private fields */ }  // in "connect0459/starlark/value"
```

| Method | Description |
| :--- | :--- |
| `StarlarkSet::new()` | Empty set |
| `add(Value) -> Result[Unit, String]` | Add a member |
| `contains(Value) -> Result[Bool, String]` | Membership test |
| `remove(Value) -> Result[Bool, String]` | Remove a member; returns whether it was present |
| `pop_first() -> Result[Value?, String]` | Remove and return the first inserted member |
| `clear() -> Result[Unit, String]` | Remove all members |
| `length() -> Int` | Number of members |
| `each((Value) -> Unit)` | Iterate members in insertion order |
| `iter() -> Iter[Value]` | Lazy iterator over members |
| `is_frozen() -> Bool` | Whether the set is frozen |
| `freeze() -> Unit` | Freeze the set (and, transitively, its members) |

---

### `@value.StarlarkRange`

The lazy integer sequence returned by `range()`; not a list.

```moonbit nocheck
pub struct StarlarkRange { /* private fields */ }  // in "connect0459/starlark/value"
```

| Method | Signature | Description |
| :--- | :--- | :--- |
| `StarlarkRange::new(Int64, Int64, Int64)` | `-> StarlarkRange` | Construct from `start`, `stop`, `step` |
| `start()` / `stop()` / `step()` | `-> Int64` | The three range parameters |
| `length()` | `-> Int` | Number of elements |
| `index_at(Int)` | `-> Int64` | The value at the i-th position |
| `contains(Int64)` | `-> Bool` | Membership test |

---

### `@value.StringDict`

A `Map[String, Value]` wrapper used for host-side string-keyed dictionaries, and the
environment type accepted by `eval_expr` and the persistent `globals` of
`exec_repl_chunk`. Analogous to `starlark.StringDict` in starlark-go.

```moonbit nocheck
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

```moonbit nocheck
pub struct StarlarkBuiltinFunc { /* private fields */ }  // in "connect0459/starlark/value"
```

| Method | Description |
| :--- | :--- |
| `StarlarkBuiltinFunc::dispatch(String)` | Create a named built-in with no body (stub for forward references) |
| `name() -> String` | Built-in function name |
| `receiver() -> Value?` | Bound receiver value, if any |
| `bind_receiver(Value) -> StarlarkBuiltinFunc` | Return a copy bound to the given receiver |
| `call_body(BuiltinCallCtx, Array[Value], Array[(String, Value)]) -> Result[Value, String]?` | Invoke the built-in's body (if any) |

Use `Value::new_builtin(name, fn)` to build a callable with a body; the callback receives a
`BuiltinCallCtx` (below) that can call back into the evaluator.

---

### `@value.StarlarkBoundMethod`

A method bound to a receiver, e.g. `"abc".upper`.

```moonbit nocheck
pub struct StarlarkBoundMethod { /* private fields */ }  // in "connect0459/starlark/value"
```

| Method | Signature | Description |
| :--- | :--- | :--- |
| `StarlarkBoundMethod::new(Value, String)` | `-> StarlarkBoundMethod` | Bind `method_name` to `recv` |
| `recv()` | `-> Value` | The receiver value |
| `method_name()` | `-> String` | The method name |

---

### `@value.StarlarkFunction`

A user-defined (Starlark-source) function. Obtain via `@value.Value::Function(f)` pattern matching.

```moonbit nocheck
pub struct StarlarkFunction { /* private fields */ }  // in "connect0459/starlark/value"
```

#### Identity

| Method | Returns | Description |
| :--- | :--- | :--- |
| `name()` | `String` | Function name; `"<lambda>"` for lambda expressions |
| `position()` | `@errors.Position` | Source position of the `def` keyword |
| `doc()` | `String` | Docstring (first string literal in body); `""` if absent |

#### Parameters

| Method | Returns | Description |
| :--- | :--- | :--- |
| `num_params()` | `Int` | Total parameter count |
| `num_kwonly_params()` | `Int` | Number of keyword-only parameters (after `*args`) |
| `has_varargs()` | `Bool` | Whether the function has a `*args` parameter |
| `has_kwargs()` | `Bool` | Whether the function has a `**kwargs` parameter |
| `param(Int)` | `(String, @errors.Position)` | Name and position of the i-th parameter |
| `param_default(Int)` | `Value?` | Default value of the i-th parameter; `None` if required |

#### Closure / module

| Method | Returns | Description |
| :--- | :--- | :--- |
| `num_free_vars()` | `Int` | Number of captured (closure) variables |
| `free_var(Int)` | `(String, Value)?` | Name and current value of the i-th free variable |
| `globals()` | `Map[String, Value]` | Module globals visible when the function was defined |
| `defining_module()` | `StarlarkModule?` | Module that defined this function; `None` for functions not created via `exec_file` |

```mbt check
///|
test {
  let thread = @eval.Thread::new("main")
  match
    @eval.exec_file(
      thread,
      "lib.star",
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
            None => fail("expected module")
          }
        }
        _ => fail("expected function")
      }
    Err(e) => fail(e.to_string())
  }
}
```

---

### `@value.StarlarkModule`

A loaded module value (e.g. obtained through `load`, or via `StarlarkFunction.defining_module`).

```moonbit nocheck
pub struct StarlarkModule { /* private fields */ }  // in "connect0459/starlark/value"
```

| Method | Signature | Description |
| :--- | :--- | :--- |
| `StarlarkModule::new(String, Map[String, Value])` | `-> StarlarkModule` | Construct from a name and attribute map |
| `name()` | `-> String` | Module name |
| `get(String)` | `-> Value?` | Look up an attribute |
| `attr_names()` | `-> Array[String]` | All attribute names |

---

### `@value.StarlarkIterator`

The iterator protocol returned by `@value.iterate`.

```moonbit nocheck
pub struct StarlarkIterator { /* private fields */ }  // in "connect0459/starlark/value"
```

| Method | Signature | Description |
| :--- | :--- | :--- |
| `next()` | `-> Value?` | Next value, or `None` when exhausted |
| `done()` | `-> Unit` | Release the iterator; must be called even on early exit (decrements the container's iteration count) |
| `collect()` | `-> Array[Value]` | Drain the iterator into an array |

---

### String and bytes iterables

The lazy iterables returned by `str.elems()`, `str.codepoints()`, and `bytes.elems()`. Each
appears as a dedicated `Value` variant and reports its own `type()` string.

```moonbit nocheck
pub struct StarlarkStringElems { /* private fields */ }       // str.elems()
pub struct StarlarkStringCodepoints { /* private fields */ }  // str.codepoints()
pub struct StarlarkBytesElems { /* private fields */ }        // bytes.elems()
```

| Type | Method | Description |
| :--- | :--- | :--- |
| `StarlarkStringElems` | `new(StarlarkString, Bool)` | Construct; `is_ords` selects int-ord vs substring elements |
| | `source_string()` / `is_ords()` | Backing string / whether it yields ordinals |
| `StarlarkStringCodepoints` | `new(StarlarkString, Bool)` | Construct; `is_ords` selects int-ord vs codepoint substrings |
| | `source_string()` / `is_ords()` | Backing string / whether it yields ordinals |
| `StarlarkBytesElems` | `new(Bytes)` | Construct from raw bytes |
| | `raw_bytes()` | The backing bytes |

---

### `@value.CustomValue` and `@value.BuiltinCallCtx`

`CustomValue` is an embedder-defined custom type that participates in the Starlark value system
as `@value.Value::ExtVal(cv)`. Construct with `CustomValue::new(repr_fn, truth_fn, type_name_fn)`
and attach optional protocol implementations via fluent `.with_*` methods
(`with_attrs`, `with_call`, `with_binary`, `with_unary`, `with_compare`, `with_contains`,
`with_equals`, `with_hash`, `with_iterate`, `with_length`, `with_items`, `with_freeze`,
`with_get_index`, `with_set_index`, `with_set_key`, `with_set_field`, `with_slice`). The matching
`get_*` / `do_*` accessors are used by the evaluator to dispatch operations.

```moonbit nocheck
pub struct CustomValue { /* private fields */ }     // in "connect0459/starlark/value"
pub struct BuiltinCallCtx { /* private fields */ }  // in "connect0459/starlark/value"
```

`BuiltinCallCtx` is passed to a built-in's body so it can call back into the evaluator:

| Method | Signature | Description |
| :--- | :--- | :--- |
| `BuiltinCallCtx::new((Value, Array[Value], Array[(String, Value)]) -> Result[Value, String], get_local? : (String) -> Value?)` | `-> BuiltinCallCtx` | Construct a call context |
| `invoke(Value, Array[Value], Array[(String, Value)])` | `-> Result[Value, String]` | Call a Starlark callable from within the built-in |
| `get_local(String)` | `-> Value?` | Read thread-local state set on the active `Thread` |

See the `src/lib/struct/` and `src/lib/time/` extensions for idiomatic `CustomValue` usage.

---

### Embedder protocol traits

Implement these on a host type to make it interoperate with the evaluator. They mirror
starlark-go's optional interfaces. Most embedders implement them indirectly through
`CustomValue`'s `.with_*` methods rather than directly.

| Trait | Method(s) | Purpose |
| :--- | :--- | :--- |
| `Container` | `has(Value) -> Result[Bool, String]` | `x in c` membership |
| `HasAttrs` | `get_attr(String)`, `attr_names()` | Attribute read (`x.attr`, `dir(x)`) |
| `HasSetField` | `set_field(String, Value)` | Attribute write (`x.attr = v`) |
| `Indexable` | `indexable_get(Int)`, `indexable_len()` | Index read (`x[i]`) |
| `HasSetIndex : Indexable` | `set_index(Int, Value)` | Index write (`x[i] = v`) |
| `Sliceable : Indexable` | `slice(Int, Int, Int)` | Slicing (`x[a:b:c]`) |
| `Mapping` | `mapping_get(Value)`, `mapping_keys()`, `mapping_len()` | Dict-like key access |
| `IterableMapping : Mapping` | `items()` | Key–value enumeration |
| `HasBinary` | `binary_op(String, Value, Bool)` | Custom binary operators |
| `HasUnary` | `unary_op(String)` | Custom unary operators |
| `StarlarkComparable` | `compare_same_type(Value)` | Same-type ordering for `sorted`/`min`/`max` |
| `TotallyOrdered` | `cmp(Value)` | Total ordering across comparisons |
| `Unpacker` (open) | `unpack(Value)` | Per-argument coercion for `@unpack.unpack_args_with` |

---

## `errors` package

All error types carry a `Position` (or call stack) and a human-readable message. `exec_file`
wraps `SyntaxError` and `ResolveError` into `EvalError` before returning, so callers typically
only need to handle `EvalError`.

### `@errors.EvalError`

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

### `@errors.SyntaxError`

Lexer or parser errors.

| Method | Returns | Description |
| :--- | :--- | :--- |
| `SyntaxError::new(Position, String)` | `SyntaxError` | Construct from a position and message |
| `msg()` | `String` | Error message |
| `pos()` | `Position` | Source position |
| `to_string()` | `String` | `"<file>:<line>:<col>: <msg>"` |

### `@errors.ResolveError`

Name-resolution errors (undefined variables, invalid scoping, etc.).

| Method | Returns | Description |
| :--- | :--- | :--- |
| `ResolveError::new(Position, String)` | `ResolveError` | Construct from a position and message |
| `msg()` | `String` | Error message |
| `pos()` | `Position` | Source position |
| `to_string()` | `String` | `"<file>:<line>:<col>: <msg>"` |

### `@errors.Position`

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

### `@errors.Span`

A start–end pair of `Position`s for ranged diagnostics.

| Method | Returns | Description |
| :--- | :--- | :--- |
| `Span::new(Position, Position)` | `Span` | Construct from start and end positions |
| `start()` | `Position` | Start position |
| `end_pos()` | `Position` | End position |
| `to_string()` | `String` | `"<start>-<end>"` |

### `@errors.Halt`

A cancellation signal, distinct from `EvalError`, used to unwind execution when a thread is
cancelled or its step budget is exhausted.

| Method | Returns | Description |
| :--- | :--- | :--- |
| `Halt::new(String)` | `Halt` | Construct with a reason |
| `reason()` | `String` | Why execution was halted |

### `@errors.Binding`

A local variable name together with its definition position. Used by the debugger API.

| Method | Returns | Description |
| :--- | :--- | :--- |
| `Binding::new(String, Position)` | `Binding` | Construct from a name and position |
| `name()` | `String` | Variable name |
| `pos()` | `Position` | Declaration position in source |

### `@errors.CallStack` and `@errors.CallFrame`

A snapshot of the call stack at a point in time.

#### `CallStack`

| Method | Returns | Description |
| :--- | :--- | :--- |
| `CallStack::new(Array[CallFrame])` | `CallStack` | Construct from frames |
| `length()` | `Int` | Number of frames |
| `at(Int)` | `CallFrame?` | Frame at index (0 = outermost) |
| `pop()` | `CallFrame?` | Remove and return the innermost frame |
| `to_string()` | `String` | Human-readable backtrace |

#### `CallFrame`

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

---

## `syntax` package

The AST node types returned by `@eval.parse_file` / `@eval.parse_expr` and consumed by
`@eval.file_program` / `@eval.eval_parsed_expr`. All node enums are `pub(all)`, so they can be
constructed and pattern-matched directly.

### Functions

| Function | Signature | Description |
| :--- | :--- | :--- |
| `walk_file` | `(File, (Node?) -> Bool) -> Unit` | Depth-first traversal of a file; visitor returns `false` to stop descending |
| `walk_stmt` | `(Stmt, (Node?) -> Bool) -> Unit` | Depth-first traversal of a statement |
| `walk_expr` | `(Expr, (Node?) -> Bool) -> Unit` | Depth-first traversal of an expression |
| `stmt_pos` | `(Stmt) -> @errors.Position` | Source position of a statement node |
| `expr_pos` | `(Expr) -> @errors.Position` | Source position of an expression node |

### `File`

```moonbit nocheck
pub struct File { /* private fields */ }  // in "connect0459/starlark/syntax"
```

| Method | Signature | Description |
| :--- | :--- | :--- |
| `File::new(String, Array[Stmt])` | `-> File` | Construct from a path and statements |
| `path()` | `-> String` | Source path |
| `stmts()` | `-> Array[Stmt]` | Top-level statements |

### AST node enums

Every node carries a trailing `@errors.Position`.

```moonbit nocheck
pub(all) enum Expr {
  EIdent(String, Position)
  ELiteral(LiteralVal, Position)
  EUnary(UnaryOp, Expr, Position)
  EBinary(Expr, BinaryOp, Expr, Position)
  ECond(Expr, Expr, Expr, Position)           // x if cond else y
  EIndex(Expr, Expr, Position)                 // a[i]
  ESlice(Expr, Expr?, Expr?, Expr?, Position)  // a[start:end:step]
  EDot(Expr, String, Position)                 // x.attr
  ECall(Expr, Array[Arg], Position)            // f(args…)
  EList(Array[Expr], Position)
  ETuple(Array[Expr], Position)
  EDict(Array[(Expr, Expr)], Position)
  ESet(Array[Expr], Position)
  ELambda(Array[Param], Expr, Position)
  EListComp(Expr, Array[CompClause], Position)
  ESetComp(Expr, Array[CompClause], Position)
  EDictComp(Expr, Expr, Array[CompClause], Position)
}

pub(all) enum Stmt {
  SExpr(Expr)
  SAssign(Expr, Expr, Position)
  SAugAssign(Expr, AugOp, Expr, Position)
  SIf(Expr, Array[Stmt], Array[Stmt], Position)
  SFor(Expr, Expr, Array[Stmt], Position)
  SWhile(Expr, Array[Stmt], Position)
  SDef(String, Array[Param], Array[Stmt], Position)
  SReturn(Expr?, Position)
  SBreak(Position)
  SContinue(Position)
  SPass(Position)
  SLoad(String, Array[(String, String, Position)], Position)
}

pub(all) enum Param {
  ParamIdent(String, Position)                 // x
  ParamDefault(String, Expr, Position)         // x=expr
  ParamStarBare(Position)                      // *
  ParamStarIdent(String, Position)             // *args
  ParamKwIdent(String, Position)               // **kwargs
}

pub(all) enum Arg {
  ArgPos(Expr)                                 // positional
  ArgKw(String, Expr, Position)                // name=expr
  ArgStarArgs(Expr)                            // *args
  ArgKwArgs(Expr)                              // **kwargs
}

pub(all) enum CompClause {
  ClauseFor(Expr, Expr, Position)              // for target in iterable
  ClauseIf(Expr, Position)                     // if guard
}

pub(all) enum LiteralVal {
  LitNone
  LitBool(Bool)
  LitInt(BigInt)
  LitFloat(Double)
  LitString(String)
  LitBytes(Bytes)
}

pub(all) enum BinaryOp {
  OpAdd; OpSub; OpMul; OpDiv; OpFloorDiv; OpMod
  OpBitAnd; OpBitOr; OpBitXor; OpLShift; OpRShift
  OpEq; OpNe; OpLt; OpLe; OpGt; OpGe
  OpIn; OpNotIn; OpAnd; OpOr
}

pub(all) enum UnaryOp {
  OpPlus; OpMinus; OpBitNot; OpNot
}

pub(all) enum AugOp {
  AugAdd; AugSub; AugMul; AugDiv; AugFloorDiv; AugMod
  AugBitAnd; AugBitOr; AugBitXor; AugLShift; AugRShift
}

// Visitor wrapper passed to walk_*; one variant per node kind.
pub(all) enum Node {
  NFile(File)
  NStmt(Stmt)
  NExpr(Expr)
  NParam(Param)
  NArg(Arg)
  NCompClause(CompClause)
}
```

---

## `unpack` package

Helpers for binding positional and keyword arguments inside host-defined built-ins. Call them as
`@unpack.unpack_args` etc.

| Function | Signature | Description |
| :--- | :--- | :--- |
| `unpack_args` | `(String, Array[Value], Array[(String, Value)], Array[String]) -> Result[Array[Value?], String]` | Bind positional + keyword args to a name spec (`"name"`, `"name?"`, `"name??"`) |
| `unpack_positional` | `(String, Array[Value], Array[(String, Value)], Int, Int) -> Result[Array[Value?], String]` | Bind positional-only args, requiring between `min` and `max` |
| `unpack_args_with` | `(String, Array[Value], Array[(String, Value)], Array[(String, &@value.Unpacker)]) -> Result[Unit, String]` | Like `unpack_args` but dispatches each matched value to a custom `@value.Unpacker` target |

Implement the `@value.Unpacker` trait (`unpack(Self, Value) -> Result[Unit, String]`)
on a host type to define custom per-argument validation/coercion, mirroring
starlark-go's `Unpacker` interface.

---

## `lib/json` package

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

```mbt check
///|
test {
  let thread = @eval.Thread::new("main")
  let predeclared = @eval.Predeclared::from_map({ "json": @json.json_module() })
  let src = "payload = json.encode({\"key\": [1, 2, 3]})"
  match
    @eval.exec_file_with_predeclared(
      thread,
      "data.star",
      src,
      @eval.Options::default(),
      predeclared,
    ) {
    Ok(m) =>
      match m.get("payload") {
        Some(@value.Value::String(s)) => assert_eq(s.raw(), "{\"key\":[1,2,3]}")
        _ => fail("expected string")
      }
    Err(e) => fail(e.to_string())
  }
}
```

---

## `lib/math` package

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

```mbt check
///|
test {
  let thread = @eval.Thread::new("main")
  let predeclared = @eval.Predeclared::from_map({ "math": @math.math_module() })
  match
    @eval.exec_file_with_predeclared(
      thread,
      "trig.star",
      "approx_pi = math.atan2(0.0, -1.0)",
      @eval.Options::default(),
      predeclared,
    ) {
    Ok(m) =>
      match m.get("approx_pi") {
        Some(@value.Value::Float(f)) => assert_true(f > 3.14 && f < 3.15)
        _ => fail("expected float")
      }
    Err(e) => fail(e.to_string())
  }
}
```

---

## `lib/struct` package

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

---

## `lib/time` package

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

```mbt check
///|
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
  match
    @eval.exec_file_with_predeclared(
      thread,
      "t.star",
      src,
      @eval.Options::default(),
      predeclared,
    ) {
    Ok(m) => {
      assert_true(m.get("stamp") is Some(@value.Value::Int(1_000_000N)))
      // 1.5 hours = 5_400_000_000_000 nanoseconds
      assert_true(
        m.get("total_ns") is Some(@value.Value::Int(5_400_000_000_000N)),
      )
    }
    Err(e) => fail(e.to_string())
  }
}
```
