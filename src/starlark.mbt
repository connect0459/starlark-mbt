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
///
/// Parameters:
///
/// * `cv` : The custom value to wrap.
///
/// Returns a `Value::ExtVal` containing `cv`.
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
///
/// Parameters:
///
/// * `filename` : Source file name used in error messages and position info.
/// * `src` : Starlark source text to parse.
///
/// Returns the parsed `SyntaxFile`, or an `EvalError` on syntax failure.
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
///
/// Parameters:
///
/// * `filename` : Source file name used in error messages and position info.
/// * `src` : Starlark expression source text to parse.
///
/// Returns the parsed `SyntaxExpr`, or an `EvalError` on syntax failure.
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
///
/// Parameters:
///
/// * `thread` : Execution context providing print/load callbacks and step budget.
/// * `expr` : Pre-parsed expression AST node to evaluate.
/// * `opts` : Feature flags controlling which dialect features are active.
/// * `env` : Global environment dict supplying variable bindings.
///
/// Returns the evaluated `Value`, or an `EvalError` on runtime failure.
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
///
/// Parameters:
///
/// * `filename` : Source file name used in error messages and position info.
/// * `src` : Starlark source text to parse and resolve.
/// * `opts` : Feature flags controlling which dialect features are active.
/// * `is_predeclared` : Predicate returning `true` for names that are
///   predeclared in the execution environment (used by the resolver).
///
/// Returns the compiled `Program`, or an `EvalError` on parse/resolve failure.
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
///
/// Parameters:
///
/// * `filename` : Source file name used in error messages and position info.
/// * `src` : Starlark source text to parse and resolve.
/// * `opts` : Feature flags controlling which dialect features are active.
/// * `is_predeclared` : Predicate returning `true` for names that are
///   predeclared in the execution environment.
///
/// Returns a tuple of the parsed `SyntaxFile` and the compiled `Program`,
/// or an `EvalError` on parse/resolve failure.
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
///
/// Parameters:
///
/// * `file` : Pre-parsed Starlark source file AST.
/// * `opts` : Feature flags controlling which dialect features are active.
/// * `is_predeclared` : Predicate returning `true` for names that are
///   predeclared in the execution environment.
///
/// Returns the compiled `Program`, or an `EvalError` on resolve failure.
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
///
/// Parameters:
///
/// * `thread` : Execution context providing print/load callbacks and step budget.
/// * `filename` : Source file name used in error messages and position info.
/// * `src` : Starlark source text to execute.
/// * `opts` : Feature flags controlling which dialect features are active.
///
/// Returns the frozen `Module` containing all top-level globals, or an
/// `EvalError` on parse, resolve, or runtime failure.
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
///
/// Parameters:
///
/// * `thread` : Execution context providing print/load callbacks and step budget.
/// * `filename` : Source file name used in error messages and position info.
/// * `src` : Starlark source text to execute.
/// * `opts` : Feature flags controlling which dialect features are active.
/// * `universe` : Custom universe of predeclared bindings to use instead of
///   the standard built-ins.
///
/// Returns the frozen `Module`, or an `EvalError` on failure.
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
///
/// Parameters:
///
/// * `thread` : Execution context providing print/load callbacks and step budget.
/// * `filename` : Source file name used in error messages and position info.
/// * `src` : Starlark source text to execute.
/// * `opts` : Feature flags controlling which dialect features are active.
/// * `predeclared` : Extra per-execution bindings injected before user globals.
///
/// Returns the frozen `Module`, or an `EvalError` on failure.
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
///
/// Parameters:
///
/// * `thread` : Execution context providing print/load callbacks and step budget.
/// * `filename` : Source file name used in error messages and position info.
/// * `src` : Starlark expression source text to evaluate.
/// * `env` : Global environment dict supplying variable bindings.
///
/// Returns the evaluated `Value`, or an `EvalError` on failure.
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
///
/// Parameters:
///
/// * `thread` : Execution context providing print/load callbacks and step budget.
/// * `filename` : Source file name used in error messages and position info.
/// * `src` : Starlark expression source text to evaluate.
/// * `opts` : Feature flags controlling which dialect features are active.
/// * `env` : Global environment dict supplying variable bindings.
///
/// Returns the evaluated `Value`, or an `EvalError` on failure.
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
///
/// Parameters:
///
/// * `thread` : Execution context providing print/load callbacks and step budget.
/// * `filename` : Source file name used in error messages and position info.
/// * `src` : Starlark source chunk to execute (may be statements or an expression).
/// * `globals` : Mutable dict that persists global bindings across REPL chunks.
/// * `opts` : Feature flags controlling which dialect features are active.
///
/// Returns `Ok(())` on success, or an `EvalError` on failure.
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
///
/// Parameters:
///
/// * `m` : The module to look up in.
/// * `name` : The global name to retrieve.
///
/// Returns the bound `Value`, or `None` if the name is absent.
pub fn module_get(m : Module, name : String) -> Value? {
  m.get(name)
}

