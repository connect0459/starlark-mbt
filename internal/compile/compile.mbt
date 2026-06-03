// Bytecode compiler: lowers a resolved `@syntax.File` to a `CompiledProgram`.
//
// The compiler assumes the file has already passed name resolution (so it never
// re-validates), and computes its own slot/global layout. This file implements
// the straight-line expression subset and module-level initialization; control
// flow, calls, functions, closures, comprehensions, and load statements are
// added in later milestones. Nodes not yet handled raise `CompileErr`.

///|
/// Raised for source constructs the compiler does not yet lower. During the
/// dual-engine migration this lets callers fall back to the AST walker.
pub suberror CompileErr {
  CompileErr(String)
}

// --- program-level compiler state ---

///|
priv struct Pcomp {
  constants : Array[Const]
  names : Array[String]
  name_index : Map[String, Int]
  functions : Array[Funcode]
  globals : Array[@errors.Binding]
  global_index : Map[String, Int]
  loads : Array[@errors.Binding]
  load_stmts : Array[LoadStmt]
  is_predeclared : (String) -> Bool
  is_universal : (String) -> Bool
}

///|
fn Pcomp::add_const(self : Pcomp, c : Const) -> Int {
  for i, existing in self.constants {
    if existing == c {
      return i
    }
  }
  let idx = self.constants.length()
  self.constants.push(c)
  idx
}

///|
fn Pcomp::add_name(self : Pcomp, name : String) -> Int {
  match self.name_index.get(name) {
    Some(i) => i
    None => {
      let idx = self.names.length()
      self.names.push(name)
      self.name_index[name] = idx
      idx
    }
  }
}

// --- function-level compiler state ---

// A pseudo-instruction emitted by the compiler. `arg` is the operand for normal
// instructions; for jumps (`is_jump`) it is a label id that the assembler
// resolves to a byte offset. Because operands are uvarint-encoded (variable
// width), jump targets are resolved in a second pass: `Fcomp::assemble`
// iterates the operand sizes to a fixpoint, then serializes to bytes. Jump-free
// code serializes identically to direct emission.

///|
priv struct PInstr {
  op : Opcode
  arg : Int
  is_jump : Bool
  pos : @errors.Position?
}

///|
priv struct Fcomp {
  pcomp : Pcomp
  name : String
  pos : @errors.Position
  doc : String
  instrs : Array[PInstr]
  // label id -> index into `instrs` where the label is placed (-1 until placed).
  // A label placed at `instrs.length()` denotes the position just past the end.
  label_at : Array[Int]
  locals : Array[@errors.Binding]
  local_index : Map[String, Int]
  // Stack of (continue_label, break_label) for the enclosing loops, so `break`
  // and `continue` jump to the right targets.
  loop_stack : Array[(Int, Int)]
  mut pending_pos : @errors.Position?
  mut cur_stack : Int
  mut max_stack : Int
  mut num_params : Int
  mut num_kwonly_params : Int
  mut has_varargs : Bool
  mut has_kwargs : Bool
  // Parameter specs in declaration order (empty for the module-init function).
  params : Array[ParamSpec]
  // Enclosing function compiler, for resolving free variables (None at module
  // scope).
  parent : Fcomp?
  // Local slot indices captured by a nested function (promoted to cells). Used
  // as a set; the value is always true.
  cell_set : Map[Int, Bool]
  // Captured free variables: names, their capture source in the enclosing frame,
  // and a name->index lookup. Parallel arrays.
  freevar_names : Array[String]
  freevar_srcs : Array[FreevarSource]
  freevar_index : Map[String, Int]
}

///|
fn Fcomp::new(
  pcomp : Pcomp,
  name : String,
  pos : @errors.Position,
  parent? : Fcomp? = None,
) -> Fcomp {
  {
    pcomp,
    name,
    pos,
    doc: "",
    instrs: [],
    label_at: [],
    locals: [],
    local_index: {},
    loop_stack: [],
    pending_pos: None,
    cur_stack: 0,
    max_stack: 0,
    num_params: 0,
    num_kwonly_params: 0,
    has_varargs: false,
    has_kwargs: false,
    params: [],
    parent,
    cell_set: {},
    freevar_names: [],
    freevar_srcs: [],
    freevar_index: {},
  }
}

///|
/// Marks local slot `idx` as a cell (captured by a nested function).
fn Fcomp::mark_cell(self : Fcomp, idx : Int) -> Unit {
  self.cell_set[idx] = true
}

///|
/// Records a captured free variable `name` with its source, returning its index.
fn Fcomp::add_freevar(self : Fcomp, name : String, src : FreevarSource) -> Int {
  match self.freevar_index.get(name) {
    Some(i) => i
    None => {
      let i = self.freevar_names.length()
      self.freevar_names.push(name)
      self.freevar_srcs.push(src)
      self.freevar_index[name] = i
      i
    }
  }
}

///|
/// Resolves `name` as a free variable captured from an enclosing function,
/// returning its free-variable index in this function (or `None` if `name` is
/// not bound in any enclosing function scope — i.e. it is a global/predeclared
/// name). Threads the capture through every intermediate function and promotes
/// the originating local to a cell.
fn Fcomp::resolve_free(self : Fcomp, name : String) -> Int? {
  match self.freevar_index.get(name) {
    Some(i) => return Some(i)
    None => ()
  }
  match self.parent {
    None => None
    Some(p) =>
      match p.local_index.get(name) {
        Some(pidx) => {
          p.mark_cell(pidx)
          Some(self.add_freevar(name, FromLocal(pidx)))
        }
        None =>
          match p.resolve_free(name) {
            Some(pfi) => Some(self.add_freevar(name, FromFree(pfi)))
            None => None
          }
      }
  }
}

