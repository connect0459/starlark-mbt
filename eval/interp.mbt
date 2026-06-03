// Bytecode virtual machine. This is the second engine in the dual-engine
// migration (see issue #1): it executes `@compile.CompiledProgram` bytecode and
// is verified against the AST walker via differential tests. It is NOT yet on
// any default execution path; `exec_file_vm` is an internal entry point used by
// the differential harness while the VM is brought up feature by feature.
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
/// Resolves a predeclared/universal name to its runtime value, mirroring the
/// walker's base environment (`EvalContext::new`): `None`/`True`/`False` map to
/// their literal values; every other name becomes a dispatched builtin.
fn vm_resolve_external(name : String) -> @value.Value {
  match name {
    "None" => @value.Value::None
    "True" => @value.Value::Bool(true)
    "False" => @value.Value::Bool(false)
    _ => @value.Value::Builtin(@value.StarlarkBuiltinFunc::dispatch(name))
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
/// resulting globals. Internal entry point for the differential harness during
/// the dual-engine migration (issue #1); the public `exec_file` still uses the
/// AST walker. Resolution is performed exactly as in `file_program` so resolver
/// errors match the walker. Removed when the engine flip lands.
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
  // Validate with the same resolver pass the walker uses; resolver errors
  // (messages and positions) match the walker exactly.
  match file_program(file, opts, fn(_) { false }) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let prog = @compile.compile(
    file,
    fn(name) { is_builtin(name) },
    fn(name) { name == "None" || name == "True" || name == "False" },
    opts.allow_recursion,
  ) catch {
    @compile.CompileErr(msg) => return Err(@errors.EvalError::simple(msg))
  }
  let ctx = EvalContext::new(thread, opts)
  let vm = VM::{ ctx, prog, globals: Array::make(prog.globals.length(), None) }
  try {
    // Push the module-init frame so backtraces begin at <toplevel>, matching
    // the walker.
    ctx.thread.call_stack.push(
      @errors.CallFrame::new(
        "<toplevel>",
        @errors.Position::new(filename, 1, 1),
      ),
    )
    let idx = ctx.thread.call_stack.length() - 1
    let no_locals : Array[@value.Value?] = []
    vm.run_frame(prog.toplevel, "<toplevel>", no_locals, idx) |> ignore
    ctx.thread.call_stack.pop() |> ignore
    let out : Map[String, @value.Value] = {}
    for i, binding in prog.globals {
      match vm.globals[i] {
        Some(v) => out[binding.name()] = v
        None => ()
      }
    }
    Ok(Module::from_map(out))
  } catch {
    EvalErr(e) => {
      ctx.thread.call_stack.pop() |> ignore
      Err(e)
    }
  }
}

///|
/// VM execution state shared across all call frames of one program run: the
/// evaluation context (thread + options) and the module's global slots. Each
/// `run_frame` invocation owns its own operand stack, locals, and iterator
/// stack.
priv struct VM {
  ctx : EvalContext
  prog : @compile.CompiledProgram
  globals : Array[@value.Value?]
}

///|
/// Executes one funcode frame and returns its `Return` value. `name` is the
/// frame's display name and `frame_idx` its slot in the thread call stack, which
/// is restamped with the current source position on every instruction so error
/// backtraces locate each frame precisely (matching the walker's live position
/// tracking).
fn VM::run_frame(
  self : VM,
  fc : @compile.Funcode,
  name : String,
  locals : Array[@value.Value?],
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
      Constant => push(const_to_value(self.prog.constants[arg]))
      Pop => pop() |> ignore
      Dup =>
        if stack.is_empty() {
          abort("vm: operand stack underflow")
        } else {
          push(stack[stack.length() - 1])
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
      MakeList =>
        push(@value.Value::List(@value.StarlarkList::new(pop_n(stack, arg))))
      MakeTuple => push(@value.Value::Tuple(pop_n(stack, arg)))
      Local =>
        match locals[arg] {
          Some(v) => push(v)
          None =>
            raise EvalErr(
              make_eval_error(
                ctx,
                "local variable \{fc.locals[arg].name()} referenced before assignment",
              ),
            )
        }
      SetLocal => locals[arg] = Some(pop())
      SetGlobal => self.globals[arg] = Some(pop())
      Global =>
        match self.globals[arg] {
          Some(v) => push(v)
          None =>
            raise EvalErr(
              make_eval_error(
                ctx,
                "global variable \{self.prog.globals[arg].name()} referenced before assignment",
              ),
            )
        }
      Predeclared => push(vm_resolve_external(self.prog.names[arg]))
      Universal => push(vm_resolve_external(self.prog.names[arg]))
      MakeFunc => {
        let funcode = self.prog.functions[arg]
        let defaults : Array[@value.Value?] = match pop() {
          @value.Value::Tuple(items) => items.map(fn(v) { Some(v) })
          other =>
            abort(
              "vm: MakeFunc expected a defaults tuple, got \{other.type_name()}",
            )
        }
        push(
          @value.Value::Function(
            @value.StarlarkFunction::from_compiled(
              funcode.name,
              funcode,
              defaults,
            ),
          ),
        )
      }
      Call => {
        let npos = arg >> 8
        let args = pop_n(stack, npos)
        let callee = pop()
        push(self.call_value(callee, args, pos))
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
  pos : @errors.Position,
) -> @value.Value raise EvalErr {
  match callee {
    @value.Value::Function(f) =>
      match f.compiled_funcode() {
        Some(fc) => {
          if self.ctx.thread.call_stack.length() >=
            self.ctx.thread.max_recursion_depth {
            raise EvalErr(
              make_eval_error(self.ctx, "maximum recursion depth exceeded"),
            )
          }
          if args.length() != fc.num_params {
            raise EvalErr(
              make_eval_error(
                self.ctx,
                "function \{f.name()} accepts \{fc.num_params} positional arguments (\{args.length()} given)",
              ),
            )
          }
          let locals : Array[@value.Value?] = Array::make(
            fc.locals.length(),
            None,
          )
          for i in 0..<args.length() {
            locals[i] = Some(args[i])
          }
          self.ctx.thread.call_stack.push(@errors.CallFrame::new(f.name(), pos))
          let fidx = self.ctx.thread.call_stack.length() - 1
          let r = self.run_frame(fc, f.name(), locals, fidx) catch {
            EvalErr(e) => {
              self.ctx.thread.call_stack.pop() |> ignore
              raise EvalErr(e)
            }
          }
          self.ctx.thread.call_stack.pop() |> ignore
          r
        }
        None => abort("vm: function value has no compiled code")
      }
    @value.Value::Builtin(_) =>
      raise EvalErr(
        make_eval_error(self.ctx, "vm: builtin calls not yet supported"),
      )
    _ =>
      raise EvalErr(
        make_eval_error(
          self.ctx,
          "invalid call of non-function (\{callee.type_name()})",
        ),
      )
  }
}
