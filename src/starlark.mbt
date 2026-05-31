///|
/// Execution context carrying the print callback, load callback, call stack,
/// and step budget for a single Starlark evaluation.
pub type Thread = @eval.Thread

///|
/// The result of executing a Starlark file: a frozen mapping of global names
/// to their values.
pub type Module = @eval.Module

///|
/// Feature-flag set controlling which optional Starlark dialect features are
/// enabled. All flags default to `true`.
pub type Options = @eval.Options

///|
/// The set of predeclared built-in bindings shared across all modules in a
/// program (e.g. `None`, `True`, `print`, `range`).
pub type Universe = @eval.Universe

///|
/// Extra per-execution bindings injected before user globals, visible to
/// both the resolver and evaluator but not exported in the resulting Module.
pub type Predeclared = @eval.Predeclared

///|
/// A Starlark value. Covers all built-in types: `None`, `Bool`, `Int`,
/// `Float`, `String`, `Bytes`, `List`, `Tuple`, `Dict`, `Set`, `Range`,
/// `Function`, `Builtin`, `BoundMethod`, `Module`, and embedder extensions.
pub type Value = @value.Value

///|
/// An insertion-ordered mutable mapping from Starlark hashable keys to values.
pub type StarlarkDict = @value.StarlarkDict

///|
/// A mutable, ordered sequence of Starlark values.
pub type StarlarkList = @value.StarlarkList

///|
/// An immutable Starlark string backed by a pre-computed UTF-8 byte array for
/// O(1) byte indexing.
pub type StarlarkString = @value.StarlarkString

///|
/// A built-in function callable from Starlark. May be a named dispatcher or
/// a closure carrying an arbitrary host implementation.
pub type StarlarkBuiltinFunc = @value.StarlarkBuiltinFunc

///|
/// A forward-only iterator over a Starlark sequence or mapping.
pub type StarlarkIterator = @value.StarlarkIterator

///|
/// Trait that embedder-defined custom types must implement to participate in
/// the Starlark value system.
pub type CustomValue = @value.CustomValue

///|
/// Wraps a `CustomValue` in the `Value` sum type.
pub fn new_custom_value(cv : CustomValue) -> Value {
  @value.Value::ExtVal(cv)
}

///|
/// The parsed AST of a complete Starlark source file.
pub type SyntaxFile = @syntax.File

///|
/// A single parsed Starlark expression node.
pub type SyntaxExpr = @syntax.Expr

///|
/// A runtime error produced during Starlark evaluation, carrying a message
/// and a call stack snapshot.
pub type EvalError = @errors.EvalError

///|
/// A parse-time error with source position.
pub type SyntaxError = @errors.SyntaxError

///|
/// A name-resolution error with source position.
pub type ResolveError = @errors.ResolveError

///|
/// A source location: 1-based line and column, matching starlark-go's
/// `syntax.Position` convention.
pub type Position = @errors.Position

///|
/// A local variable name together with its definition position; used by the
/// debugger API.
pub type Binding = @errors.Binding

///|
/// A single frame in a Starlark call stack, recording the function name and
/// the source position of the call site.
pub type CallFrame = @errors.CallFrame

///|
/// An ordered snapshot of call frames, outermost first.
pub type CallStack = @errors.CallStack

///|
/// A read-only snapshot of an active Starlark call frame; returned by
/// `Thread.debug_frame`.
pub type DebugFrame = @eval.DebugFrame

///|
/// A parsed-and-resolved Starlark program that can be executed repeatedly
/// without re-parsing or re-resolving.
pub type Program = @eval.Program

///|
/// Parses `src` as a Starlark source file and returns its AST.
pub fn parse_file(
  filename : String,
  src : String,
) -> Result[SyntaxFile, EvalError] {
  match @parser.parse_file(filename, src) {
    Ok(f) => Ok(f)
    Err(e) => Err(@errors.EvalError::simple(e.to_string()))
  }
}

