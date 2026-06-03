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

///|
priv struct Fcomp {
  pcomp : Pcomp
  name : String
  pos : @errors.Position
  doc : String
  code : Array[Byte]
  pclinetab : Array[PcLine]
  locals : Array[@errors.Binding]
  local_index : Map[String, Int]
  mut last_line : Int
  mut last_col : Int
  mut cur_stack : Int
  mut max_stack : Int
}

///|
fn Fcomp::new(pcomp : Pcomp, name : String, pos : @errors.Position) -> Fcomp {
  {
    pcomp,
    name,
    pos,
    doc: "",
    code: [],
    pclinetab: [],
    locals: [],
    local_index: {},
    last_line: -1,
    last_col: -1,
    cur_stack: 0,
    max_stack: 0,
  }
}

///|
/// Records a source position for the instruction about to be emitted. Only adds
/// a line-table entry when the position differs from the previous one, keeping
/// the table compact (the binary search in `Funcode::position` recovers the
/// right position for intervening offsets).
fn Fcomp::set_pos(self : Fcomp, pos : @errors.Position) -> Unit {
  let line = pos.line()
  let col = pos.col()
  if line != self.last_line || col != self.last_col {
    self.pclinetab.push(PcLine::{ pc: self.code.length(), line, col })
    self.last_line = line
    self.last_col = col
  }
}

///|
/// Adjusts the tracked operand-stack height and updates the peak.
fn Fcomp::stack(self : Fcomp, pop : Int, push : Int) -> Unit {
  self.cur_stack = self.cur_stack - pop + push
  if self.cur_stack > self.max_stack {
    self.max_stack = self.cur_stack
  }
}

///|
fn Fcomp::emit0(self : Fcomp, op : Opcode, pop : Int, push : Int) -> Unit {
  self.code.push(op.to_byte())
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
  self.code.push(op.to_byte())
  write_uvarint(self.code, arg)
  self.stack(pop, push)
}

///|
fn write_uvarint(code : Array[Byte], n : Int) -> Unit {
  let mut v = n
  while v >= 0x80 {
    code.push(((v & 0x7f) | 0x80).to_byte())
    v = v >> 7
  }
  code.push(v.to_byte())
}

///|
fn Fcomp::finish(self : Fcomp) -> Funcode {
  {
    pos: self.pos,
    name: self.name,
    doc: self.doc,
    code: Bytes::from_array(self.code),
    pclinetab: self.pclinetab,
    locals: self.locals,
    cells: [],
    freevars: [],
    max_stack: self.max_stack,
    num_params: 0,
    num_kwonly_params: 0,
    has_varargs: false,
    has_kwargs: false,
  }
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
    _ => raise CompileErr("compile: unsupported expression")
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
  match self.local_index.get(name) {
    Some(idx) => self.emit1(Opcode::Local, idx, 0, 1)
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

///|
fn Fcomp::compile_binary(
  self : Fcomp,
  l : @syntax.Expr,
  op : @syntax.BinaryOp,
  r : @syntax.Expr,
  pos : @errors.Position,
) -> Unit raise CompileErr {
  // `and` / `or` short-circuit (jumps) are handled with control flow later.
  match op {
    OpAnd | OpOr => raise CompileErr("compile: and/or not yet supported")
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

// --- statement compilation ---

///|
fn Fcomp::compile_stmt(self : Fcomp, s : @syntax.Stmt) -> Unit raise CompileErr {
  match s {
    SExpr(e) => {
      self.compile_expr(e)
      self.emit0(Opcode::Pop, 1, 0)
    }
    SAssign(lhs, rhs, pos) =>
      match lhs {
        EIdent(name, _) => {
          self.compile_expr(rhs)
          self.set_pos(pos)
          self.compile_store(name)
        }
        _ => raise CompileErr("compile: unsupported assignment target")
      }
    SPass(_) => ()
    _ => raise CompileErr("compile: unsupported statement")
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

// --- module-global collection ---

///|
/// Pre-pass: assign a global slot index to every name bound at module scope, in
/// source order, so that forward references compile to the right `Global` index.
/// Mirrors the binding sites the resolver treats as module globals.
fn collect_globals(
  pcomp : Pcomp,
  stmts : Array[@syntax.Stmt],
) -> Unit raise CompileErr {
  fn add(name : String, pos : @errors.Position) -> Unit {
    if !pcomp.global_index.contains(name) {
      let idx = pcomp.globals.length()
      pcomp.globals.push(@errors.Binding::new(name, pos))
      pcomp.global_index[name] = idx
    }
  }

  for s in stmts {
    match s {
      SAssign(EIdent(name, pos), _, _) => add(name, pos)
      SPass(_) | SExpr(_) => ()
      _ => raise CompileErr("compile: unsupported top-level statement")
    }
  }
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
  }
}
