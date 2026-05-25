// Phase 0.75: Thread, Module, Options, and entry point stubs.

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
pub fn exec_file(
  _thread : Thread,
  _filename : String,
  _src : String,
  _opts : Options,
) -> Result[Module, @errors.EvalError] {
  Err({
    msg: "exec_file: not implemented",
    call_stack: @errors.CallStack::new([]),
    cause: None,
  })
}

///|
pub fn eval_expr(
  _thread : Thread,
  _filename : String,
  _src : String,
  _env : @value.StarlarkDict,
) -> Result[@value.Value, @errors.EvalError] {
  Err({
    msg: "eval_expr: not implemented",
    call_stack: @errors.CallStack::new([]),
    cause: None,
  })
}