///|
/// Records the source position to associate with subsequent emitted
/// instructions, until the next `set_pos`. The assembler turns these into the
/// line table (deduplicated), which `Funcode::position` searches.
fn Fcomp::set_pos(self : Fcomp, pos : @errors.Position) -> Unit {
  self.pending_pos = Some(pos)
}

///|
/// Adjusts the tracked operand-stack height and updates the peak.
fn Fcomp::stack(self : Fcomp, pop : Int, push : Int) -> Unit {
  self.cur_stack = self.cur_stack - pop + push
  if self.cur_stack < 0 {
    abort("compile: operand-stack underflow (max_stack would be invalid)")
  }
  if self.cur_stack > self.max_stack {
    self.max_stack = self.cur_stack
  }
}

///|
/// Forces the tracked stack height at a control-flow merge point (where the
/// linear instruction order does not reflect the real runtime height). The
/// compiler knows the correct height at each label it places.
fn Fcomp::set_stack(self : Fcomp, h : Int) -> Unit {
  self.cur_stack = h
  if h > self.max_stack {
    self.max_stack = h
  }
}

///|
fn Fcomp::emit0(self : Fcomp, op : Opcode, pop : Int, push : Int) -> Unit {
  self.instrs.push({ op, arg: 0, is_jump: false, pos: self.pending_pos })
  self.stack(pop, push)
}

///|
fn Fcomp::emit1(
  self : Fcomp,
  op : Opcode,
  arg : Int,
  pop : Int,
  push : Int,
) -> Unit {
  self.instrs.push({ op, arg, is_jump: false, pos: self.pending_pos })
  self.stack(pop, push)
}

///|
/// Emits a jump instruction targeting `label` (resolved to a byte offset at
/// assembly time).
fn Fcomp::emit_jump(
  self : Fcomp,
  op : Opcode,
  label : Int,
  pop : Int,
  push : Int,
) -> Unit {
  self.instrs.push({ op, arg: label, is_jump: true, pos: self.pending_pos })
  self.stack(pop, push)
}

///|
/// Allocates a fresh, unplaced jump label.
fn Fcomp::new_label(self : Fcomp) -> Int {
  let id = self.label_at.length()
  self.label_at.push(-1)
  id
}

///|
/// Places `label` at the current emission point (the next instruction emitted,
/// or the end of the stream).
fn Fcomp::place_label(self : Fcomp, label : Int) -> Unit {
  self.label_at[label] = self.instrs.length()
}

///|
fn write_uvarint(code : Array[Byte], n : Int) -> Unit {
  if n < 0 {
    abort("compile: uvarint operand must be non-negative, got \{n}")
  }
  let mut v = n
  while v >= 0x80 {
    code.push(((v & 0x7f) | 0x80).to_byte())
    v = v >> 7
  }
  code.push(v.to_byte())
}

///|
/// Returns the number of bytes a non-negative uvarint operand occupies.
fn uvarint_len(n : Int) -> Int {
  let mut v = n
  let mut count = 1
  while v >= 0x80 {
    count += 1
    v = v >> 7
  }
  count
}

///|
/// Serializes the pseudo-instruction stream into bytecode, resolving jump labels
/// to byte offsets. Jump operand widths and instruction offsets are mutually
/// dependent (uvarint is variable-width), so sizes are iterated to a fixpoint;
/// because operand sizes only grow, this converges.
fn Fcomp::finish(self : Fcomp) -> Funcode {
  // Rewrite accesses to cell locals into their cell forms. Cells are only known
  // after the whole body (including nested functions that capture them) has been
  // compiled, so this is a deferred pass over the pseudo-instructions.
  if self.cell_set.length() > 0 {
    for i in 0..<self.instrs.length() {
      let ins = self.instrs[i]
      if !ins.is_jump && self.cell_set.contains(ins.arg) {
        let new_op = match ins.op {
          Local => Some(Opcode::LocalCell)
          SetLocal => Some(Opcode::SetLocalCell)
          _ => None
        }
        match new_op {
          Some(op) => self.instrs[i] = { ..ins, op, }
          None => ()
        }
      }
    }
  }
  let n = self.instrs.length()
  let opsize : Array[Int] = Array::make(n, 0)
  for i in 0..<n {
    let ins = self.instrs[i]
    if ins.is_jump && self.label_at[ins.arg] < 0 {
      abort("compile: jump to unplaced label \{ins.arg}")
    }
    opsize[i] = if !ins.op.has_arg() {
      0
    } else if ins.is_jump {
      1
    } else {
      uvarint_len(ins.arg)
    }
  }
  let offsets : Array[Int] = Array::make(n + 1, 0)
  let mut changed = true
  while changed {
    changed = false
    let mut off = 0
    for i in 0..<n {
      offsets[i] = off
      off = off + 1 + opsize[i]
    }
    offsets[n] = off
    for i in 0..<n {
      let ins = self.instrs[i]
      if ins.is_jump {
        let target = offsets[self.label_at[ins.arg]]
        let need = uvarint_len(target)
        if need != opsize[i] {
          opsize[i] = need
          changed = true
        }
      }
    }
  }
  let code : Array[Byte] = []
  let pclinetab : Array[PcLine] = []
  let mut last_line = -1
  let mut last_col = -1
  for i in 0..<n {
    let ins = self.instrs[i]
    match ins.pos {
      Some(pp) => {
        let line = pp.line()
        let col = pp.col()
        if line != last_line || col != last_col {
          pclinetab.push(PcLine::{ pc: code.length(), line, col })
          last_line = line
          last_col = col
        }
      }
      None => ()
    }
    code.push(ins.op.to_byte())
    if ins.op.has_arg() {
      let operand = if ins.is_jump {
        offsets[self.label_at[ins.arg]]
      } else {
        ins.arg
      }
      write_uvarint(code, operand)
    }
  }
  {
    pos: self.pos,
    name: self.name,
    doc: self.doc,
    code: Bytes::from_array(code),
    pclinetab,
    locals: self.locals,
    cells: cell_indices(self.cell_set),
    freevars: self.freevar_names.map(fn(nm) {
      @errors.Binding::new(nm, self.pos)
    }),
    freevar_sources: self.freevar_srcs,
    max_stack: self.max_stack,
    num_params: self.num_params,
    num_kwonly_params: self.num_kwonly_params,
    has_varargs: self.has_varargs,
    has_kwargs: self.has_kwargs,
    params: self.params,
  }
}

