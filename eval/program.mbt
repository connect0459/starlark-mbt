// Program represents a parsed and resolved Starlark source file.
// Unlike exec_file, source_program does not execute the file.
// A Program can be Init'd multiple times with different predeclared values.

///|
/// A parsed and resolved Starlark source file. Execute via `init`; parsing and
/// resolution costs are paid once. A `Program` may be `init`'d multiple times
/// with different `predeclared` dictionaries.
pub struct Program {
  priv filename : String
  priv opts : Options
  priv compiled : @compile.CompiledProgram
}

///|
/// Parses `src` as a Starlark source file and returns its AST.
///
/// Parameters:
///
/// - `filename` : Source file name used in error messages and position info.
/// - `src` : Starlark source text to parse.
///
/// Returns the parsed `@syntax.File`, or an `EvalError` on syntax failure.
pub fn parse_file(
  filename : String,
  src : String,
) -> Result[@syntax.File, @errors.EvalError] {
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
/// - `filename` : Source file name used in error messages and position info.
/// - `src` : Starlark expression source text to parse.
///
/// Returns the parsed `@syntax.Expr`, or an `EvalError` on syntax failure.
pub fn parse_expr(
  filename : String,
  src : String,
) -> Result[@syntax.Expr, @errors.EvalError] {
  match @parser.parse_expr(filename, src) {
    Ok(e) => Ok(e)
    Err(e) => Err(@errors.EvalError::simple(e.to_string()))
  }
}

///|
/// Parses and resolves `src` as a Starlark file named `filename`, returning
/// an immutable `Program` on success. `is_predeclared` answers whether a name
/// is provided by the embedder's predeclared environment.
///
/// Parameters:
///
/// - `filename` : The name used to identify this source file in error messages
///   and stack traces.
/// - `src` : The Starlark source text to parse and resolve.
/// - `opts` : Evaluation options controlling language features.
/// - `is_predeclared` : A predicate that returns `true` if a given name is
///   provided by the embedder's predeclared environment.
///
/// Returns a `Program` ready for `init`, or an `EvalError` if parsing or
/// resolution fails.
pub fn source_program(
  filename : String,
  src : String,
  opts : Options,
  is_predeclared : (String) -> Bool,
) -> Result[Program, @errors.EvalError] {
  source_program_with_file(filename, src, opts, is_predeclared).map(fn(pair) {
    pair.1
  })
}

///|
/// Like `source_program` but also returns the parsed `File` AST alongside the
/// `Program`, useful when the caller needs to inspect load statements before
/// executing.
///
/// Parameters:
///
/// - `filename` : The name used to identify this source file in error messages
///   and stack traces.
/// - `src` : The Starlark source text to parse and resolve.
/// - `opts` : Evaluation options controlling language features.
/// - `is_predeclared` : A predicate that returns `true` if a given name is
///   provided by the embedder's predeclared environment.
///
/// Returns a pair of the parsed `File` AST and the resolved `Program`, or an
/// `EvalError` if parsing or resolution fails.
pub fn source_program_with_file(
  filename : String,
  src : String,
  opts : Options,
  is_predeclared : (String) -> Bool,
) -> Result[(@syntax.File, Program), @errors.EvalError] {
  let file = match @parser.parse_file(filename, src) {
    Ok(f) => f
    Err(e) => return Err(@errors.EvalError::simple(e.to_string()))
  }
  match file_program(file, opts, is_predeclared) {
    Ok(prog) => Ok((file, prog))
    Err(e) => Err(e)
  }
}

///|
/// Resolves an already-parsed `File` AST with the given options, returning a
/// `Program` ready for `init`. Skips lexing and parsing.
///
/// Parameters:
///
/// - `file` : A previously parsed `File` AST to resolve.
/// - `opts` : Evaluation options controlling language features.
/// - `is_predeclared` : A predicate that returns `true` if a given name is
///   provided by the embedder's predeclared environment.
///
/// Returns a resolved `Program`, or an `EvalError` if name resolution fails.
pub fn file_program(
  file : @syntax.File,
  opts : Options,
  is_predeclared : (String) -> Bool,
) -> Result[Program, @errors.EvalError] {
  match validate_resolution(file, opts, is_predeclared) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let compiled = compile_resolved(file, opts) catch {
    @compile.CompileErr(msg) => return Err(@errors.EvalError::simple(msg))
  }
  Ok({ filename: file.path(), opts, compiled })
}

///|
/// Runs the resolver over `file`, returning an `EvalError` carrying the joined
/// resolver messages if resolution fails. Shared by `file_program` and the
/// one-shot execution entries so resolver errors (messages and positions) are
/// reported consistently.
fn validate_resolution(
  file : @syntax.File,
  opts : Options,
  is_predeclared : (String) -> Bool,
) -> Result[Unit, @errors.EvalError] {
  let resolve_opts = @resolver.ResolveOptions::default()
    .with_allow_global_reassign(opts.allow_global_reassign)
    .with_allow_set(opts.allow_set)
    .with_allow_while(opts.allow_while)
    .with_allow_top_level_control(opts.allow_top_level_control)
    .with_load_binds_globally(opts.load_binds_globally)
  let resolved = @resolver.resolve(
    file,
    fn(name) { is_builtin(name) || is_predeclared(name) },
    is_universal_name,
    resolve_opts,
  )
  if !resolved.is_valid() {
    let msg = resolved.errors()[0].to_string()
    return Err(@errors.EvalError::simple(msg))
  }
  Ok(())
}

///|
/// Returns `true` for the universal constants `None`, `True`, and `False`.
fn is_universal_name(name : String) -> Bool {
  name == "None" || name == "True" || name == "False"
}

///|
/// Compiles an already-resolved `file` to bytecode. Because the resolver has
/// already validated every name, any free name that is not a module global,
/// local, free, or universal must be predeclared; classifying every such name
/// as predeclared reproduces exactly the classification the resolver settled on
/// without needing to retain the embedder's original `is_predeclared` predicate.
/// This lets a `Program` carry its compiled form across `init` calls (and across
/// serialization) without re-resolving.
fn compile_resolved(
  file : @syntax.File,
  opts : Options,
) -> @compile.CompiledProgram raise @compile.CompileErr {
  @compile.compile(
    file,
    fn(name) { !is_universal_name(name) },
    is_universal_name,
    opts.allow_recursion,
  )
}

///|
/// Returns the source filename recorded in the program.
///
/// Returns the filename string that was supplied when the program was created.
pub fn Program::filename(self : Program) -> String {
  self.filename
}

///|
/// Returns the file-level dialect options this program was resolved with.
/// These options are bound to the program (and survive serialization), so a
/// `Program` plays the role starlark-go assigns to a file's `FileOptions`:
/// per-file, immutable dialect configuration rather than global flags.
pub fn Program::options(self : Program) -> Options {
  self.opts
}

///|
/// Returns the number of `load(...)` statements in the program.
///
/// Returns the count of top-level `load` statements found in the program.
pub fn Program::num_loads(self : Program) -> Int {
  self.compiled.load_stmts.length()
}

///|
/// Returns the path string and source position of the `i`-th `load` statement.
/// Returns an empty string and unknown position if `i` is out of range.
///
/// Parameters:
///
/// - `self` : The program whose load statements are queried.
/// - `i` : Zero-based index of the load statement to retrieve.
///
/// Returns a tuple of the module path string and the source position of that
/// `load` statement, or an empty string and unknown position if `i` is out of
/// range.
pub fn Program::load(self : Program, i : Int) -> (String, @errors.Position) {
  if i < 0 || i >= self.compiled.load_stmts.length() {
    return ("", @errors.Position::new("", 0, 0))
  }
  let ls = self.compiled.load_stmts[i]
  (ls.path, ls.pos)
}

///|
/// Executes the program with the given `predeclared` bindings, returning an
/// unfrozen `Module`. Unlike `exec_file`, does not freeze the module on return.
/// May be called multiple times with different `predeclared` dictionaries.
///
/// Parameters:
///
/// - `self` : The resolved program to execute.
/// - `thread` : The thread context that carries the call stack and load handler.
/// - `predeclared` : The set of predeclared name–value bindings visible to the
///   program during execution.
///
/// Returns an unfrozen `Module` whose globals are the top-level bindings
/// produced by the execution, or an `EvalError` if execution fails.
pub fn Program::init(
  self : Program,
  thread : Thread,
  predeclared : Predeclared,
) -> Result[Module, @errors.EvalError] {
  let ctx = EvalContext::new(thread, self.opts)
  predeclared.bindings.each(fn(name, v) { ctx.global_env.bind(name, v) })
  // Resolution and compilation were paid once when the program was created;
  // `init` only binds the predeclared values and runs the cached bytecode.
  let rm = match run_program_vm(ctx, self.compiled, self.filename) {
    Ok(m) => m
    Err(e) => return Err(e)
  }
  // Unlike `exec_file`, the returned module is left unfrozen.
  let m = { ..Module::new(), predeclared: predeclared.bindings }
  module_output(self.compiled, rm, self.opts).each(fn(name, v) {
    let key = @value.Value::String(@value.StarlarkString::new(name))
    m.globals.set(key, v) |> ignore
  })
  Ok(m)
}