///|
/// Parses `src` as a single Starlark expression and returns its AST node.
pub fn parse_expr(
  filename : String,
  src : String,
) -> Result[SyntaxExpr, EvalError] {
  match @parser.parse_expr(filename, src) {
    Ok(e) => Ok(e)
    Err(e) => Err(@errors.EvalError::simple(e.to_string()))
  }
}

///|
/// Evaluates a pre-parsed expression node under `opts` with the bindings in
/// `env` as the global environment.
pub fn eval_parsed_expr(
  thread : Thread,
  expr : SyntaxExpr,
  opts : Options,
  env : StarlarkDict,
) -> Result[Value, EvalError] {
  @eval.eval_parsed_expr(thread, expr, opts, env)
}

///|
/// Parses and resolves `src` without executing it, returning an immutable
/// `Program` that can be executed repeatedly via `Program.init`.
pub fn source_program(
  filename : String,
  src : String,
  opts : Options,
  is_predeclared : (String) -> Bool,
) -> Result[Program, EvalError] {
  @eval.source_program(filename, src, opts, is_predeclared)
}

///|
/// Like `source_program` but also returns the parsed `SyntaxFile` alongside
/// the `Program`.
pub fn source_program_with_file(
  filename : String,
  src : String,
  opts : Options,
  is_predeclared : (String) -> Bool,
) -> Result[(SyntaxFile, Program), EvalError] {
  @eval.source_program_with_file(filename, src, opts, is_predeclared)
}

///|
/// Resolves an already-parsed `SyntaxFile` into an executable `Program`.
pub fn file_program(
  file : SyntaxFile,
  opts : Options,
  is_predeclared : (String) -> Bool,
) -> Result[Program, EvalError] {
  @eval.file_program(file, opts, is_predeclared)
}

///|
/// Parses, resolves, and executes a Starlark source file; returns the frozen
/// module whose globals are the file's top-level bindings.
pub fn exec_file(
  thread : Thread,
  filename : String,
  src : String,
  opts : Options,
) -> Result[Module, EvalError] {
  @eval.exec_file(thread, filename, src, opts)
}

///|
/// Like `exec_file` but replaces the default built-in universe with
/// `universe`, allowing the embedder to override or extend predeclared names.
pub fn exec_file_with_universe(
  thread : Thread,
  filename : String,
  src : String,
  opts : Options,
  universe : Universe,
) -> Result[Module, EvalError] {
  @eval.exec_file_with_universe(thread, filename, src, opts, universe)
}

///|
/// Like `exec_file` but injects extra `predeclared` bindings that are visible
/// to the script but not included in the returned module's globals.
pub fn exec_file_with_predeclared(
  thread : Thread,
  filename : String,
  src : String,
  opts : Options,
  predeclared : Predeclared,
) -> Result[Module, EvalError] {
  @eval.exec_file_with_predeclared(thread, filename, src, opts, predeclared)
}

///|
/// Parses and evaluates a single Starlark expression with the default options,
/// using `env` as the global environment.
pub fn eval_expr(
  thread : Thread,
  filename : String,
  src : String,
  env : StarlarkDict,
) -> Result[Value, EvalError] {
  @eval.eval_expr(thread, filename, src, env)
}

///|
/// Like `eval_expr` but accepts explicit `opts`.
pub fn eval_expr_with_opts(
  thread : Thread,
  filename : String,
  src : String,
  opts : Options,
  env : StarlarkDict,
) -> Result[Value, EvalError] {
  @eval.eval_expr_with_opts(thread, filename, src, opts, env)
}

///|
/// Executes one REPL chunk: parses `src`, resolves it against the existing
/// `globals` dict, evaluates it, and writes any new or updated bindings back
/// into `globals`.
pub fn exec_repl_chunk(
  thread : Thread,
  filename : String,
  src : String,
  globals : StarlarkDict,
  opts : Options,
) -> Result[Unit, EvalError] {
  @eval.exec_repl_chunk(thread, filename, src, globals, opts)
}

///|
/// Returns the value bound to `name` in the module's global namespace, or
/// `None` if the name is not present.
pub fn module_get(m : Module, name : String) -> Value? {
  m.get(name)
}