///|
/// Returns the cell local-slot indices in ascending order.
fn cell_indices(set : Map[Int, Bool]) -> Array[Int] {
  let out : Array[Int] = []
  for idx, _ in set {
    out.push(idx)
  }
  out.sort()
  out
}

// --- expression compilation ---

///|
fn Fcomp::compile_expr(self : Fcomp, e : @syntax.Expr) -> Unit raise CompileErr {
  match e {
    ELiteral(lit, pos) => {
      self.set_pos(pos)
      self.compile_literal(lit)
    }
    EIdent(name, pos) => {
      self.set_pos(pos)
      self.compile_ident(name)
    }
    EUnary(op, x, pos) => {
      self.compile_expr(x)
      self.set_pos(pos)
      let opcode = match op {
        OpPlus => Opcode::UPlus
        OpMinus => Opcode::UMinus
        OpBitNot => Opcode::Tilde
        OpNot => Opcode::Not
      }
      self.emit0(opcode, 1, 1)
    }
    EBinary(l, op, r, pos) => self.compile_binary(l, op, r, pos)
    // `then if cond else orelse` — note the AST stores the then-value first.
    ECond(then_e, cond_e, else_e, _) => {
      let else_lbl = self.new_label()
      let end_lbl = self.new_label()
      let base = self.cur_stack
      self.compile_expr(cond_e)
      // jump to the else branch when the condition is false: negate then CJMP.
      self.emit0(Opcode::Not, 1, 1)
      self.emit_jump(Opcode::CJmp, else_lbl, 1, 0)
      self.compile_expr(then_e)
      self.emit_jump(Opcode::Jmp, end_lbl, 0, 0)
      self.place_label(else_lbl)
      self.set_stack(base)
      self.compile_expr(else_e)
      self.place_label(end_lbl)
      self.set_stack(base + 1)
    }
    EIndex(x, i, pos) => {
      self.compile_expr(x)
      self.compile_expr(i)
      self.set_pos(pos)
      self.emit0(Opcode::Index, 2, 1)
    }
    ESlice(x, lo, hi, step, pos) => {
      self.compile_expr(x)
      self.compile_opt_expr(lo)
      self.compile_opt_expr(hi)
      self.compile_opt_expr(step)
      self.set_pos(pos)
      self.emit0(Opcode::Slice, 4, 1)
    }
    EDot(x, name, pos) => {
      self.compile_expr(x)
      self.set_pos(pos)
      self.emit1(Opcode::Attr, self.pcomp.add_name(name), 1, 1)
    }
    EList(xs, pos) => {
      for x in xs {
        self.compile_expr(x)
      }
      self.set_pos(pos)
      self.emit1(Opcode::MakeList, xs.length(), xs.length(), 1)
    }
    ETuple(xs, pos) => {
      for x in xs {
        self.compile_expr(x)
      }
      self.set_pos(pos)
      self.emit1(Opcode::MakeTuple, xs.length(), xs.length(), 1)
    }
    ECall(callee, args, pos) => self.compile_call(callee, args, pos)
    EListComp(elt, clauses, pos) =>
      self.compile_comprehension(CList(elt), clauses, pos)
    EDictComp(k, v, clauses, pos) =>
      self.compile_comprehension(CDict(k, v), clauses, pos)
    ELambda(params, body_e, pos) => {
      // A lambda is a function whose body is a single `return <expr>`.
      let body : Array[@syntax.Stmt] = [
        @syntax.Stmt::SReturn(Some(body_e), pos),
      ]
      self.compile_make_func("lambda", params, body, pos)
    }
    _ =>
      raise CompileErr(
        "compile: unsupported expression at \{@syntax.expr_pos(e).to_string()}",
      )
  }
}

///|
/// Compiles a call with positional and keyword arguments. Each keyword argument
/// pushes its name (a string constant) then its value, so the VM can recover the
/// `(name, value)` pairs. `*args`/`**kwargs` at the call site are not yet
/// supported. The operand encodes `(npositional << 8) | nkeyword`.
fn Fcomp::compile_call(
  self : Fcomp,
  callee : @syntax.Expr,
  args : Array[@syntax.Arg],
  pos : @errors.Position,
) -> Unit raise CompileErr {
  self.compile_expr(callee)
  let mut npos = 0
  let mut nkw = 0
  for a in args {
    match a {
      ArgPos(e) => {
        self.compile_expr(e)
        npos += 1
      }
      ArgKw(kw_name, e, _) => {
        self.emit1(Opcode::Constant, self.pcomp.add_const(CStr(kw_name)), 0, 1)
        self.compile_expr(e)
        nkw += 1
      }
      ArgStarArgs(_) | ArgKwArgs(_) =>
        raise CompileErr(
          "compile: *args and **kwargs call arguments not yet supported at \{pos.to_string()}",
        )
    }
  }
  // The Call operand packs `(npos << 8) | nkw`; each field is 8 bits, so both
  // counts must stay below 256 or they would corrupt one another at decode.
  if npos >= 256 {
    raise CompileErr(
      "compile: \{npos} positional arguments in call, limit is 255 at \{pos.to_string()}",
    )
  }
  if nkw >= 256 {
    raise CompileErr(
      "compile: \{nkw} keyword arguments in call, limit is 255 at \{pos.to_string()}",
    )
  }
  self.set_pos(pos)
  // pops callee + npos positional + nkw (name, value) pairs, pushes the result.
  self.emit1(Opcode::Call, (npos << 8) | nkw, 1 + npos + 2 * nkw, 1)
}

