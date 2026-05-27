// Starlark name-resolution pass.
// Walks the parsed AST, classifies each identifier as local/global/free/
// predeclared/universal, validates scoping rules, and returns a list of
// errors together with collected global and file-local bindings.

///|
pub(all) enum Scope {
  Undefined
  Local(Int)
  Cell(Int)
  Free(Int)
  Global(Int)
  Predeclared
  Universal
}

///|
pub struct Binding {
  priv name : String
  priv pos : @errors.Position
  priv scope : Scope
}

///|
pub fn Binding::name(self : Binding) -> String {
  self.name
}

///|
pub fn Binding::pos(self : Binding) -> @errors.Position {
  self.pos
}

///|
pub fn Binding::scope(self : Binding) -> Scope {
  self.scope
}

///|
pub struct ResolveOptions {
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
pub fn ResolveOptions::default() -> ResolveOptions {
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
pub fn ResolveOptions::allow_set(self : ResolveOptions) -> Bool {
  self.allow_set
}

///|
pub fn ResolveOptions::allow_recursion(self : ResolveOptions) -> Bool {
  self.allow_recursion
}

///|
pub fn ResolveOptions::allow_lambda(self : ResolveOptions) -> Bool {
  self.allow_lambda
}

///|
pub fn ResolveOptions::allow_while(self : ResolveOptions) -> Bool {
  self.allow_while
}

///|
pub fn ResolveOptions::allow_bytes(self : ResolveOptions) -> Bool {
  self.allow_bytes
}

///|
pub fn ResolveOptions::allow_float(self : ResolveOptions) -> Bool {
  self.allow_float
}

///|
pub fn ResolveOptions::allow_global_reassign(self : ResolveOptions) -> Bool {
  self.allow_global_reassign
}

///|
pub fn ResolveOptions::allow_top_level_control(self : ResolveOptions) -> Bool {
  self.allow_top_level_control
}

///|
pub fn ResolveOptions::load_binds_globally(self : ResolveOptions) -> Bool {
  self.load_binds_globally
}

///|
pub fn ResolveOptions::with_allow_global_reassign(
  self : ResolveOptions,
  v : Bool,
) -> ResolveOptions {
  { ..self, allow_global_reassign: v }
}

///|
pub fn ResolveOptions::with_allow_top_level_control(
  self : ResolveOptions,
  v : Bool,
) -> ResolveOptions {
  { ..self, allow_top_level_control: v }
}

///|
pub fn ResolveOptions::with_allow_recursion(
  self : ResolveOptions,
  v : Bool,
) -> ResolveOptions {
  { ..self, allow_recursion: v }
}

///|
pub struct ResolvedFile {
  priv globals : Array[Binding]
  priv locals : Array[Binding]
  priv errors : Array[@errors.ResolveError]
}

///|
pub fn ResolvedFile::is_valid(self : ResolvedFile) -> Bool {
  self.errors.is_empty()
}

///|
pub fn ResolvedFile::errors(self : ResolvedFile) -> Array[@errors.ResolveError] {
  self.errors
}

///|
pub fn ResolvedFile::globals(self : ResolvedFile) -> Array[Binding] {
  self.globals
}

///|
pub fn ResolvedFile::locals(self : ResolvedFile) -> Array[Binding] {
  self.locals
}

// --- Internal types ---

// A Block tracks the lexical environment for one scope level.

///|
priv struct Block {
  parent : Block?
  bindings : Map[String, Binding]
  // Deferred uses (name, pos) to be resolved after the container is fully walked.
  uses : Array[(String, @errors.Position)]
}

///|
priv struct Resolver {
  // The current (innermost) lexical block
  mut env : Block
  // The file-level (root) block
  file_block : Block
  // Module-level globals (name → Binding)
  globals : Map[String, Binding]
  // Cached predeclared/universal bindings
  predeclared_cache : Map[String, Binding]
  // Ordered lists returned in the result
  module_globals : Array[Binding]
  module_locals : Array[Binding]
  // Accumulated errors
  errors : Array[@errors.ResolveError]
  // Callbacks
  is_predeclared : (String) -> Bool
  is_universal : (String) -> Bool
  // Options
  opts : ResolveOptions
  // Nesting counters
  mut loops : Int
  mut in_func : Int
  // Name of the innermost function (for recursion detection)
  mut current_fn_name : String
  // Names imported via load statements (always immutable)
  load_names : Map[String, @errors.Position]
}

///|
fn Resolver::new(
  is_predeclared : (String) -> Bool,
  is_universal : (String) -> Bool,
  opts : ResolveOptions,
) -> Resolver {
  let file_block : Block = { parent: None, bindings: {}, uses: [] }
  {
    env: file_block,
    file_block,
    globals: {},
    predeclared_cache: {},
    module_globals: [],
    module_locals: [],
    errors: [],
    is_predeclared,
    is_universal,
    opts,
    loops: 0,
    in_func: 0,
    current_fn_name: "",
    load_names: {},
  }
}

///|
fn Resolver::errorf(
  self : Resolver,
  pos : @errors.Position,
  msg : String,
) -> Unit {
  self.errors.push(@errors.ResolveError::new(pos, msg))
}

///|
fn Resolver::is_at_module_scope(self : Resolver) -> Bool {
  self.in_func == 0
}

// Push a new lexical block. Returns the saved outer block for restoration.

///|
fn Resolver::push_block(self : Resolver) -> Block {
  let saved = self.env
  self.env = { parent: Some(saved), bindings: {}, uses: [] }
  saved
}

// Restore to the saved outer block.

///|
fn Resolver::pop_block(self : Resolver, saved : Block) -> Unit {
  self.env = saved
}

// Create or check a global binding for `name` at `pos`.

///|
fn Resolver::bind_global(
  self : Resolver,
  name : String,
  pos : @errors.Position,
) -> Unit {
  if self.globals.contains(name) {
    if self.load_names.contains(name) {
      self.errorf(
        pos,
        "cannot reassign name '\{name}' imported from a load statement",
      )
    } else if !self.opts.allow_global_reassign {
      let prev = self.globals[name]
      self.errorf(
        pos,
        "cannot reassign global \{name} declared at \{prev.pos.to_string()}",
      )
    }
  } else {
    let idx = self.module_globals.length()
    let b : Binding = { name, pos, scope: Global(idx) }
    self.globals[name] = b
    self.module_globals.push(b)
  }
}

// Bind a name introduced by a load statement.
// Unlike regular assignments, a load may rebind an existing load-imported name
// when allow_global_reassign is enabled.

///|
fn Resolver::bind_load(
  self : Resolver,
  name : String,
  pos : @errors.Position,
) -> Unit {
  if self.globals.contains(name) {
    if !self.opts.allow_global_reassign {
      self.errorf(pos, "cannot reassign global \{name}")
    }
  } else {
    let idx = self.module_globals.length()
    let b : Binding = { name, pos, scope: Global(idx) }
    self.globals[name] = b
    self.module_globals.push(b)
  }
  self.load_names[name] = pos
}

// Bind a name in the current local block.

///|
fn Resolver::bind_local(
  self : Resolver,
  name : String,
  pos : @errors.Position,
) -> Unit {
  if !self.env.bindings.contains(name) {
    let idx = self.env.bindings.length()
    let b : Binding = { name, pos, scope: Local(idx) }
    self.env.bindings[name] = b
  }
}

// Bind an LHS expression (assignment or for-target). Handles ident and tuple unpack.

///|
fn Resolver::bind_lhs(self : Resolver, lhs : @syntax.Expr) -> Unit {
  match lhs {
    @syntax.Expr::EIdent(name, pos) => self.bind_name(name, pos)
    @syntax.Expr::ETuple(elems, _) | @syntax.Expr::EList(elems, _) =>
      for elem in elems {
        self.bind_lhs(elem)
      }
    _ => ()
  }
}

// Bind a name in the current scope (global or local depending on function depth).

///|
fn Resolver::bind_name(
  self : Resolver,
  name : String,
  pos : @errors.Position,
) -> Unit {
  if self.is_at_module_scope() {
    self.bind_global(name, pos)
  } else {
    self.bind_local(name, pos)
  }
}

// Record a use of `name` at `pos`.

///|
fn Resolver::use_name(
  self : Resolver,
  name : String,
  pos : @errors.Position,
) -> Unit {
  if self.is_at_module_scope() {
    self.file_block.uses.push((name, pos))
  } else {
    self.env.uses.push((name, pos))
  }
}

// Resolve all module-level deferred uses after the file is fully walked.

///|
fn Resolver::resolve_deferred_uses(self : Resolver) -> Unit {
  for pair in self.file_block.uses {
    let (name, pos) = pair
    self.resolve_name_at_toplevel(name, pos)
  }
}

///|
fn Resolver::resolve_name_at_toplevel(
  self : Resolver,
  name : String,
  pos : @errors.Position,
) -> Unit {
  if self.globals.contains(name) || self.predeclared_cache.contains(name) {
    ()
  } else if (self.is_predeclared)(name) {
    let b : Binding = { name, pos, scope: Predeclared }
    self.predeclared_cache[name] = b
  } else if (self.is_universal)(name) {
    let b : Binding = { name, pos, scope: Universal }
    self.predeclared_cache[name] = b
  } else {
    self.errorf(pos, "undefined: \{name}")
  }
}

// Resolve uses recorded inside a function/comprehension block.

///|
fn Resolver::resolve_function_uses(
  self : Resolver,
  block : Block,
  fn_name : String,
) -> Unit {
  for pair in block.uses {
    let (name, pos) = pair
    // Check if the name is local to the function scope chain
    match lookup_in_local_scope(block, name) {
      Some(_) => ()
      None =>
        // Not a local: check for recursion, globals, and predeclared names
        if name == fn_name && fn_name != "" && !self.opts.allow_recursion {
          self.errorf(pos, "recursion not allowed: \{name}")
        } else if self.globals.contains(name) {
          ()
        } else if self.predeclared_cache.contains(name) {
          ()
        } else if (self.is_predeclared)(name) {
          let b : Binding = { name, pos, scope: Predeclared }
          self.predeclared_cache[name] = b
        } else if (self.is_universal)(name) {
          let b : Binding = { name, pos, scope: Universal }
          self.predeclared_cache[name] = b
        } else {
          // Could be a forward-referenced global; defer resolution.
          self.file_block.uses.push((name, pos))
        }
    }
  }
}

// Walk local scope chain upward (stopping before the file block).

///|
fn lookup_in_local_scope(env : Block, name : String) -> Binding? {
  if env.bindings.contains(name) {
    Some(env.bindings[name])
  } else {
    match env.parent {
      None => None
      Some(parent) =>
        // Stop at the file block (it has no parent)
        if parent.parent is None {
          None
        } else {
          lookup_in_local_scope(parent, name)
        }
    }
  }
}

// --- Statement walker ---

///|
fn Resolver::walk_stmts(self : Resolver, stmts : Array[@syntax.Stmt]) -> Unit {
  for stmt in stmts {
    self.walk_stmt(stmt)
  }
}

///|
fn Resolver::walk_stmt(self : Resolver, stmt : @syntax.Stmt) -> Unit {
  match stmt {
    @syntax.Stmt::SExpr(e) => self.walk_expr(e)
    @syntax.Stmt::SAssign(lhs, rhs, _) => {
      self.walk_expr(rhs)
      self.bind_lhs(lhs)
    }
    @syntax.Stmt::SAugAssign(lhs, _, rhs, pos) => {
      self.walk_expr(rhs)
      if self.is_at_module_scope() && !self.opts.allow_global_reassign {
        match lhs {
          @syntax.Expr::EIdent(name, _) =>
            if self.globals.contains(name) {
              let prev = self.globals[name]
              self.errorf(
                pos,
                "cannot reassign global \{name} declared at \{prev.pos.to_string()}",
              )
            } else {
              self.bind_lhs(lhs)
            }
          _ => self.bind_lhs(lhs)
        }
      } else {
        self.bind_lhs(lhs)
      }
    }
    @syntax.Stmt::SIf(cond, then_stmts, else_stmts, pos) => {
      if self.is_at_module_scope() && !self.opts.allow_top_level_control {
        self.errorf(pos, "if statements are not allowed at module level")
      }
      self.walk_expr(cond)
      self.walk_stmts(then_stmts)
      self.walk_stmts(else_stmts)
    }
    @syntax.Stmt::SFor(target, iter, body, pos) => {
      if self.is_at_module_scope() && !self.opts.allow_top_level_control {
        self.errorf(pos, "for loops are not allowed at module level")
      }
      self.walk_expr(iter)
      let old_loops = self.loops
      self.loops = self.loops + 1
      self.bind_lhs(target)
      self.walk_stmts(body)
      self.loops = old_loops
    }
    @syntax.Stmt::SWhile(cond, body, pos) => {
      if self.is_at_module_scope() && !self.opts.allow_top_level_control {
        self.errorf(pos, "while loops are not allowed at module level")
      }
      self.walk_expr(cond)
      let old_loops = self.loops
      self.loops = self.loops + 1
      self.walk_stmts(body)
      self.loops = old_loops
    }
    @syntax.Stmt::SDef(name, params, body, pos) => {
      self.bind_name(name, pos)
      let saved = self.push_block()
      let old_fn = self.current_fn_name
      let old_in_func = self.in_func
      self.current_fn_name = name
      self.in_func = self.in_func + 1
      self.walk_params(params, pos)
      self.pre_collect_stmts(body)
      self.walk_stmts(body)
      self.resolve_function_uses(self.env, name)
      let fn_block = self.env
      self.in_func = old_in_func
      self.current_fn_name = old_fn
      self.pop_block(saved)
      ignore(fn_block)
    }
    @syntax.Stmt::SReturn(e, pos) => {
      if self.in_func == 0 {
        self.errorf(pos, "return outside function")
      }
      match e {
        Some(expr) => self.walk_expr(expr)
        None => ()
      }
    }
    @syntax.Stmt::SBreak(pos) =>
      if self.loops == 0 {
        self.errorf(pos, "break outside loop")
      }
    @syntax.Stmt::SContinue(pos) =>
      if self.loops == 0 {
        self.errorf(pos, "continue outside loop")
      }
    @syntax.Stmt::SPass(_) => ()
    @syntax.Stmt::SLoad(_, names, pos) =>
      if !self.is_at_module_scope() {
        self.errorf(pos, "load statement must be at module level")
      } else {
        for pair in names {
          let (local_name, _original) = pair
          self.bind_load(local_name, pos)
        }
      }
  }
}

// Validate and bind function parameters.

///|
fn Resolver::walk_params(
  self : Resolver,
  params : Array[@syntax.Param],
  def_pos : @errors.Position,
) -> Unit {
  let seen : Map[String, Bool] = {}
  let mut seen_star = false
  let mut seen_kwargs = false
  for param in params {
    match param {
      @syntax.Param::ParamIdent(name, pos) => {
        if seen_kwargs {
          self.errorf(pos, "parameter after **kwargs")
        }
        if seen.contains(name) {
          self.errorf(pos, "duplicate parameter: \{name}")
        } else {
          seen[name] = true
          self.bind_local(name, pos)
        }
      }
      @syntax.Param::ParamDefault(name, default_expr, pos) => {
        if seen_kwargs {
          self.errorf(pos, "parameter after **kwargs")
        }
        if seen.contains(name) {
          self.errorf(pos, "duplicate parameter: \{name}")
        } else {
          seen[name] = true
          self.walk_expr(default_expr)
          self.bind_local(name, pos)
        }
      }
      @syntax.Param::ParamStarBare(pos) => {
        if seen_star {
          self.errorf(pos, "multiple * in parameters")
        }
        seen_star = true
      }
      @syntax.Param::ParamStarIdent(name, pos) => {
        if seen_star {
          self.errorf(pos, "multiple * in parameters")
        }
        if seen.contains(name) {
          self.errorf(pos, "duplicate parameter: \{name}")
        } else {
          seen_star = true
          seen[name] = true
          self.bind_local(name, pos)
        }
      }
      @syntax.Param::ParamKwIdent(name, pos) => {
        if seen_kwargs {
          self.errorf(def_pos, "multiple **kwargs in parameters")
        }
        if seen.contains(name) {
          self.errorf(pos, "duplicate parameter: \{name}")
        } else {
          seen_kwargs = true
          seen[name] = true
          self.bind_local(name, pos)
        }
      }
    }
  }
}

// Pre-collect all binding names in function body before resolving uses.
// This ensures forward references (e.g., x referenced in an inner def before
// x = ... appears in the enclosing function) are visible during resolution.

///|
fn Resolver::pre_collect_stmts(
  self : Resolver,
  stmts : Array[@syntax.Stmt],
) -> Unit {
  for stmt in stmts {
    self.pre_collect_stmt(stmt)
  }
}

///|
fn Resolver::pre_collect_stmt(self : Resolver, stmt : @syntax.Stmt) -> Unit {
  match stmt {
    @syntax.Stmt::SAssign(lhs, _, _) => self.pre_collect_lhs(lhs)
    @syntax.Stmt::SAugAssign(_, _, _, _) => ()
    @syntax.Stmt::SIf(_, then_body, else_body, _) => {
      self.pre_collect_stmts(then_body)
      self.pre_collect_stmts(else_body)
    }
    @syntax.Stmt::SFor(target, _, body, _) => {
      self.pre_collect_lhs(target)
      self.pre_collect_stmts(body)
    }
    @syntax.Stmt::SWhile(_, body, _) => self.pre_collect_stmts(body)
    @syntax.Stmt::SDef(name, _, _, pos) => self.bind_local(name, pos)
    _ => ()
  }
}

///|
fn Resolver::pre_collect_lhs(self : Resolver, lhs : @syntax.Expr) -> Unit {
  match lhs {
    @syntax.Expr::EIdent(name, pos) => self.bind_local(name, pos)
    @syntax.Expr::ETuple(elems, _) | @syntax.Expr::EList(elems, _) =>
      for elem in elems {
        self.pre_collect_lhs(elem)
      }
    _ => ()
  }
}

// --- Expression walker ---

///|
fn Resolver::walk_expr(self : Resolver, expr : @syntax.Expr) -> Unit {
  match expr {
    @syntax.Expr::EIdent(name, pos) => self.use_name(name, pos)
    @syntax.Expr::ELiteral(_, _) => ()
    @syntax.Expr::EUnary(_, e, _) => self.walk_expr(e)
    @syntax.Expr::EBinary(l, _, r, _) => {
      self.walk_expr(l)
      self.walk_expr(r)
    }
    @syntax.Expr::ECond(cond, a, b, _) => {
      self.walk_expr(cond)
      self.walk_expr(a)
      self.walk_expr(b)
    }
    @syntax.Expr::EIndex(e, idx, _) => {
      self.walk_expr(e)
      self.walk_expr(idx)
    }
    @syntax.Expr::ESlice(e, lo, hi, step, _) => {
      self.walk_expr(e)
      match lo {
        Some(x) => self.walk_expr(x)
        None => ()
      }
      match hi {
        Some(x) => self.walk_expr(x)
        None => ()
      }
      match step {
        Some(x) => self.walk_expr(x)
        None => ()
      }
    }
    @syntax.Expr::EDot(e, _, _) => self.walk_expr(e)
    @syntax.Expr::ECall(f, args, _) => {
      self.walk_expr(f)
      for arg in args {
        match arg {
          @syntax.Arg::ArgPos(e) => self.walk_expr(e)
          @syntax.Arg::ArgKw(_, e, _) => self.walk_expr(e)
          @syntax.Arg::ArgStarArgs(e) => self.walk_expr(e)
          @syntax.Arg::ArgKwArgs(e) => self.walk_expr(e)
        }
      }
    }
    @syntax.Expr::EList(elems, _) =>
      for e in elems {
        self.walk_expr(e)
      }
    @syntax.Expr::ETuple(elems, _) =>
      for e in elems {
        self.walk_expr(e)
      }
    @syntax.Expr::EDict(pairs, _) =>
      for pair in pairs {
        let (k, v) = pair
        self.walk_expr(k)
        self.walk_expr(v)
      }
    @syntax.Expr::ESet(elems, _) =>
      for e in elems {
        self.walk_expr(e)
      }
    @syntax.Expr::ELambda(params, body, pos) => {
      let saved = self.push_block()
      let old_fn = self.current_fn_name
      let old_in_func = self.in_func
      self.current_fn_name = "<lambda>"
      self.in_func = self.in_func + 1
      self.walk_params(params, pos)
      self.walk_expr(body)
      self.resolve_function_uses(self.env, "<lambda>")
      self.in_func = old_in_func
      self.current_fn_name = old_fn
      self.pop_block(saved)
    }
    @syntax.Expr::EListComp(body, clauses, _) =>
      self.walk_comprehension(body, None, clauses)
    @syntax.Expr::ESetComp(body, clauses, _) =>
      self.walk_comprehension(body, None, clauses)
    @syntax.Expr::EDictComp(key, val, clauses, _) =>
      self.walk_comprehension(key, Some(val), clauses)
  }
}

// Walk a comprehension with an isolated scope for iteration variables.

///|
fn Resolver::walk_comprehension(
  self : Resolver,
  body : @syntax.Expr,
  body2 : @syntax.Expr?,
  clauses : Array[@syntax.CompClause],
) -> Unit {
  let saved = self.push_block()
  for clause in clauses {
    match clause {
      @syntax.CompClause::ClauseFor(target, iter, _) => {
        self.walk_expr(iter)
        self.bind_lhs(target)
      }
      @syntax.CompClause::ClauseIf(cond, _) => self.walk_expr(cond)
    }
  }
  self.walk_expr(body)
  match body2 {
    Some(e) => self.walk_expr(e)
    None => ()
  }
  self.pop_block(saved)
}

// --- Public API ---

///|
pub fn resolve(
  file : @syntax.File,
  is_predeclared : (String) -> Bool,
  is_universal : (String) -> Bool,
  opts : ResolveOptions,
) -> ResolvedFile {
  let r = Resolver::new(is_predeclared, is_universal, opts)
  r.walk_stmts(file.stmts)
  r.resolve_deferred_uses()
  { globals: r.module_globals, locals: r.module_locals, errors: r.errors }
}
