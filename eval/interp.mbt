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
  let globals_map : Map[String, @value.Value] = {}
  try {
    run_program_into(ctx, prog, globals_map)
    Ok(Module::from_map(globals_map))
  } catch {
    EvalErr(e) => Err(e)
  }
}

///|
/// Runs the program and writes the resulting module globals into `out`
/// (name -> value, assigned globals only), mirroring the walker's module dict.
fn run_program_into(
  ctx : EvalContext,
  prog : @compile.CompiledProgram,
  out : Map[String, @value.Value],
) -> Unit raise EvalErr {
  let fc = prog.toplevel
  let code = fc.code
  let globals : Array[@value.Value?] = Array::make(prog.globals.length(), None)
  let stack : Array[@value.Value] = []
  // Active iterators (the `for`-loop iterator stack). `IterPop` releases each
  // one (decrementing the container's iteration count). Releasing iterators
  // when an error unwinds through an active loop is deferred until the engine
  // flip; it is not observable here because such errors propagate out of the
  // VM entry point and abandon the module.
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
    match op {
      NoneOp => push(@value.Value::None)
      TrueOp => push(@value.Value::Bool(true))
      FalseOp => push(@value.Value::Bool(false))
      Constant => push(const_to_value(prog.constants[arg]))
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
      SetGlobal => globals[arg] = Some(pop())
      Global =>
        match globals[arg] {
          Some(v) => push(v)
          None =>
            raise EvalErr(
              make_eval_error(
                ctx,
                "global variable \{prog.globals[arg].name()} referenced before assignment",
              ),
            )
        }
      Predeclared => push(vm_resolve_external(prog.names[arg]))
      Universal => push(vm_resolve_external(prog.names[arg]))
      Jmp => pc = arg
      CJmp => if pop().truth() { pc = arg }
      IterPush =>
        match @value.iterate(pop()) {
          Ok(it) => iterstack.push(it)
          Err(msg) => raise EvalErr(make_eval_error(ctx, msg))
        }
      IterJmp =>
        match iterstack[iterstack.length() - 1].next() {
          Some(elem) => push(elem) // fall through with the next element
          None => pc = arg // exhausted: jump past the loop body
        }
      IterPop =>
        match iterstack.pop() {
          Some(it) => it.done()
          None => abort("vm: iterator stack underflow")
        }
      Return => break
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
  for i, binding in prog.globals {
    match globals[i] {
      Some(v) => out[binding.name()] = v
      None => ()
    }
  }
}