///|
/// What a comprehension accumulates: a list element, or a dict key/value.
priv enum CompKind {
  CList(@syntax.Expr)
  CDict(@syntax.Expr, @syntax.Expr)
}

///|
/// Compiles a list or dict comprehension to an accumulator plus a nest of
/// iterator loops and `if` guards. An empty accumulator stays on the operand
/// stack throughout; each innermost iteration appends to it. Comprehension
/// variables are isolated comp-local slots (saved/restored around the
/// comprehension); the first clause's iterable is evaluated in the enclosing
/// scope, while all later iterables see every comprehension target as a
/// (possibly-unassigned) comp local — matching the walker's scoping.
fn Fcomp::compile_comprehension(
  self : Fcomp,
  kind : CompKind,
  clauses : Array[@syntax.CompClause],
  pos : @errors.Position,
) -> Unit raise CompileErr {
  let base = self.cur_stack
  self.set_pos(pos)
  match kind {
    CList(_) => self.emit1(Opcode::MakeList, 0, 0, 1)
    CDict(_, _) => self.emit0(Opcode::MakeDict, 0, 1)
  }
  // Validate and collect comprehension target names (idents only).
  let targets : Array[(String, @errors.Position)] = []
  for c in clauses {
    match c {
      ClauseFor(EIdent(name, tp), _, _) => targets.push((name, tp))
      ClauseFor(t, _, _) =>
        raise CompileErr(
          "compile: unsupported comprehension target at \{@syntax.expr_pos(t).to_string()}",
        )
      ClauseIf(_, _) => ()
    }
  }
  // The first clause is always a `for` (Starlark grammar). Its iterable is
  // evaluated in the enclosing scope, before any comprehension target is bound.
  guard clauses[0] is ClauseFor(first_target, first_iter, _) else {
    raise CompileErr("compile: comprehension must begin with a for clause")
  }
  self.compile_expr(first_iter)
  self.emit0(Opcode::IterPush, 1, 0)
  // Now bind every comprehension target as a comp-local slot. A name that
  // repeats across `for` clauses is one variable sharing a single slot, so it
  // is bound and recorded once; otherwise the restore loop below would replay
  // duplicate entries and leave the name pointing at a comp-local slot after
  // the comprehension ends.
  let saved : Array[(String, Int?)] = []
  let bound : Map[String, Unit] = {}
  for t in targets {
    let (name, tp) = t
    if bound.contains(name) {
      continue
    }
    bound[name] = ()
    saved.push((name, self.local_index.get(name)))
    let slot = self.locals.length()
    self.locals.push(@errors.Binding::new(name, tp))
    self.local_index[name] = slot
  }
  let head = self.new_label()
  let end_lbl = self.new_label()
  self.place_label(head)
  self.set_stack(base + 1)
  self.emit_jump(Opcode::IterJmp, end_lbl, 0, 1)
  self.compile_comp_store(first_target)
  self.emit_comp_rest(kind, clauses, 1, base)
  self.emit_jump(Opcode::Jmp, head, 0, 0)
  self.place_label(end_lbl)
  self.set_stack(base + 1)
  self.emit0(Opcode::IterPop, 0, 0)
  // Restore the names the comprehension targets shadowed.
  for s in saved {
    let (name, old) = s
    match old {
      Some(i) => self.local_index[name] = i
      None => self.local_index.remove(name)
    }
  }
}

///|
/// Emits the remaining comprehension clauses from index `ci`, then the body that
/// appends to the accumulator. `base + 1` is the operand height with just the
/// accumulator on the stack.
fn Fcomp::emit_comp_rest(
  self : Fcomp,
  kind : CompKind,
  clauses : Array[@syntax.CompClause],
  ci : Int,
  base : Int,
) -> Unit raise CompileErr {
  if ci >= clauses.length() {
    match kind {
      CList(elt) => {
        self.compile_expr(elt)
        self.emit0(Opcode::Append, 1, 0)
      }
      CDict(k, v) => {
        self.compile_expr(k)
        self.compile_expr(v)
        self.emit0(Opcode::SetDict, 2, 0)
      }
    }
    return
  }
  match clauses[ci] {
    ClauseFor(target, iter_e, _) => {
      self.compile_expr(iter_e)
      self.emit0(Opcode::IterPush, 1, 0)
      let head = self.new_label()
      let end_lbl = self.new_label()
      self.place_label(head)
      self.set_stack(base + 1)
      self.emit_jump(Opcode::IterJmp, end_lbl, 0, 1)
      self.compile_comp_store(target)
      self.emit_comp_rest(kind, clauses, ci + 1, base)
      self.emit_jump(Opcode::Jmp, head, 0, 0)
      self.place_label(end_lbl)
      self.set_stack(base + 1)
      self.emit0(Opcode::IterPop, 0, 0)
    }
    ClauseIf(cond, _) => {
      self.compile_expr(cond)
      let keep = self.new_label()
      let skip = self.new_label()
      self.emit_jump(Opcode::CJmp, keep, 1, 0)
      self.emit_jump(Opcode::Jmp, skip, 0, 0)
      self.place_label(keep)
      self.set_stack(base + 1)
      self.emit_comp_rest(kind, clauses, ci + 1, base)
      self.place_label(skip)
      self.set_stack(base + 1)
    }
  }
}

///|
/// Stores the current iteration element into a comprehension target (idents
/// only; validated by `compile_comprehension`).
fn Fcomp::compile_comp_store(
  self : Fcomp,
  target : @syntax.Expr,
) -> Unit raise CompileErr {
  match target {
    EIdent(name, _) => self.compile_store(name)
    _ =>
      raise CompileErr(
        "compile: unsupported comprehension target at \{@syntax.expr_pos(target).to_string()}",
      )
  }
}

