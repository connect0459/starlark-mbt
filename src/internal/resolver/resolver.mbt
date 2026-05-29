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
pub fn ResolveOptions::with_allow_set(
  self : ResolveOptions,
  v : Bool,
) -> ResolveOptions {
  { ..self, allow_set: v }
}

///|
pub fn ResolveOptions::with_load_binds_globally(
  self : ResolveOptions,
  v : Bool,
) -> ResolveOptions {
  { ..self, load_binds_globally: v }
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
    if !self.opts.allow_global_reassign {
      if self.load_names.contains(name) {
        self.errorf(
          pos,
          "cannot reassign name '\{name}' imported from a load statement",
        )
      } else {
        let prev = self.globals[name]
        self.errorf(
          pos,
          "cannot reassign global \{name} declared at \{prev.pos.to_string()}",
        )
      }
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
fn Resolver::bind_lhs(
  self : Resolver,
  lhs : @syntax.Expr,
  is_augmented? : Bool = false,
) -> Unit {
  match lhs {
    @syntax.Expr::EIdent(name, pos) => self.bind_name(name, pos)
    // x[i] = ... / x.f = ... — the object and index are uses, not bindings.
    @syntax.Expr::EIndex(obj, idx, _) => {
      self.walk_expr(obj)
      self.walk_expr(idx)
    }
    @syntax.Expr::EDot(obj, _, _) => self.walk_expr(obj)
    @syntax.Expr::ETuple(elems, pos) => {
      if is_augmented {
        self.errorf(pos, "can't use tuple expression in augmented assignment")
      }
      for elem in elems {
        self.bind_lhs(elem, is_augmented~)
      }
    }
    @syntax.Expr::EList(elems, pos) => {
      if is_augmented {
        self.errorf(pos, "can't use list expression in augmented assignment")
      }
      for elem in elems {
        self.bind_lhs(elem, is_augmented~)
      }
    }
    _ => self.errorf(@syntax.expr_pos(lhs), "can't assign to \{lhs_kind(lhs)}")
  }
}

// Names the kind of a non-assignable LHS expression, mirroring starlark-go's
// lowercased AST type name in "can't assign to <kind>".

///|
fn lhs_kind(e : @syntax.Expr) -> String {
  match e {
    @syntax.Expr::ELiteral(_, _) => "literal"
    @syntax.Expr::ECall(_, _, _) => "callexpr"
    @syntax.Expr::EBinary(_, _, _, _) => "binaryexpr"
    @syntax.Expr::EUnary(_, _, _) => "unaryexpr"
    @syntax.Expr::ECond(_, _, _, _) => "condexpr"
    @syntax.Expr::ESlice(_, _, _, _, _) => "sliceexpr"
    @syntax.Expr::EDict(_, _) => "dictexpr"
    @syntax.Expr::ESet(_, _) => "setexpr"
    @syntax.Expr::ELambda(_, _, _) => "lambdaexpr"
    @syntax.Expr::EListComp(_, _, _) => "listcomp"
    @syntax.Expr::ESetComp(_, _, _) => "setcomp"
    @syntax.Expr::EDictComp(_, _, _, _) => "dictcomp"
    _ => "expression"
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
  _fn_name : String,
) -> Unit {
  for pair in block.uses {
    let (name, pos) = pair
    // Check if the name is local to the function scope chain
    match lookup_in_local_scope(block, name) {
      Some(_) => ()
      None =>
        // Not a local: check globals and predeclared names
        if self.globals.contains(name) {
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
            if self.load_names.contains(name) {
              self.errorf(
                pos,
                "cannot reassign name '\{name}' imported from a load statement",
              )
            } else if self.globals.contains(name) {
              let prev = self.globals[name]
              self.errorf(
                pos,
                "cannot reassign global \{name} declared at \{prev.pos.to_string()}",
              )
            } else {
              self.bind_lhs(lhs, is_augmented=true)
            }
          _ => self.bind_lhs(lhs, is_augmented=true)
        }
      } else {
        self.bind_lhs(lhs, is_augmented=true)
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
          let (local_name, original) = pair
          if original.is_empty() {
            self.errorf(pos, "load: empty identifier")
            continue
          }
          if original.has_prefix("_") {
            self.errorf(
              pos,
              "load: names with leading underscores are not exported: \{original}",
            )
          }
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
  let mut seen_optional = false
  let mut seen_star = false
  let mut star_is_bare = false
  let mut star_pos = def_pos
  let mut num_kwonly = 0
  let mut kwargs_name : String? = None
  for param in params {
    match param {
      @syntax.Param::ParamIdent(name, pos) => {
        match kwargs_name {
          Some(kn) =>
            self.errorf(pos, "required parameter may not follow **\{kn}")
          None =>
            if seen_star {
              num_kwonly = num_kwonly + 1
            } else if seen_optional {
              self.errorf(pos, "required parameter may not follow optional")
            }
        }
        if seen.contains(name) {
          self.errorf(pos, "duplicate parameter: \{name}")
        } else {
          seen[name] = true
          self.bind_local(name, pos)
        }
      }
      @syntax.Param::ParamDefault(name, default_expr, pos) => {
        match kwargs_name {
          Some(kn) =>
            self.errorf(pos, "optional parameter may not follow **\{kn}")
          None => if seen_star { num_kwonly = num_kwonly + 1 }
        }
        if seen.contains(name) {
          self.errorf(pos, "duplicate parameter: \{name}")
        } else {
          seen[name] = true
          self.walk_expr(default_expr)
          self.bind_local(name, pos)
        }
        seen_optional = true
      }
      @syntax.Param::ParamStarBare(pos) =>
        match kwargs_name {
          Some(kn) => self.errorf(pos, "* parameter may not follow **\{kn}")
          None =>
            if seen_star {
              self.errorf(pos, "multiple * parameters not allowed")
            } else {
              seen_star = true
              star_is_bare = true
              star_pos = pos
            }
        }
      @syntax.Param::ParamStarIdent(name, pos) =>
        match kwargs_name {
          Some(kn) => self.errorf(pos, "* parameter may not follow **\{kn}")
          None =>
            if seen_star {
              self.errorf(pos, "multiple * parameters not allowed")
            } else {
              seen_star = true
              star_is_bare = false
              star_pos = pos
              if seen.contains(name) {
                self.errorf(pos, "duplicate parameter: \{name}")
              } else {
                seen[name] = true
                self.bind_local(name, pos)
              }
            }
        }
      @syntax.Param::ParamKwIdent(name, pos) =>
        match kwargs_name {
          Some(_) => self.errorf(pos, "multiple ** parameters not allowed")
          None => {
            kwargs_name = Some(name)
            if seen.contains(name) {
              self.errorf(pos, "duplicate parameter: \{name}")
            } else {
              seen[name] = true
              self.bind_local(name, pos)
            }
          }
        }
    }
  }
  // A bare `*` separates positional from keyword-only parameters; it must be
  // followed by at least one such parameter (starlark-go resolve.go:905).
  if seen_star && star_is_bare && num_kwonly == 0 {
    self.errorf(star_pos, "bare * must be followed by keyword-only parameters")
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
    @syntax.Expr::ECall(f, args, call_pos) => {
      self.walk_expr(f)
      let mut seen_varargs = false
      let mut seen_kwargs = false
      let seen_names : Map[String, Bool] = {}
      let mut n_pos = 0
      let mut n_kw = 0
      for arg in args {
        match arg {
          @syntax.Arg::ArgKwArgs(e) => {
            if seen_kwargs {
              self.errorf(@syntax.expr_pos(e), "multiple **kwargs not allowed")
            }
            seen_kwargs = true
            self.walk_expr(e)
          }
          @syntax.Arg::ArgStarArgs(e) => {
            let pos = @syntax.expr_pos(e)
            if seen_kwargs {
              self.errorf(pos, "*args may not follow **kwargs")
            } else if seen_varargs {
              self.errorf(pos, "multiple *args not allowed")
            }
            seen_varargs = true
            self.walk_expr(e)
          }
          @syntax.Arg::ArgKw(name, e, kpos) => {
            n_kw = n_kw + 1
            if seen_kwargs {
              self.errorf(kpos, "keyword argument may not follow **kwargs")
            } else if seen_varargs {
              self.errorf(kpos, "keyword argument may not follow *args")
            }
            if seen_names.contains(name) {
              self.errorf(kpos, "keyword argument \"\{name}\" is repeated")
            } else {
              seen_names[name] = true
            }
            self.walk_expr(e)
          }
          @syntax.Arg::ArgPos(e) => {
            n_pos = n_pos + 1
            let pos = @syntax.expr_pos(e)
            if seen_varargs {
              self.errorf(pos, "positional argument may not follow *args")
            } else if seen_kwargs {
              self.errorf(pos, "positional argument may not follow **kwargs")
            } else if seen_names.length() > 0 {
              self.errorf(pos, "positional argument may not follow named")
            }
            self.walk_expr(e)
          }
        }
      }
      if n_pos >= 256 {
        self.errorf(
          call_pos,
          "\{n_pos} positional arguments in call, limit is 255",
        )
      }
      if n_kw >= 256 {
        self.errorf(call_pos, "\{n_kw} keyword arguments in call, limit is 255")
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
    @syntax.Expr::ESet(elems, pos) => {
      if !self.opts.allow_set {
        self.errorf(pos, "this Starlark dialect does not support sets")
      }
      for e in elems {
        self.walk_expr(e)
      }
    }
    @syntax.Expr::ELambda(params, body, pos) => {
      let saved = self.push_block()
      let old_fn = self.current_fn_name
      let old_in_func = self.in_func
      self.current_fn_name = "lambda"
      self.in_func = self.in_func + 1
      self.walk_params(params, pos)
      self.walk_expr(body)
      self.resolve_function_uses(self.env, "lambda")
      self.in_func = old_in_func
      self.current_fn_name = old_fn
      self.pop_block(saved)
    }
    @syntax.Expr::EListComp(body, clauses, _) =>
      self.walk_comprehension(body, None, clauses)
    @syntax.Expr::ESetComp(body, clauses, pos) => {
      if !self.opts.allow_set {
        self.errorf(pos, "this Starlark dialect does not support sets")
      }
      self.walk_comprehension(body, None, clauses)
    }
    @syntax.Expr::EDictComp(key, val, clauses, _) =>
      self.walk_comprehension(key, Some(val), clauses)
  }
}

// Walk a comprehension with an isolated scope for iteration variables.
// Per starlark-go resolve.go: the first clause's iterable is resolved in the
// outer scope; subsequent for-clause targets are bound BEFORE their iterables
// so that a variable used as its own iterable (e.g. `for x in x`) is flagged
// as "local variable x referenced before assignment".

///|
fn Resolver::walk_comprehension(
  self : Resolver,
  body : @syntax.Expr,
  body2 : @syntax.Expr?,
  clauses : Array[@syntax.CompClause],
) -> Unit {
  // First clause: walk iterable in the outer scope before pushing the comp block.
  match clauses[0] {
    @syntax.CompClause::ClauseFor(first_target, first_iter, _) => {
      self.walk_expr(first_iter)
      let saved = self.push_block()
      self.bind_lhs(first_target)
      for i in 1..<clauses.length() {
        match clauses[i] {
          @syntax.CompClause::ClauseFor(target, iter, _) => {
            self.bind_lhs(target)
            self.walk_expr(iter)
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
    _ => ()
  }
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
  r.walk_stmts(file.stmts())
  r.resolve_deferred_uses()
  { globals: r.module_globals, locals: r.module_locals, errors: r.errors }
}
