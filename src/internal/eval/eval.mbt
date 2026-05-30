///|
let default_max_recursion_depth : Int = 100

///|
pub struct Options {
  priv allow_set : Bool
  priv allow_recursion : Bool
  priv allow_lambda : Bool
  priv allow_while : Bool
  priv allow_bytes : Bool
  priv allow_float : Bool
  priv allow_global_reassign : Bool
  priv allow_top_level_control : Bool
  priv load_binds_globally : Bool
}

///|
pub fn Options::default() -> Options {
  {
    allow_set: true,
    allow_recursion: true,
    allow_lambda: true,
    allow_while: true,
    allow_bytes: true,
    allow_float: true,
    allow_global_reassign: true,
    allow_top_level_control: true,
    load_binds_globally: false,
  }
}

///|
pub fn Options::allow_set(self : Options) -> Bool {
  self.allow_set
}

///|
pub fn Options::allow_recursion(self : Options) -> Bool {
  self.allow_recursion
}

///|
pub fn Options::allow_lambda(self : Options) -> Bool {
  self.allow_lambda
}

///|
pub fn Options::allow_while(self : Options) -> Bool {
  self.allow_while
}

///|
pub fn Options::allow_bytes(self : Options) -> Bool {
  self.allow_bytes
}

///|
pub fn Options::allow_float(self : Options) -> Bool {
  self.allow_float
}

///|
pub fn Options::allow_global_reassign(self : Options) -> Bool {
  self.allow_global_reassign
}

///|
pub fn Options::allow_top_level_control(self : Options) -> Bool {
  self.allow_top_level_control
}

///|
pub fn Options::load_binds_globally(self : Options) -> Bool {
  self.load_binds_globally
}

///|
pub fn Options::with_load_binds_globally(self : Options, v : Bool) -> Options {
  { ..self, load_binds_globally: v }
}

///|
pub fn Options::with_allow_recursion(self : Options, v : Bool) -> Options {
  { ..self, allow_recursion: v }
}

///|
pub fn Options::with_allow_set(self : Options, v : Bool) -> Options {
  { ..self, allow_set: v }
}

///|
pub fn Options::with_global_reassign(self : Options, v : Bool) -> Options {
  { ..self, allow_global_reassign: v }
}

///|
pub struct Universe {
  priv bindings : Map[String, @value.Value]
}

///|
pub fn Universe::empty() -> Universe {
  { bindings: {} }
}

///|
pub fn Universe::standard() -> Universe {
  let m : Map[String, @value.Value] = {}
  m["None"] = @value.Value::None
  m["True"] = @value.Value::Bool(true)
  m["False"] = @value.Value::Bool(false)
  for name in builtin_names {
    m[name] = @value.Value::Builtin(@value.StarlarkBuiltinFunc::dispatch(name))
  }
  { bindings: m }
}

///|
pub fn Universe::get(self : Universe, name : String) -> @value.Value? {
  self.bindings.get(name)
}

///|
pub fn Universe::has(self : Universe, name : String) -> Bool {
  self.bindings.contains(name)
}

///|
pub fn Universe::set(
  self : Universe,
  name : String,
  value : @value.Value,
) -> Unit {
  self.bindings[name] = value
}

///|
pub struct Predeclared {
  priv bindings : Map[String, @value.Value]
}

///|
pub fn Predeclared::new() -> Predeclared {
  { bindings: {} }
}

///|
pub fn Predeclared::from_map(m : Map[String, @value.Value]) -> Predeclared {
  { bindings: m }
}

///|
pub fn Predeclared::set(
  self : Predeclared,
  name : String,
  v : @value.Value,
) -> Unit {
  self.bindings[name] = v
}

///|
pub fn Predeclared::get(self : Predeclared, name : String) -> @value.Value? {
  self.bindings.get(name)
}

///|
pub struct Thread {
  priv name : String
  priv mut print_fn : (Thread, String) -> Unit
  priv mut load_fn : ((Thread, String) -> Result[Module, @errors.EvalError])?
  priv call_stack : Array[@errors.CallFrame]
  priv debug_stack : Array[ActiveCallFrame]
  priv max_recursion_depth : Int
  priv mut max_steps : Int?
  priv mut steps : Int
  priv mut cancel_reason : String?
  priv mut on_max_steps : ((Thread) -> Unit)?
  priv locals : Map[String, @value.Value]
}

