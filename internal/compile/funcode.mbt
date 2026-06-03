// Compiled function code and program, modeled on starlark-go's
// `compile.Funcode` / `compile.Program`. These types are deliberately
// syntax-free: their fields name only `@errors` types and primitives, never
// `@syntax`. This is what lets the runtime function value hold compiled code
// without leaking the AST into the public `value` API.

///|
/// A line-table entry mapping a bytecode offset to a source position. Entries
/// are stored ascending by `pc`; `Funcode::position` recovers the position for
/// an arbitrary pc by finding the last entry whose `pc` does not exceed it.
/// This is the structural equivalent of starlark-go's `pclinetab`.
pub(all) struct PcLine {
  pc : Int
  line : Int
  col : Int
} derive(Eq)

///|
/// The compiled code of a single function (or the implicit module-init
/// function). The executable body is `code` (opcode bytes); `pclinetab` recovers
/// source positions for diagnostics. `locals` lists every local slot with
/// parameters first (matching the reflection contract: `param(i)` reads
/// `locals[i]`). `cells` holds the indices of locals that must be boxed because
/// a nested function captures them; `freevars` names the parent cells this
/// function captures.
pub(all) struct Funcode {
  pos : @errors.Position
  name : String
  doc : String
  code : Bytes
  pclinetab : Array[PcLine]
  locals : Array[@errors.Binding]
  cells : Array[Int]
  freevars : Array[@errors.Binding]
  max_stack : Int
  num_params : Int
  num_kwonly_params : Int
  has_varargs : Bool
  has_kwargs : Bool
  // Parameter specs in declaration order, AST-free, so the VM can bind call
  // arguments with the same algorithm the AST walker uses. Named parameters
  // occupy local slots 0,1,2,... in this order (a bare `*` separator takes no
  // slot). Defaults are carried separately on the runtime function value,
  // aligned to this list.
  params : Array[ParamSpec]
  // For each captured free variable (parallel to `freevars`), where the
  // enclosing frame holds its cell: a local-cell slot or one of the enclosing
  // function's own free variables. `MakeFunc` reads these to gather the closure's
  // cells from the frame that builds it.
  freevar_sources : Array[FreevarSource]
}

///|
/// Where a closure's captured cell comes from in the enclosing frame.
pub(all) enum FreevarSource {
  FromLocal(Int) // the enclosing frame's local-cell slot
  FromFree(Int) // the enclosing function's own free variable
} derive(Eq)

///|
/// An AST-free description of a single function parameter, mirroring the
/// `@syntax.Param` kinds the binder needs (without the default expression, which
/// is evaluated at definition time and stored on the function value).
pub(all) enum ParamSpec {
  PRequired(String) // `x`
  POptional(String) // `x = default`
  PStarBare // bare `*` separator (keyword-only marker; no slot)
  PStarArgs(String) // `*args`
  PKwArgs(String) // `**kwargs`
} derive(Eq)

///|
/// Recovers the source position for the instruction at bytecode offset `pc`.
///
/// Returns the position of the last line-table entry whose `pc` does not exceed
/// the argument; falls back to the function's own definition position when the
/// table is empty or `pc` precedes the first entry. The filename is always taken
/// from the function's definition position (every instruction in a function
/// belongs to the same source file).
pub fn Funcode::position(self : Funcode, pc : Int) -> @errors.Position {
  let filename = self.pos.filename()
  let tab = self.pclinetab
  if tab.length() == 0 || pc < tab[0].pc {
    return self.pos
  }
  // Binary search for the last entry with entry.pc <= pc.
  let mut lo = 0
  let mut hi = tab.length() - 1
  while lo < hi {
    let mid = (lo + hi + 1) / 2
    if tab[mid].pc <= pc {
      lo = mid
    } else {
      hi = mid - 1
    }
  }
  @errors.Position::new(filename, tab[lo].line, tab[lo].col)
}

///|
/// A fully compiled module: a constant pool, the table of nested function
/// codes, the module-global and load binding tables, and the implicit
/// module-init function (`toplevel`). `recursion` records whether the dialect
/// permits recursive calls (so the VM can skip the runtime recursion check).
pub(all) struct CompiledProgram {
  loads : Array[@errors.Binding]
  names : Array[String]
  constants : Array[Const]
  functions : Array[Funcode]
  globals : Array[@errors.Binding]
  toplevel : Funcode
  recursion : Bool
  // Load statements, indexed by the `Load` opcode operand. The VM calls the
  // loader for `path` and binds each export into its module-global slot.
  load_stmts : Array[LoadStmt]
}

///|
/// A compiled `load("path", local=export, ...)` statement. `slots[i]` is the
/// module-global slot that receives the symbol named `exports[i]`; `locals[i]`
/// is the local name (tracked so module-local load bindings can be excluded from
/// the module's exported globals).
pub(all) struct LoadStmt {
  path : String
  pos : @errors.Position
  exports : Array[String]
  locals : Array[String]
  slots : Array[Int]
}
