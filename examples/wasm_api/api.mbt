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
/// Formats a successfully executed `Module` as the standard JSON response
/// `{"globals":{...},"output":"..."}`.
fn format_module(m : @eval.Module, out_buf : @buffer.Buffer) -> String {
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

///|
/// Shared execution engine: sets up a thread, runs `src` with `opts` and
/// `predeclared`, and returns a JSON-encoded result string.
fn do_exec(
  src : String,
  opts : @eval.Options,
  predeclared : @eval.Predeclared,
) -> String {
  let out_buf = @buffer.Buffer::Buffer()
  let thread = @eval.Thread::new("exec")
  thread.set_print(fn(_, bytes) {
    out_buf.write_bytes(bytes[:])
    out_buf.write_byte(b'\n')
  })
  match
    @eval.exec_file_with_predeclared(thread, "script.star", src, opts, predeclared) {
    Err(e) => "{\"error\":\{encode_str(e.msg())}}"
    Ok(m) => format_module(m, out_buf)
  }
}

///|
/// Parses a JSON object string into an `Options` value.
///
/// Returns `Ok(options)` on success, or `Err(error_message)` if `options_json`
/// is not valid JSON, not a JSON object, contains a non-boolean value, or
/// contains an unrecognised option key.
///
/// Known option keys (all map to `Bool`):
/// `allow_set`, `allow_recursion`, `allow_lambda`, `allow_while`,
/// `allow_bytes`, `allow_float`, `allow_global_reassign`,
/// `allow_top_level_control`, `load_binds_globally`.
fn parse_options_json(options_json : String) -> Result[@eval.Options, String] {
  let parsed = match @json.decode_from_json(options_json, None) {
    Err(msg) => return Err(msg)
    Ok(v) => v
  }
  let d = match parsed {
    @value.Value::Dict(d) => d
    _ => return Err("options must be a JSON object")
  }
  let mut opts = @eval.Options::default()
  let mut err : String? = None
  d.each(fn(k, v) {
    if err is Some(_) {
      return
    }
    let key = match k {
      @value.Value::String(s) => s.raw()
      _ => {
        err = Some("option key must be a string")
        return
      }
    }
    let flag = match v {
      @value.Value::Bool(b) => b
      _ => {
        err = Some("option \"\{key}\" must be a boolean")
        return
      }
    }
    match key {
      "allow_set" => opts = opts.with_allow_set(flag)
      "allow_recursion" => opts = opts.with_allow_recursion(flag)
      "allow_lambda" => opts = opts.with_allow_lambda(flag)
      "allow_while" => opts = opts.with_allow_while(flag)
      "allow_bytes" => opts = opts.with_allow_bytes(flag)
      "allow_float" => opts = opts.with_allow_float(flag)
      "allow_global_reassign" => opts = opts.with_allow_global_reassign(flag)
      "allow_top_level_control" => opts = opts.with_allow_top_level_control(flag)
      "load_binds_globally" => opts = opts.with_load_binds_globally(flag)
      _ => {
        err = Some("unknown option: \"\{key}\"")
        return
      }
    }
  })
  match err {
    Some(msg) => Err(msg)
    None => Ok(opts)
  }
}

///|
/// Parses a JSON object string into a `Predeclared` binding set.
///
/// Returns `Ok(predeclared)` on success, or `Err(json_error_message)` if
/// `env_json` is not valid JSON or not a JSON object.
fn parse_env_json(
  env_json : String,
) -> Result[@eval.Predeclared, String] {
  let parsed = match @json.decode_from_json(env_json, None) {
    Err(msg) => return Err(msg)
    Ok(v) => v
  }
  match parsed {
    @value.Value::Dict(d) => {
      let map : Map[String, @value.Value] = {}
      d.each(fn(k, v) {
        if k is @value.Value::String(s) {
          map[s.raw()] = v
        }
      })
      Ok(@eval.Predeclared::from_map(map))
    }
    _ => Err("predeclared env must be a JSON object")
  }
}

///|
/// Executes a Starlark script with host-injected predeclared bindings and
/// returns a JSON-encoded result string.
///
/// `env_json` must be a JSON object whose keys are binding names and whose
/// values are the corresponding Starlark-compatible JSON values (null, bool,
/// number, string, array, object). The injected names are visible to the script
/// before any user-defined globals are evaluated and are **not** included in
/// the returned `globals` map — unless the script assigns to the same name, in
/// which case the assignment shadows the predeclared binding and the new value
/// appears in `globals` as a regular global.
///
/// On success, returns `{"globals":{...},"output":"..."}` where `globals` maps
/// each top-level binding to its JSON-encoded value and `output` contains all
/// text written by `print()`. On failure (invalid `env_json`, parse error, or
/// runtime error), returns `{"error":"..."}`.
///
/// **BigInt precision**: Starlark `Int` values are arbitrary-precision integers
/// serialized as bare JSON number tokens. JavaScript's `JSON.parse` converts
/// them to IEEE 754 doubles, so integers whose absolute value exceeds 2^53 will
/// lose precision silently. If lossless handling of large integers is required,
/// consumers should treat `Int` fields as strings (pass them through a
/// BigInt-aware JSON parser) rather than relying on `JSON.parse`.
///
/// This function is exported for the `wasm-gc` and `js` build targets via the
/// `link` options in `moon.pkg`, making it callable from a JavaScript host
/// through the WebAssembly JS API or an ES module import.
pub fn exec_script_with_env(src : String, env_json : String) -> String {
  let predeclared = match parse_env_json(env_json) {
    Err(msg) => return "{\"error\":\{encode_str(msg)}}"
    Ok(p) => p
  }
  do_exec(src, @eval.Options::default(), predeclared)
}

///|
/// Executes a Starlark script with caller-supplied dialect options and returns
/// a JSON-encoded result string.
///
/// `options_json` must be a JSON object mapping flag names to boolean values.
/// Recognised keys: `allow_set`, `allow_recursion`, `allow_lambda`,
/// `allow_while`, `allow_bytes`, `allow_float`, `allow_global_reassign`,
/// `allow_top_level_control`, `load_binds_globally`. Missing keys fall back to
/// `Options::default()`. An unknown key or a non-boolean value produces an
/// `{"error":"..."}` response.
///
/// On success, returns `{"globals":{...},"output":"..."}` with the same
/// semantics as `exec_script`. On failure, returns `{"error":"..."}`.
///
/// **BigInt precision**: see `exec_script_with_env` for caveats on large integers.
///
/// This function is exported for the `wasm-gc` and `js` build targets via the
/// `link` options in `moon.pkg`, making it callable from a JavaScript host
/// through the WebAssembly JS API or an ES module import.
pub fn exec_script_with_options(src : String, options_json : String) -> String {
  let opts = match parse_options_json(options_json) {
    Err(msg) => return "{\"error\":\{encode_str(msg)}}"
    Ok(o) => o
  }
  do_exec(src, opts, @eval.Predeclared::new())
}

///|
/// Executes a Starlark script and returns a JSON-encoded result string.
///
/// Equivalent to `exec_script_with_env(src, "{}")` with no predeclared
/// bindings. See that function for the full output format, BigInt precision
/// notes, and predeclared-vs-global semantics.
///
/// This function is exported for the `wasm-gc` and `js` build targets via the
/// `link` options in `moon.pkg`, making it callable from a JavaScript host
/// through the WebAssembly JS API or an ES module import.
pub fn exec_script(src : String) -> String {
  exec_script_with_env(src, "{}")
}
