///|
let default_max_recursion_depth : Int = 100

///|
/// Feature-flag set controlling which optional Starlark dialect features are
/// enabled. All flags default to `true` unless otherwise noted.
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
/// Returns the default `Options` with all feature flags enabled.
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
/// Returns `true` if set literals and set comprehensions are allowed.
pub fn Options::allow_set(self : Options) -> Bool {
  self.allow_set
}

///|
/// Returns `true` if recursive function calls are allowed at runtime.
pub fn Options::allow_recursion(self : Options) -> Bool {
  self.allow_recursion
}

///|
/// Returns `true` if `lambda` expressions are allowed.
pub fn Options::allow_lambda(self : Options) -> Bool {
  self.allow_lambda
}

///|
/// Returns `true` if `while` loops are allowed.
pub fn Options::allow_while(self : Options) -> Bool {
  self.allow_while
}

///|
/// Returns `true` if `bytes` literals and the `bytes()` builtin are allowed.
pub fn Options::allow_bytes(self : Options) -> Bool {
  self.allow_bytes
}

///|
/// Returns `true` if floating-point literals and `float` arithmetic are
/// allowed.
pub fn Options::allow_float(self : Options) -> Bool {
  self.allow_float
}

///|
/// Returns `true` if module-level globals may be reassigned after their
/// initial binding.
pub fn Options::allow_global_reassign(self : Options) -> Bool {
  self.allow_global_reassign
}

///|
/// Returns `true` if `if`, `for`, and `while` statements are allowed at
/// the module (top) level.
pub fn Options::allow_top_level_control(self : Options) -> Bool {
  self.allow_top_level_control
}

///|
/// Returns `true` if `load`-imported names are bound at module (global) scope
/// rather than file-local scope.
pub fn Options::load_binds_globally(self : Options) -> Bool {
  self.load_binds_globally
}

///|
/// Returns a copy of `self` with `load_binds_globally` set to `v`.
///
/// Parameters:
///
/// - `self` : The options to copy.
/// - `v` : The new value for the `load_binds_globally` flag.
///
/// Returns a new `Options` with the `load_binds_globally` flag set to `v`.
pub fn Options::with_load_binds_globally(self : Options, v : Bool) -> Options {
  { ..self, load_binds_globally: v }
}

///|
/// Returns a copy of `self` with `allow_recursion` set to `v`.
///
/// Parameters:
///
/// - `self` : The options to copy.
/// - `v` : The new value for the `allow_recursion` flag.
///
/// Returns a new `Options` with the `allow_recursion` flag set to `v`.
pub fn Options::with_allow_recursion(self : Options, v : Bool) -> Options {
  { ..self, allow_recursion: v }
}

///|
/// Returns a copy of `self` with `allow_set` set to `v`.
///
/// Parameters:
///
/// - `self` : The options to copy.
/// - `v` : The new value for the `allow_set` flag.
///
/// Returns a new `Options` with the `allow_set` flag set to `v`.
pub fn Options::with_allow_set(self : Options, v : Bool) -> Options {
  { ..self, allow_set: v }
}

///|
/// Returns a copy of `self` with `allow_global_reassign` set to `v`.
///
/// Parameters:
///
/// - `self` : The options to copy.
/// - `v` : The new value for the `allow_global_reassign` flag.
///
/// Returns a new `Options` with the `allow_global_reassign` flag set to `v`.
pub fn Options::with_allow_global_reassign(self : Options, v : Bool) -> Options {
  { ..self, allow_global_reassign: v }
}

///|
/// Returns a copy of `self` with `allow_lambda` set to `v`.
///
/// Parameters:
///
/// - `self` : The options to copy.
/// - `v` : The new value for the `allow_lambda` flag.
///
/// Returns a new `Options` with the `allow_lambda` flag set to `v`.
pub fn Options::with_allow_lambda(self : Options, v : Bool) -> Options {
  { ..self, allow_lambda: v }
}

///|
/// Returns a copy of `self` with `allow_while` set to `v`.
///
/// Parameters:
///
/// - `self` : The options to copy.
/// - `v` : The new value for the `allow_while` flag.
///
/// Returns a new `Options` with the `allow_while` flag set to `v`.
pub fn Options::with_allow_while(self : Options, v : Bool) -> Options {
  { ..self, allow_while: v }
}