///|
pub fn Thread::new(name : String) -> Thread {
  {
    name,
    print_fn: fn(_, msg) { println(msg) },
    load_fn: None,
    call_stack: [],
    debug_stack: [],
    max_recursion_depth: default_max_recursion_depth,
    max_steps: None,
    steps: 0,
    cancel_reason: None,
    on_max_steps: None,
    locals: {},
  }
}

///|
pub fn Thread::with_print(
  name : String,
  print_fn : (Thread, String) -> Unit,
) -> Thread {
  {
    name,
    print_fn,
    load_fn: None,
    call_stack: [],
    debug_stack: [],
    max_recursion_depth: default_max_recursion_depth,
    max_steps: None,
    steps: 0,
    cancel_reason: None,
    on_max_steps: None,
    locals: {},
  }
}

///|
pub fn Thread::with_loader(
  name : String,
  load_fn : (Thread, String) -> Result[Module, @errors.EvalError],
) -> Thread {
  {
    name,
    print_fn: fn(_, msg) { println(msg) },
    load_fn: Some(load_fn),
    call_stack: [],
    debug_stack: [],
    max_recursion_depth: default_max_recursion_depth,
    max_steps: None,
    steps: 0,
    cancel_reason: None,
    on_max_steps: None,
    locals: {},
  }
}

///|
pub fn Thread::with_step_budget(name : String, max_steps : Int) -> Thread {
  {
    name,
    print_fn: fn(_, msg) { println(msg) },
    load_fn: None,
    call_stack: [],
    debug_stack: [],
    max_recursion_depth: default_max_recursion_depth,
    max_steps: Some(max_steps),
    steps: 0,
    cancel_reason: None,
    on_max_steps: None,
    locals: {},
  }
}

///|
pub fn Thread::set_local(
  self : Thread,
  key : String,
  value : @value.Value,
) -> Unit {
  self.locals[key] = value
}

///|
pub fn Thread::get_local(self : Thread, key : String) -> @value.Value? {
  self.locals.get(key)
}

///|
pub fn Thread::cancel(self : Thread, reason : String) -> Unit {
  if self.cancel_reason is None {
    self.cancel_reason = Some(reason)
  }
}

///|
pub fn Thread::uncancel(self : Thread) -> Unit {
  self.cancel_reason = None
}

///|
pub fn Thread::reset_steps(self : Thread) -> Unit {
  self.steps = 0
}

///|
// Sets the execution-step budget without resetting the accumulated step count.
// Use `reset_steps` to zero the counter explicitly.
pub fn Thread::set_max_steps(self : Thread, max : Int) -> Unit {
  self.max_steps = Some(max)
}

///|
// Sets the print callback on an existing thread. Combined with `set_loader` and
// `set_max_steps`, this lets a single thread carry all three.
pub fn Thread::set_print(
  self : Thread,
  print_fn : (Thread, String) -> Unit,
) -> Unit {
  self.print_fn = print_fn
}

///|
// Sets the load callback on an existing thread.
pub fn Thread::set_loader(
  self : Thread,
  load_fn : (Thread, String) -> Result[Module, @errors.EvalError],
) -> Unit {
  self.load_fn = Some(load_fn)
}

///|
pub fn Thread::set_on_max_steps(self : Thread, cb : (Thread) -> Unit) -> Unit {
  self.on_max_steps = Some(cb)
}

///|
pub fn Thread::call_stack_depth(self : Thread) -> Int {
  self.call_stack.length()
}

///|
pub fn Thread::debug_frame(self : Thread, depth : Int) -> DebugFrame? {
  let idx = self.debug_stack.length() - 1 - depth
  if idx < 0 || idx >= self.debug_stack.length() {
    return None
  }
  Some(DebugFrame::from_active(self.debug_stack[idx]))
}

///|
pub fn Thread::call_stack(self : Thread) -> @errors.CallStack {
  @errors.CallStack::new(self.call_stack.copy())
}

///|
pub fn Thread::call_frames(self : Thread) -> Array[@errors.CallFrame] {
  self.call_stack.copy()
}

///|
pub fn Thread::call_frame(self : Thread, n : Int) -> @errors.CallFrame? {
  let idx = self.call_stack.length() - 1 - n
  if idx < 0 || idx >= self.call_stack.length() {
    return None
  }
  Some(self.call_stack[idx])
}

///|
pub fn Thread::execution_steps(self : Thread) -> Int {
  self.steps
}

