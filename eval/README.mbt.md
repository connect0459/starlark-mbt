# `eval` package

The main entry point for parsing, resolving, and executing Starlark. Import
`connect0459/starlark/eval` to run scripts, evaluate expressions, compile reusable
programs, and configure the Starlark dialect.

## Key types

| Type | Description |
| :--- | :--- |
| `Thread` | Execution context: print callback, loader, step budget, thread-local storage |
| `Options` | Dialect flags (which language extensions are enabled) |
| `Module` | Frozen result of a successful `exec_file`; holds the script's globals |
| `Program` | Pre-compiled program that can be executed multiple times without re-parsing |
| `Predeclared` | Extra host bindings injected before user globals |
| `Universe` | The built-in environment (default: standard Starlark builtins) |
| `DebugFrame` | Read-only snapshot of an active call frame |

## Quick start

### Execute a Starlark file

```mbt check
///|
test {
  let thread = @eval.Thread::new("main")
  match
    @eval.exec_file(
      thread,
      "build.star",
      "greeting = 'hello ' + 'world'",
      @eval.Options::default(),
    ) {
    Ok(m) =>
      match m.get("greeting") {
        Some(@value.Value::String(s)) => assert_eq(s.raw(), "hello world")
        _ => fail("expected string")
      }
    Err(e) => fail(e.to_string())
  }
}
```

### Evaluate a single expression

```mbt check
///|
test {
  let thread = @eval.Thread::new("expr")
  let env = @value.StringDict::new()
  env.set("n", @value.Value::new_int(7L))
  match @eval.eval_expr(thread, "<expr>", "n * 6", env) {
    Ok(@value.Value::Int(v)) => assert_eq(v, 42N)
    _ => fail("expected int 42")
  }
}
```

### Inject host bindings (predeclared)

```mbt check
///|
test {
  let thread = @eval.Thread::new("main")
  let predeclared = @eval.Predeclared::from_map({
    "VERSION": @value.Value::new_string("1.0"),
  })
  match
    @eval.exec_file_with_predeclared(
      thread,
      "check.star",
      "v = VERSION",
      @eval.Options::default(),
      predeclared,
    ) {
    Ok(m) => assert_true(m.get("v") is Some(@value.Value::String(_)))
    Err(e) => fail(e.to_string())
  }
}
```

### Compile a program for repeated execution

```mbt check
///|
test {
  let prog_result = @eval.source_program(
    "lib.star",
    "def double(n): return n * 2",
    @eval.Options::default(),
    fn(_) { false },
  )
  match prog_result {
    Ok(prog) => {
      let t1 = @eval.Thread::new("run1")
      let t2 = @eval.Thread::new("run2")
      // prog.init() returns Result[Module, EvalError]; execute independently per thread.
      match prog.init(t1, @eval.Predeclared::new()) {
        Ok(m) => assert_true(m.get("double") is Some(@value.Value::Function(_)))
        Err(e) => fail(e.to_string())
      }
      let _ = prog.init(t2, @eval.Predeclared::new())
    }
    Err(e) => fail(e.to_string())
  }
}
```

### Thread cancellation

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

### Non-standard dialect options

```mbt check
///|
test {
  let opts = @eval.Options::default().with_allow_recursion(true)
  let thread = @eval.Thread::new("main")
  let src = "def fact(n): return 1 if n == 0 else n * fact(n - 1)"
  let _ = @eval.exec_file(thread, "r.star", src, opts)
}
```

## API reference

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

### Operator dispatch

Apply Starlark operators by name from host code.

| Function | Signature | Description |
| :--- | :--- | :--- |
| `binary` | `(String, @value.Value, @value.Value) -> Result[@value.Value, @errors.EvalError]` | Apply a binary operator by name (`"+"`, `"-"`, `"*"`, etc.) |
| `unary` | `(String, @value.Value) -> Result[@value.Value, @errors.EvalError]` | Apply a unary operator by name (`"-"`, `"~"`, `"not"`) |
| `compare` | `(String, @value.Value, @value.Value) -> Result[Bool, @errors.EvalError]` | Apply a comparison operator by name (`"=="`, `"<"`, etc.) |

---

## `Thread`

Holds execution context: print callback, load callback, call stack, and step budget.

### Constructors