///|
/// Returns a copy of `self` with `allow_bytes` set to `v`.
///
/// Parameters:
///
/// - `self` : The options to copy.
/// - `v` : The new value for the `allow_bytes` flag.
///
/// Returns a new `Options` with the `allow_bytes` flag set to `v`.
pub fn Options::with_allow_bytes(self : Options, v : Bool) -> Options {
  { ..self, allow_bytes: v }
}

///|
/// Returns a copy of `self` with `allow_float` set to `v`.
///
/// Parameters:
///
/// - `self` : The options to copy.
/// - `v` : The new value for the `allow_float` flag.
///
/// Returns a new `Options` with the `allow_float` flag set to `v`.
pub fn Options::with_allow_float(self : Options, v : Bool) -> Options {
  { ..self, allow_float: v }
}

///|
/// Returns a copy of `self` with `allow_top_level_control` set to `v`.
///
/// Parameters:
///
/// - `self` : The options to copy.
/// - `v` : The new value for the `allow_top_level_control` flag.
///
/// Returns a new `Options` with the `allow_top_level_control` flag set to `v`.
pub fn Options::with_allow_top_level_control(
  self : Options,
  v : Bool,
) -> Options {
  { ..self, allow_top_level_control: v }
}

///|
/// The set of predeclared built-in bindings shared across all modules.
/// `Universe::standard()` provides the default Starlark built-ins; embedders
/// may extend it with `set()`.
pub struct Universe {
  priv bindings : Map[String, @value.Value]
}

///|
/// Creates an empty `Universe` with no predeclared names.
pub fn Universe::empty() -> Universe {
  { bindings: {} }
}

///|
/// Creates a `Universe` pre-populated with all standard Starlark built-ins
/// (`None`, `True`, `False`, `print`, `range`, etc.).
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
/// Returns the value bound to `name` in the universe, or `None`.
///
/// Parameters:
///
/// - `self` : The universe to look up in.
/// - `name` : The predeclared name to retrieve.
///
/// Returns `Some(value)` if `name` is present, `None` otherwise.
pub fn Universe::get(self : Universe, name : String) -> @value.Value? {
  self.bindings.get(name)
}

///|
/// Returns `true` if `name` is present in the universe.
///
/// Parameters:
///
/// - `self` : The universe to query.
/// - `name` : The name to test for presence.
///
/// Returns `true` if `name` exists in the universe.
pub fn Universe::has(self : Universe, name : String) -> Bool {
  self.bindings.contains(name)
}

///|
/// Adds or replaces the binding for `name` in the universe.
///
/// Parameters:
///
/// - `self` : The universe to modify.
/// - `name` : The predeclared name to bind.
/// - `value` : The value to associate with `name`.
pub fn Universe::set(
  self : Universe,
  name : String,
  value : @value.Value,
) -> Unit {
  self.bindings[name] = value
}

///|
/// Per-execution extra bindings injected before user globals. Visible to
/// both the resolver and evaluator but not exported in the resulting Module.
pub struct Predeclared {
  priv bindings : Map[String, @value.Value]
}

///|
/// Creates an empty `Predeclared` set.
pub fn Predeclared::new() -> Predeclared {
  { bindings: {} }
}

///|
/// Creates a `Predeclared` set wrapping an existing map.
///
/// Parameters:
///
/// - `m` : The map to wrap; keys are name strings, values are the bindings.
///
/// Returns a `Predeclared` backed by `m`.
pub fn Predeclared::from_map(m : Map[String, @value.Value]) -> Predeclared {
  { bindings: m }
}

///|
/// Adds or replaces the binding for `name`.
///
/// Parameters:
///
/// - `self` : The predeclared set to modify.
/// - `name` : The name to bind.
/// - `v` : The value to associate with `name`.
pub fn Predeclared::set(
  self : Predeclared,
  name : String,
  v : @value.Value,
) -> Unit {
  self.bindings[name] = v
}

///|
/// Returns the value bound to `name`, or `None`.
///
/// Parameters:
///
/// - `self` : The predeclared set to look up in.
/// - `name` : The name to retrieve.
///
/// Returns `Some(value)` if `name` is present, `None` otherwise.
pub fn Predeclared::get(self : Predeclared, name : String) -> @value.Value? {
  self.bindings.get(name)
}