///|
pub fn Thread::name(self : Thread) -> String {
  self.name
}

///|
pub fn Thread::max_recursion_depth(self : Thread) -> Int {
  self.max_recursion_depth
}

///|
pub fn Thread::max_steps(self : Thread) -> Int? {
  self.max_steps
}

///|
pub struct Module {
  priv globals : @value.StarlarkDict
  priv mut frozen : Bool
  priv predeclared : Map[String, @value.Value]
}

///|
pub fn Module::new() -> Module {
  { globals: @value.StarlarkDict::new(), frozen: false, predeclared: {} }
}

///|
pub fn Module::from_map(m : Map[String, @value.Value]) -> Module {
  let mod = Module::new()
  m.each(fn(name, v) {
    let key = @value.Value::String(@value.StarlarkString::new(name))
    mod.globals.set(key, v) |> ignore
  })
  mod.freeze()
  mod
}

///|
pub fn Module::freeze(self : Module) -> Unit {
  self.frozen = true
  self.globals.freeze()
  self.globals.each(fn(_, v) { @value.freeze_value(v) })
}

///|
pub fn Module::is_frozen(self : Module) -> Bool {
  self.frozen
}

///|
pub fn Module::get(self : Module, name : String) -> @value.Value? {
  let key = @value.Value::String(@value.StarlarkString::new(name))
  match self.globals.get(key) {
    Ok(Some(v)) => Some(v)
    _ => None
  }
}

///|
pub fn Module::globals_count(self : Module) -> Int {
  self.globals.length()
}

///|
pub fn Module::globals_map(self : Module) -> Map[String, @value.Value] {
  let result : Map[String, @value.Value] = {}
  self.globals.each(fn(k, v) {
    match k {
      @value.Value::String(s) => result[s.raw()] = v
      _ => ()
    }
  })
  result
}

///|
pub fn Module::predeclared_map(self : Module) -> Map[String, @value.Value] {
  self.predeclared
}

///|
fn collect_module_globals_into(
  stmts : Array[@syntax.Stmt],
  load_binds_globally : Bool,
  result : Map[String, Bool],
) -> Unit {
  for stmt in stmts {
    match stmt {
      @syntax.Stmt::SDef(name, _, _, _) => result[name] = false
      @syntax.Stmt::SAssign(lhs, _, _) => collect_lhs_global_names(lhs, result)
      @syntax.Stmt::SAugAssign(lhs, _, _, _) =>
        collect_lhs_global_names(lhs, result)
      @syntax.Stmt::SLoad(_, bindings, _) => {
        let is_local = !load_binds_globally
        for pair in bindings {
          result[pair.0] = is_local
        }
      }
      @syntax.Stmt::SIf(_, then_body, else_body, _) => {
        collect_module_globals_into(then_body, load_binds_globally, result)
        collect_module_globals_into(else_body, load_binds_globally, result)
      }
      @syntax.Stmt::SFor(target, _, body, _) => {
        collect_lhs_global_names(target, result)
        collect_module_globals_into(body, load_binds_globally, result)
      }
      @syntax.Stmt::SWhile(_, body, _) =>
        collect_module_globals_into(body, load_binds_globally, result)
      _ => ()
    }
  }
}

///|
fn collect_lhs_global_names(
  expr : @syntax.Expr,
  result : Map[String, Bool],
) -> Unit {
  match expr {
    @syntax.Expr::EIdent(name, _) => result[name] = false
    @syntax.Expr::ETuple(elems, _) | @syntax.Expr::EList(elems, _) =>
      for elem in elems {
        collect_lhs_global_names(elem, result)
      }
    _ => ()
  }
}

///|
let builtin_names : Array[String] = [
  "print", "len", "str", "repr", "type", "range", "list", "tuple", "dict", "bool",
  "int", "float", "abs", "min", "max", "set", "enumerate", "zip", "sorted", "reversed",
  "hasattr", "getattr", "fail", "any", "all", "hash", "dir", "chr", "ord", "bytes",
  "module",
]

///|
fn is_builtin(name : String) -> Bool {
  builtin_names.contains(name)
}

///|
pub fn call(
  thread : Thread,
  func : @value.Value,
  args : Array[@value.Value],
  kwargs : Array[(String, @value.Value)],
) -> Result[@value.Value, @errors.EvalError] {
  let ctx = EvalContext::new(thread, Options::default())
  let pos = @errors.Position::new("<call>", 0, 0)
  Ok(call_value(ctx, func, args, kwargs, pos)) catch {
    EvalErr(e) => Err(e)
  }
}

