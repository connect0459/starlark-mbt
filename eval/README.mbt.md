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
