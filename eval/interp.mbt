// Bytecode virtual machine. This is now the default engine (issue #1): it
// executes `@compile.CompiledProgram` bytecode, and every public entry point
// (`exec_file`, `eval_expr`, the universe/predeclared variants, the REPL, and
// `Program::init`) runs on it. The AST walker is retained behind the flip for
// rollback and for the differential harness, which still verifies the two
// engines agree.
//
// Operator semantics are reused wholesale from `ops.mbt` (eval_binary /
// eval_unary / eval_index): the VM pops operands off its stack and calls the
// same functions the walker does, passing a source position recovered from the
// funcode's line table so error messages and positions match.

///|
/// Materializes a compile-time constant-pool entry into a runtime value.
fn const_to_value(c : @compile.Const) -> @value.Value {
  match c {
    CNone => @value.Value::None
    CBool(b) => @value.Value::Bool(b)
    CInt(n) => @value.Value::Int(n)
    CFloat(f) => @value.Value::Float(f)
    CStr(s) => @value.Value::String(@value.StarlarkString::new(s))
    CBytes(b) => @value.Value::Bytes(b)
  }
}

///|
/// Maps a binary-operator opcode to its `@syntax.BinaryOp`, so the VM can reuse
/// the walker's `eval_binary`. Returns `None` for non-binary opcodes.
fn binop_of_opcode(op : @compile.Opcode) -> @syntax.BinaryOp? {
  match op {
    Plus => Some(OpAdd)
    Minus => Some(OpSub)
    Star => Some(OpMul)
    Slash => Some(OpDiv)
    SlashSlash => Some(OpFloorDiv)
    Percent => Some(OpMod)
    Amp => Some(OpBitAnd)
    Pipe => Some(OpBitOr)
    Circumflex => Some(OpBitXor)
    LtLt => Some(OpLShift)
    GtGt => Some(OpRShift)
    Eql => Some(OpEq)
    Neq => Some(OpNe)
    Lt => Some(OpLt)
    Le => Some(OpLe)
    Gt => Some(OpGt)
    Ge => Some(OpGe)
    In => Some(OpIn)
    _ => None
  }
}

///|
/// Reads a uvarint operand from `code` starting at `i`, returning the value and
/// the offset just past it. The compiler guarantees well-formed operands; a
/// truncated or over-long stream is an internal invariant violation and aborts
/// with a clear message, mirroring the disassembler's bounded decode.
fn vm_read_arg(code : Bytes, i : Int) -> (Int, Int) {
  let mut result = 0
  let mut shift = 0
  let mut pc = i
  for _ in 0..<5 {
    if pc >= code.length() {
      abort("vm: truncated operand")
    }
    let b = code[pc].to_int()
    pc += 1
    result = result | ((b & 0x7f) << shift)
    if (b & 0x80) == 0 {
      return (result, pc)
    }
    shift += 7
  }
  abort("vm: operand too long")
}

///|
/// Collects exactly `n` values from `value` for a sequence assignment, mirroring
/// the walker's unpacking: tuples/lists yield their items directly, other values
/// are iterated, and a non-iterable or a length mismatch raises the same error.
fn unpack_items(
  ctx : EvalContext,
  value : @value.Value,
  n : Int,
) -> Array[@value.Value] raise EvalErr {
  let items : Array[@value.Value] = match value {
    @value.Value::Tuple(t) => t
    @value.Value::List(l) => {
      let arr : Array[@value.Value] = []
      for v in l.iter() {
        arr.push(v)
      }
      arr
    }
    _ =>
      match @value.iterate(value) {
        Ok(it) => {
          let collected : Array[@value.Value] = []
          while true {
            match it.next() {
              None => break
              Some(item) => collected.push(item)
            }
          }
          it.done()
          collected
        }
        Err(_) =>
          raise EvalErr(
            make_eval_error(
              ctx,
              "got \{value.type_name()} in sequence assignment",
            ),
          )
      }
  }
  if items.length() < n {
    raise EvalErr(
      make_eval_error(
        ctx,
        "too few values to unpack (got \{items.length()}, want \{n})",
      ),
    )
  } else if items.length() > n {
    raise EvalErr(
      make_eval_error(
        ctx,
        "too many values to unpack (got \{items.length()}, want \{n})",
      ),
    )
  }
  items
}

///|
/// Expands a `*args` call argument, appending each item of `iterable` to `out`.
/// Mirrors the walker's argument expansion, including the not-iterable error.
fn expand_star_args(
  ctx : EvalContext,
  iterable : @value.Value,
  out : Array[@value.Value],
) -> Unit raise EvalErr {
  let it = match @value.iterate(iterable) {
    Ok(it) => it
    Err(_) =>
      raise EvalErr(
        make_eval_error(
          ctx,
          "argument after * must be iterable, not \{iterable.type_name()}",
        ),
      )
  }
  while true {
    match it.next() {
      None => {
        it.done()
        break
      }
      Some(item) => out.push(item)
    }
  }
}