///|
/// Returns the Starlark `repr(v)` string — a quoted, round-trip-safe
/// representation.
pub fn repr(v : Value) -> String {
  @value.repr(v)
}

///|
/// Returns the Starlark `str(v)` string — unquoted for strings, `repr` for
/// everything else.
pub fn to_str(v : Value) -> String {
  @value.to_str(v)
}

///|
/// Returns the Starlark `type(v)` string (e.g. `"int"`, `"list"`).
pub fn type_name(v : Value) -> String {
  @value.type_name(v)
}

///|
/// Returns the boolean truth value of `v`, as used by `if`, `while`, `and`,
/// and `or` expressions.
pub fn truth(v : Value) -> Bool {
  @value.truth(v)
}

///|
/// Returns `true` if `a == b` under Starlark semantics, including cross-type
/// `Int`/`Float` comparison and NaN inequality.
pub fn starlark_equals(a : Value, b : Value) -> Bool {
  @value.starlark_equals(a, b)
}

///|
/// Wraps `starlark_equals` in a `Result`; always succeeds.
pub fn equal(a : Value, b : Value) -> Result[Bool, EvalError] {
  Ok(@value.starlark_equals(a, b))
}

///|
/// Converts an `Int` or `Float` value to `Int64`, returning `None` if the
/// value is out of range, NaN, or infinite.
pub fn number_to_int(v : Value) -> Int64? {
  match v {
    @value.Value::Int(n) =>
      if n.compare_int64(@int64.MAX_VALUE) > 0 ||
        n.compare_int64(@int64.MIN_VALUE) < 0 {
        None
      } else {
        Some(n.to_int64())
      }
    @value.Value::Float(f) =>
      if f.is_nan() || f.is_inf() {
        None
      } else {
        Some(f.to_int64())
      }
    _ => None
  }
}

///|
/// Extracts a `Double` from an `Int` or `Float` value. Returns `(value, true)`
/// on success, `(0.0, false)` if `v` is neither numeric type.
pub fn as_float(v : Value) -> (Double, Bool) {
  match v {
    @value.Value::Float(f) => (f, true)
    @value.Value::Int(n) => (@value.bigint_to_double(n), true)
    _ => (0.0, false)
  }
}

///|
/// Extracts the raw `String` from a Starlark `String` value. Returns
/// `("", false)` if `v` is not a string.
pub fn as_string(v : Value) -> (String, Bool) {
  match v {
    @value.Value::String(s) => (s.raw(), true)
    _ => ("", false)
  }
}

///|
/// Returns the sequence length of `v` (list, tuple, string, bytes, range),
/// or `-1` if `v` has no length.
pub fn len_of(v : Value) -> Int {
  match @value.length_of(v) {
    Ok(n) => n
    Err(_) => -1
  }
}

///|
/// Returns an iterator over the elements of `v`. Fails if `v` is not
/// iterable.
pub fn iterate(v : Value) -> Result[StarlarkIterator, EvalError] {
  match @value.iterate(v) {
    Ok(it) => Ok(it)
    Err(msg) => Err(@errors.EvalError::simple(msg))
  }
}

///|
/// Invokes a Starlark callable from host code with positional `args` and
/// keyword `kwargs`.
pub fn call(
  thread : Thread,
  func : Value,
  args : Array[Value],
  kwargs : Array[(String, Value)],
) -> Result[Value, EvalError] {
  @eval.call(thread, func, args, kwargs)
}

///|
/// A string-keyed dict of `Value`s; used by the embedding API to pass named
/// globals or inspect module exports.
pub struct StringDict {
  priv data : Map[String, Value]
}

///|
/// Creates an empty `StringDict`.
pub fn StringDict::new() -> StringDict {
  { data: {} }
}

///|
/// Creates a `StringDict` wrapping an existing `Map[String, Value]`.
pub fn StringDict::from_map(m : Map[String, Value]) -> StringDict {
  { data: m }
}