///|
/// Compiles an optional slice operand, pushing `None` when absent.
fn Fcomp::compile_opt_expr(
  self : Fcomp,
  e : @syntax.Expr?,
) -> Unit raise CompileErr {
  match e {
    Some(x) => self.compile_expr(x)
    None => self.emit0(Opcode::NoneOp, 0, 1)
  }
}

///|
fn Fcomp::compile_literal(self : Fcomp, lit : @syntax.LiteralVal) -> Unit {
  match lit {
    LitNone => self.emit0(Opcode::NoneOp, 0, 1)
    LitBool(true) => self.emit0(Opcode::TrueOp, 0, 1)
    LitBool(false) => self.emit0(Opcode::FalseOp, 0, 1)
    LitInt(n) =>
      self.emit1(Opcode::Constant, self.pcomp.add_const(CInt(n)), 0, 1)
    LitFloat(f) =>
      self.emit1(Opcode::Constant, self.pcomp.add_const(CFloat(f)), 0, 1)
    LitString(s) =>
      self.emit1(Opcode::Constant, self.pcomp.add_const(CStr(s)), 0, 1)
    LitBytes(b) =>
      self.emit1(Opcode::Constant, self.pcomp.add_const(CBytes(b)), 0, 1)
  }
}

///|
/// Compiles a name reference. Locals (when inside a function) take precedence;
/// at module scope a name is a global, else predeclared, else universal. A name
/// that resolves to none of these would have been rejected by the resolver, so
/// reaching that branch indicates a compiler/resolver disagreement.
fn Fcomp::compile_ident(self : Fcomp, name : String) -> Unit raise CompileErr {
  // Resolution order: local -> free (enclosing function) -> global ->
  // predeclared -> universal. A free variable shadows a module global of the
  // same name (lexical scoping).
  match self.local_index.get(name) {
    Some(idx) => self.emit1(Opcode::Local, idx, 0, 1)
    None =>
      match self.resolve_free(name) {
        Some(fi) => self.emit1(Opcode::FreeCell, fi, 0, 1)
        None =>
          match self.pcomp.global_index.get(name) {
            Some(idx) => self.emit1(Opcode::Global, idx, 0, 1)
            None =>
              if (self.pcomp.is_predeclared)(name) {
                self.emit1(Opcode::Predeclared, self.pcomp.add_name(name), 0, 1)
              } else if (self.pcomp.is_universal)(name) {
                self.emit1(Opcode::Universal, self.pcomp.add_name(name), 0, 1)
              } else {
                raise CompileErr("compile: undefined name \{name}")
              }
          }
      }
  }
}

///|
fn Fcomp::compile_binary(
  self : Fcomp,
  l : @syntax.Expr,
  op : @syntax.BinaryOp,
  r : @syntax.Expr,
  pos : @errors.Position,
) -> Unit raise CompileErr {
  // `and` / `or` short-circuit via jumps, so the right operand is only
  // evaluated when needed.
  match op {
    OpAnd => return self.compile_and(l, r)
    OpOr => return self.compile_or(l, r)
    _ => ()
  }
  self.compile_expr(l)
  self.compile_expr(r)
  self.set_pos(pos)
  match op {
    OpAdd => self.emit0(Opcode::Plus, 2, 1)
    OpSub => self.emit0(Opcode::Minus, 2, 1)
    OpMul => self.emit0(Opcode::Star, 2, 1)
    OpDiv => self.emit0(Opcode::Slash, 2, 1)
    OpFloorDiv => self.emit0(Opcode::SlashSlash, 2, 1)
    OpMod => self.emit0(Opcode::Percent, 2, 1)
    OpBitAnd => self.emit0(Opcode::Amp, 2, 1)
    OpBitOr => self.emit0(Opcode::Pipe, 2, 1)
    OpBitXor => self.emit0(Opcode::Circumflex, 2, 1)
    OpLShift => self.emit0(Opcode::LtLt, 2, 1)
    OpRShift => self.emit0(Opcode::GtGt, 2, 1)
    OpEq => self.emit0(Opcode::Eql, 2, 1)
    OpNe => self.emit0(Opcode::Neq, 2, 1)
    OpLt => self.emit0(Opcode::Lt, 2, 1)
    OpLe => self.emit0(Opcode::Le, 2, 1)
    OpGt => self.emit0(Opcode::Gt, 2, 1)
    OpGe => self.emit0(Opcode::Ge, 2, 1)
    OpIn => self.emit0(Opcode::In, 2, 1)
    OpNotIn => {
      self.emit0(Opcode::In, 2, 1)
      self.emit0(Opcode::Not, 1, 1)
    }
    OpAnd | OpOr => abort("unreachable: and/or handled above")
  }
}

///|
/// `l or r`: evaluate `l`; if it is truthy keep it, otherwise evaluate `r`.
fn Fcomp::compile_or(
  self : Fcomp,
  l : @syntax.Expr,
  r : @syntax.Expr,
) -> Unit raise CompileErr {
  let done = self.new_label()
  let base = self.cur_stack
  self.compile_expr(l)
  self.emit0(Opcode::Dup, 0, 1)
  self.emit_jump(Opcode::CJmp, done, 1, 0) // keep l when truthy
  self.emit0(Opcode::Pop, 1, 0)
  self.compile_expr(r)
  self.place_label(done)
  self.set_stack(base + 1)
}

///|
/// `l and r`: evaluate `l`; if it is falsy keep it, otherwise evaluate `r`.
fn Fcomp::compile_and(
  self : Fcomp,
  l : @syntax.Expr,
  r : @syntax.Expr,
) -> Unit raise CompileErr {
  let cont = self.new_label()
  let done = self.new_label()
  let base = self.cur_stack
  self.compile_expr(l)
  self.emit0(Opcode::Dup, 0, 1)
  self.emit_jump(Opcode::CJmp, cont, 1, 0) // evaluate r when l truthy
  self.emit_jump(Opcode::Jmp, done, 0, 0) // otherwise keep l
  self.place_label(cont)
  self.set_stack(base + 1) // the CJMP-taken path keeps the duplicated value
  self.emit0(Opcode::Pop, 1, 0)
  self.compile_expr(r)
  self.place_label(done)
  self.set_stack(base + 1)
}