///|
/// Expands a `**kwargs` call argument, appending each `(name, value)` of the
/// mapping to `out`. Mirrors the walker: the argument must be a dict and every
/// key must be a string.
fn expand_kwargs(
  ctx : EvalContext,
  mapping : @value.Value,
  out : Array[(String, @value.Value)],
) -> Unit raise EvalErr {
  match mapping {
    @value.Value::Dict(d) =>
      for entry in d.to_entries() {
        let (k, val) = entry
        match k {
          @value.Value::String(s) => out.push((s.raw(), val))
          _ =>
            raise EvalErr(
              make_eval_error(
                ctx,
                "keywords must be strings, not \{k.type_name()}",
              ),
            )
        }
      }
    _ =>
      raise EvalErr(
        make_eval_error(
          ctx,
          "argument after ** must be a mapping, not \{mapping.type_name()}",
        ),
      )
  }
}

///|
/// Reports whether `name` is bound by a `load` statement of `prog` (its local
/// alias). Such names are module-local unless `load_binds_globally`, which the
/// referenced-before-assignment message reflects.
fn load_binds_name(prog : @compile.CompiledProgram, name : String) -> Bool {
  for ls in prog.load_stmts {
    for loc in ls.locals {
      if loc == name {
        return true
      }
    }
  }
  false
}

///|
/// Decodes an `AugApply` operand back into an augmented-assignment operator.
fn augop_of_int(code : Int) -> @syntax.AugOp {
  match code {
    0 => AugAdd
    1 => AugSub
    2 => AugMul
    3 => AugDiv
    4 => AugFloorDiv
    5 => AugMod
    6 => AugBitAnd
    7 => AugBitOr
    8 => AugBitXor
    9 => AugLShift
    10 => AugRShift
    _ => abort("vm: invalid augmented-operator code \{code}")
  }
}

///|
/// Pops `n` values off the operand stack and returns them in source order
/// (bottom-to-top), as produced by `MakeList`/`MakeTuple`.
fn pop_n(stack : Array[@value.Value], n : Int) -> Array[@value.Value] {
  let out : Array[@value.Value] = Array::make(n, @value.Value::None)
  for i = n - 1; i >= 0; i = i - 1 {
    out[i] = match stack.pop() {
      Some(v) => v
      None => abort("vm: operand stack underflow")
    }
  }
  out
}

///|
/// Compiles and runs `src` on the bytecode VM, returning a `Module` of the
/// resulting globals. The public `exec_file` delegates here. Retained as an
/// internal entry so the differential harness can run the VM explicitly while
/// the walker remains available. Resolution matches `file_program` so resolver
/// errors match the walker.
#internal(unsafe, "experimental bytecode VM entry; not part of the public embedding API")
pub fn exec_file_vm(
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
  let (prog, m) = match
    compile_and_run_vm(ctx, file, filename, fn(_) { false }) {
    Ok(pair) => pair
    Err(e) => return Err(e)
  }
  Ok(Module::from_map(module_output(prog, m, opts)))
}

///|
/// Validates `file` with the resolver, compiles it, and runs it on the VM,
/// returning the compiled program and the resulting module state. `extra_pred`
/// names the embedder-supplied predeclared names (a custom universe or per-call
/// predeclared bindings) so resolution and compilation classify them correctly;
/// the bindings themselves must already be bound into `ctx.global_env`. Shared by
/// every VM entry point.
fn compile_and_run_vm(
  ctx : EvalContext,
  file : @syntax.File,
  filename : String,
  extra_pred : (String) -> Bool,
  init? : (String) -> @value.Value? = fn(_) { None },
) -> Result[(@compile.CompiledProgram, RunModule), @errors.EvalError] {
  // Validate with the same resolver pass the walker uses; resolver errors
  // (messages and positions) match the walker exactly.
  match file_program(file, ctx.opts, extra_pred) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let prog = @compile.compile(
    file,
    fn(name) { is_builtin(name) || extra_pred(name) },
    fn(name) { name == "None" || name == "True" || name == "False" },
    ctx.opts.allow_recursion,
  ) catch {
    @compile.CompileErr(msg) => return Err(@errors.EvalError::simple(msg))
  }
  match run_program_vm(ctx, prog, filename, init~) {
    Ok(m) => Ok((prog, m))
    Err(e) => Err(e)
  }
}

///|
/// Collects a finished run's module globals as a name -> value map, excluding
/// load-local bindings unless `load_binds_globally`.
fn module_output(
  prog : @compile.CompiledProgram,
  m : RunModule,
  opts : Options,
) -> Map[String, @value.Value] {
  let out : Map[String, @value.Value] = {}
  for i, binding in prog.globals {
    match m.globals[i] {
      Some(v) =>
        if opts.load_binds_globally || !m.load_bound.contains(binding.name()) {
          out[binding.name()] = v
        }
      None => ()
    }
  }
  out
}