///|
/// Inserts or updates the binding for `key`.
pub fn StringDict::set(self : StringDict, key : String, v : Value) -> Unit {
  self.data[key] = v
}

///|
/// Returns the value bound to `key`, or `None`.
pub fn StringDict::get(self : StringDict, key : String) -> Value? {
  self.data.get(key)
}

///|
/// Returns `true` if `key` is present.
pub fn StringDict::has(self : StringDict, key : String) -> Bool {
  self.data.contains(key)
}

///|
/// Returns the keys in lexicographic order.
pub fn StringDict::keys(self : StringDict) -> Array[String] {
  let ks = self.data.keys().collect()
  ks.sort_by(fn(a, b) {
    let la = a.length()
    let lb = b.length()
    let min_len = if la < lb { la } else { lb }
    let mut result = 0
    let mut i = 0
    while i < min_len && result == 0 {
      let ca = a.get_char(i).unwrap()
      let cb = b.get_char(i).unwrap()
      result = ca.compare(cb)
      i = i + 1
    }
    if result != 0 {
      result
    } else {
      la.compare(lb)
    }
  })
  ks
}

///|
/// Recursively deep-freezes all values in the dict.
pub fn StringDict::freeze(self : StringDict) -> Unit {
  self.data.each(fn(_, v) { @value.freeze_value(v) })
}

///|
/// The maximum recursion depth used by structural equality and comparison.
pub let compare_limit : Int = @value.compare_limit

///|
/// Structural equality with a recursion-depth cap to guard against cycles.
pub fn equal_depth(
  a : Value,
  b : Value,
  depth : Int,
) -> Result[Bool, EvalError] {
  match @value.starlark_equals_depth(a, b, depth) {
    Ok(b) => Ok(b)
    Err(e) => Err(@errors.EvalError::simple(e))
  }
}

///|
/// Applies a comparison operator (`"=="`, `"!="`, `"<"`, `"<="`, `">"`,
/// `">="`) to `a` and `b` with a recursion-depth cap.
pub fn compare_depth(
  op : String,
  a : Value,
  b : Value,
  depth : Int,
) -> Result[Bool, EvalError] {
  match op {
    "==" =>
      match @value.starlark_equals_depth(a, b, depth) {
        Ok(v) => Ok(v)
        Err(e) => Err(@errors.EvalError::simple(e))
      }
    "!=" =>
      match @value.starlark_equals_depth(a, b, depth) {
        Ok(v) => Ok(!v)
        Err(e) => Err(@errors.EvalError::simple(e))
      }
    "<" | "<=" | ">" | ">=" =>
      match @value.compare_values_depth(a, b, depth) {
        Ok(c) =>
          match op {
            "<" => Ok(c < 0)
            "<=" => Ok(c <= 0)
            ">" => Ok(c > 0)
            _ => Ok(c >= 0)
          }
        Err(e) => Err(@errors.EvalError::simple(e))
      }
    _ => Err(@errors.EvalError::simple("unknown comparison operator: \{op}"))
  }
}

///|
/// Applies a Starlark binary operator by name to `x` and `y`.
/// Valid operator strings: `"+"`, `"-"`, `"*"`, `"/"`, `"//"`, `"%"`,
/// `"&"`, `"|"`, `"^"`, `"<<"`, `">>"`.
pub fn binary(op : String, x : Value, y : Value) -> Result[Value, EvalError] {
  @eval.binary(op, x, y)
}

///|
/// Applies a Starlark unary operator by name to `x`.
/// Valid operator strings: `"+"`, `"-"`, `"~"`, `"not"`.
pub fn unary(op : String, x : Value) -> Result[Value, EvalError] {
  @eval.unary(op, x)
}

///|
/// Applies a Starlark comparison operator by name to `x` and `y`.
/// Valid operator strings: `"=="`, `"!="`, `"<"`, `"<="`, `">"`, `">="`.
pub fn compare(op : String, x : Value, y : Value) -> Result[Bool, EvalError] {
  @eval.compare(op, x, y)
}