// --- statement compilation ---

///|
fn Fcomp::compile_stmt(self : Fcomp, s : @syntax.Stmt) -> Unit raise CompileErr {
  match s {
    SExpr(e) => {
      self.compile_expr(e)
      self.emit0(Opcode::Pop, 1, 0)
    }
    SAssign(lhs, rhs, pos) => {
      // The right-hand side is evaluated first, then assigned to the target.
      self.compile_expr(rhs)
      self.set_pos(pos)
      self.compile_assign_target(lhs)
    }
    SAugAssign(lhs, aug_op, rhs, pos) =>
      match lhs {
        EIdent(name, _) => {
          // load <name>; <rhs>; AugApply<op>; store <name>
          self.compile_ident(name)
          self.compile_expr(rhs)
          self.set_pos(pos)
          self.emit1(Opcode::AugApply, aug_op_code(aug_op), 2, 1)
          self.compile_store(name)
        }
        _ =>
          raise CompileErr(
            "compile: augmented assignment to index/attribute targets not yet supported at \{@syntax.expr_pos(lhs).to_string()}",
          )
      }
    SPass(_) => ()
    SIf(cond, then_body, else_body, _) => {
      let then_lbl = self.new_label()
      let end_lbl = self.new_label()
      let base = self.cur_stack
      self.compile_expr(cond)
      self.emit_jump(Opcode::CJmp, then_lbl, 1, 0)
      self.compile_stmts(else_body)
      self.emit_jump(Opcode::Jmp, end_lbl, 0, 0)
      self.place_label(then_lbl)
      self.set_stack(base)
      self.compile_stmts(then_body)
      self.place_label(end_lbl)
      self.set_stack(base)
    }
    SWhile(cond, body, _) => {
      let head = self.new_label()
      let body_lbl = self.new_label()
      let end_lbl = self.new_label()
      let base = self.cur_stack
      self.place_label(head)
      self.set_stack(base)
      self.compile_expr(cond)
      self.emit_jump(Opcode::CJmp, body_lbl, 1, 0)
      self.emit_jump(Opcode::Jmp, end_lbl, 0, 0)
      self.place_label(body_lbl)
      self.set_stack(base)
      self.loop_stack.push((head, end_lbl)) // continue -> head, break -> end
      self.compile_stmts(body)
      self.loop_stack.pop() |> ignore
      self.emit_jump(Opcode::Jmp, head, 0, 0)
      self.place_label(end_lbl)
      self.set_stack(base)
    }
    SFor(target, iter_expr, body, pos) =>
      self.compile_for(target, iter_expr, body, pos)
    SBreak(_) =>
      match self.loop_stack.last() {
        Some((_, brk)) => self.emit_jump(Opcode::Jmp, brk, 0, 0)
        None => raise CompileErr("compile: break not in a loop")
      }
    SContinue(_) =>
      match self.loop_stack.last() {
        Some((cont, _)) => self.emit_jump(Opcode::Jmp, cont, 0, 0)
        None => raise CompileErr("compile: continue not in a loop")
      }
    SReturn(expr_opt, pos) => {
      match expr_opt {
        Some(e) => self.compile_expr(e)
        None => self.emit0(Opcode::NoneOp, 0, 1)
      }
      self.set_pos(pos)
      self.emit0(Opcode::Return, 1, 0)
    }
    SDef(name, params, body, pos) => {
      self.compile_make_func(name, params, body, pos)
      self.set_pos(pos)
      self.compile_store(name)
    }
    SLoad(path, bindings, pos) => {
      let exports : Array[String] = []
      let locals : Array[String] = []
      let slots : Array[Int] = []
      for b in bindings {
        let (local_name, export_name, _) = b
        let slot = match self.pcomp.global_index.get(local_name) {
          Some(i) => i
          None =>
            raise CompileErr("compile: load binds unknown global \{local_name}")
        }
        exports.push(export_name)
        locals.push(local_name)
        slots.push(slot)
      }
      let idx = self.pcomp.load_stmts.length()
      self.pcomp.load_stmts.push({ path, pos, exports, locals, slots })
      self.set_pos(pos)
      self.emit1(Opcode::Load, idx, 0, 0)
    }
  }
}

///|
/// Compiles a function definition into a nested funcode and emits the code that
/// builds the function value at runtime (its defaults gathered into a tuple,
/// then `MakeFunc`). Leaves the function value on the operand stack.
fn Fcomp::compile_make_func(
  self : Fcomp,
  name : String,
  params : Array[@syntax.Param],
  body : Array[@syntax.Stmt],
  pos : @errors.Position,
) -> Unit raise CompileErr {
  let idx = compile_function(self.pcomp, name, params, body, pos, parent=self)
  // Default values are evaluated now, in the enclosing scope, in parameter order
  // (only parameters with a default), then gathered into a tuple consumed by
  // MakeFunc. The VM maps them back onto the optional parameters' slots.
  let mut ndefaults = 0
  for p in params {
    match p {
      ParamDefault(_, default_e, _) => {
        self.compile_expr(default_e)
        ndefaults += 1
      }
      _ => ()
    }
  }
  self.set_pos(pos)
  self.emit1(Opcode::MakeTuple, ndefaults, ndefaults, 1)
  self.emit1(Opcode::MakeFunc, idx, 1, 1)
}