///|
/// Runs a compiled program's module-init function on a fresh VM and returns the
/// resulting module state (its populated global slots). Shared by `exec_file_vm`
/// and `eval_expr_vm`. Pushes and pops the `<toplevel>` call frame so backtraces
/// begin at `<toplevel>`, matching the walker.
fn run_program_vm(
  ctx : EvalContext,
  prog : @compile.CompiledProgram,
  filename : String,
  init? : (String) -> @value.Value? = fn(_) { None },
) -> Result[RunModule, @errors.EvalError] {
  let vm = VM::{ ctx, active: [] }
  let m = RunModule::{
    prog,
    globals: Array::make(prog.globals.length(), None),
    load_bound: [],
  }
  // Pre-fill module-global slots from `init` (the REPL seeds a chunk's globals
  // with the values accumulated by previous chunks, so a global reassigned in a
  // later chunk starts from its prior value rather than unbound).
  for i, binding in prog.globals {
    match init(binding.name()) {
      Some(v) => m.globals[i] = Some(v)
      None => ()
    }
  }
  ctx.vm = Some(vm)
  try {
    ctx.thread.call_stack.push(
      @errors.CallFrame::new(
        "<toplevel>",
        @errors.Position::new(filename, 1, 1),
      ),
    )
    let idx = ctx.thread.call_stack.length() - 1
    let top_locals : Array[LocalSlot] = Array::make(
      prog.toplevel.locals.length(),
      LUnbound,
    )
    let no_freevars : Array[@value.Cell] = []
    vm.run_frame(m, prog.toplevel, "<toplevel>", top_locals, no_freevars, idx)
    |> ignore
    ctx.thread.call_stack.pop() |> ignore
    Ok(m)
  } catch {
    EvalErr(e) => {
      ctx.thread.call_stack.pop() |> ignore
      Err(e)
    }
  }
}

///|
/// Compiles and evaluates a single expression on the bytecode VM, returning its
/// value. The expression is lowered as a synthetic `<result> = <expr>` module
/// (named after the expression's source file) so the VM can run it; `env`
/// bindings are bound into the context (and treated as predeclared) so they
/// resolve, and the result is read back from its global.
#internal(unsafe, "bytecode VM only; not part of the public embedding API")
pub fn eval_expr_vm(
  thread : Thread,
  expr : @syntax.Expr,
  opts : Options,
  env : @value.StringDict,
) -> Result[@value.Value, @errors.EvalError] {
  let ctx = EvalContext::new(thread, opts)
  env.each(fn(k, v) { ctx.global_env.bind(k, v) })
  let pos = @syntax.expr_pos(expr)
  let filename = pos.filename()
  let result_name = "eval_expr_result"
  let stmt = @syntax.Stmt::SAssign(
    @syntax.Expr::EIdent(result_name, pos),
    expr,
    pos,
  )
  let file = @syntax.File::new(filename, [stmt])
  // Validate with the same resolver pass the file entries use, treating `env`
  // bindings as predeclared, so an undefined name reports the walker's runtime
  // "<pos>: undefined: name" instead of a position-less compile error.
  match file_program(file, opts, fn(name) { env.get(name) is Some(_) }) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let prog = @compile.compile(
    file,
    fn(name) { is_builtin(name) || env.get(name) is Some(_) },
    fn(name) { name == "None" || name == "True" || name == "False" },
    opts.allow_recursion,
  ) catch {
    @compile.CompileErr(msg) => return Err(@errors.EvalError::simple(msg))
  }
  let m = match run_program_vm(ctx, prog, filename) {
    Ok(m) => m
    Err(e) => return Err(e)
  }
  for i, binding in prog.globals {
    if binding.name() == result_name {
      match m.globals[i] {
        Some(v) => return Ok(v)
        None => return Ok(@value.Value::None)
      }
    }
  }
  Ok(@value.Value::None)
}

///|
/// A function frame's local slot. A plain local holds `LVal`/`LUnbound`; a local
/// captured by a nested function is promoted to `LBoxed` (a shared cell) at frame
/// entry, so the closure and this frame observe each other's assignments.
priv enum LocalSlot {
  LUnbound
  LVal(@value.Value)
  LBoxed(@value.Cell)
}

///|
/// VM execution state shared across all call frames of one execution: the
/// evaluation context (thread + options) and the active-funcode stack used for
/// the recursion check. Module-specific state (program + global slots) is not
/// here — each frame runs against the module of the function it executes (see
/// `RunModule`), so a function loaded from another module resolves its
/// constants, globals, and nested functions against its own module.
priv struct VM {
  ctx : EvalContext
  active : Array[@compile.Funcode]
}

///|
/// The compiled module a frame runs against: its program (constant pool,
/// function table, name table, load statements) and its live global slots. The
/// toplevel frame uses the run's module; a called function uses the module it
/// was defined in (carried on the function value). Mirrors starlark-go's
/// `fn.module`.
priv struct RunModule {
  prog : @compile.CompiledProgram
  globals : Array[@value.Value?]
  // Module-global names bound by `load`. Excluded from the module's exported
  // globals unless `load_binds_globally` (matching the walker).
  load_bound : Array[String]
}

