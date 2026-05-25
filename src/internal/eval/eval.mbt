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
pub(all) struct Thread {
  name : String
  print_fn : (String) -> Unit
  load_fn : ((String) -> Result[Map[String, @value.Value], String])?
  mut call_stack : Array[@errors.CallFrame]
  max_recursion_depth : Int
  max_steps : Int?
  mut steps : Int
}

///|
pub fn Thread::new(name : String) -> Thread {
  {
    name,
    print_fn: fn(msg) { println(msg) },
    load_fn: None,
    call_stack: [],
    max_recursion_depth: 100,
    max_steps: None,
    steps: 0,
  }
}

///|
pub fn Thread::with_print(name : String, print_fn : (String) -> Unit) -> Thread {
  {
    name,
    print_fn,
    load_fn: None,
    call_stack: [],
    max_recursion_depth: 100,
    max_steps: None,
    steps: 0,
  }
}

///|
pub fn Thread::with_loader(
  name : String,
  load_fn : (String) -> Result[Map[String, @value.Value], String],
) -> Thread {
  {
    name,
    print_fn: fn(msg) { println(msg) },
    load_fn: Some(load_fn),
    call_stack: [],
    max_recursion_depth: 100,
    max_steps: None,
    steps: 0,
  }
}

///|
pub(all) struct Module {
  globals : @value.StarlarkDict
  mut frozen : Bool
}

///|
pub fn Module::new() -> Module {
  { globals: @value.StarlarkDict::new(), frozen: false }
}

///|
pub fn Module::freeze(self : Module) -> Unit {
  self.frozen = true
  self.globals.freeze()
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
    let key = @value.Value::StrVal(@value.StarlarkString::new(name))
    m.globals.set(key, v) |> ignore
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