| Constructor | Signature | Description |
| :--- | :--- | :--- |
| `Thread::new` | `(String) -> Thread` | Thread with default print (stdout) and no loader |
| `Thread::with_print` | `(String, (Thread, String) -> Unit) -> Thread` | Thread with a custom print callback |
| `Thread::with_loader` | `(String, (Thread, String) -> Result[Module, @errors.EvalError]) -> Thread` | Thread with a module loader |
| `Thread::with_step_budget` | `(String, Int) -> Thread` | Thread that halts after `n` evaluation steps |

The `with_*` constructors are composable: start from `Thread::new(name)` then call
`set_print`, `set_loader`, `set_max_steps`, and `set_on_max_steps` in any combination.

### Accessors

| Method | Returns | Description |
| :--- | :--- | :--- |
| `name()` | `String` | Thread name |
| `max_recursion_depth()` | `Int` | Call depth limit (default 100) |
| `max_steps()` | `Int?` | Step budget; `None` if uncapped |
| `execution_steps()` | `Int` | Steps consumed so far |
| `call_stack_depth()` | `Int` | Current call depth |
| `call_stack()` | `@errors.CallStack` | Snapshot of the current call stack |
| `call_frame(Int)` | `@errors.CallFrame?` | Frame at depth `n` (0 = innermost) |
| `debug_frame(Int)` | `DebugFrame?` | Snapshot of an active call frame (0 = innermost Starlark function) |

### Customization (mutators)

| Method | Description |
| :--- | :--- |
| `set_print((Thread, String) -> Unit)` | Set the print callback |
| `set_loader((Thread, String) -> Result[Module, @errors.EvalError])` | Set the module loader |

### Step budget control

| Method | Description |
| :--- | :--- |
| `set_max_steps(Int)` | Set the step budget (does not reset the accumulated count) |
| `set_on_max_steps((Thread) -> Unit)` | Callback invoked when the budget is reached instead of halting |
| `reset_steps()` | Reset the accumulated step counter to zero |

### Thread-local storage

| Method | Description |
| :--- | :--- |
| `set_local(String, @value.Value)` | Store a value under a string key |
| `get_local(String) -> @value.Value?` | Retrieve a stored value; `None` if not set |

### Cancellation

| Method | Description |
| :--- | :--- |
| `cancel(String)` | Signal the thread to halt; raises `EvalError` at the next step check |
| `uncancel()` | Clear a previous cancel signal |

---

## `Options`

Feature flags that control the Starlark dialect. `Options::default()` is the
spec-conformant dialect.

Standard features — part of the Starlark spec, enabled by default:

| Accessor | Mutator | Default | Description |
| :--- | :--- | :--- | :--- |
| `allow_set()` | `with_allow_set(Bool)` | `true` | Enable `set` literals and the `set()` built-in |
| `allow_lambda()` | `with_allow_lambda(Bool)` | `true` | Enable `lambda` expressions |
| `allow_bytes()` | `with_allow_bytes(Bool)` | `true` | Enable `bytes` literals (`b"..."`) |
| `allow_float()` | `with_allow_float(Bool)` | `true` | Enable float literals and float arithmetic |

Non-standard extensions — disabled by default:

| Accessor | Mutator | Default | Description |
| :--- | :--- | :--- | :--- |
| `allow_recursion()` | `with_allow_recursion(Bool)` | `false` | Allow recursive function calls (the spec forbids recursion) |
| `allow_while()` | `with_allow_while(Bool)` | `false` | Enable `while` loops |
| `allow_top_level_control()` | `with_allow_top_level_control(Bool)` | `false` | Allow `if`/`for`/`while` at module scope |
| `allow_global_reassign()` | `with_allow_global_reassign(Bool)` | `false` | Allow re-assigning module-level names |
| `load_binds_globally()` | `with_load_binds_globally(Bool)` | `false` | `load` imports are visible module-wide |

Each `with_*` mutator returns a modified copy, so flags can be chained.

```mbt check
///|
test {
  let opts = @eval.Options::default()
  assert_eq(opts.allow_set(), true)
  assert_eq(opts.allow_float(), true)
  assert_eq(opts.allow_while(), false)
  assert_eq(opts.allow_top_level_control(), false)
  assert_eq(opts.allow_global_reassign(), false)
  assert_eq(opts.load_binds_globally(), false)
}
```

---

## `Module`

The result of a successful `exec_file` call. Its globals dict is frozen on return.