///|
/// Returns the Starlark `repr(v)` string — a quoted, round-trip-safe
/// representation.
///
/// Parameters:
///
/// * `v` : The Starlark value to represent.
///
/// Returns the `repr` string of `v`.
pub fn repr(v : Value) -> String {
  @value.repr(v)
}

///|
/// Returns the Starlark `str(v)` string — unquoted for strings, `repr` for
/// everything else.
///
/// Parameters:
///
/// * `v` : The Starlark value to convert to a string.
///
/// Returns the `str` string of `v`.
pub fn to_str(v : Value) -> String {
  @value.to_str(v)
}

///|
/// Returns the Starlark `type(v)` string (e.g. `"int"`, `"list"`).
///
/// Parameters:
///
/// * `v` : The Starlark value whose type name to retrieve.
///
/// Returns the type name string.
pub fn type_name(v : Value) -> String {
  @value.type_name(v)
}

///|
/// Returns the boolean truth value of `v`, as used by `if`, `while`, `and`,
/// and `or` expressions.
///
/// Parameters:
///
/// * `v` : The Starlark value to test for truthiness.
///
/// Returns `true` if `v` is truthy, `false` otherwise.
pub fn truth(v : Value) -> Bool {
  @value.truth(v)
}

///|
/// Returns `true` if `a == b` under Starlark semantics, including cross-type
/// `Int`/`Float` comparison and NaN inequality.
///
/// Parameters:
///
/// * `a` : The left-hand value.
/// * `b` : The right-hand value.
///
/// Returns `true` if `a` and `b` are equal under Starlark semantics.
pub fn starlark_equals(a : Value, b : Value) -> Bool {
  @value.starlark_equals(a, b)
}

///|
/// Wraps `starlark_equals` in a `Result`; always succeeds.
///
/// Parameters:
///
/// * `a` : The left-hand value.
/// * `b` : The right-hand value.
///
/// Returns `Ok(true)` if `a == b`, `Ok(false)` otherwise.
pub fn equal(a : Value, b : Value) -> Result[Bool, EvalError] {
  Ok(@value.starlark_equals(a, b))
}

///|
/// Converts an `Int` or `Float` value to `Int64`, returning `None` if the
/// value is out of range, NaN, or infinite.
///
/// Parameters:
///
/// * `v` : The Starlark numeric value to convert.
///
/// Returns `Some(n)` if the conversion succeeds, `None` if `v` is not a
/// numeric type, is NaN or infinite, or is outside the signed 64-bit range.
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
///
/// Parameters:
///
/// * `v` : The Starlark value to extract a float from.
///
/// Returns a tuple `(f, ok)` where `f` is the extracted value and `ok`
/// indicates whether `v` was a numeric type.
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
///
/// Parameters:
///
/// * `v` : The Starlark value to extract a string from.
///
/// Returns a tuple `(s, ok)` where `s` is the raw string and `ok` indicates
/// whether `v` was a string type.
pub fn as_string(v : Value) -> (String, Bool) {
  match v {
    @value.Value::String(s) => (s.raw(), true)
    _ => ("", false)
  }
}

///|
/// Returns the sequence length of `v` (list, tuple, string, bytes, range),
/// or `-1` if `v` has no length.
///
/// Parameters:
///
/// * `v` : The Starlark value whose length to retrieve.
///
/// Returns the non-negative length, or `-1` if `v` does not support `len`.
pub fn len_of(v : Value) -> Int {
  match @value.length_of(v) {
    Ok(n) => n
    Err(_) => -1
  }
}

///|
/// Returns an iterator over the elements of `v`. Fails if `v` is not
/// iterable.
///
/// Parameters:
///
/// * `v` : The Starlark value to iterate over.
///
/// Returns `Ok(iterator)` on success, or an `EvalError` if `v` is not iterable.
pub fn iterate(v : Value) -> Result[StarlarkIterator, EvalError] {
  match @value.iterate(v) {
    Ok(it) => Ok(it)
    Err(msg) => Err(@errors.EvalError::simple(msg))
  }
}