///|
pub fn binary(
  op : String,
  x : @value.Value,
  y : @value.Value,
) -> Result[@value.Value, @errors.EvalError] {
  let bop = match op {
    "+" => @syntax.BinaryOp::OpAdd
    "-" => @syntax.BinaryOp::OpSub
    "*" => @syntax.BinaryOp::OpMul
    "/" => @syntax.BinaryOp::OpDiv
    "//" => @syntax.BinaryOp::OpFloorDiv
    "%" => @syntax.BinaryOp::OpMod
    "&" => @syntax.BinaryOp::OpBitAnd
    "|" => @syntax.BinaryOp::OpBitOr
    "^" => @syntax.BinaryOp::OpBitXor
    "<<" => @syntax.BinaryOp::OpLShift
    ">>" => @syntax.BinaryOp::OpRShift
    _ => return Err(@errors.EvalError::simple("unknown binary operator: \{op}"))
  }
  let thread = Thread::new("<binary>")
  let ctx = EvalContext::new(thread, Options::default())
  let pos = @errors.Position::new("<binary>", 0, 0)
  Ok(eval_binary(ctx, x, bop, y, pos)) catch {
    EvalErr(e) => Err(e)
  }
}

///|
pub fn unary(
  op : String,
  x : @value.Value,
) -> Result[@value.Value, @errors.EvalError] {
  let uop = match op {
    "+" => @syntax.UnaryOp::OpPlus
    "-" => @syntax.UnaryOp::OpMinus
    "~" => @syntax.UnaryOp::OpBitNot
    "not" => @syntax.UnaryOp::OpNot
    _ => return Err(@errors.EvalError::simple("unknown unary operator: \{op}"))
  }
  let thread = Thread::new("<unary>")
  let ctx = EvalContext::new(thread, Options::default())
  let pos = @errors.Position::new("<unary>", 0, 0)
  Ok(eval_unary(ctx, uop, x, pos)) catch {
    EvalErr(e) => Err(e)
  }
}

///|
pub fn compare(
  op : String,
  x : @value.Value,
  y : @value.Value,
) -> Result[Bool, @errors.EvalError] {
  let bop = match op {
    "==" => @syntax.BinaryOp::OpEq
    "!=" => @syntax.BinaryOp::OpNe
    "<" => @syntax.BinaryOp::OpLt
    "<=" => @syntax.BinaryOp::OpLe
    ">" => @syntax.BinaryOp::OpGt
    ">=" => @syntax.BinaryOp::OpGe
    _ =>
      return Err(
        @errors.EvalError::simple("unknown comparison operator: \{op}"),
      )
  }
  let thread = Thread::new("<compare>")
  let ctx = EvalContext::new(thread, Options::default())
  let pos = @errors.Position::new("<compare>", 0, 0)
  let result = eval_binary(ctx, x, bop, y, pos) catch {
    EvalErr(e) => return Err(e)
  }
  match result {
    @value.Value::Bool(b) => Ok(b)
    _ => Err(@errors.EvalError::simple("comparison did not return bool"))
  }
}

///|
pub fn exec_file(
  thread : Thread,
  filename : String,
  src : String,
  opts : Options,
) -> Result[Module, @errors.EvalError] {
  let file = match @parser.parse_file(filename, src) {
    Ok(f) => f
    Err(e) => return Err(@errors.EvalError::simple(e.to_string()))
  }
  let ctx = EvalContext::new(thread, opts)
  collect_module_globals_into(
    file.stmts(),
    opts.load_binds_globally,
    ctx.global_env.known_module_globals,
  )
  let resolve_opts = @resolver.ResolveOptions::default()
    .with_allow_global_reassign(opts.allow_global_reassign)
    .with_allow_set(opts.allow_set)
    .with_load_binds_globally(opts.load_binds_globally)
  let resolved = @resolver.resolve(
    file,
    is_builtin,
    fn(name) { name == "None" || name == "True" || name == "False" },
    resolve_opts,
  )
  if !resolved.is_valid() {
    let msg = resolved.errors().map(fn(e) { e.to_string() }).join("; ")
    return Err(@errors.EvalError::simple(msg))
  }
  ctx.toplevel_frame_idx = ctx.thread.call_stack.length()
  ctx.thread.call_stack.push(
    @errors.CallFrame::new("<toplevel>", @errors.Position::new(filename, 1, 1)),
  )
  ignore(exec_stmts(ctx, ctx.global_env, file.stmts())) catch {
    EvalErr(e) => {
      ignore(ctx.thread.call_stack.pop())
      ctx.toplevel_frame_idx = -1
      return Err(e)
    }
  }
  ignore(ctx.thread.call_stack.pop())
  ctx.toplevel_frame_idx = -1
  let m = Module::new()
  ctx.global_env.locals.each(fn(name, v) {
    if ctx.opts.load_binds_globally || !ctx.load_bound_names.contains(name) {
      let key = @value.Value::String(@value.StarlarkString::new(name))
      m.globals.set(key, v) |> ignore
    }
  })
  m.freeze()
  Ok(m)
}

