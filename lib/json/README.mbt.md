# `lib/json` package

JSON encode and decode extension for Starlark. Import `connect0459/starlark/lib/json`
and inject `json_module()` as a predeclared binding to expose `json.encode`,
`json.decode`, and `json.indent` inside Starlark scripts.

## MoonBit-level API

| Function | Signature | Description |
| :--- | :--- | :--- |
| `json_module()` | `() -> @value.Value` | Returns the `json` module value to inject |
| `encode_to_json(@value.Value)` | `-> Result[String, String]` | Encode a Starlark value to a JSON string |
| `decode_from_json(String, @value.Value?)` | `-> Result[@value.Value, String]` | Decode a JSON string; `default` returned on parse error when provided |
| `indent_json(String, String, String)` | `-> Result[String, String]` | Pretty-print JSON with `prefix` and `indent` |

## Starlark-level functions (inside scripts)

After injecting `json_module()` as `"json"` in predeclared:

| Function | Description |
| :--- | :--- |
| `json.encode(value)` | Serialize to JSON; dict keys sorted; `<`, `>`, `&`, U+2028, U+2029 HTML-escaped; other non-ASCII Unicode as raw UTF-8 |
| `json.encode_indent(value, prefix=, indent=)` | Serialize with indentation |
| `json.decode(x, default=)` | Parse JSON; returns `default` on error if provided |
| `json.indent(x, prefix=, indent=)` | Pretty-print a JSON string |

## Starlark → JSON type mapping

| Starlark | JSON |
| :--- | :--- |
| `None` | `null` |
| `True` / `False` | `true` / `false` |
| `int` | number |
| `float` | number |
| `string` | string |
| `list` / `tuple` / `range` / `set` | array |
| `dict` | object (keys must be strings) |
| `ExtVal` with `get_attr_names()` | object (attribute names sorted, values encoded recursively) |

## Dialect notes

| Behaviour | This library | starlark-go |
| :--- | :--- | :--- |
| Raw control characters in JSON strings | Rejected (`json.decode` raises an error) — RFC 7159 §7 compliance | Accepted (safe-path optimisation bypasses validation) |
| `json.indent` structural validation | Missing separators (`,`/`:`), trailing commas, surplus tokens, and empty input are rejected with Go-compatible error messages | Same |
| `json.indent` on Float64-overflowing number tokens (e.g. `1e999`) | Passes through as-is (semantic validity not checked) | Same |
| Nesting depth limit in `json.indent` | No depth limit — the iterative state-machine formatter handles arbitrary nesting without stack growth | Same (`encoding/json.Indent` is also unlimited) |
| Nesting depth limit in `json.decode` / `json.encode` | Rejected at 10 000 levels with `nesting depth limit exceeded` — intentional hardening against deeply-nested input | Go uses recursive descent with goroutine-stack growth; no hard limit |

`json.decode` rejects unescaped control characters (U+0000–U+001F) inside JSON string
literals. RFC 7159 §7 explicitly prohibits them; the `\n`, `\r`, `\t` etc. escape sequences
must be used instead. starlark-go accepts raw control characters as a side-effect of an
optimisation that skips full validation for simple ASCII strings; this library prioritises
RFC conformance.

## Quick start

Encoding from MoonBit directly:

```mbt check
///|
test {
  let v = @value.Value::new_list([
    @value.Value::new_int(1L),
    @value.Value::new_int(2L),
    @value.Value::Bool(true),
  ])
  match @json.encode_to_json(v) {
    Ok(s) => assert_eq(s, "[1,2,true]")
    Err(e) => fail(e)
  }
}
```

Decoding a JSON string from MoonBit:

```mbt check
///|
test {
  match @json.decode_from_json("{\"x\":1}", None) {
    Ok(@value.Value::Dict(d)) =>
      assert_true(d.get(@value.Value::new_string("x")) is Ok(Some(_)))
    _ => fail("expected dict")
  }
}
```

Injecting into Starlark scripts:

```mbt nocheck
let thread = @eval.Thread::new("main")
let predeclared = @eval.Predeclared::from_map({ "json": @json.json_module() })
let src = "payload = json.encode({\"key\": [1, 2, 3]})"
let _ = @eval.exec_file_with_predeclared(thread, "data.star", src,
  @eval.Options::default(), predeclared)
```