///|
/// Invokes a Starlark callable from host code with positional `args` and
/// keyword `kwargs`.
///
/// Parameters:
///
/// * `thread` : Execution context providing print/load callbacks and step budget.
/// * `func` : The Starlark callable to invoke (function, builtin, or bound method).
/// * `args` : Positional arguments to pass.
/// * `kwargs` : Keyword arguments as `(name, value)` pairs.
///
/// Returns the call result, or an `EvalError` on failure.
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
///
/// Returns a new `StringDict` with no bindings.
pub fn StringDict::new() -> StringDict {
  { data: {} }
}

///|
/// Creates a `StringDict` wrapping an existing `Map[String, Value]`.
///
/// Parameters:
///
/// * `m` : The map to wrap; ownership is transferred.
///
/// Returns a `StringDict` backed by `m`.
pub fn StringDict::from_map(m : Map[String, Value]) -> StringDict {
  { data: m }
}

///|
/// Inserts or updates the binding for `key`.
///
/// Parameters:
///
/// * `self` : The dict to modify.
/// * `key` : The string key to bind.
/// * `v` : The value to associate with `key`.
pub fn StringDict::set(self : StringDict, key : String, v : Value) -> Unit {
  self.data[key] = v
}

///|
/// Returns the value bound to `key`, or `None`.
///
/// Parameters:
///
/// * `self` : The dict to look up in.
/// * `key` : The string key to retrieve.
///
/// Returns `Some(value)` if `key` is present, `None` otherwise.
pub fn StringDict::get(self : StringDict, key : String) -> Value? {
  self.data.get(key)
}

///|
/// Returns `true` if `key` is present.
///
/// Parameters:
///
/// * `self` : The dict to query.
/// * `key` : The string key to test for presence.
///
/// Returns `true` if `key` exists in the dict.
pub fn StringDict::has(self : StringDict, key : String) -> Bool {
  self.data.contains(key)
}

///|
/// Returns the keys in lexicographic order.
///
/// Parameters:
///
/// * `self` : The dict whose keys to retrieve.
///
/// Returns an array of all keys sorted lexicographically.
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
///
/// Parameters:
///
/// * `self` : The dict whose values to freeze.
pub fn StringDict::freeze(self : StringDict) -> Unit {
  self.data.each(fn(_, v) { @value.freeze_value(v) })
}

///|
/// The maximum recursion depth used by structural equality and comparison.
pub let compare_limit : Int = @value.compare_limit

///|
/// Structural equality with a recursion-depth cap to guard against cycles.
///
/// Parameters:
///
/// * `a` : The left-hand value.
/// * `b` : The right-hand value.
/// * `depth` : Remaining recursion budget; use `compare_limit` as the initial
///   value. Returns an error when this reaches zero.
///
/// Returns `Ok(true)` if `a == b`, `Ok(false)` if not, or an `EvalError`
/// when the depth limit is exceeded (cyclic structure).
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
///
/// Parameters:
///
/// * `op` : The comparison operator string: `"=="`, `"!="`, `"<"`, `"<="`,
///   `">"`, or `">="`.
/// * `a` : The left-hand value.
/// * `b` : The right-hand value.
/// * `depth` : Remaining recursion budget; use `compare_limit` as the initial
///   value.
///
/// Returns `Ok(result)` on success, or an `EvalError` on type mismatch,
/// depth exhaustion, or unknown operator.
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
///
/// Parameters:
///
/// * `op` : The binary operator name.
/// * `x` : The left-hand operand.
/// * `y` : The right-hand operand.
///
/// Returns the operation result, or an `EvalError` on type mismatch or
/// arithmetic error (e.g. division by zero).
pub fn binary(op : String, x : Value, y : Value) -> Result[Value, EvalError] {
  @eval.binary(op, x, y)
}

///|
/// Applies a Starlark unary operator by name to `x`.
/// Valid operator strings: `"+"`, `"-"`, `"~"`, `"not"`.
///
/// Parameters:
///
/// * `op` : The unary operator name.
/// * `x` : The operand.
///
/// Returns the operation result, or an `EvalError` on type mismatch.
pub fn unary(op : String, x : Value) -> Result[Value, EvalError] {
  @eval.unary(op, x)
}

///|
/// Applies a Starlark comparison operator by name to `x` and `y`.
/// Valid operator strings: `"=="`, `"!="`, `"<"`, `"<="`, `">"`, `">="`.
///
/// Parameters:
///
/// * `op` : The comparison operator name.
/// * `x` : The left-hand operand.
/// * `y` : The right-hand operand.
///
/// Returns `Ok(result)` on success, or an `EvalError` on type mismatch.
pub fn compare(op : String, x : Value, y : Value) -> Result[Bool, EvalError] {
  @eval.compare(op, x, y)
}