///|
pub fn exec_file_with_universe(
  thread : Thread,
  filename : String,
  src : String,
  opts : Options,
  universe : Universe,
) -> Result[Module, @errors.EvalError] {
  let file = match @parser.parse_file(filename, src) {
    Ok(f) => f
    Err(e) => return Err(@errors.EvalError::simple(e.to_string()))
  }
  let ctx = EvalContext::new(thread, opts)
  universe.bindings.each(fn(name, v) { ctx.global_env.bind(name, v) })
  collect_module_globals_into(
    file.stmts(),
    opts.load_binds_globally,
    ctx.global_env.known_module_globals,
  )
  let universe_names : Array[String] = universe.bindings.keys().collect()
  let resolve_opts = @resolver.ResolveOptions::default()
    .with_allow_global_reassign(opts.allow_global_reassign)
    .with_allow_set(opts.allow_set)
    .with_load_binds_globally(opts.load_binds_globally)
  let resolved = @resolver.resolve(
    file,
    fn(name) { is_builtin(name) || universe_names.contains(name) },
    fn(name) { name == "None" || name == "True" || name == "False" },
    resolve_opts,
  )
  if !resolved.is_valid() {
    let msg = resolved.errors().map(fn(e) { e.to_string() }).join("; ")
    return Err(@errors.EvalError::simple(msg))
  }
  ctx.toplevel_frame_idx = ctx.thread.call_stack.length()
  ctx.thread.call_stack.push(
    @errors.CallFrame::new("<toplevel>", @errors.Position::new(filename, 1, 1)),
  )
  ignore(exec_stmts(ctx, ctx.global_env, file.stmts())) catch {
    EvalErr(e) => {
      ignore(ctx.thread.call_stack.pop())
      ctx.toplevel_frame_idx = -1
      return Err(e)
    }
  }
  ignore(ctx.thread.call_stack.pop())
  ctx.toplevel_frame_idx = -1
  let m = Module::new()
  ctx.global_env.locals.each(fn(name, v) {
    if ctx.opts.load_binds_globally || !ctx.load_bound_names.contains(name) {
      let key = @value.Value::String(@value.StarlarkString::new(name))
      m.globals.set(key, v) |> ignore
    }
  })
  m.freeze()
  Ok(m)
}

///|
pub fn exec_file_with_predeclared(
  thread : Thread,
  filename : String,
  src : String,
  opts : Options,
  predeclared : Predeclared,
) -> Result[Module, @errors.EvalError] {
  let file = match @parser.parse_file(filename, src) {
    Ok(f) => f
    Err(e) => return Err(@errors.EvalError::simple(e.to_string()))
  }
  let ctx = EvalContext::new(thread, opts)
  predeclared.bindings.each(fn(name, v) { ctx.global_env.bind(name, v) })
  collect_module_globals_into(
    file.stmts(),
    opts.load_binds_globally,
    ctx.global_env.known_module_globals,
  )
  let extra_names : Array[String] = predeclared.bindings.keys().collect()
  let resolve_opts = @resolver.ResolveOptions::default()
    .with_allow_global_reassign(opts.allow_global_reassign)
    .with_allow_set(opts.allow_set)
    .with_load_binds_globally(opts.load_binds_globally)
  let resolved = @resolver.resolve(
    file,
    fn(name) { is_builtin(name) || extra_names.contains(name) },
    fn(name) { name == "None" || name == "True" || name == "False" },
    resolve_opts,
  )
  if !resolved.is_valid() {
    let msg = resolved.errors().map(fn(e) { e.to_string() }).join("; ")
    return Err(@errors.EvalError::simple(msg))
  }
  ctx.toplevel_frame_idx = ctx.thread.call_stack.length()
  ctx.thread.call_stack.push(
    @errors.CallFrame::new("<toplevel>", @errors.Position::new(filename, 1, 1)),
  )
  ignore(exec_stmts(ctx, ctx.global_env, file.stmts())) catch {
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
    if ctx.opts.load_binds_globally || !ctx.load_bound_names.contains(name) {
      let key = @value.Value::String(@value.StarlarkString::new(name))
      m.globals.set(key, v) |> ignore
    }
  })
  m.freeze()
  Ok(m)
}

