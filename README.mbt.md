# starlark-mbt

[![CI](https://github.com/connect0459/starlark-mbt/actions/workflows/ci.yml/badge.svg)](https://github.com/connect0459/starlark-mbt/actions/workflows/ci.yml)
[![License: Apache-2.0](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

A MoonBit implementation of the [Starlark](https://github.com/bazelbuild/starlark/blob/master/spec.md)
scripting language interpreter.

All optional features (`set`, `lambda`, `while`, `bytes`, `float`, recursion) are **enabled by default**.

## Packages

| Package | Description |
| :--- | :--- |
| `connect0459/starlark` | Core interpreter: `Thread`, `exec_file`, `eval_expr` |
| `connect0459/starlark/lib/json` | JSON encode / decode extension |
| `connect0459/starlark/lib/math` | Math functions extension (mirrors Python's `math` module) |

## Installation

```sh
moon add connect0459/starlark
```

Then declare the packages you need in your `moon.pkg`:

```text
import {
  "connect0459/starlark",
}
```

## Usage

### Running a Starlark script

```moonbit
test {
  let thread = @starlark.Thread::new("main")
  let src = "result = sum([i * i for i in range(5)])"
  match @starlark.exec_file(thread, "example.star", src, @starlark.Options::default()) {
    Ok(m) =>
      assert_true(@starlark.module_get(m, "result") is Some(@starlark.Value::Int(30L)))
    Err(e) => fail!(e.to_string())
  }
}
```

### Capturing print output

```moonbit
test {
  let buf = StringBuilder::new()
  let thread = @starlark.Thread::with_print("main", fn(s) { buf.write_string(s) })
  let _ = @starlark.exec_file(
    thread, "hello.star",
    "print('hello', 'world')",
    @starlark.Options::default(),
  )
  assert_eq(buf.to_string(), "hello world")
}
```

### Evaluating a single expression

```moonbit
test {
  let thread = @starlark.Thread::new("expr")
  let env = @starlark.StarlarkDict::new()
  match @starlark.eval_expr(thread, "<expr>", "2 ** 10", env) {
    Ok(v) => assert_true(v is @starlark.Value::Int(1024L))
    Err(e) => fail!(e.to_string())
  }
}
```

### Injecting host bindings

```moonbit
test {
  let thread = @starlark.Thread::new("main")
  let predeclared = @starlark.Predeclared::from_map({
    "MAX": @starlark.Value::Int(100L),
  })
  match @starlark.exec_file_with_predeclared(
    thread, "conf.star",
    "ok = MAX >= 50",
    @starlark.Options::default(),
    predeclared,
  ) {
    Ok(m) =>
      assert_true(@starlark.module_get(m, "ok") is Some(@starlark.Value::Bool(true)))
    Err(e) => fail!(e.to_string())
  }
}
```

### Loading modules

```moonbit
test {
  let thread = @starlark.Thread::with_loader(
    "main",
    fn(t, path) {
      match path {
        "utils.star" =>
          @starlark.exec_file(
            t, path,
            "def double(x): return x * 2",
            @starlark.Options::default(),
          )
        _ => Err(@starlark.EvalError::simple("module not found: \{path}"))
      }
    },
  )
  match @starlark.exec_file(
    thread, "main.star",
    "load('utils.star', 'double')\nresult = double(21)",
    @starlark.Options::default(),
  ) {
    Ok(m) =>
      assert_true(@starlark.module_get(m, "result") is Some(@starlark.Value::Int(42L)))
    Err(e) => fail!(e.to_string())
  }
}
```

### Error handling

```moonbit
test {
  let thread = @starlark.Thread::new("main")
  match @starlark.exec_file(thread, "bad.star", "x = 1 // 0", @starlark.Options::default()) {
    Err(e) => {
      assert_true(e.msg().contains("zero"))
      // e.backtrace() returns a formatted call stack
    }
    Ok(_) => fail!("expected error")
  }
}
```

### JSON extension

```moonbit
test {
  let json_mod = @json.json_module()
  let predeclared = @starlark.Predeclared::from_map({ "json": json_mod })
  let thread = @starlark.Thread::new("main")
  let src =
    #|data = json.decode('{"answer": 42}')
    #|answer = data["answer"]
  match @starlark.exec_file_with_predeclared(
    thread, "data.star", src, @starlark.Options::default(), predeclared,
  ) {
    Ok(m) =>
      assert_true(@starlark.module_get(m, "answer") is Some(@starlark.Value::Int(42L)))
    Err(e) => fail!(e.to_string())
  }
}
```

### Math extension

```moonbit
test {
  let math_mod = @math.math_module()
  let predeclared = @starlark.Predeclared::from_map({ "math": math_mod })
  let thread = @starlark.Thread::new("main")
  let src = "r = math.floor(math.sqrt(2.0) * 1000)"
  match @starlark.exec_file_with_predeclared(
    thread, "calc.star", src, @starlark.Options::default(), predeclared,
  ) {
    Ok(m) =>
      assert_true(@starlark.module_get(m, "r") is Some(@starlark.Value::Int(1414L)))
    Err(e) => fail!(e.to_string())
  }
}
```

## Documentation

- [API Reference](docs/api.md) — Full API reference for all packages

## License

Apache-2.0
