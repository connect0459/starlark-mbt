///|
/// Encodes a plain MoonBit `String` as a JSON string literal by delegating to
/// `lib/json.encode_to_json`. All escaping is handled by `lib/json`'s string
/// quoting logic, ensuring consistency with the rest of the project.
fn encode_str(s : String) -> String {
  match @json.encode_to_json(
    @value.Value::String(@value.StarlarkString::new(s)),
  ) {
    Ok(js) => js
    Err(e) => abort("unexpected encode error for string: \{e}")
  }
}

///|
/// Converts a Starlark value to a JSON fragment.
///
/// Delegates to `lib/json.encode_to_json` for all types; if encoding fails
/// (non-finite `Float`, `Function`, or other unsupported types), falls back
/// to the Starlark `repr()` wrapped in a JSON string via `encode_str`.
fn value_to_json(v : @value.Value) -> String {
  match @json.encode_to_json(v) {
    Ok(s) => s
    Err(_) => encode_str(v.repr())
  }
}

///|
/// Executes a Starlark script and returns a JSON-encoded result string.
///
/// On success, returns `{"globals":{...},"output":"..."}` where `globals` maps
/// each top-level binding name to its JSON-encoded value and `output` contains
/// all text written by `print()` calls during execution.
///
/// On failure, returns `{"error":"..."}` with the error message.
///
/// **BigInt precision**: Starlark `Int` values are arbitrary-precision integers
/// serialized as bare JSON number tokens. JavaScript's `JSON.parse` converts
/// them to IEEE 754 doubles, so integers whose absolute value exceeds 2^53 will
/// lose precision silently. If lossless handling of large integers is required,
/// consumers should treat the `Int` fields as strings (pass them through a
/// BigInt-aware JSON parser) rather than relying on `JSON.parse`.
///
/// This function is exported for the `wasm-gc` and `js` build targets via the
/// `link` options in `moon.pkg`, making it callable from a JavaScript host
/// through the WebAssembly JS API or an ES module import.
pub fn exec_script(src : String) -> String {
  let out_buf = @buffer.Buffer::Buffer()
  let thread = @eval.Thread::new("exec_script")
  thread.set_print(fn(_, bytes) {
    out_buf.write_bytes(bytes[:])
    out_buf.write_byte(b'\n')
  })
  match @eval.exec_file(thread, "script.star", src, @eval.Options::default()) {
    Err(e) => "{\"error\":\{encode_str(e.msg())}}"
    Ok(m) => {
      let gbuf = StringBuilder::new()
      gbuf.write_string("{")
      let mut first = true
      for name in m.global_names() {
        match m.get(name) {
          None => ()
          Some(v) => {
            if !first {
              gbuf.write_string(",")
            }
            first = false
            gbuf.write_string(encode_str(name))
            gbuf.write_string(":")
            gbuf.write_string(value_to_json(v))
          }
        }
      }
      gbuf.write_string("}")
      let out_json = match @json.encode_to_json(
        @value.Value::String(
          @value.StarlarkString::from_bytes(out_buf.contents()),
        ),
      ) {
        Ok(s) => s
        Err(e) => abort("unexpected encode error for output buffer: \{e}")
      }
      "{\"globals\":\{gbuf.to_string()},\"output\":\{out_json}}"
    }
  }
}