///|
/// Executes one funcode frame and returns its `Return` value. `name` is the
/// frame's display name and `frame_idx` its slot in the thread call stack, which
/// is restamped with the current source position on every instruction so error
/// backtraces locate each frame precisely (matching the walker's live position
/// tracking).
fn VM::run_frame(
  self : VM,
  m : RunModule,
  fc : @compile.Funcode,
  name : String,
  locals : Array[LocalSlot],
  freevars : Array[@value.Cell],
  frame_idx : Int,
) -> @value.Value raise EvalErr {
  let ctx = self.ctx
  let code = fc.code
  let stack : Array[@value.Value] = []
  // See note in exec_file_vm: iterator release on the error-unwind path is
  // deferred until the engine flip; it is not observable here.
  let iterstack : Array[@value.StarlarkIterator] = []
  fn push(v : @value.Value) -> Unit {
    stack.push(v)
  }

  fn pop() -> @value.Value {
    match stack.pop() {
      Some(v) => v
      None => abort("vm: operand stack underflow")
    }
  }

  // Pops the fixed call arguments for a `Call`-family opcode: `nargs` packs the
  // positional count in the high bits and the keyword count in the low 8 bits.
  // Returns the callee and the positional and keyword arguments in source order.
  // Splat arguments (the `*args` iterable / `**kwargs` mapping) sit above these
  // on the stack and are popped by the caller before this runs.
  fn pop_call_fixed(
    nargs : Int,
  ) -> (@value.Value, Array[@value.Value], Array[(String, @value.Value)]) {
    let npos = nargs >> 8
    let nkw = nargs & 0xff
    let kwargs : Array[(String, @value.Value)] = Array::make(
      nkw,
      ("", @value.Value::None),
    )
    for i = nkw - 1; i >= 0; i = i - 1 {
      let v = pop()
      let nm = match pop() {
        @value.Value::String(s) => s.raw()
        other =>
          abort(
            "vm: keyword argument name must be a string, got \{other.type_name()}",
          )
      }
      kwargs[i] = (nm, v)
    }
    let args = pop_n(stack, npos)
    let callee = pop()
    (callee, args, kwargs)
  }

  let mut result = @value.Value::None
  let mut pc = 0
  while pc < code.length() {
    check_steps(ctx)
    let op = match @compile.Opcode::from_byte(code[pc]) {
      Some(o) => o
      None => abort("vm: invalid opcode byte \{code[pc].to_int()}")
    }
    let cur_pc = pc
    pc += 1
    let arg = if op.has_arg() {
      let (v, next) = vm_read_arg(code, pc)
      pc = next
      v
    } else {
      0
    }
    let pos = fc.position(cur_pc)
    // Keep this frame's backtrace position current. An outer frame stops
    // advancing at its Call instruction, so it naturally shows the call site.
    ctx.thread.call_stack[frame_idx] = @errors.CallFrame::new(name, pos)
    match op {
      NoneOp => push(@value.Value::None)
      TrueOp => push(@value.Value::Bool(true))
      FalseOp => push(@value.Value::Bool(false))
      Constant => push(const_to_value(m.prog.constants[arg]))
      Pop => pop() |> ignore
      Dup =>
        if stack.is_empty() {
          abort("vm: operand stack underflow")
        } else {
          push(stack[stack.length() - 1])
        }
      Dup2 => {
        // [.., x, y] -> [.., x, y, x, y]
        let n = stack.length()
        if n < 2 {
          abort("vm: operand stack underflow")
        }
        push(stack[n - 2])
        push(stack[n - 1])
      }
      Exch => {
        // [.., x, y] -> [.., y, x]
        let y = pop()
        let x = pop()
        push(y)
        push(x)
      }
      UPlus => push(eval_unary(ctx, OpPlus, pop(), pos))
      UMinus => push(eval_unary(ctx, OpMinus, pop(), pos))
      Tilde => push(eval_unary(ctx, OpBitNot, pop(), pos))
      Not => push(eval_unary(ctx, OpNot, pop(), pos))
      Index => {
        let idx = pop()
        let obj = pop()
        push(eval_index(ctx, obj, idx, pos))
      }
      Attr => {
        let obj = pop()
        push(eval_getattr(ctx, obj, m.prog.names[arg], pos))
      }
      Slice => {
        // stack: [obj, lo, hi, step] (omitted bounds pushed as None). The
        // bound conversion order matches the walker for identical errors.
        let step_v = pop()
        let hi_v = pop()
        let lo_v = pop()
        let obj = pop()
        let step = slice_int_arg(ctx, step_v, "slice step")
        let lo = slice_int_arg(ctx, lo_v, "start index")
        let hi = slice_int_arg(ctx, hi_v, "end index")
        push(eval_slice(ctx, obj, lo, hi, step))
      }
      MakeList =>
        push(@value.Value::List(@value.StarlarkList::new(pop_n(stack, arg))))
      MakeTuple => push(@value.Value::Tuple(pop_n(stack, arg)))
      MakeDict => push(@value.Value::Dict(@value.StarlarkDict::new()))
      MakeSet => push(@value.Value::Set(@value.StarlarkSet::new()))
      Append => {
        // [.., list, elem] -> append elem to the accumulator list, which stays.
        let elem = pop()
        match stack[stack.length() - 1] {
          @value.Value::List(l) => check(ctx, l.push(elem))
          other => abort("vm: Append expects a list, got \{other.type_name()}")
        }
      }
      SetAdd => {
        // [.., set, elem] -> add elem to the accumulator set, which stays.
        let elem = pop()
        match stack[stack.length() - 1] {
          @value.Value::Set(s) => check(ctx, s.add(elem))
          other => abort("vm: SetAdd expects a set, got \{other.type_name()}")
        }
      }
      SetDict => {
        // [.., dict, key, value] -> dict[key] = value; the dict stays.
        let value = pop()
        let key = pop()
        match stack[stack.length() - 1] {
          @value.Value::Dict(d) => check(ctx, d.set(key, value))
          other => abort("vm: SetDict expects a dict, got \{other.type_name()}")
        }
      }
      SetDictUniq => {
        // [.., dict, key, value] -> dict[key] = value, but error if the key
        // already appears (dict-literal semantics); the dict stays.
        let value = pop()
        let key = pop()
        match stack[stack.length() - 1] {
          @value.Value::Dict(d) =>
            match check(ctx, d.get(key)) {
              Some(_) =>
                raise EvalErr(
                  make_eval_error(ctx, "duplicate key: \{key.repr()}"),
                )
              None => check(ctx, d.set(key, value))
            }
          other =>
            abort("vm: SetDictUniq expects a dict, got \{other.type_name()}")
        }
      }
      Local =>
        match locals[arg] {
          LVal(v) => push(v)
          LUnbound =>
            raise EvalErr(
              make_eval_error(
                ctx,
                "local variable \{fc.locals[arg].name()} referenced before assignment",
              ),
            )
          LBoxed(_) => abort("vm: Local on a cell slot")
        }
      SetLocal => locals[arg] = LVal(pop())
      LocalCell =>
        match locals[arg] {
          LBoxed(c) =>
            match c.get() {
              Some(v) => push(v)
              None =>
                raise EvalErr(
                  make_eval_error(
                    ctx,
                    "local variable \{fc.locals[arg].name()} referenced before assignment",
                  ),
                )
            }
          _ => abort("vm: LocalCell on a non-cell slot")
        }
      SetLocalCell =>
        match locals[arg] {
          LBoxed(c) => c.set(pop())
          _ => abort("vm: SetLocalCell on a non-cell slot")
        }
      FreeCell =>
        match freevars[arg].get() {
          Some(v) => push(v)
          None =>
            raise EvalErr(
              make_eval_error(
                ctx,
                "local variable \{fc.freevars[arg].name()} referenced before assignment",
              ),
            )
        }
      SetGlobal => m.globals[arg] = Some(pop())
      SetIndex => {
        // stack: [obj, idx, value]
        let value = pop()
        let idx = pop()
        let obj = pop()
        set_index(ctx, obj, idx, value, pos)
      }
      SetField => {
        // stack: [obj, value]
        let value = pop()
        let obj = pop()
        let attr = m.prog.names[arg]
        match obj {
          @value.Value::Module(_) =>
            raise EvalErr(
              make_eval_error(ctx, "can't assign to .\{attr} field of module"),
            )
          @value.Value::ExtVal(c) =>
            match c.get_set_field(attr, value) {
              Some(Ok(_)) => ()
              Some(Err(msg)) => raise EvalErr(make_eval_error(ctx, msg))
              None =>
                raise EvalErr(
                  make_eval_error(
                    ctx,
                    "can't assign to .\{attr} field of \{obj.type_name()}",
                  ),
                )
            }
          _ =>
            raise EvalErr(
              make_eval_error(
                ctx,
                "can't assign to .\{attr} field of \{obj.type_name()}",
              ),
            )
        }
      }
      Unpack => {
        let items = unpack_items(ctx, pop(), arg)
        // push elements so element 0 ends up on top of the stack
        for i = items.length() - 1; i >= 0; i = i - 1 {
          push(items[i])
        }
      }
      AugApply => {
        let rv = pop()
        let lv = pop()
        push(eval_aug_val(ctx, lv, augop_of_int(arg), rv, pos))
      }
      Global =>
        match m.globals[arg] {
          Some(v) => push(v)
          None => {
            // A name bound by `load` is module-local unless `load_binds_globally`,
            // so referencing it before its load reports "local variable", matching
            // the walker.
            let gname = m.prog.globals[arg].name()
            let kind = if !ctx.opts.load_binds_globally &&
              load_binds_name(m.prog, gname) {
              "local"
            } else {
              "global"
            }
            raise EvalErr(
              make_eval_error(
                ctx,
                "\{kind} variable \{gname} referenced before assignment",
              ),
            )
          }
        }
      // Resolve predeclared/universal names against the context's base
      // environment, which holds the builtins, the universal `None`/`True`/
      // `False`, and embedder-supplied bindings (a custom universe, per-call
      // predeclared values, or `eval_expr`'s `env`). A name with no binding
      // there is undefined and raises the same error the walker reports,
      // rather than resolving to a fabricated builtin.
      Predeclared | Universal => {
        let name = m.prog.names[arg]
        match ctx.global_env.lookup(name) {
          LFound(v) => push(v)
          _ =>
            raise EvalErr(
              make_eval_error(ctx, "\{pos.to_string()}: undefined: \{name}"),
            )
        }
      }
      Load => self.exec_load(m, m.prog.load_stmts[arg])
      MakeFunc => {
        let funcode = m.prog.functions[arg]
        let provided : Array[@value.Value] = match pop() {
          @value.Value::Tuple(items) => items
          other =>
            abort(
              "vm: MakeFunc expected a defaults tuple, got \{other.type_name()}",
            )
        }
        // Align the supplied defaults onto the optional parameters (in order);
        // every other parameter slot has no default.
        let defaults : Array[@value.Value?] = Array::make(
          funcode.params.length(),
          None,
        )
        let mut di = 0
        for i, spec in funcode.params {
          if spec is POptional(_) {
            defaults[i] = Some(provided[di])
            di += 1
          }
        }
        // Gather the closure's captured cells from this (the defining) frame.
        let fvs : Array[@value.Cell] = Array::make(
          funcode.freevar_sources.length(),
          @value.Cell::new(),
        )
        for k, src in funcode.freevar_sources {
          fvs[k] = match src {
            FromLocal(li) =>
              match locals[li] {
                LBoxed(c) => c
                _ => abort("vm: MakeFunc free variable expects a cell slot")
              }
            FromFree(fi) => freevars[fi]
          }
        }
        push(
          @value.Value::Function(
            @value.StarlarkFunction::from_compiled(
              funcode.name,
              funcode,
              m.prog,
              m.globals,
              defaults,
              fvs,
            ),
          ),
        )
      }
      Call => {
        let (callee, args, kwargs) = pop_call_fixed(arg)
        push(self.call_value(callee, args, kwargs, pos))
      }
      CallVar => {
        // [.., callee, pos.., kw pairs.., *args]
        let star = pop()
        let (callee, args, kwargs) = pop_call_fixed(arg)
        expand_star_args(ctx, star, args)
        push(self.call_value(callee, args, kwargs, pos))
      }
      CallKw => {
        // [.., callee, pos.., kw pairs.., **kwargs]
        let kwstar = pop()
        let (callee, args, kwargs) = pop_call_fixed(arg)
        expand_kwargs(ctx, kwstar, kwargs)
        push(self.call_value(callee, args, kwargs, pos))
      }
      CallVarKw => {
        // [.., callee, pos.., kw pairs.., *args, **kwargs]
        let kwstar = pop()
        let star = pop()
        let (callee, args, kwargs) = pop_call_fixed(arg)
        // Expand `*args` before `**kwargs` so the iteration order (and thus the
        // order any error surfaces) matches the walker's left-to-right argument
        // expansion.
        expand_star_args(ctx, star, args)
        expand_kwargs(ctx, kwstar, kwargs)
        push(self.call_value(callee, args, kwargs, pos))
      }
      Jmp => pc = arg
      CJmp => if pop().truth() { pc = arg }
      IterPush =>
        match @value.iterate(pop()) {
          Ok(it) => iterstack.push(it)
          Err(msg) => raise EvalErr(make_eval_error(ctx, msg))
        }
      IterJmp =>
        match iterstack.last() {
          Some(it) =>
            match it.next() {
              Some(elem) => push(elem) // fall through with the next element
              None => pc = arg // exhausted: jump past the loop body
            }
          None => abort("vm: iterator stack underflow")
        }
      IterPop =>
        match iterstack.pop() {
          Some(it) => it.done()
          None => abort("vm: iterator stack underflow")
        }
      Return => {
        result = pop()
        break
      }
      _ =>
        match binop_of_opcode(op) {
          Some(binop) => {
            let rv = pop()
            let lv = pop()
            push(eval_binary(ctx, lv, binop, rv, pos))
          }
          None =>
            abort(
              "vm: opcode byte \{op.to_byte().to_int()} not yet implemented",
            )
        }
    }
  }
  result
}

