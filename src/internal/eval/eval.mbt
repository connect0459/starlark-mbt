///|
let default_max_recursion_depth : Int = 100

///|
pub(all) struct Options {
  allow_set : Bool
  allow_recursion : Bool
  allow_lambda : Bool
  allow_while : Bool
  allow_bytes : Bool
  allow_float : Bool
  allow_global_reassign : Bool
  allow_top_level_control : Bool
  load_binds_globally : Bool
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
  m["None"] = @value.Value::NoneVal
  m["True"] = @value.Value::BoolVal(true)
  m["False"] = @value.Value::BoolVal(false)
  for name in builtin_names {
    m[name] = @value.Value::BuiltinFuncVal({ name, body: None })
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
  name : String
  priv print_fn : (String) -> Unit
  priv load_fn : ((Thread, String) -> Result[Module, @errors.EvalError])?
  priv call_stack : Array[@errors.CallFrame]
  max_recursion_depth : Int
  max_steps : Int?
  priv mut steps : Int
  priv mut cancel_reason : String?
}

///|
pub fn Thread::new(name : String) -> Thread {
  {
    name,
    print_fn: fn(msg) { println(msg) },
    load_fn: None,
    call_stack: [],
    max_recursion_depth: default_max_recursion_depth,
    max_steps: None,
    steps: 0,
    cancel_reason: None,
  }
}

///|
pub fn Thread::with_print(name : String, print_fn : (String) -> Unit) -> Thread {
  {
    name,
    print_fn,
    load_fn: None,
    call_stack: [],
    max_recursion_depth: default_max_recursion_depth,
    max_steps: None,
    steps: 0,
    cancel_reason: None,
  }
}

///|
pub fn Thread::with_loader(
  name : String,
  load_fn : (Thread, String) -> Result[Module, @errors.EvalError],
) -> Thread {
  {
    name,
    print_fn: fn(msg) { println(msg) },
    load_fn: Some(load_fn),
    call_stack: [],
    max_recursion_depth: default_max_recursion_depth,
    max_steps: None,
    steps: 0,
    cancel_reason: None,
  }
}

///|
pub fn Thread::with_step_budget(name : String, max_steps : Int) -> Thread {
  {
    name,
    print_fn: fn(msg) { println(msg) },
    load_fn: None,
    call_stack: [],
    max_recursion_depth: default_max_recursion_depth,
    max_steps: Some(max_steps),
    steps: 0,
    cancel_reason: None,
  }
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
pub fn Thread::call_stack_depth(self : Thread) -> Int {
  self.call_stack.length()
}

///|
pub fn Thread::call_frames(self : Thread) -> Array[@errors.CallFrame] {
  self.call_stack.copy()
}

///|
pub fn Thread::execution_steps(self : Thread) -> Int {
  self.steps
}

///|
pub struct Module {
  priv globals : @value.StarlarkDict
  priv mut frozen : Bool
}

///|
pub fn Module::new() -> Module {
  { globals: @value.StarlarkDict::new(), frozen: false }
}

///|
pub fn Module::from_map(m : Map[String, @value.Value]) -> Module {
  let mod = Module::new()
  m.each(fn(name, v) {
    let key = @value.Value::StrVal(@value.StarlarkString::new(name))
    mod.globals.set(key, v) |> ignore
  })
  mod.freeze()
  mod
}

///|
pub fn Module::freeze(self : Module) -> Unit {
  self.frozen = true
  self.globals.freeze()
}

///|
pub fn Module::is_frozen(self : Module) -> Bool {
  self.frozen
}

///|
pub fn Module::get(self : Module, name : String) -> @value.Value? {
  let key = @value.Value::StrVal(@value.StarlarkString::new(name))
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
let builtin_names : Array[String] = [
  "None", "True", "False", "print", "len", "str", "repr", "type", "range", "list",
  "tuple", "dict", "bool", "int", "float", "abs", "min", "max", "set", "enumerate",
  "zip", "sorted", "reversed", "hasattr", "getattr", "fail", "any", "all", "hash",
  "dir", "chr", "ord", "bytes", "module",
]

///|
fn is_builtin(name : String) -> Bool {
  builtin_names.contains(name)
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
    Err(e) =>
      return Err({
        msg: e.to_string(),
        call_stack: @errors.CallStack::new([]),
        cause: None,
      })
  }
  let ctx = EvalContext::new(thread, opts)
  let resolve_opts = @resolver.ResolveOptions::default()
  let resolved = @resolver.resolve(
    file,
    is_builtin,
    fn(name) { name == "None" || name == "True" || name == "False" },
    resolve_opts,
  )
  if !resolved.errors.is_empty() {
    let msg = resolved.errors.map(fn(e) { e.to_string() }).join("; ")
    return Err({ msg, call_stack: @errors.CallStack::new([]), cause: None })
  }
  ignore(exec_stmts(ctx, ctx.global_env, file.stmts)) catch {
    EvalErr(e) => return Err(e)
  }
  let m = Module::new()
  ctx.global_env.locals.each(fn(name, v) {
    if ctx.opts.load_binds_globally || !ctx.load_bound_names.contains(name) {
      let key = @value.Value::StrVal(@value.StarlarkString::new(name))
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
    Err(e) =>
      return Err({
        msg: e.to_string(),
        call_stack: @errors.CallStack::new([]),
        cause: None,
      })
  }
  let ctx = EvalContext::new(thread, opts)
  predeclared.bindings.each(fn(name, v) { ctx.global_env.bind(name, v) })
  let extra_names : Array[String] = predeclared.bindings.keys().collect()
  let resolve_opts = @resolver.ResolveOptions::default()
  let resolved = @resolver.resolve(
    file,
    fn(name) { is_builtin(name) || extra_names.contains(name) },
    fn(name) { name == "None" || name == "True" || name == "False" },
    resolve_opts,
  )
  if !resolved.errors.is_empty() {
    let msg = resolved.errors.map(fn(e) { e.to_string() }).join("; ")
    return Err({ msg, call_stack: @errors.CallStack::new([]), cause: None })
  }
  ignore(exec_stmts(ctx, ctx.global_env, file.stmts)) catch {
    EvalErr(e) => return Err(e)
  }
  let m = Module::new()
  ctx.global_env.locals.each(fn(name, v) {
    if ctx.opts.load_binds_globally || !ctx.load_bound_names.contains(name) {
      let key = @value.Value::StrVal(@value.StarlarkString::new(name))
      m.globals.set(key, v) |> ignore
    }
  })
  m.freeze()
  Ok(m)
}

///|
pub fn eval_expr(
  thread : Thread,
  filename : String,
  src : String,
  env : @value.StarlarkDict,
) -> Result[@value.Value, @errors.EvalError] {
  let expr = match @parser.parse_expr(filename, src) {
    Ok(e) => e
    Err(e) =>
      return Err({
        msg: e.to_string(),
        call_stack: @errors.CallStack::new([]),
        cause: None,
      })
  }
  let opts = Options::default()
  let ctx = EvalContext::new(thread, opts)
  env.each(fn(k, v) {
    match k {
      @value.Value::StrVal(s) => ctx.global_env.bind(s.raw, v)
      _ => ()
    }
  })
  Ok(eval_expr_node(ctx, ctx.global_env, expr)) catch {
    EvalErr(e) => Err(e)
  }
}