///|
/// Execution context for a single Starlark evaluation. Carries the print
/// and load callbacks, call stack, recursion limit, step budget, and
/// cancellation state. A `Thread` is not safe for concurrent use.
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
/// Creates a `Thread` with the given name, printing to stdout, no loader,
/// and the default recursion depth limit.
///
/// Parameters:
///
/// - `name` : A label for the thread used in diagnostics.
///
/// Returns a new `Thread` ready for Starlark execution.
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
/// Creates a `Thread` with a custom print callback.
///
/// Parameters:
///
/// - `name` : A label for the thread used in diagnostics.
/// - `print_fn` : Callback invoked for each `print()` call; receives the
///   active thread and the formatted message string.
///
/// Returns a new `Thread` with the given print callback.
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
/// Creates a `Thread` with a load callback for `load()` statements.
///
/// Parameters:
///
/// - `name` : A label for the thread used in diagnostics.
/// - `load_fn` : Callback invoked for each `load("path", ...)` statement;
///   receives the active thread and the module path, returns the loaded module.
///
/// Returns a new `Thread` with the given load callback.
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
/// Creates a `Thread` with a maximum step budget; execution raises an error
/// when the budget is exhausted.
///
/// Parameters:
///
/// - `name` : A label for the thread used in diagnostics.
/// - `max_steps` : Maximum number of evaluation steps before the execution
///   is cancelled with an error.
///
/// Returns a new `Thread` with the given step budget.
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
/// Stores a thread-local value under `key`. Used by extension libraries (e.g.
/// `time.now()`) to communicate per-thread state such as clock overrides.
///
/// Parameters:
///
/// - `self` : The thread to store the value on.
/// - `key` : The key identifying this thread-local slot.
/// - `value` : The value to store.
pub fn Thread::set_local(
  self : Thread,
  key : String,
  value : @value.Value,
) -> Unit {
  self.locals[key] = value
}

///|
/// Retrieves the thread-local value previously stored under `key`, or `None`.
///
/// Parameters:
///
/// - `self` : The thread to retrieve from.
/// - `key` : The key identifying the thread-local slot.
///
/// Returns `Some(value)` if a value was stored under `key`, `None` otherwise.
pub fn Thread::get_local(self : Thread, key : String) -> @value.Value? {
  self.locals.get(key)
}

///|
/// Marks the thread as cancelled with the given reason. The evaluator checks
/// this flag at each step and raises an error on the next opportunity. Only
/// the first call takes effect.
///
/// Parameters:
///
/// - `self` : The thread to cancel.
/// - `reason` : A message describing why the thread was cancelled; used in
///   the raised error.
pub fn Thread::cancel(self : Thread, reason : String) -> Unit {
  if self.cancel_reason is None {
    self.cancel_reason = Some(reason)
  }
}

///|
/// Clears a previous cancellation, allowing execution to resume.
pub fn Thread::uncancel(self : Thread) -> Unit {
  self.cancel_reason = None
}

///|
/// Resets the accumulated step counter to zero without changing the budget.
pub fn Thread::reset_steps(self : Thread) -> Unit {
  self.steps = 0
}

///|
/// Sets the execution-step budget without resetting the accumulated step
/// count. Use `reset_steps` to zero the counter explicitly.
///
/// Parameters:
///
/// - `self` : The thread to update.
/// - `max` : The new maximum step count.
pub fn Thread::set_max_steps(self : Thread, max : Int) -> Unit {
  self.max_steps = Some(max)
}

///|
/// Replaces the print callback. Combined with `set_loader` and
/// `set_max_steps`, this lets a single thread carry all three settings.
///
/// Parameters:
///
/// - `self` : The thread to update.
/// - `print_fn` : The new print callback; receives the active thread and the
///   formatted message string.
pub fn Thread::set_print(
  self : Thread,
  print_fn : (Thread, String) -> Unit,
) -> Unit {
  self.print_fn = print_fn
}

///|
/// Replaces the load callback used by `load()` statements.
///
/// Parameters:
///
/// - `self` : The thread to update.
/// - `load_fn` : The new load callback; receives the active thread and the
///   module path, returns the loaded module or an error.
pub fn Thread::set_loader(
  self : Thread,
  load_fn : (Thread, String) -> Result[Module, @errors.EvalError],
) -> Unit {
  self.load_fn = Some(load_fn)
}

