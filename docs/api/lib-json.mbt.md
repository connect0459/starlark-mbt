# `lib/json` package

Inject `json_module()` as a predeclared binding to make all functions available in Starlark scripts.

```moonbit nocheck
import {
  "connect0459/starlark/eval",
  "connect0459/starlark/value",
  "connect0459/starlark/lib/json",
}
```

## MoonBit-level API

| Function | Signature | Description |
| :--- | :--- | :--- |
| `json_module()` | `() -> @value.Value` | Returns the `json` module value to inject |
| `encode_to_json(@value.Value)` | `-> Result[String, String]` | Encode a Starlark value to a JSON string |
| `decode_from_json(String, @value.Value?)` | `-> Result[@value.Value, String]` | Decode a JSON string; `default` returned on parse error when provided |
| `indent_json(String, String, String)` | `-> Result[String, String]` | Pretty-print JSON with `prefix` and `indent` |

## Starlark-level functions (inside scripts)

| Function | Description |
| :--- | :--- |
| `json.encode(value)` | Serialize to JSON; dict keys sorted; non-ASCII output as raw UTF-8 |
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