///|
/// Invokes `callee` with positional `args`, returning its result. User-defined
/// functions run on a fresh frame; the call position `pos` is recorded on the
/// callee's frame for backtraces. Only positional calls to compiled functions
/// are supported so far (builtin dispatch and keyword/splat arguments follow).
fn VM::call_value(
  self : VM,
  callee : @value.Value,
  args : Array[@value.Value],
  kwargs : Array[(String, @value.Value)],
  pos : @errors.Position,
) -> @value.Value raise EvalErr {
  match callee {
    @value.Value::Function(f) =>
      match f.compiled_funcode() {
        Some(fc) => self.call_compiled(f, fc, args, kwargs, pos)
        // An AST-backed function (e.g. one loaded from a module compiled by the
        // walker) has no bytecode, so the walker runs it. After the engine flip
        // every function is compiled and this path goes away.
        None => call_value(self.ctx, callee, args, kwargs, pos)
      }
    // Builtins, bound methods, and custom values are value-level operations with
    // no AST involvement, so the walker's `call_value` handles them directly,
    // reusing every builtin implementation. The non-callable error path is
    // produced there as well. A builtin that calls back into a compiled function
    // — e.g. `sorted(iterable, key)` with the key passed positionally — re-enters
    // the VM through `ctx.vm`, so the callback runs on a VM frame with the same
    // recursion and backtrace semantics as a direct VM call.
    _ => call_value(self.ctx, callee, args, kwargs, pos)
  }
}