///|
/// Registers a callback invoked when the step budget is exhausted, before
/// the error is raised.
///
/// Parameters:
///
/// - `self` : The thread to update.
/// - `cb` : The callback to invoke when the step budget is exhausted.
pub fn Thread::set_on_max_steps(self : Thread, cb : (Thread) -> Unit) -> Unit {
  self.on_max_steps = Some(cb)
}

///|
/// Returns the current call-stack depth (number of active Starlark frames).
pub fn Thread::call_stack_depth(self : Thread) -> Int {
  self.call_stack.length()
}

///|
/// Returns a snapshot of the active Starlark call frame at `depth` steps
/// from the innermost frame (0 = innermost). Returns `None` if `depth` is
/// out of range or the frame is not a Starlark function frame.
///
/// Parameters:
///
/// - `self` : The thread whose debug call stack to inspect.
/// - `depth` : Distance from the innermost Starlark function frame (0 = innermost).
///
/// Returns `Some(frame)` if a Starlark frame exists at that depth, `None`
/// otherwise.
pub fn Thread::debug_frame(self : Thread, depth : Int) -> DebugFrame? {
  let idx = self.debug_stack.length() - 1 - depth
  if idx < 0 || idx >= self.debug_stack.length() {
    return None
  }
  Some(DebugFrame::from_active(self.debug_stack[idx]))
}

///|
/// Returns a snapshot of the current call stack (outermost frame first).
pub fn Thread::call_stack(self : Thread) -> @errors.CallStack {
  @errors.CallStack::new(self.call_stack.copy())
}

///|
/// Returns a copy of the raw call-frame array (outermost first).
pub fn Thread::call_frames(self : Thread) -> Array[@errors.CallFrame] {
  self.call_stack.copy()
}

///|
/// Returns the call frame at `n` steps from the innermost frame (0 =
/// innermost, 1 = its caller, etc.), or `None` if out of range.
///
/// Parameters:
///
/// - `self` : The thread whose call stack to inspect.
/// - `n` : Distance from the innermost frame (0 = innermost).
///
/// Returns `Some(frame)` if the index is valid, `None` otherwise.
pub fn Thread::call_frame(self : Thread, n : Int) -> @errors.CallFrame? {
  let idx = self.call_stack.length() - 1 - n
  if idx < 0 || idx >= self.call_stack.length() {
    return None
  }
  Some(self.call_stack[idx])
}

///|
/// Returns the total number of evaluation steps executed on this thread.
pub fn Thread::execution_steps(self : Thread) -> Int {
  self.steps
}

///|
/// Returns the name the thread was created with.
pub fn Thread::name(self : Thread) -> String {
  self.name
}

///|
/// Returns the maximum call-stack depth before a recursion-limit error is
/// raised.
pub fn Thread::max_recursion_depth(self : Thread) -> Int {
  self.max_recursion_depth
}

///|
/// Returns the current step budget, or `None` if no budget was set.
pub fn Thread::max_steps(self : Thread) -> Int? {
  self.max_steps
}

///|
/// The result of executing a Starlark file: a frozen mapping of global names
/// to their values, plus any injected predeclared bindings.
pub struct Module {
  priv globals : @value.StarlarkDict
  priv mut frozen : Bool
  priv predeclared : Map[String, @value.Value]
}

///|
/// Creates an empty, unfrozen `Module`.
pub fn Module::new() -> Module {
  { globals: @value.StarlarkDict::new(), frozen: false, predeclared: {} }
}

///|
/// Creates a frozen `Module` pre-populated from `m`.
///
/// Parameters:
///
/// - `m` : A map of global name strings to their initial values.
///
/// Returns a new, frozen `Module` containing the bindings from `m`.
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
/// Freezes the module: marks the globals dict and all contained values as
/// immutable so they can safely be shared across threads.
pub fn Module::freeze(self : Module) -> Unit {
  self.frozen = true
  self.globals.freeze()
  self.globals.each(fn(_, v) { v.freeze() })
}

///|
/// Returns `true` if this module has been frozen.
pub fn Module::is_frozen(self : Module) -> Bool {
  self.frozen
}

