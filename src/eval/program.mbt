// Program represents a parsed and resolved Starlark source file.
// Unlike exec_file, source_program does not execute the file.
// A Program can be Init'd multiple times with different predeclared values.

///|
/// A parsed and resolved Starlark source file. Execute via `init`; parsing and
/// resolution costs are paid once. A `Program` may be `init`'d multiple times
/// with different `predeclared` dictionaries.
pub struct Program {
  priv file : @syntax.File
  priv opts : Options
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
    Ok(prog) => Ok((prog.file, prog))
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
  let resolve_opts = @resolver.ResolveOptions::default()
    .with_allow_global_reassign(opts.allow_global_reassign)
    .with_allow_set(opts.allow_set)
    .with_load_binds_globally(opts.load_binds_globally)
  let resolved = @resolver.resolve(
    file,
    fn(name) { is_builtin(name) || is_predeclared(name) },
    fn(name) { name == "None" || name == "True" || name == "False" },
    resolve_opts,
  )
  if !resolved.is_valid() {
    let msg = resolved.errors().map(fn(e) { e.to_string() }).join("; ")
    return Err(@errors.EvalError::simple(msg))
  }
  Ok({ file, opts })
}

///|
/// Returns the source filename recorded in the program.
///
/// Returns the filename string that was supplied when the program was created.
pub fn Program::filename(self : Program) -> String {
  self.file.path()
}

///|
/// Returns the number of `load(...)` statements in the program.
///
/// Returns the count of top-level `load` statements found in the parsed file.
pub fn Program::num_loads(self : Program) -> Int {
  let mut count = 0
  for stmt in self.file.stmts() {
    match stmt {
      @syntax.Stmt::SLoad(_) => count += 1
      _ => ()
    }
  }
  count
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
  let mut idx = 0
  for stmt in self.file.stmts() {
    match stmt {
      @syntax.Stmt::SLoad(path, _, pos) => {
        if idx == i {
          return (path, pos)
        }
        idx += 1
      }
      _ => ()
    }
  }
  ("", @errors.Position::new("", 0, 0))
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
  collect_module_globals_into(
    self.file.stmts(),
    self.opts.load_binds_globally,
    ctx.global_env.known_module_globals,
  )
  ctx.toplevel_frame_idx = ctx.thread.call_stack.length()
  ctx.thread.call_stack.push(
    @errors.CallFrame::new(
      "<toplevel>",
      @errors.Position::new(self.file.path(), 1, 1),
    ),
  )
  ignore(exec_stmts(ctx, ctx.global_env, self.file.stmts())) catch {
    EvalErr(e) => {
      ignore(ctx.thread.call_stack.pop())
      ctx.toplevel_frame_idx = -1
      return Err(e)
    }
  }
  ignore(ctx.thread.call_stack.pop())
  ctx.toplevel_frame_idx = -1
  let m = { ..Module::new(), predeclared: predeclared.bindings }
  ctx.global_env.locals.each(fn(name, v) {
    if self.opts.load_binds_globally || !ctx.load_bound_names.contains(name) {
      let key = @value.Value::String(@value.StarlarkString::new(name))
      m.globals.set(key, v) |> ignore
    }
  })
  Ok(m)
}