///|
pub fn exec_repl_chunk(
  thread : Thread,
  filename : String,
  src : String,
  globals : @value.StarlarkDict,
  opts : Options,
) -> Result[Unit, @errors.EvalError] {
  let file = match @parser.parse_file(filename, src) {
    Ok(f) => f
    Err(e) => return Err(@errors.EvalError::simple(e.to_string()))
  }
  let ctx = EvalContext::new(thread, { ..opts, load_binds_globally: true })
  globals.each(fn(k, v) {
    match k {
      @value.Value::String(s) => ctx.global_env.bind(s.raw(), v)
      _ => ()
    }
  })
  collect_module_globals_into(
    file.stmts(),
    true,
    ctx.global_env.known_module_globals,
  )
  let extra_names : Array[String] = []
  globals.each(fn(k, _) {
    match k {
      @value.Value::String(s) => extra_names.push(s.raw())
      _ => ()
    }
  })
  let resolve_opts = @resolver.ResolveOptions::default()
    .with_allow_set(opts.allow_set)
    .with_load_binds_globally(true)
  let resolved = @resolver.resolve(
    file,
    fn(name) { is_builtin(name) || extra_names.contains(name) },
    fn(name) { name == "None" || name == "True" || name == "False" },
    resolve_opts,
  )
  if !resolved.is_valid() {
    let msg = resolved.errors().map(fn(e) { e.to_string() }).join("; ")
    return Err(@errors.EvalError::simple(msg))
  }
  ctx.toplevel_frame_idx = ctx.thread.call_stack.length()
  ctx.thread.call_stack.push(
    @errors.CallFrame::new("<toplevel>", @errors.Position::new(filename, 1, 1)),
  )
  ignore(exec_stmts(ctx, ctx.global_env, file.stmts())) catch {
    EvalErr(e) => {
      ignore(ctx.thread.call_stack.pop())
      ctx.toplevel_frame_idx = -1
      return Err(e)
    }
  }
  ignore(ctx.thread.call_stack.pop())
  ctx.toplevel_frame_idx = -1
  ctx.global_env.locals.each(fn(name, v) {
    let key = @value.Value::String(@value.StarlarkString::new(name))
    globals.set(key, v) |> ignore
  })
  Ok(())
}

///|
pub fn eval_expr(
  thread : Thread,
  filename : String,
  src : String,
  env : @value.StarlarkDict,
) -> Result[@value.Value, @errors.EvalError] {
  eval_expr_with_opts(thread, filename, src, Options::default(), env)
}

///|
pub fn eval_expr_with_opts(
  thread : Thread,
  filename : String,
  src : String,
  opts : Options,
  env : @value.StarlarkDict,
) -> Result[@value.Value, @errors.EvalError] {
  let expr = match @parser.parse_expr(filename, src) {
    Ok(e) => e
    Err(e) => return Err(@errors.EvalError::simple(e.to_string()))
  }
  let ctx = EvalContext::new(thread, opts)
  env.each(fn(k, v) {
    match k {
      @value.Value::String(s) => ctx.global_env.bind(s.raw(), v)
      _ => ()
    }
  })
  Ok(eval_expr_node(ctx, ctx.global_env, expr)) catch {
    EvalErr(e) => Err(e)
  }
}

///|
pub fn eval_parsed_expr(
  thread : Thread,
  expr : @syntax.Expr,
  opts : Options,
  env : @value.StarlarkDict,
) -> Result[@value.Value, @errors.EvalError] {
  let ctx = EvalContext::new(thread, opts)
  env.each(fn(k, v) {
    match k {
      @value.Value::String(s) => ctx.global_env.bind(s.raw(), v)
      _ => ()
    }
  })
  Ok(eval_expr_node(ctx, ctx.global_env, expr)) catch {
    EvalErr(e) => Err(e)
  }
}