///|
/// Runs a compiled function `f` (with code `fc`) on a fresh VM frame, binding
/// `args` positionally. `pos` is recorded on the callee's call frame for
/// backtraces. Shared by the `Call` opcode and by builtin callbacks that re-enter
/// the VM, so recursion detection, depth limits, and argument-count errors are
/// produced identically on both paths.
fn VM::call_compiled(
  self : VM,
  f : @value.StarlarkFunction,
  fc : @compile.Funcode,
  args : Array[@value.Value],
  kwargs : Array[(String, @value.Value)],
  pos : @errors.Position,
) -> @value.Value raise EvalErr {
  // The callee runs against its own module (program + global slots), carried on
  // the function value, so a function loaded from another module resolves its
  // constants, globals, and nested functions against that module — not the
  // caller's.
  let callee_prog = match f.compiled_module_prog() {
    Some(p) => p
    None => abort("vm: compiled function is missing its module program")
  }
  let m = RunModule::{
    prog: callee_prog,
    globals: f.compiled_module_slots(),
    load_bound: [],
  }
  if !m.prog.recursion {
    let fpos = fc.pos
    for g in self.active {
      let gpos = g.pos
      if fpos.line() == gpos.line() &&
        fpos.col() == gpos.col() &&
        fpos.filename() == gpos.filename() {
        raise EvalErr(
          make_eval_error(self.ctx, "function \{f.name()} called recursively"),
        )
      }
    }
  }
  if self.ctx.thread.call_stack.length() >= self.ctx.thread.max_recursion_depth {
    raise EvalErr(make_eval_error(self.ctx, "maximum recursion depth exceeded"))
  }
  let locals : Array[LocalSlot] = Array::make(fc.locals.length(), LUnbound)
  self.bind_args(fc, f.name(), f.defaults(), args, kwargs, locals)
  // Promote captured locals to shared cells, carrying any bound value in.
  for ci in fc.cells {
    let cell = @value.Cell::new()
    match locals[ci] {
      LVal(v) => cell.set(v)
      _ => ()
    }
    locals[ci] = LBoxed(cell)
  }
  self.ctx.thread.call_stack.push(@errors.CallFrame::new(f.name(), pos))
  self.active.push(fc)
  // Record the frame for debugger inspection (`Thread::debug_frame`), referencing
  // the live local slots so locals read at their current values.
  self.ctx.thread.debug_stack.push(
    ActiveCallFrame::VmFrame(@value.Value::Function(f), fc, locals),
  )
  let fidx = self.ctx.thread.call_stack.length() - 1
  let r = self.run_frame(m, fc, f.name(), locals, f.compiled_freevars(), fidx) catch {
    EvalErr(e) => {
      self.ctx.thread.debug_stack.pop() |> ignore
      self.active.pop() |> ignore
      self.ctx.thread.call_stack.pop() |> ignore
      raise EvalErr(e)
    }
  }
  self.ctx.thread.debug_stack.pop() |> ignore
  self.active.pop() |> ignore
  self.ctx.thread.call_stack.pop() |> ignore
  r
}