| Method | Signature | Description |
| :--- | :--- | :--- |
| `Module::new()` | `-> Module` | Empty unfrozen module |
| `Module::from_map(Map[String, @value.Value])` | `-> Module` | Construct from a map (for testing) |
| `get(String)` | `-> @value.Value?` | Look up a global by name |
| `global_names()` | `-> Array[String]` | Names of all defined globals |
| `globals_count()` | `-> Int` | Number of defined globals |
| `predeclared_names()` | `-> Array[String]` | Names of predeclared bindings |
| `predeclared_count()` | `-> Int` | Number of predeclared bindings |
| `is_frozen()` | `-> Bool` | Always `true` after `exec_file` returns |
| `freeze()` | `-> Unit` | Freeze the module manually (rarely needed) |

---

## `Program`

A parsed-and-resolved Starlark program that can be executed multiple times without
re-parsing. Unlike `exec_file`, `Program::init` does **not** freeze the returned module.

`Program::write() -> Bytes` serializes a compiled program so it can be persisted and
reloaded with `compiled_program`. The format is **not** byte-compatible with starlark-go.

| Method | Signature | Description |
| :--- | :--- | :--- |
| `filename()` | `() -> String` | Source file name used during compilation |
| `num_loads()` | `() -> Int` | Number of `load` statements in the file |
| `load(Int)` | `(Int) -> (String, @errors.Position)` | Path and position of the i-th `load` statement |
| `options()` | `() -> Options` | The dialect options the program was resolved with |
| `init(Thread, Predeclared)` | `-> Result[Module, @errors.EvalError]` | Execute the program and return an **unfrozen** module |
| `write()` | `() -> Bytes` | Serialize the resolved program for later reload |

---

## `Predeclared` and `Universe`

`Predeclared` holds extra bindings injected before user globals; scripts can read but
not reassign them. `Universe` is the predeclared built-in environment shared across all
threads.

| Constructor / Method | `Predeclared` | `Universe` |
| :--- | :--- | :--- |
| Empty constructor | `Predeclared::new()` | `Universe::new()` |
| From map | `Predeclared::from_map(Map[String, Value])` | `Universe::from_map(Map[String, Value])` |
| Standard builtins | — | `Universe::standard()` |
| `get(String) -> Value?` | Look up a name | Look up a built-in |
| `set(String, Value)` | Add or replace | Add or replace |
| `has(String) -> Bool` | Membership test | Membership test |
| `delete(String) -> Bool` | Remove; returns whether present | Remove; returns whether present |
| `keys() -> Array[String]` | All bound names | All built-in names |
| `values() -> Array[Value]` | All bound values | All built-in values |
| `each((String, Value) -> Unit)` | Iterate all pairs | Iterate all pairs |

---

## Intentional extensions and dialect differences

The following behaviours differ from starlark-go by design.

### Spell-hint on unexpected keyword argument

When a function call passes an unrecognised keyword argument, the error
message includes a spell-hint:

```text
function f got an unexpected keyword argument "nme" (did you mean "name"?)
```

starlark-go omits the parenthetical hint. This is a quality-of-life
extension; it does not affect correctness or accepted syntax.

### `(1 << 31) in range(0, 1 << 32)` returns `True`

starlark-go evaluates this as `False` because `rangeValue.contains` calls
`AsInt32` to classify the needle, and `AsInt32` returns an error for any
value outside the signed 32-bit range. `1<<31 = 2,147,483,648` exceeds
`math.MaxInt32`, causing `AsInt32` to return an out-of-range error; `contains`
treats any such error as "not in range" and returns `false` without evaluating
the bounds. This implementation performs the containment check with full Int64
precision, returning `True`.

---

## `DebugFrame`

A read-only snapshot of an active Starlark call frame. Obtain via `Thread::debug_frame(depth)`.

| Method | Returns | Description |
| :--- | :--- | :--- |
| `callable()` | `@value.Value` | The `Function` or `Builtin` executing in this frame |
| `num_locals()` | `Int` | Total number of local variables |
| `frame_local(Int)` | `(@errors.Binding, @value.Value?)` | Binding descriptor and current value of the i-th local |
| `local_by_name(String)` | `@value.Value?` | Current value of the named local; `None` if absent |
| `position()` | `@errors.Position` | Current execution position within the frame (stub: always returns an invalid position) |