///|
/// Compiles a `for target in iterable: body` loop. The iterable is pushed onto
/// the VM's iterator stack (`IterPush`); each round `IterJmp` either yields the
/// next element (fall through) or exits the loop; `IterPop` releases the
/// iterator (and unfreezes the container) on exit. Only a simple identifier
/// target is supported so far; destructuring targets are added with tuple
/// unpacking.
fn Fcomp::compile_for(
  self : Fcomp,
  target : @syntax.Expr,
  iter_expr : @syntax.Expr,
  body : Array[@syntax.Stmt],
  pos : @errors.Position,
) -> Unit raise CompileErr {
  let head = self.new_label()
  let end_lbl = self.new_label()
  let base = self.cur_stack
  self.compile_expr(iter_expr)
  self.set_pos(pos)
  self.emit0(Opcode::IterPush, 1, 0)
  self.place_label(head)
  self.set_stack(base)
  // IterJmp: on exhaustion jump to end; otherwise push the next element.
  self.emit_jump(Opcode::IterJmp, end_lbl, 0, 1)
  match target {
    EIdent(name, _) => {
      self.set_pos(pos)
      self.compile_store(name)
    }
    _ =>
      raise CompileErr(
        "compile: unsupported for-loop target at \{@syntax.expr_pos(target).to_string()}",
      )
  }
  self.loop_stack.push((head, end_lbl)) // continue -> head, break -> end
  self.compile_stmts(body)
  self.loop_stack.pop() |> ignore
  self.emit_jump(Opcode::Jmp, head, 0, 0)
  self.place_label(end_lbl)
  self.set_stack(base)
  self.emit0(Opcode::IterPop, 0, 0)
}

///|
/// Compiles a statement sequence.
fn Fcomp::compile_stmts(
  self : Fcomp,
  stmts : Array[@syntax.Stmt],
) -> Unit raise CompileErr {
  for s in stmts {
    self.compile_stmt(s)
  }
}

///|
/// Emits a store to a named binding. Mirrors `compile_ident` precedence: a local
/// (inside a function) else a module global. Storing to a predeclared/universal
/// name is impossible (the resolver classifies any assigned name as a binding).
fn Fcomp::compile_store(self : Fcomp, name : String) -> Unit raise CompileErr {
  match self.local_index.get(name) {
    Some(idx) => self.emit1(Opcode::SetLocal, idx, 1, 0)
    None =>
      match self.pcomp.global_index.get(name) {
        Some(idx) => self.emit1(Opcode::SetGlobal, idx, 1, 0)
        None => raise CompileErr("compile: store to unbound name \{name}")
      }
  }
}

///|
/// Assigns the value currently on top of the operand stack to `target`,
/// consuming it. The right-hand side is evaluated before this is called, so
/// for index/attribute targets the container and index/attribute are evaluated
/// after the value (matching the walker). Tuple/list targets unpack the value
/// and assign each element (recursively, supporting nesting).
fn Fcomp::compile_assign_target(
  self : Fcomp,
  target : @syntax.Expr,
) -> Unit raise CompileErr {
  match target {
    EIdent(name, _) => self.compile_store(name)
    EIndex(obj, idx, ipos) => {
      self.compile_expr(obj)
      self.compile_expr(idx)
      self.set_pos(ipos)
      // stack: [value, obj, idx] -> set_index(obj, idx, value)
      self.emit0(Opcode::SetIndex, 3, 0)
    }
    EDot(obj, attr, dpos) => {
      self.compile_expr(obj)
      self.set_pos(dpos)
      // stack: [value, obj] -> obj.attr = value
      self.emit1(Opcode::SetField, self.pcomp.add_name(attr), 2, 0)
    }
    ETuple(elems, tpos) | EList(elems, tpos) => {
      self.set_pos(tpos)
      // pops the value, pushes its `n` elements with element 0 on top
      self.emit1(Opcode::Unpack, elems.length(), 1, elems.length())
      for e in elems {
        self.compile_assign_target(e)
      }
    }
    _ =>
      raise CompileErr(
        "compile: invalid assignment target at \{@syntax.expr_pos(target).to_string()}",
      )
  }
}

///|
/// Maps an augmented-assignment operator to its integer code (the `AugApply`
/// operand). Matches the serialization ordering of `@syntax.AugOp`.
fn aug_op_code(op : @syntax.AugOp) -> Int {
  match op {
    AugAdd => 0
    AugSub => 1
    AugMul => 2
    AugDiv => 3
    AugFloorDiv => 4
    AugMod => 5
    AugBitAnd => 6
    AugBitOr => 7
    AugBitXor => 8
    AugLShift => 9
    AugRShift => 10
  }
}

///|
/// Calls `add(name, pos)` for every name an assignment to `target` binds: the
/// identifier itself, or each element of a tuple/list target (recursively).
/// Index and attribute targets bind no new name.
fn collect_target_names(
  target : @syntax.Expr,
  add : (String, @errors.Position) -> Unit,
) -> Unit {
  match target {
    EIdent(name, pos) => add(name, pos)
    ETuple(elems, _) | EList(elems, _) =>
      for e in elems {
        collect_target_names(e, add)
      }
    _ => ()
  }
}