///|
/// Executes a `load` statement: invokes the thread's loader for the module path
/// and binds each requested export into its module-global slot, recording the
/// bound names so module-local load bindings can be filtered from the exported
/// globals. Mirrors the AST walker's `exec_load`, including error messages.
fn VM::exec_load(
  self : VM,
  m : RunModule,
  ls : @compile.LoadStmt,
) -> Unit raise EvalErr {
  let ctx = self.ctx
  let loader = match ctx.thread.load_fn {
    Some(l) => l
    None =>
      raise EvalErr(
        make_eval_error(ctx, "load not implemented by this application"),
      )
  }
  let loaded = match loader(ctx.thread, ls.path) {
    Ok(m) => m
    Err(inner) => {
      let frames : Array[@errors.CallFrame] = []
      for frame in ctx.thread.call_stack {
        frames.push(frame)
      }
      raise EvalErr(
        @errors.EvalError::with_cause(
          "cannot load \{ls.path}: \{inner.msg()}",
          @errors.CallStack::new(frames),
          inner,
        ),
      )
    }
  }
  for i in 0..<ls.exports.length() {
    let export_name = ls.exports[i]
    match loaded.get(export_name) {
      Some(v) => {
        m.globals[ls.slots[i]] = Some(v)
        m.load_bound.push(ls.locals[i])
      }
      None => {
        let suggestion = @utf8util.spell_nearest(
          export_name,
          loaded.global_names(),
        )
        let hint = if suggestion == "" {
          ""
        } else {
          " (did you mean \{suggestion}?)"
        }
        raise EvalErr(
          make_eval_error(
            ctx,
            "load: name \{export_name} not found in module \{ls.path}\{hint}",
          ),
        )
      }
    }
  }
}

