# `eval` package

The main entry point. Import `connect0459/starlark/eval` to parse, resolve, and execute
Starlark, and for the `Thread`/`Module`/`Options`/`Program` types.

## Execution functions

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

## Parsing and compilation

| Function | Signature | Description |
| :--- | :--- | :--- |
| `parse_file` | `(String, String) -> Result[@syntax.File, @errors.EvalError]` | Parse Starlark source to an AST |
| `parse_expr` | `(String, String) -> Result[@syntax.Expr, @errors.EvalError]` | Parse a single Starlark expression to an AST node |
| `source_program` | `(String, String, Options, (String)->Bool) -> Result[Program, @errors.EvalError]` | Parse and resolve without executing; returns a reusable `Program` |
| `source_program_with_file` | `(String, String, Options, (String)->Bool) -> Result[(@syntax.File, Program), @errors.EvalError]` | Like `source_program` but also returns the parsed AST |
| `file_program` | `(@syntax.File, Options, (String)->Bool) -> Result[Program, @errors.EvalError]` | Resolve an already-parsed `@syntax.File` into a `Program` |
| `compiled_program` | `(Bytes) -> Result[Program, @errors.EvalError]` | Reload a `Program` from bytes produced by `Program::write`, skipping parse + resolve |

`Program::write() -> Bytes` serializes a compiled program so it can be persisted
and reloaded with `compiled_program`. The format holds the compiled bytecode
program (constant pool, function table, global/load tables, and the module-init
funcode) plus the program's options (a versioned, magic-tagged binary); it is
**not** byte-compatible with starlark-go's `Program.Write`.

## Operator dispatch

Apply Starlark operators by name from host code. These return `@errors.EvalError`.

| Function | Signature | Description |
| :--- | :--- | :--- |
| `binary` | `(String, @value.Value, @value.Value) -> Result[@value.Value, @errors.EvalError]` | Apply a binary operator by name (`"+"`, `"-"`, `"*"`, etc.) |
| `unary` | `(String, @value.Value) -> Result[@value.Value, @errors.EvalError]` | Apply a unary operator by name (`"-"`, `"~"`, `"not"`) |
| `compare` | `(String, @value.Value, @value.Value) -> Result[Bool, @errors.EvalError]` | Apply a comparison operator by name (`"=="`, `"<"`, etc.) |

### `exec_file`

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

### `eval_expr`

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

### `exec_file_with_predeclared`

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

## `@eval.Thread`

Holds execution context: print callback, load callback, call stack, and step budget.

```moonbit nocheck
pub struct Thread { /* private fields */ }  // in "connect0459/starlark/eval"
```

### Constructors

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

### Accessors

| Method | Returns | Description |
| :--- | :--- | :--- |
| `name()` | `String` | Thread name |
| `max_recursion_depth()` | `Int` | Call depth limit (default 100) |
| `max_steps()` | `Int?` | Step budget; `None` if uncapped |
| `execution_steps()` | `Int` | Steps consumed so far |
| `call_stack_depth()` | `Int` | Current call depth |
| `call_stack()` | `@errors.CallStack` | Snapshot of the current call stack |
| `call_frame(Int)` | `@errors.CallFrame?` | Frame at depth `n` (0 = innermost); `None` if out of range |
| `debug_frame(Int)` | `DebugFrame?` | Snapshot of an active call frame (0 = innermost Starlark function); `None` if out of range |

### Customization (mutators)

A `Thread` built with `Thread::new` can be customized after construction; these compose freely.

| Method | Description |
| :--- | :--- |
| `set_print((Thread, String) -> Unit)` | Set the print callback |
| `set_loader((Thread, String) -> Result[Module, @errors.EvalError])` | Set the module loader |

### Step budget control

| Method | Description |
| :--- | :--- |
| `set_max_steps(Int)` | Set the step budget (does not reset the accumulated count) |
| `set_on_max_steps((Thread) -> Unit)` | Set a callback invoked when the step budget is reached instead of halting |
| `reset_steps()` | Reset the accumulated step counter to zero |

### Thread-local storage

Embedders can store per-thread context (request IDs, counters, etc.) without subclassing.

| Method | Description |
| :--- | :--- |
| `set_local(String, @value.Value)` | Store a value under a string key |
| `get_local(String) -> @value.Value?` | Retrieve a stored value; `None` if not set |

### Cancellation

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

## `@eval.Options`

Feature flags that control the Starlark dialect. `Options::default()` is the
spec-conformant dialect that matches [starlark-go]'s zero-value `FileOptions`:
the **standard** features are enabled, and the **non-standard** extensions are
disabled and must be opted into explicitly.

```moonbit nocheck
pub struct Options { /* private fields */ }  // in "connect0459/starlark/eval"
```

Standard features — part of the Starlark language spec, enabled by default:

| Accessor | Mutator | Default | Description |
| :--- | :--- | :--- | :--- |
| `allow_set()` | `with_allow_set(Bool)` | `true` | Enable `set` literals and the `set()` built-in (now in the spec) |
| `allow_lambda()` | `with_allow_lambda(Bool)` | `true` | Enable `lambda` expressions |
| `allow_bytes()` | `with_allow_bytes(Bool)` | `true` | Enable `bytes` literals (`b"..."`) |
| `allow_float()` | `with_allow_float(Bool)` | `true` | Enable float literals and float arithmetic |

Non-standard extensions — not part of standard Starlark, disabled by default:

| Accessor | Mutator | Default | Description |
| :--- | :--- | :--- | :--- |
| `allow_recursion()` | `with_allow_recursion(Bool)` | `false` | Allow recursive function calls (the spec forbids recursion) |
| `allow_while()` | `with_allow_while(Bool)` | `false` | Enable `while` loops (not in the spec; the grammar reserves the word only) |
| `allow_top_level_control()` | `with_allow_top_level_control(Bool)` | `false` | Allow `if` / `for` / `while` at module scope (the spec makes these a static error) |
| `allow_global_reassign()` | `with_allow_global_reassign(Bool)` | `false` | Allow re-assigning module-level names (the spec permits a single top-level assignment) |
| `load_binds_globally()` | `with_load_binds_globally(Bool)` | `false` | `load` imports are visible module-wide (legacy compatibility flag) |

Each `with_*` mutator returns a modified copy, so flags can be chained. To
recover the previous permissive behavior, opt the extensions back in:
`Options::default().with_allow_while(true).with_allow_top_level_control(true).with_allow_global_reassign(true)`.

> **Migration note.** Before this change `allow_while`, `allow_top_level_control`,
> and `allow_global_reassign` defaulted to `true`. Scripts that use `while`
> loops, top-level `if`/`for`/`while`, or top-level reassignment under
> `Options::default()` now fail to resolve unless the matching flag is enabled.

[starlark-go]: https://github.com/google/starlark-go/blob/master/syntax/options.go

```mbt check
///|
test {
  let opts = @eval.Options::default()
  // Standard features are enabled.
  assert_eq(opts.allow_set(), true)
  assert_eq(opts.allow_float(), true)
  // Non-standard extensions are disabled by default.
  assert_eq(opts.allow_while(), false)
  assert_eq(opts.allow_top_level_control(), false)
  assert_eq(opts.allow_global_reassign(), false)
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

## `@eval.Module`

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

## `@eval.Predeclared`

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

## `@eval.Universe`

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

## `@eval.Program`

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

## `@eval.DebugFrame`

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
