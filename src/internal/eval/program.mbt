// Program represents a parsed and resolved Starlark source file.
// Unlike exec_file, source_program does not execute the file.
// A Program can be Init'd multiple times with different predeclared values.

///|
pub struct Program {
  priv file : @syntax.File
  priv opts : Options
}

///|
pub fn source_program(
  filename : String,
  src : String,
  opts : Options,
  is_predeclared : (String) -> Bool,
) -> Result[Program, @errors.EvalError] {
  let file = match @parser.parse_file(filename, src) {
    Ok(f) => f
    Err(e) => return Err(@errors.EvalError::simple(e.to_string()))
  }
  let resolve_opts = @resolver.ResolveOptions::default()
    .with_allow_global_reassign(opts.allow_global_reassign)
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
pub fn Program::filename(self : Program) -> String {
  self.file.path()
}

///|
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
pub fn Program::init(
  self : Program,
  thread : Thread,
  predeclared : Predeclared,
) -> Result[Module, @errors.EvalError] {
  let ctx = EvalContext::new(thread, self.opts)
  predeclared.bindings.each(fn(name, v) { ctx.global_env.bind(name, v) })
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