///|
/// Compiles a function body into a nested funcode, registers it in the program's
/// function table, and returns its index (the `MakeFunc` operand). Parameters
/// become the first local slots; names assigned in the body become further
/// locals. Only plain positional parameters are supported so far.
fn compile_function(
  pcomp : Pcomp,
  name : String,
  params : Array[@syntax.Param],
  body : Array[@syntax.Stmt],
  pos : @errors.Position,
  parent~ : Fcomp,
) -> Int raise CompileErr {
  let fc = Fcomp::new(pcomp, name, pos, parent=Some(parent))
  // Assign a local slot to each named parameter (a bare `*` separator gets none)
  // and record an AST-free spec so the VM can bind arguments. `after_star` tracks
  // keyword-only parameters (those following a `*`/`*args`).
  fn add_param_local(pname : String, ppos : @errors.Position) -> Unit {
    let idx = fc.locals.length()
    fc.locals.push(@errors.Binding::new(pname, ppos))
    fc.local_index[pname] = idx
  }

  let mut after_star = false
  for p in params {
    match p {
      ParamIdent(pname, ppos) => {
        add_param_local(pname, ppos)
        fc.params.push(PRequired(pname))
        fc.num_params += 1
        if after_star {
          fc.num_kwonly_params += 1
        }
      }
      ParamDefault(pname, _, ppos) => {
        add_param_local(pname, ppos)
        fc.params.push(POptional(pname))
        fc.num_params += 1
        if after_star {
          fc.num_kwonly_params += 1
        }
      }
      ParamStarBare(_) => {
        fc.params.push(PStarBare)
        after_star = true
      }
      ParamStarIdent(pname, ppos) => {
        add_param_local(pname, ppos)
        fc.params.push(PStarArgs(pname))
        fc.num_params += 1
        fc.has_varargs = true
        after_star = true
      }
      ParamKwIdent(pname, ppos) => {
        add_param_local(pname, ppos)
        fc.params.push(PKwArgs(pname))
        fc.num_params += 1
        fc.has_kwargs = true
      }
    }
  }
  collect_function_locals(fc, body)
  fc.compile_stmts(body)
  // Functions implicitly return None when control reaches the end.
  fc.emit0(Opcode::NoneOp, 0, 1)
  fc.emit0(Opcode::Return, 1, 0)
  let funcode = fc.finish()
  let idx = pcomp.functions.length()
  pcomp.functions.push(funcode)
  idx
}

///|
/// Pre-pass over a function body: every name bound inside it (assignment LHS,
/// `for` target, nested `def` name) becomes a local slot after the parameters.
fn collect_function_locals(fc : Fcomp, body : Array[@syntax.Stmt]) -> Unit {
  fn add(name : String, pos : @errors.Position) -> Unit {
    if !fc.local_index.contains(name) {
      let idx = fc.locals.length()
      fc.locals.push(@errors.Binding::new(name, pos))
      fc.local_index[name] = idx
    }
  }

  fn walk(ss : Array[@syntax.Stmt]) -> Unit {
    for s in ss {
      match s {
        SAssign(target, _, _) => collect_target_names(target, add)
        SAugAssign(target, _, _, _) => collect_target_names(target, add)
        SFor(target, _, b, _) => {
          collect_target_names(target, add)
          walk(b)
        }
        SIf(_, t, e, _) => {
          walk(t)
          walk(e)
        }
        SWhile(_, b, _) => walk(b)
        // A nested def binds its name in this scope; its body is a separate scope.
        SDef(name, _, _, p) => add(name, p)
        _ => ()
      }
    }
  }

  walk(body)
}

// --- module-global collection ---

///|
/// Pre-pass: assign a global slot index to every name bound at module scope, in
/// source order, so that forward references compile to the right `Global` index.
/// Mirrors the binding sites the resolver treats as module globals.
fn collect_globals(pcomp : Pcomp, stmts : Array[@syntax.Stmt]) -> Unit {
  fn add(name : String, pos : @errors.Position) -> Unit {
    if !pcomp.global_index.contains(name) {
      let idx = pcomp.globals.length()
      pcomp.globals.push(@errors.Binding::new(name, pos))
      pcomp.global_index[name] = idx
    }
  }

  // Collects binding sites within `ss`; module-scope `if`/`for`/`while` bodies
  // still bind module globals, so recurse into them.
  fn walk(ss : Array[@syntax.Stmt]) -> Unit {
    for s in ss {
      match s {
        SAssign(target, _, _) => collect_target_names(target, add)
        SAugAssign(target, _, _, _) => collect_target_names(target, add)
        SDef(name, _, _, pos) => add(name, pos)
        SLoad(_, bindings, _) =>
          for b in bindings {
            add(b.0, b.2)
          }
        SFor(target, _, body, _) => {
          collect_target_names(target, add)
          walk(body)
        }
        SIf(_, then_body, else_body, _) => {
          walk(then_body)
          walk(else_body)
        }
        SWhile(_, body, _) => walk(body)
        SReturn(_, _) | SPass(_) | SExpr(_) | SBreak(_) | SContinue(_) => ()
      }
    }
  }

  walk(stmts)
}

// --- public entry ---

///|
/// Compiles a resolved file into a `CompiledProgram`. The file must already have
/// passed name resolution. `is_predeclared` and `is_universal` classify free
/// names exactly as during resolution. `recursion` records whether the dialect
/// permits recursive calls.
///
/// Raises `CompileErr` for source constructs not yet lowered (the compiler is
/// being built up milestone by milestone).
pub fn compile(
  file : @syntax.File,
  is_predeclared : (String) -> Bool,
  is_universal : (String) -> Bool,
  recursion : Bool,
) -> CompiledProgram raise CompileErr {
  let pcomp : Pcomp = {
    constants: [],
    names: [],
    name_index: {},
    functions: [],
    globals: [],
    global_index: {},
    loads: [],
    load_stmts: [],
    is_predeclared,
    is_universal,
  }
  let stmts = file.stmts()
  collect_globals(pcomp, stmts)
  let top_pos = @errors.Position::new(file.path(), 1, 1)
  let fc = Fcomp::new(pcomp, "<toplevel>", top_pos)
  for s in stmts {
    fc.compile_stmt(s)
  }
  // Module-init function implicitly returns None.
  fc.emit0(Opcode::NoneOp, 0, 1)
  fc.emit0(Opcode::Return, 1, 0)
  let toplevel = fc.finish()
  {
    loads: pcomp.loads,
    names: pcomp.names,
    constants: pcomp.constants,
    functions: pcomp.functions,
    globals: pcomp.globals,
    toplevel,
    recursion,
    load_stmts: pcomp.load_stmts,
  }
}