///|
/// Binds positional and keyword arguments to a compiled function's parameter
/// slots, applying defaults and collecting `*args`/`**kwargs`. This is a direct
/// port of the AST walker's `bind_args` over the funcode's parameter specs, so
/// the argument-error messages are identical. Named parameters occupy
/// `locals[0..]` in declaration order (a bare `*` separator takes no slot);
/// `defaults` is aligned to the parameter-spec index.
fn VM::bind_args(
  self : VM,
  fc : @compile.Funcode,
  fname : String,
  defaults : Array[@value.Value?],
  pos_args : Array[@value.Value],
  kw_args : Array[(String, @value.Value)],
  locals : Array[LocalSlot],
) -> Unit raise EvalErr {
  let params = fc.params
  if params.length() == 0 {
    let nactual = pos_args.length() + kw_args.length()
    if nactual > 0 {
      raise EvalErr(
        make_eval_error(
          self.ctx,
          "function \{fname} accepts no arguments (\{nactual} given)",
        ),
      )
    }
    return
  }
  let kw_map : Map[String, @value.Value] = {}
  for kw in kw_args {
    let (kn, kv) = kw
    if kw_map.contains(kn) {
      raise EvalErr(
        make_eval_error(
          self.ctx,
          "function \{fname} got multiple values for parameter \"\{kn}\"",
        ),
      )
    }
    kw_map[kn] = kv
  }
  let mut pos_idx = 0
  let mut slot = 0
  let mut param_idx = 0
  let mut passed_star = false
  let mut had_kwargs_param = false
  let missing_required : Array[String] = []
  fn dup_error(name : String) -> EvalErr {
    EvalErr(
      make_eval_error(
        self.ctx,
        "function \{fname} got multiple values for parameter \"\{name}\"",
      ),
    )
  }

  while param_idx < params.length() {
    match params[param_idx] {
      PRequired(name) => {
        if pos_idx < pos_args.length() && !passed_star {
          if kw_map.contains(name) {
            raise dup_error(name)
          }
          locals[slot] = LVal(pos_args[pos_idx])
          pos_idx += 1
        } else if kw_map.contains(name) {
          locals[slot] = LVal(kw_map[name])
          kw_map.remove(name)
        } else if defaults[param_idx] is Some(dv) {
          locals[slot] = LVal(dv)
        } else {
          missing_required.push(name)
        }
        slot += 1
        param_idx += 1
      }
      POptional(name) => {
        if pos_idx < pos_args.length() && !passed_star {
          if kw_map.contains(name) {
            raise dup_error(name)
          }
          locals[slot] = LVal(pos_args[pos_idx])
          pos_idx += 1
        } else if kw_map.contains(name) {
          locals[slot] = LVal(kw_map[name])
          kw_map.remove(name)
        } else {
          match defaults[param_idx] {
            Some(dv) => locals[slot] = LVal(dv)
            None => missing_required.push(name)
          }
        }
        slot += 1
        param_idx += 1
      }
      PStarArgs(_) => {
        passed_star = true
        let rest : Array[@value.Value] = []
        while pos_idx < pos_args.length() {
          rest.push(pos_args[pos_idx])
          pos_idx += 1
        }
        locals[slot] = LVal(@value.Value::Tuple(rest))
        slot += 1
        param_idx += 1
      }
      PStarBare => {
        passed_star = true
        if pos_idx < pos_args.length() {
          let max_pos = count_max_positional_spec(params)
          let has_opt = has_optional_pos_spec(params)
          raise EvalErr(
            make_eval_error(
              self.ctx,
              "function \{fname} accepts \{pos_arg_count_msg(max_pos, pos_args.length(), has_opt)}",
            ),
          )
        }
        param_idx += 1
      }
      PKwArgs(_) => {
        had_kwargs_param = true
        let kw_dict = @value.StarlarkDict::new()
        kw_map.each(fn(kn, kv) {
          let key = @value.Value::String(@value.StarlarkString::new(kn))
          ignore(kw_dict.set(key, kv))
        })
        kw_map.clear()
        locals[slot] = LVal(@value.Value::Dict(kw_dict))
        slot += 1
        param_idx += 1
      }
    }
  }
  if pos_idx < pos_args.length() && !passed_star {
    let max_pos = count_max_positional_spec(params)
    let has_opt = has_optional_pos_spec(params)
    raise EvalErr(
      make_eval_error(
        self.ctx,
        "function \{fname} accepts \{pos_arg_count_msg(max_pos, pos_args.length(), has_opt)}",
      ),
    )
  }
  if !had_kwargs_param && kw_map.length() > 0 {
    let mut first_key = ""
    kw_map.each(fn(k, _) { if first_key == "" { first_key = k } })
    let valid_names : Array[String] = []
    for p in params {
      match p {
        PRequired(name) | POptional(name) => valid_names.push(name)
        _ => ()
      }
    }
    let hint = match @utf8util.spell_nearest(first_key, valid_names) {
      "" => ""
      s => " (did you mean \{s}?)"
    }
    raise EvalErr(
      make_eval_error(
        self.ctx,
        "function \{fname} got an unexpected keyword argument \"\{first_key}\"\{hint}",
      ),
    )
  }
  if !missing_required.is_empty() {
    let n = missing_required.length()
    let names = missing_required.join(", ")
    let arg_word = if n == 1 { "argument" } else { "arguments" }
    raise EvalErr(
      make_eval_error(
        self.ctx,
        "function \{fname} missing \{n} \{arg_word} (\{names})",
      ),
    )
  }
}

///|
/// Number of leading positional parameters (before any `*`/`*args`), used in
/// the argument-count error message. Mirrors the walker's `count_max_positional`
/// over parameter specs.
fn count_max_positional_spec(params : Array[@compile.ParamSpec]) -> Int {
  let mut n = 0
  for p in params {
    match p {
      PRequired(_) | POptional(_) => n += 1
      PStarBare | PStarArgs(_) => break
      _ => ()
    }
  }
  n
}

///|
/// Whether any leading positional parameter (before a `*`/`*args`) is optional.
fn has_optional_pos_spec(params : Array[@compile.ParamSpec]) -> Bool {
  for p in params {
    match p {
      POptional(_) => return true
      PStarBare | PStarArgs(_) => break
      _ => ()
    }
  }
  false
}