///|
/// Returns the value bound to `name` in the module globals, or `None`.
///
/// Parameters:
///
/// - `self` : The module to look up in.
/// - `name` : The global name to retrieve.
///
/// Returns `Some(value)` if `name` is present, `None` otherwise.
pub fn Module::get(self : Module, name : String) -> @value.Value? {
  let key = @value.Value::String(@value.StarlarkString::new(name))
  match self.globals.get(key) {
    Ok(Some(v)) => Some(v)
    _ => None
  }
}

///|
/// Returns the number of exported globals in the module.
pub fn Module::globals_count(self : Module) -> Int {
  self.globals.length()
}

///|
/// Returns the names of all exported globals in insertion order.
///
/// Returns an `Array[String]` of every global name bound in the module.
pub fn Module::global_names(self : Module) -> Array[String] {
  let result : Array[String] = []
  self.globals.each(fn(k, _) {
    match k {
      @value.Value::String(s) => result.push(s.raw())
      _ => ()
    }
  })
  result
}

///|
/// Returns the names of all predeclared bindings that were injected before
/// execution.
///
/// Returns an `Array[String]` of every predeclared name.
pub fn Module::predeclared_names(self : Module) -> Array[String] {
  let result : Array[String] = []
  self.predeclared.each(fn(k, _) { result.push(k) })
  result
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
/// Invokes a Starlark callable from host code with positional `args` and
/// keyword `kwargs`.
///
/// Parameters:
///
/// - `thread` : Execution context providing print/load callbacks and step budget.
/// - `func` : The Starlark callable to invoke (function, builtin, or bound method).
/// - `args` : Positional arguments to pass.
/// - `kwargs` : Keyword arguments as `(name, value)` pairs.
///
/// Returns the call result, or an `EvalError` on failure.
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
/// Applies a Starlark binary operator by name to `x` and `y`.
/// Valid operators: `"+"`, `"-"`, `"*"`, `"/"`, `"//"`, `"%"`,
/// `"&"`, `"|"`, `"^"`, `"<<"`, `">>"`.
///
/// Parameters:
///
/// - `op` : The binary operator name.
/// - `x` : The left-hand operand.
/// - `y` : The right-hand operand.
///
/// Returns the operation result, or an `EvalError` on type mismatch or
/// arithmetic error.
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
/// Applies a Starlark unary operator by name to `x`.
/// Valid operators: `"+"`, `"-"`, `"~"`, `"not"`.
///
/// Parameters:
///
/// - `op` : The unary operator name.
/// - `x` : The operand.
///
/// Returns the operation result, or an `EvalError` on type mismatch.
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
/// Applies a Starlark comparison operator by name to `x` and `y`.
/// Valid operators: `"=="`, `"!="`, `"<"`, `"<="`, `">"`, `">="`.
///
/// Parameters:
///
/// - `op` : The comparison operator name.
/// - `x` : The left-hand operand.
/// - `y` : The right-hand operand.
///
/// Returns `Ok(result)` on success, or an `EvalError` on type mismatch.
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
/// Parses, resolves, and executes a Starlark source file; returns the frozen
/// module whose globals are the file's top-level bindings.
///
/// Parameters:
///
/// - `thread` : Execution context providing print/load callbacks and step budget.
/// - `filename` : Source file name used in error messages and position info.
/// - `src` : Starlark source text to execute.
/// - `opts` : Feature flags controlling which dialect features are active.
///
/// Returns the frozen `Module`, or an `EvalError` on parse, resolve, or
/// runtime failure.
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
/// Like `exec_file` but replaces the default built-in universe with
/// `universe`, allowing the embedder to override or extend predeclared names.
///
/// Parameters:
///
/// - `thread` : Execution context providing print/load callbacks and step budget.
/// - `filename` : Source file name used in error messages and position info.
/// - `src` : Starlark source text to execute.
/// - `opts` : Feature flags controlling which dialect features are active.
/// - `universe` : Custom universe of predeclared bindings to use instead of
///   the standard built-ins.
///
/// Returns the frozen `Module`, or an `EvalError` on failure.
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
/// Like `exec_file` but injects extra `predeclared` bindings that are visible
/// to the script but not included in the returned module's globals.
///
/// Parameters:
///
/// - `thread` : Execution context providing print/load callbacks and step budget.
/// - `filename` : Source file name used in error messages and position info.
/// - `src` : Starlark source text to execute.
/// - `opts` : Feature flags controlling which dialect features are active.
/// - `predeclared` : Extra per-execution bindings injected before user globals.
///
/// Returns the frozen `Module`, or an `EvalError` on failure.
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
/// Executes one REPL chunk: parses `src`, resolves it against `globals`,
/// evaluates it, and writes any new or updated bindings back into `globals`.
///
/// Parameters:
///
/// - `thread` : Execution context providing print/load callbacks and step budget.
/// - `filename` : Source file name used in error messages and position info.
/// - `src` : Starlark source chunk to execute (may be statements or an expression).
/// - `globals` : Mutable dict that persists global bindings across REPL chunks.
/// - `opts` : Feature flags controlling which dialect features are active.
///
/// Returns `Ok(())` on success, or an `EvalError` on failure.
pub fn exec_repl_chunk(
  thread : Thread,
  filename : String,
  src : String,
  globals : @value.StringDict,
  opts : Options,
) -> Result[Unit, @errors.EvalError] {
  let file = match @parser.parse_file(filename, src) {
    Ok(f) => f
    Err(e) => return Err(@errors.EvalError::simple(e.to_string()))
  }
  let ctx = EvalContext::new(thread, { ..opts, load_binds_globally: true })
  globals.each(fn(k, v) { ctx.global_env.bind(k, v) })
  collect_module_globals_into(
    file.stmts(),
    true,
    ctx.global_env.known_module_globals,
  )
  let extra_names = globals.keys()
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
  ctx.global_env.locals.each(fn(name, v) { globals.set(name, v) })
  Ok(())
}

///|
/// Parses and evaluates a single Starlark expression with the default options,
/// using `env` as the global environment.
///
/// Parameters:
///
/// - `thread` : Execution context providing print/load callbacks and step budget.
/// - `filename` : Source file name used in error messages and position info.
/// - `src` : Starlark expression source text to evaluate.
/// - `env` : Global environment dict supplying variable bindings.
///
/// Returns the evaluated `Value`, or an `EvalError` on failure.
pub fn eval_expr(
  thread : Thread,
  filename : String,
  src : String,
  env : @value.StringDict,
) -> Result[@value.Value, @errors.EvalError] {
  eval_expr_with_opts(thread, filename, src, Options::default(), env)
}

///|
/// Like `eval_expr` but accepts explicit `opts`.
///
/// Parameters:
///
/// - `thread` : Execution context providing print/load callbacks and step budget.
/// - `filename` : Source file name used in error messages and position info.
/// - `src` : Starlark expression source text to evaluate.
/// - `opts` : Feature flags controlling which dialect features are active.
/// - `env` : Global environment dict supplying variable bindings.
///
/// Returns the evaluated `Value`, or an `EvalError` on failure.
pub fn eval_expr_with_opts(
  thread : Thread,
  filename : String,
  src : String,
  opts : Options,
  env : @value.StringDict,
) -> Result[@value.Value, @errors.EvalError] {
  let expr = match @parser.parse_expr(filename, src) {
    Ok(e) => e
    Err(e) => return Err(@errors.EvalError::simple(e.to_string()))
  }
  let ctx = EvalContext::new(thread, opts)
  env.each(fn(k, v) { ctx.global_env.bind(k, v) })
  Ok(eval_expr_node(ctx, ctx.global_env, expr)) catch {
    EvalErr(e) => Err(e)
  }
}

///|
/// Evaluates a pre-parsed expression node under `opts` with the bindings in
/// `env` as the global environment.
///
/// Parameters:
///
/// - `thread` : Execution context providing print/load callbacks and step budget.
/// - `expr` : Pre-parsed expression AST node to evaluate.
/// - `opts` : Feature flags controlling which dialect features are active.
/// - `env` : Global environment dict supplying variable bindings.
///
/// Returns the evaluated `Value`, or an `EvalError` on runtime failure.
pub fn eval_parsed_expr(
  thread : Thread,
  expr : @syntax.Expr,
  opts : Options,
  env : @value.StringDict,
) -> Result[@value.Value, @errors.EvalError] {
  let ctx = EvalContext::new(thread, opts)
  env.each(fn(k, v) { ctx.global_env.bind(k, v) })
  Ok(eval_expr_node(ctx, ctx.global_env, expr)) catch {
    EvalErr(e) => Err(e)
  }
}
