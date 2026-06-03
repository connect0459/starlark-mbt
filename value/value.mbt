///|
/// An immutable Starlark string backed by a pre-computed UTF-8 `Bytes` array.
/// All length, indexing, and hashing operations use the byte array so that
/// `s[i]` returns the i-th byte, matching starlark-go semantics.
pub struct StarlarkString {
  priv raw : String
  priv bytes : Bytes
}

///|
/// Creates a `StarlarkString` from a MoonBit `String`, encoding it to UTF-8.
///
/// Parameters:
///
/// - `raw` : The MoonBit `String` to encode.
///
/// Returns a new `StarlarkString` backed by the UTF-8 encoding of `raw`.
pub fn StarlarkString::new(raw : String) -> StarlarkString {
  let bytes = @utf8.encode(raw)
  { raw, bytes }
}

///|
/// Creates a `StarlarkString` from a raw UTF-8 byte sequence. Invalid bytes
/// are replaced with U+FFFD.
///
/// Parameters:
///
/// - `bytes` : The raw UTF-8 byte sequence to wrap.
///
/// Returns a new `StarlarkString` decoded from `bytes`, replacing any invalid
/// sequences with U+FFFD.
pub fn StarlarkString::from_bytes(bytes : Bytes) -> StarlarkString {
  let raw = @utf8.decode_lossy(bytes[:])
  { raw, bytes }
}

///|
/// Returns the number of UTF-8 bytes in the string (the Starlark `len()`).
///
/// Returns the byte length of the underlying UTF-8 encoding.
pub fn StarlarkString::byte_len(self : StarlarkString) -> Int {
  self.bytes.length()
}

///|
/// Returns the byte at UTF-8 offset `i`.
///
/// Parameters:
///
/// - `self` : The string to index into.
/// - `i` : The zero-based UTF-8 byte offset.
///
/// Returns the byte value at offset `i`.
pub fn StarlarkString::byte_at(self : StarlarkString, i : Int) -> Byte {
  self.bytes[i]
}

///|
/// Returns `true` if `self` and `other` contain the same bytes.
///
/// Parameters:
///
/// - `self` : The first string to compare.
/// - `other` : The second string to compare.
///
/// Returns `true` if both strings have identical UTF-8 byte content.
pub fn StarlarkString::equals(
  self : StarlarkString,
  other : StarlarkString,
) -> Bool {
  self.bytes == other.bytes
}

///|
/// Returns the underlying UTF-8 `Bytes` array.
///
/// Returns the pre-computed UTF-8 `Bytes` backing this string.
pub fn StarlarkString::to_bytes(self : StarlarkString) -> Bytes {
  self.bytes
}

///|
/// Returns the MoonBit `String` (UTF-16 internally) that was used to create
/// this `StarlarkString`.
///
/// Returns the original MoonBit `String` value.
pub fn StarlarkString::raw(self : StarlarkString) -> String {
  self.raw
}

///|
/// A mutable, ordered sequence of Starlark values. Mutation is rejected when
/// the list is frozen or has active iterators.
pub struct StarlarkList {
  priv mut items : Array[Value]
  priv mut frozen : Bool
  priv mut itercount : Int
}

///|
/// Creates a new, unfrozen `StarlarkList` wrapping `items`.
///
/// Parameters:
///
/// - `items` : The initial array of `Value` elements.
///
/// Returns a new mutable `StarlarkList` containing `items`.
pub fn StarlarkList::new(items : Array[Value]) -> StarlarkList {
  { items, frozen: false, itercount: 0 }
}

///|
/// Returns `true` if the list has been frozen.
///
/// Returns `true` when the list is immutable; `false` otherwise.
pub fn StarlarkList::is_frozen(self : StarlarkList) -> Bool {
  self.frozen
}

///|
/// Marks the list as frozen; subsequent mutation attempts raise an error.
pub fn StarlarkList::freeze(self : StarlarkList) -> Unit {
  self.frozen = true
}

///|
/// Returns `Ok(())` if the list can be mutated, otherwise `Err` with a
/// descriptive message using `verb` (e.g. `"append to"`, `"clear"`).
///
/// Parameters:
///
/// - `self` : The list to check.
/// - `verb` : A short phrase describing the attempted operation, used in the
///   error message (e.g. `"append to"`, `"clear"`).
///
/// Returns `Ok(())` if mutation is allowed, or `Err` with a descriptive
/// message if the list is frozen or has active iterators.
#internal(unsafe, "eval engine only; not part of the public embedding API")
pub fn StarlarkList::check_mutable(
  self : StarlarkList,
  verb : String,
) -> Result[Unit, String] {
  if self.frozen {
    Err("cannot \{verb} frozen list")
  } else if self.itercount > 0 {
    Err("cannot \{verb} list during iteration")
  } else {
    Ok(())
  }
}

///|
/// Returns the number of elements in the list.
///
/// Returns the element count.
pub fn StarlarkList::length(self : StarlarkList) -> Int {
  self.items.length()
}

///|
/// Returns `true` if the list contains no elements.
///
/// Returns `true` when the list has zero elements.
pub fn StarlarkList::is_empty(self : StarlarkList) -> Bool {
  self.items.is_empty()
}

///|
/// Returns the element at index `i` (unchecked).
///
/// Parameters:
///
/// - `self` : The list to index into.
/// - `i` : The zero-based index of the element to retrieve.
///
/// Returns `Some(value)` at index `i`, or `None` if `i` is out of bounds.
/// Mirrors `Array::get`; use `list[i]` for direct (aborting) indexed access.
pub fn StarlarkList::get(self : StarlarkList, i : Int) -> Value? {
  self.items.get(i)
}

///|
/// Returns the `Value` at index `i`, aborting if `i` is out of bounds.
/// Mirrors `Array`'s indexed access; use `get` for a bounds-checked option.
pub fn StarlarkList::op_get(self : StarlarkList, i : Int) -> Value {
  self.items[i]
}

///|
/// Returns a lazy iterator over the list elements.
///
/// Returns an `Iter[Value]` that yields each element in order.
pub fn StarlarkList::iter(self : StarlarkList) -> Iter[Value] {
  self.items.iter()
}

///|
/// Calls `f(value)` for each element in order.
///
/// Parameters:
///
/// - `self` : The list to iterate over.
/// - `f` : A callback receiving each element value.
pub fn StarlarkList::each(self : StarlarkList, f : (Value) -> Unit) -> Unit {
  self.items.each(f)
}

///|
/// Calls `f(index, value)` for each element.
///
/// Parameters:
///
/// - `self` : The list to iterate over.
/// - `f` : A callback receiving the zero-based index and the element value.
pub fn StarlarkList::eachi(
  self : StarlarkList,
  f : (Int, Value) -> Unit,
) -> Unit {
  self.items.eachi(f)
}

///|
fn StarlarkList::is_same_storage(
  self : StarlarkList,
  other : StarlarkList,
) -> Bool {
  physical_equal(self.items, other.items)
}

///|
/// Returns a copy of the underlying items array.
///
/// Returns a shallow copy of the internal `Array[Value]`.
pub fn StarlarkList::copy_items(self : StarlarkList) -> Array[Value] {
  self.items.copy()
}

///|
/// Appends `v` to the end of the list. Fails if the list is frozen or being
/// iterated.
///
/// Parameters:
///
/// - `self` : The list to append to.
/// - `v` : The value to append.
///
/// Returns `Ok(())` on success, or `Err` if the list is frozen or being
/// iterated.
pub fn StarlarkList::push(
  self : StarlarkList,
  v : Value,
) -> Result[Unit, String] {
  match self.check_mutable("append to") {
    Err(e) => Err(e)
    Ok(_) => {
      self.items.push(v)
      Ok(())
    }
  }
}

///|
/// Removes and returns the last element, or `None` if the list is empty.
/// Fails if the list is frozen or being iterated.
///
/// Returns `Ok(Some(v))` with the removed element, `Ok(None)` if the list
/// was empty, or `Err` if the list is frozen or being iterated.
pub fn StarlarkList::pop(self : StarlarkList) -> Result[Value?, String] {
  match self.check_mutable("pop from") {
    Err(e) => Err(e)
    Ok(_) => Ok(self.items.pop())
  }
}

///|
/// Removes and returns the element at index `i`. Fails if the list is frozen
/// or being iterated.
///
/// Parameters:
///
/// - `self` : The list to remove from.
/// - `i` : The zero-based index of the element to remove.
/// - `verb` : Verb used in the error message (e.g. `"pop from"`, `"remove from"`).
///
/// Returns `Ok(v)` with the removed element, or `Err` if the list is frozen
/// or being iterated.
#internal(unsafe, "eval engine only; not part of the public embedding API")
pub fn StarlarkList::pop_at(
  self : StarlarkList,
  i : Int,
  verb : String,
) -> Result[Value, String] {
  match self.check_mutable(verb) {
    Err(e) => Err(e)
    Ok(_) => Ok(self.items.remove(i))
  }
}

///|
/// Inserts `v` at index `i`, shifting subsequent elements right. Fails if
/// the list is frozen or being iterated.
///
/// Parameters:
///
/// - `self` : The list to insert into.
/// - `i` : The zero-based index at which to insert.
/// - `v` : The value to insert.
///
/// Returns `Ok(())` on success, or `Err` if the list is frozen or being
/// iterated.
pub fn StarlarkList::insert(
  self : StarlarkList,
  i : Int,
  v : Value,
) -> Result[Unit, String] {
  match self.check_mutable("insert into") {
    Err(e) => Err(e)
    Ok(_) => {
      self.items.insert(i, v)
      Ok(())
    }
  }
}

///|
/// Replaces the element at index `i` with `v`. Fails if the list is frozen
/// or being iterated.
///
/// Parameters:
///
/// - `self` : The list to update.
/// - `i` : The zero-based index of the element to replace.
/// - `v` : The new value to store at index `i`.
///
/// Returns `Ok(())` on success, or `Err` if the list is frozen or being
/// iterated.
pub fn StarlarkList::set(
  self : StarlarkList,
  i : Int,
  v : Value,
) -> Result[Unit, String] {
  match self.check_mutable("assign to element of") {
    Err(e) => Err(e)
    Ok(_) => {
      self.items[i] = v
      Ok(())
    }
  }
}

///|
/// Removes all elements. Fails if the list is frozen or being iterated.
///
/// Returns `Ok(())` on success, or `Err` if the list is frozen or being
/// iterated.
pub fn StarlarkList::clear(self : StarlarkList) -> Result[Unit, String] {
  match self.check_mutable("clear") {
    Err(e) => Err(e)
    Ok(_) => {
      self.items.clear()
      Ok(())
    }
  }
}

///|
/// Sorts the list in place using `cmp`. Fails if the list is frozen or being
/// iterated.
///
/// Parameters:
///
/// - `self` : The list to sort.
/// - `cmp` : A comparator returning a negative int, zero, or positive int.
///
/// Returns `Ok(())` on success, or `Err` if the list is frozen or being
/// iterated.
pub fn StarlarkList::sort_by(
  self : StarlarkList,
  cmp : (Value, Value) -> Int,
) -> Result[Unit, String] {
  match self.check_mutable("sort") {
    Err(e) => Err(e)
    Ok(_) => {
      self.items.sort_by(cmp)
      Ok(())
    }
  }
}

///|
/// Reverses the list in place. Fails if the list is frozen or being iterated.
///
/// Returns `Ok(())` on success, or `Err` if the list is frozen or being
/// iterated.
pub fn StarlarkList::reverse(self : StarlarkList) -> Result[Unit, String] {
  match self.check_mutable("reverse") {
    Err(e) => Err(e)
    Ok(_) => {
      let n = self.items.length()
      let mut i = 0
      while i < n / 2 {
        let tmp = self.items[i]
        self.items[i] = self.items[n - 1 - i]
        self.items[n - 1 - i] = tmp
        i += 1
      }
      Ok(())
    }
  }
}

///|
/// A lazy, immutable arithmetic sequence returned by `range()`. Not a list;
/// supports membership testing and indexing without materialising all elements.
pub struct StarlarkRange {
  priv start : Int64
  priv stop : Int64
  priv step : Int64
}

///|
/// Creates a `StarlarkRange` with the given start, stop, and step.
///
/// Parameters:
///
/// - `start` : The first value of the range (inclusive).
/// - `stop` : The exclusive upper (or lower) bound of the range.
/// - `step` : The increment between consecutive values; must not be zero.
///
/// Returns a new `StarlarkRange` representing the arithmetic sequence.
pub fn StarlarkRange::new(
  start : Int64,
  stop : Int64,
  step : Int64,
) -> StarlarkRange {
  { start, stop, step }
}

///|
/// Returns the start of the range.
///
/// Returns the inclusive start value of the range.
pub fn StarlarkRange::start(self : StarlarkRange) -> Int64 {
  self.start
}

///|
/// Returns the stop (exclusive end) of the range.
///
/// Returns the exclusive stop value of the range.
pub fn StarlarkRange::stop(self : StarlarkRange) -> Int64 {
  self.stop
}

///|
/// Returns the step of the range.
///
/// Returns the increment between consecutive elements.
pub fn StarlarkRange::step(self : StarlarkRange) -> Int64 {
  self.step
}

///|
/// Returns the number of elements in the range.
///
/// Returns the count of integers produced by iterating the range.
pub fn StarlarkRange::length(self : StarlarkRange) -> Int {
  if self.step > 0L {
    if self.stop > self.start {
      return ((self.stop - self.start - 1L) / self.step + 1L).to_int()
    }
  } else if self.step < 0L {
    if self.start > self.stop {
      return ((self.start - self.stop - 1L) / -self.step + 1L).to_int()
    }
  }
  0
}

///|
/// Returns the value at position `i` within the range.
///
/// Parameters:
///
/// - `self` : The range to index into.
/// - `i` : The zero-based position within the range.
///
/// Returns the arithmetic value at position `i` (i.e. `start + step * i`).
pub fn StarlarkRange::index_at(self : StarlarkRange, i : Int) -> Int64 {
  self.start + self.step * i.to_int64()
}

///|
/// Returns `true` if `n` is a member of the range.
///
/// Parameters:
///
/// - `self` : The range to test membership against.
/// - `n` : The integer value to look up.
///
/// Returns `true` if `n` lies within the range bounds and aligns to the step.
pub fn StarlarkRange::contains(self : StarlarkRange, n : Int64) -> Bool {
  if self.step > 0L {
    n >= self.start && n < self.stop && (n - self.start) % self.step == 0L
  } else if self.step < 0L {
    n <= self.start && n > self.stop && (n - self.start) % self.step == 0L
  } else {
    false
  }
}

///|
pub struct StarlarkFunction {
  priv name : String
  priv params : Array[@syntax.Param]
  priv body : Array[@syntax.Stmt]
  priv defaults : Array[Value?]
  priv captured_scope : Array[(Map[String, Value], Array[String])]
  priv pos : @errors.Position
  priv module_globals : Map[String, Value]?
  // Compiled code for the bytecode VM. `None` for functions built by the AST
  // walker (which interprets `body`/`params` directly). During the dual-engine
  // migration (issue #1) the VM builds functions via `from_compiled`, which sets
  // this; the AST fields then go away once the walker is removed.
  priv funcode : @compile.Funcode?
  // Captured cells for a compiled closure, one per `funcode.freevars` entry.
  // Empty for AST functions (which capture via `captured_scope`) and for
  // compiled functions that close over nothing.
  priv vm_freevars : Array[Cell]
  // The compiled module this function belongs to: its program and its live
  // module-global slots. A compiled function resolves its constants, globals,
  // nested functions, and predeclared names against this module — never the
  // caller's — matching starlark-go (`fn.module`). `None`/empty for AST
  // functions.
  priv module_prog : @compile.CompiledProgram?
  priv module_slots : Array[Value?]
}

///|
/// Creates a new `StarlarkFunction` from its constituent parts.
///
/// Parameters:
///
/// - `name` : The function's declared name.
/// - `params` : The parsed parameter list.
/// - `body` : The list of statements forming the function body.
/// - `defaults` : Default values aligned to the parameter list (`None` for
///   parameters without a default).
/// - `captured_scope` : The closure scope as a list of
///   `(bindings, insertion-order-keys)` pairs.
/// - `pos` : Source position of the `def` statement.
///
/// Returns a new `StarlarkFunction` with no module-globals binding.
#internal(unsafe, "eval engine only; not part of the public embedding API")
pub fn StarlarkFunction::new(
  name : String,
  params : Array[@syntax.Param],
  body : Array[@syntax.Stmt],
  defaults : Array[Value?],
  captured_scope : Array[(Map[String, Value], Array[String])],
  pos : @errors.Position,
) -> StarlarkFunction {
  {
    name,
    params,
    body,
    defaults,
    captured_scope,
    pos,
    module_globals: None,
    funcode: None,
    vm_freevars: [],
    module_prog: None,
    module_slots: [],
  }
}

///|
/// Creates a `StarlarkFunction` backed by compiled bytecode rather than an AST.
/// Used by the bytecode VM during the dual-engine migration (issue #1); the AST
/// fields are left empty because the VM executes `funcode` directly.
///
/// Parameters:
///
/// - `name` : The function's declared name.
/// - `funcode` : The compiled code for this function.
/// - `prog` : The compiled program (module) this function belongs to.
/// - `slots` : The module's live global slots, shared so the function resolves
///   its module globals (and forward references) against its own module.
/// - `defaults` : Default values aligned to the optional parameters.
/// - `freevars` : Captured cells, one per `funcode.freevars` entry.
#internal(unsafe, "bytecode VM only; not part of the public embedding API")
pub fn StarlarkFunction::from_compiled(
  name : String,
  funcode : @compile.Funcode,
  prog : @compile.CompiledProgram,
  slots : Array[Value?],
  defaults : Array[Value?],
  freevars : Array[Cell],
) -> StarlarkFunction {
  {
    name,
    params: [],
    body: [],
    defaults,
    captured_scope: [],
    pos: funcode.pos,
    module_globals: None,
    funcode: Some(funcode),
    vm_freevars: freevars,
    module_prog: Some(prog),
    module_slots: slots,
  }
}

///|
/// Returns the compiled program (module) this function belongs to, or `None` for
/// an AST function. The VM runs the function's funcode against this program so
/// constants, globals, and nested functions resolve correctly across modules.
#internal(unsafe, "bytecode VM only; not part of the public embedding API")
pub fn StarlarkFunction::compiled_module_prog(
  self : StarlarkFunction,
) -> @compile.CompiledProgram? {
  self.module_prog
}

///|
/// Returns the function's module-global slots (shared with its defining module).
#internal(unsafe, "bytecode VM only; not part of the public embedding API")
pub fn StarlarkFunction::compiled_module_slots(
  self : StarlarkFunction,
) -> Array[Value?] {
  self.module_slots
}

///|
/// Returns the captured cells of a compiled closure (one per `funcode.freevars`
/// entry). Empty for AST functions. Used by the VM to set up a call frame.
#internal(unsafe, "bytecode VM only; not part of the public embedding API")
pub fn StarlarkFunction::compiled_freevars(
  self : StarlarkFunction,
) -> Array[Cell] {
  self.vm_freevars
}

///|
/// Returns the compiled code backing this function, or `None` if it is an
/// AST-interpreted function. Used by the VM to run a called function.
#internal(unsafe, "bytecode VM only; not part of the public embedding API")
pub fn StarlarkFunction::compiled_funcode(
  self : StarlarkFunction,
) -> @compile.Funcode? {
  self.funcode
}

///|
/// Returns the declared name of the function.
///
/// Returns the function's name string.
pub fn StarlarkFunction::name(self : StarlarkFunction) -> String {
  self.name
}

///|
/// Returns the source position of the function's `def` statement.
///
/// Returns the `@errors.Position` where this function was defined.
pub fn StarlarkFunction::position(self : StarlarkFunction) -> @errors.Position {
  self.pos
}

///|
/// Returns the parsed parameter list of the function.
///
/// Returns an array of `@syntax.Param` values describing each parameter.
#internal(unsafe, "eval engine only; not part of the public embedding API")
pub fn StarlarkFunction::params(
  self : StarlarkFunction,
) -> Array[@syntax.Param] {
  self.params
}

///|
/// Returns the list of statements forming the function body.
///
/// Returns the function body as an array of `@syntax.Stmt`.
#internal(unsafe, "eval engine only; not part of the public embedding API")
pub fn StarlarkFunction::body(self : StarlarkFunction) -> Array[@syntax.Stmt] {
  self.body
}

///|
/// Returns the default value array aligned to the parameter list.
///
/// Returns an array of `Value?`, where `None` indicates no default for that
/// parameter position.
pub fn StarlarkFunction::defaults(self : StarlarkFunction) -> Array[Value?] {
  self.defaults
}

///|
/// Returns the captured closure scope of the function.
///
/// Returns the list of `(bindings, insertion-order-keys)` pairs representing
/// all enclosing scopes captured at definition time.
#internal(unsafe, "eval engine only; not part of the public embedding API")
pub fn StarlarkFunction::captured_scope(
  self : StarlarkFunction,
) -> Array[(Map[String, Value], Array[String])] {
  self.captured_scope
}

///|
/// Returns a copy of the function with module-level globals bound to `g`.
///
/// Parameters:
///
/// - `self` : The function to update.
/// - `g` : The module-level globals map to associate with this function.
///
/// Returns a new `StarlarkFunction` identical to `self` but with
/// `module_globals` set to `Some(g)`.
#internal(unsafe, "eval engine only; not part of the public embedding API")
pub fn StarlarkFunction::with_module_globals(
  self : StarlarkFunction,
  g : Map[String, Value],
) -> StarlarkFunction {
  { ..self, module_globals: Some(g) }
}

///|
/// Returns the module-level globals map, or an empty map if none is bound.
///
/// Returns the associated `Map[String, Value]`, or `{}` when no module
/// globals have been set.
#internal(unsafe, "eval engine only; not part of the public embedding API")
pub fn StarlarkFunction::globals(self : StarlarkFunction) -> Map[String, Value] {
  match self.module_prog {
    // Compiled function: build the name->value map from the module's global
    // bindings and their current slot values.
    Some(prog) => {
      let m : Map[String, Value] = {}
      for i, b in prog.globals {
        if i < self.module_slots.length() {
          match self.module_slots[i] {
            Some(v) => m[b.name()] = v
            None => ()
          }
        }
      }
      m
    }
    None =>
      match self.module_globals {
        Some(g) => g
        None => {}
      }
  }
}

///|
/// Returns the module that defined this function, if module globals are bound.
///
/// Returns `Some(module)` when module globals have been associated via
/// `with_module_globals`, or `None` otherwise.
pub fn StarlarkFunction::defining_module(
  self : StarlarkFunction,
) -> StarlarkModule? {
  match self.module_prog {
    Some(_) => Some(StarlarkModule::new(self.pos.filename(), self.globals()))
    None =>
      match self.module_globals {
        None => None
        Some(globals) => Some(StarlarkModule::new(self.pos.filename(), globals))
      }
  }
}

///|
/// Returns the docstring of the function, or an empty string if absent.
///
/// Returns the string literal from the first statement of the body when it
/// is a bare string expression; otherwise `""`.
pub fn StarlarkFunction::doc(self : StarlarkFunction) -> String {
  match self.funcode {
    Some(fc) => fc.doc
    None =>
      match self.body {
        [
          @syntax.Stmt::SExpr(
            @syntax.Expr::ELiteral(@syntax.LiteralVal::LitString(s), _)
          ),
          ..,
        ] => s
        _ => ""
      }
  }
}

///|
/// Returns `true` if the function accepts a variadic positional parameter (`*args`).
///
/// Returns `true` when any parameter is `ParamStarIdent`.
pub fn StarlarkFunction::has_varargs(self : StarlarkFunction) -> Bool {
  match self.funcode {
    Some(fc) => return fc.has_varargs
    None => ()
  }
  for p in self.params {
    if p is @syntax.Param::ParamStarIdent(_, _) {
      return true
    }
  }
  false
}

///|
/// Returns `true` if the function accepts a variadic keyword parameter (`**kwargs`).
///
/// Returns `true` when any parameter is `ParamKwIdent`.
pub fn StarlarkFunction::has_kwargs(self : StarlarkFunction) -> Bool {
  match self.funcode {
    Some(fc) => return fc.has_kwargs
    None => ()
  }
  for p in self.params {
    if p is @syntax.Param::ParamKwIdent(_, _) {
      return true
    }
  }
  false
}

///|
/// Returns the number of named parameters (excludes bare `*` separators).
///
/// Returns the count of parameters that bind to a name (positional, default,
/// `*args`, and `**kwargs`), excluding bare `ParamStarBare` separators.
pub fn StarlarkFunction::num_params(self : StarlarkFunction) -> Int {
  match self.funcode {
    Some(fc) => return fc.num_params
    None => ()
  }
  let mut count = 0
  for p in self.params {
    match p {
      @syntax.Param::ParamStarBare(_) => ()
      _ => count = count + 1
    }
  }
  count
}

///|
/// Returns the number of keyword-only parameters (those appearing after `*`).
///
/// Returns the count of `ParamIdent` and `ParamDefault` parameters that
/// follow a `ParamStarBare` or `ParamStarIdent` separator.
pub fn StarlarkFunction::num_kwonly_params(self : StarlarkFunction) -> Int {
  match self.funcode {
    Some(fc) => return fc.num_kwonly_params
    None => ()
  }
  let mut after_star = false
  let mut count = 0
  for p in self.params {
    match p {
      @syntax.Param::ParamStarBare(_) | @syntax.Param::ParamStarIdent(_, _) =>
        after_star = true
      @syntax.Param::ParamKwIdent(_, _) => ()
      @syntax.Param::ParamIdent(_, _) | @syntax.Param::ParamDefault(_, _, _) =>
        if after_star {
          count = count + 1
        }
    }
  }
  count
}

///|
/// Returns the name and source position of the `i`-th named parameter.
///
/// Parameters:
///
/// - `self` : The function to query.
/// - `i` : The zero-based index among named parameters (same count as
///   `num_params`).
///
/// Returns a `(name, position)` tuple. Aborts if `i` is out of range.
pub fn StarlarkFunction::param(
  self : StarlarkFunction,
  i : Int,
) -> (String, @errors.Position) {
  match self.funcode {
    // Named parameters occupy the first `num_params` local slots, in order.
    Some(fc) =>
      if i >= 0 && i < fc.num_params {
        let b = fc.locals[i]
        return (b.name(), b.pos())
      } else {
        abort("StarlarkFunction::param: index \{i} out of range")
      }
    None => ()
  }
  let mut idx = 0
  for p in self.params {
    match p {
      @syntax.Param::ParamStarBare(_) => ()
      @syntax.Param::ParamIdent(name, pos) => {
        if idx == i {
          return (name, pos)
        }
        idx = idx + 1
      }
      @syntax.Param::ParamDefault(name, _, pos) => {
        if idx == i {
          return (name, pos)
        }
        idx = idx + 1
      }
      @syntax.Param::ParamStarIdent(name, pos) => {
        if idx == i {
          return (name, pos)
        }
        idx = idx + 1
      }
      @syntax.Param::ParamKwIdent(name, pos) => {
        if idx == i {
          return (name, pos)
        }
        idx = idx + 1
      }
    }
  }
  abort("StarlarkFunction::param: index \{i} out of range")
}

///|
/// Returns the default value for parameter at position `i`, or `None`.
///
/// Parameters:
///
/// - `self` : The function to query.
/// - `i` : The zero-based parameter index into the defaults array.
///
/// Returns `Some(v)` if a default exists at position `i`, or `None` if `i`
/// is out of range or the parameter has no default.
pub fn StarlarkFunction::param_default(
  self : StarlarkFunction,
  i : Int,
) -> Value? {
  if i < 0 || i >= self.defaults.length() {
    return None
  }
  self.defaults[i]
}

///|
/// Returns the total number of captured free variables across all closure scopes.
///
/// Returns the sum of binding counts across all captured-scope layers.
pub fn StarlarkFunction::num_free_vars(self : StarlarkFunction) -> Int {
  match self.funcode {
    Some(fc) => return fc.freevars.length()
    None => ()
  }
  let mut total = 0
  for scope in self.captured_scope {
    total = total + scope.0.length()
  }
  total
}

///|
/// Returns the `i`-th captured free variable as a `(name, value)` pair.
///
/// Parameters:
///
/// - `self` : The function to query.
/// - `i` : The zero-based index across all captured-scope layers.
///
/// Returns `Some((name, value))` if index `i` exists, or `None` if out of range.
pub fn StarlarkFunction::free_var(
  self : StarlarkFunction,
  i : Int,
) -> (String, Value)? {
  match self.funcode {
    // Free variables parallel `funcode.freevars`; the captured value lives in
    // the corresponding closure cell (`None` if the cell is still unbound).
    Some(fc) =>
      if i >= 0 && i < fc.freevars.length() {
        let name = fc.freevars[i].name()
        let v = match self.vm_freevars[i].get() {
          Some(v) => v
          None => Value::None
        }
        return Some((name, v))
      } else {
        return None
      }
    None => ()
  }
  let mut idx = 0
  let mut result : (String, Value)? = None
  for scope in self.captured_scope {
    scope.0.each(fn(name, v) {
      if idx == i && result is None {
        result = Some((name, v))
      }
      idx = idx + 1
    })
    if result is Some(_) {
      break
    }
  }
  result
}

///|
pub struct BuiltinCallCtx {
  priv call : (Value, Array[Value], Array[(String, Value)]) -> Result[
    Value,
    String,
  ]
  priv get_local_fn : (String) -> Value?
}

///|
/// Creates a `BuiltinCallCtx` with the given call dispatcher and optional
/// thread-local lookup function.
///
/// Parameters:
///
/// - `call` : The function used to invoke a Starlark callable; receives the
///   callee, positional args, and keyword args.
/// - `get_local` : An optional function to read per-thread overrides by key
///   (defaults to always returning `None`).
///
/// Returns a new `BuiltinCallCtx`.
#internal(unsafe, "eval engine only; not part of the public embedding API")
pub fn BuiltinCallCtx::new(
  call : (Value, Array[Value], Array[(String, Value)]) -> Result[Value, String],
  get_local? : (String) -> Value? = fn(_) { None },
) -> BuiltinCallCtx {
  { call, get_local_fn: get_local }
}

///|
/// Reads the active thread's thread-local value for `key`. Used by extension
/// builtins (e.g. `time.now`) that honor an embedder-provided per-thread override.
///
/// Parameters:
///
/// - `self` : The call context.
/// - `key` : The key to look up in the per-thread override store.
///
/// Returns `Some(v)` if the embedder has set a value for `key`, or `None`.
pub fn BuiltinCallCtx::get_local(self : BuiltinCallCtx, key : String) -> Value? {
  (self.get_local_fn)(key)
}

///|
/// Invokes a Starlark callable through this context's call dispatcher.
///
/// Parameters:
///
/// - `self` : The call context.
/// - `callee` : The Starlark value to call.
/// - `args` : Positional arguments.
/// - `kwargs` : Keyword arguments as `(name, value)` pairs.
///
/// Returns `Ok(result)` on success, or `Err` with an error message.
pub fn BuiltinCallCtx::invoke(
  self : BuiltinCallCtx,
  callee : Value,
  args : Array[Value],
  kwargs : Array[(String, Value)],
) -> Result[Value, String] {
  (self.call)(callee, args, kwargs)
}

///|
pub struct StarlarkBuiltinFunc {
  priv name : String
  priv body : ((BuiltinCallCtx, Array[Value], Array[(String, Value)]) -> Result[
    Value,
    String,
  ])?
  priv recv : Value?
}

///|
/// Creates a dispatch-only `StarlarkBuiltinFunc` with the given name and no
/// inline body. Calls are handled externally by pattern-matching on the name.
///
/// Parameters:
///
/// - `name` : The name to associate with this builtin function.
///
/// Returns a `StarlarkBuiltinFunc` with `body` set to `None`.
#internal(unsafe, "eval engine only; not part of the public embedding API")
pub fn StarlarkBuiltinFunc::dispatch(name : String) -> StarlarkBuiltinFunc {
  { name, body: None, recv: None }
}

///|
/// Returns the name of the builtin function.
///
/// Returns the function's name string.
pub fn StarlarkBuiltinFunc::name(self : StarlarkBuiltinFunc) -> String {
  self.name
}

///|
/// Returns the bound receiver of this builtin, or `None` if unbound.
///
/// Returns `Some(recv)` when the builtin was created via `bind_receiver`,
/// or `None` for a free function.
pub fn StarlarkBuiltinFunc::receiver(self : StarlarkBuiltinFunc) -> Value? {
  self.recv
}

///|
/// Returns a copy of this builtin with `recv` bound as its receiver.
///
/// Parameters:
///
/// - `self` : The builtin function to bind.
/// - `recv` : The receiver value to bind (typically the owning object).
///
/// Returns a new `StarlarkBuiltinFunc` with `recv` set.
pub fn StarlarkBuiltinFunc::bind_receiver(
  self : StarlarkBuiltinFunc,
  recv : Value,
) -> StarlarkBuiltinFunc {
  { ..self, recv: Some(recv) }
}

///|
/// Calls the inline body of this builtin, if one was provided.
///
/// Parameters:
///
/// - `self` : The builtin function to call.
/// - `ctx` : The call context providing the call dispatcher and thread-local
///   lookup.
/// - `pos_args` : Positional arguments.
/// - `kw_args` : Keyword arguments as `(name, value)` pairs.
///
/// Returns `Some(Ok(v))` or `Some(Err(msg))` when a body is present, or
/// `None` for dispatch-only builtins.
pub fn StarlarkBuiltinFunc::call_body(
  self : StarlarkBuiltinFunc,
  ctx : BuiltinCallCtx,
  pos_args : Array[Value],
  kw_args : Array[(String, Value)],
) -> Result[Value, String]? {
  match self.body {
    None => None
    Some(f) => Some(f(ctx, pos_args, kw_args))
  }
}

///|
let bound_method_id_counter : Ref[Int] = { val: 0 }

///|
pub struct StarlarkBoundMethod {
  priv recv : Value
  priv method_name : String
  priv id : Int
}

///|
/// Creates a new `StarlarkBoundMethod` binding `method_name` to `recv`,
/// assigning a globally unique identity id.
///
/// Parameters:
///
/// - `recv` : The receiver value that the method is bound to.
/// - `method_name` : The name of the method.
///
/// Returns a new `StarlarkBoundMethod` with a unique `id`.
pub fn StarlarkBoundMethod::new(
  recv : Value,
  method_name : String,
) -> StarlarkBoundMethod {
  let id = bound_method_id_counter.val
  bound_method_id_counter.val += 1
  { recv, method_name, id }
}

///|
/// Returns the receiver value this method is bound to.
///
/// Returns the `Value` that was passed as `recv` when this bound method was
/// created.
pub fn StarlarkBoundMethod::recv(self : StarlarkBoundMethod) -> Value {
  self.recv
}

///|
/// Returns the name of the method this object is bound to.
///
/// Returns the method name string.
pub fn StarlarkBoundMethod::method_name(self : StarlarkBoundMethod) -> String {
  self.method_name
}

///|
pub struct StarlarkModule {
  priv name : String
  priv attrs : Map[String, Value]
}

///|
/// Creates a new `StarlarkModule` with the given name and attribute map.
///
/// Parameters:
///
/// - `name` : The module's name (typically its filename or import path).
/// - `attrs` : The module-level exported bindings.
///
/// Returns a new `StarlarkModule`.
pub fn StarlarkModule::new(
  name : String,
  attrs : Map[String, Value],
) -> StarlarkModule {
  { name, attrs }
}

///|
/// Returns the name of the module.
///
/// Returns the module's name string.
pub fn StarlarkModule::name(self : StarlarkModule) -> String {
  self.name
}

///|
/// Looks up an attribute by name in the module.
///
/// Parameters:
///
/// - `self` : The module to query.
/// - `key` : The attribute name to look up.
///
/// Returns `Some(v)` if the attribute exists, or `None`.
pub fn StarlarkModule::get(self : StarlarkModule, key : String) -> Value? {
  self.attrs.get(key)
}

///|
/// Returns the list of all attribute names exported by the module.
///
/// Returns an array of attribute name strings.
pub fn StarlarkModule::attr_names(self : StarlarkModule) -> Array[String] {
  self.attrs.keys().collect()
}

///|
pub struct StarlarkStringElems {
  priv s : StarlarkString
  priv ords : Bool
}

///|
/// Creates a `StarlarkStringElems` view over a string.
///
/// Parameters:
///
/// - `s` : The source string to iterate over.
/// - `ords` : When `true`, the iterator yields integer byte values; when
///   `false`, it yields single-byte `StarlarkString` values.
///
/// Returns a new `StarlarkStringElems`.
pub fn StarlarkStringElems::new(
  s : StarlarkString,
  ords : Bool,
) -> StarlarkStringElems {
  { s, ords }
}

///|
/// Returns the source string this view was created from.
///
/// Returns the underlying `StarlarkString`.
pub fn StarlarkStringElems::source_string(
  self : StarlarkStringElems,
) -> StarlarkString {
  self.s
}

///|
/// Returns `true` if this view yields integer byte ordinals rather than
/// single-byte strings.
///
/// Returns the `ords` flag set at construction time.
pub fn StarlarkStringElems::is_ords(self : StarlarkStringElems) -> Bool {
  self.ords
}

///|
pub struct StarlarkStringCodepoints {
  priv s : StarlarkString
  priv ords : Bool
}

///|
/// Creates a `StarlarkStringCodepoints` view over a string.
///
/// Parameters:
///
/// - `s` : The source string to iterate over.
/// - `ords` : When `true`, the iterator yields integer codepoint values;
///   when `false`, it yields single-codepoint `StarlarkString` values.
///
/// Returns a new `StarlarkStringCodepoints`.
pub fn StarlarkStringCodepoints::new(
  s : StarlarkString,
  ords : Bool,
) -> StarlarkStringCodepoints {
  { s, ords }
}

///|
/// Returns the source string this codepoints view was created from.
///
/// Returns the underlying `StarlarkString`.
pub fn StarlarkStringCodepoints::source_string(
  self : StarlarkStringCodepoints,
) -> StarlarkString {
  self.s
}

///|
/// Returns `true` if this view yields integer codepoint ordinals rather than
/// single-codepoint strings.
///
/// Returns the `ords` flag set at construction time.
pub fn StarlarkStringCodepoints::is_ords(
  self : StarlarkStringCodepoints,
) -> Bool {
  self.ords
}

///|
pub struct StarlarkBytesElems {
  priv b : Bytes
}

///|
/// Creates a `StarlarkBytesElems` view over a raw byte sequence.
///
/// Parameters:
///
/// - `b` : The raw bytes to iterate over.
///
/// Returns a new `StarlarkBytesElems` wrapping `b`.
pub fn StarlarkBytesElems::new(b : Bytes) -> StarlarkBytesElems {
  { b, }
}

///|
/// Returns the raw bytes backing this view.
///
/// Returns the underlying `Bytes` array.
pub fn StarlarkBytesElems::raw_bytes(self : StarlarkBytesElems) -> Bytes {
  self.b
}

///|
/// The Starlark value sum type. Covers all built-in types plus embedder
/// extensions via `ExtVal`.
pub(all) enum Value {
  None
  Bool(Bool)
  Int(BigInt)
  Float(Double)
  String(StarlarkString)
  Bytes(Bytes)
  List(StarlarkList)
  Tuple(Array[Value])
  Dict(StarlarkDict)
  Set(StarlarkSet)
  Range(StarlarkRange)
  Function(StarlarkFunction)
  Builtin(StarlarkBuiltinFunc)
  BoundMethod(StarlarkBoundMethod)
  Module(StarlarkModule)
  StringElems(StarlarkStringElems)
  StringCodepoints(StarlarkStringCodepoints)
  BytesElems(StarlarkBytesElems)
  ExtVal(CustomValue)
}

///|
/// Creates a `Value::String` from a MoonBit `String`.
///
/// Parameters:
///
/// - `s` : The MoonBit `String` to wrap.
///
/// Returns a `Value::String` backed by a new `StarlarkString`.
pub fn Value::new_string(s : String) -> Value {
  String(StarlarkString::new(s))
}

///|
/// Creates a `Value::Int` from an `Int64`.
///
/// Parameters:
///
/// - `n` : The 64-bit signed integer to wrap.
///
/// Returns a `Value::Int` containing `n` as an arbitrary-precision integer.
pub fn Value::new_int(n : Int64) -> Value {
  Int(BigInt::from_int64(n))
}

///|
/// Creates a `Value::Float` from a `Double`.
///
/// Parameters:
///
/// - `f` : The double-precision float to wrap.
///
/// Returns a `Value::Float` containing `f`.
pub fn Value::new_float(f : Double) -> Value {
  Float(f)
}

///|
/// Creates a `Value::List` wrapping a new `StarlarkList`.
///
/// Parameters:
///
/// - `items` : The initial array of `Value` elements.
///
/// Returns a `Value::List` containing `items`.
pub fn Value::new_list(items : Array[Value]) -> Value {
  List(StarlarkList::new(items))
}

///|
/// Creates an empty `Value::Dict`.
///
/// Returns a new empty `Value::Dict`.
pub fn Value::new_dict() -> Value {
  Dict(StarlarkDict::new())
}

///|
/// Creates an empty `Value::Set`.
///
/// Returns a new empty `Value::Set`.
pub fn Value::new_set() -> Value {
  Set(StarlarkSet::new())
}

///|
/// Creates a `Value::Builtin` with the given name and callable body.
///
/// Parameters:
///
/// - `name` : The name of the builtin function.
/// - `body` : The implementation closure receiving the call context, positional
///   args, and keyword args.
///
/// Returns a `Value::Builtin` that dispatches through `body`.
pub fn Value::new_builtin(
  name : String,
  body : (BuiltinCallCtx, Array[Value], Array[(String, Value)]) -> Result[
    Value,
    String,
  ],
) -> Value {
  Builtin({ name, body: Some(body), recv: None })
}

///|
/// Returns the Starlark `type()` string for `v` (e.g. `"int"`, `"list"`).
///
/// Parameters:
///
/// - `v` : The value whose type name to retrieve.
///
/// Returns the Starlark type name string.
pub fn Value::type_name(v : Value) -> String {
  match v {
    None => "NoneType"
    Bool(_) => "bool"
    Int(_) => "int"
    Float(_) => "float"
    String(_) => "string"
    Bytes(_) => "bytes"
    List(_) => "list"
    Tuple(_) => "tuple"
    Dict(_) => "dict"
    Set(_) => "set"
    Range(_) => "range"
    Function(_) => "function"
    Builtin(_) => "builtin_function_or_method"
    BoundMethod(_) => "builtin_function_or_method"
    Module(_) => "module"
    StringElems(_) => "string.elems"
    StringCodepoints(_) => "string.codepoints"
    BytesElems(_) => "bytes.elems"
    ExtVal(c) => c.get_type_name()
  }
}

///|
/// Returns the Starlark truth value of `v` (equivalent to `bool(v)`).
///
/// Parameters:
///
/// - `v` : The value to evaluate.
///
/// Returns `false` for `None`, `False`, zero numbers, empty strings/bytes/
/// collections, and zero-length ranges; `true` for everything else.
pub fn Value::truth(v : Value) -> Bool {
  match v {
    None => false
    Bool(b) => b
    Int(i) => !i.is_zero()
    Float(f) => f != 0.0
    String(s) => s.byte_len() > 0
    Bytes(b) => b.length() > 0
    List(l) => l.items.is_empty() == false
    Tuple(t) => t.is_empty() == false
    Dict(d) => d.length() > 0
    Set(s) => s.length() > 0
    Range(r) => r.length() > 0
    Function(_) => true
    Builtin(_) => true
    BoundMethod(_) => true
    Module(_) => true
    StringElems(_) | StringCodepoints(_) | BytesElems(_) => true
    ExtVal(c) => c.get_truth()
  }
}

// ASCII byte boundaries used in repr output (matching starlark-go's quote.go).

///|
// First printable ASCII byte (U+0020 SPACE), inclusive lower bound.
let ascii_space : Int = 0x20

///|
// DEL byte (0x7F); not printable — emitted as \x7f in repr, not verbatim.
let ascii_del : Int = 0x7F

///|
// First byte of a UTF-8 multi-byte sequence (U+0080 and above).
let utf8_multibyte_lo : Int = 0x80

///|
fn write_unicode_escape(r : Int, buf : StringBuilder) -> Unit {
  if r < 0x10000 {
    buf.write_string("\\u")
    @utf8util.write_hex4(buf, r)
  } else {
    buf.write_string("\\U")
    @utf8util.write_hex8(buf, r)
  }
}

///|
fn repr_bytes_inner(b : Bytes, buf : StringBuilder, quote_char : Char) -> Unit {
  let len = b.length()
  let mut i = 0
  while i < len {
    let byte_val = b[i].to_int()
    match byte_val {
      0x5C => {
        buf.write_string("\\\\")
        i += 1
      }
      0x0A => {
        buf.write_string("\\n")
        i += 1
      }
      0x0D => {
        buf.write_string("\\r")
        i += 1
      }
      0x09 => {
        buf.write_string("\\t")
        i += 1
      }
      0x07 => {
        buf.write_string("\\a")
        i += 1
      }
      0x08 => {
        buf.write_string("\\b")
        i += 1
      }
      0x0C => {
        buf.write_string("\\f")
        i += 1
      }
      0x0B => {
        buf.write_string("\\v")
        i += 1
      }
      n =>
        if n.unsafe_to_char() == quote_char {
          buf.write_char('\\')
          buf.write_char(quote_char)
          i += 1
        } else if n >= ascii_space && n < ascii_del {
          buf.write_char(n.unsafe_to_char())
          i += 1
        } else if n >= utf8_multibyte_lo {
          let (r, width) = @utf8util.utf8_decode_rune(b, i)
          if r >= 0 && @utf8util.is_unicode_printable(r) {
            buf.write_char(r.unsafe_to_char())
            i += width
          } else if r >= 0 {
            write_unicode_escape(r, buf)
            i += width
          } else {
            buf.write_string("\\x")
            @utf8util.write_hex2(buf, n)
            i += 1
          }
        } else {
          buf.write_string("\\x")
          @utf8util.write_hex2(buf, n)
          i += 1
        }
    }
  }
}

///|
fn repr_string_val(s : StarlarkString) -> String {
  let buf = StringBuilder::new()
  buf.write_char('"')
  repr_bytes_inner(s.bytes, buf, '"')
  buf.write_char('"')
  buf.to_string()
}

///|
fn repr_bytes_val(b : Bytes) -> String {
  let buf = StringBuilder::new()
  buf.write_string("b\"")
  repr_bytes_inner(b, buf, '"')
  buf.write_char('"')
  buf.to_string()
}

///|
/// Returns the Starlark `repr(v)` string. Detects cyclic list/dict references
/// and replaces them with `[...]` / `{...}`.
///
/// Parameters:
///
/// - `v` : The value to represent.
///
/// Returns the Starlark `repr()` string for `v`.
pub fn Value::repr(v : Value) -> String {
  repr_inner(v, [], [])
}

///|
fn repr_inner(
  v : Value,
  seen_lists : Array[StarlarkList],
  seen_dicts : Array[StarlarkDict],
) -> String {
  match v {
    None => "None"
    Bool(true) => "True"
    Bool(false) => "False"
    Int(i) => i.to_string()
    Float(f) => @numeric.format_float(f)
    String(s) => repr_string_val(s)
    Bytes(b) => repr_bytes_val(b)
    List(l) => repr_list_inner(l, seen_lists, seen_dicts)
    Tuple(t) => repr_tuple_inner(t, seen_lists, seen_dicts)
    Dict(d) => repr_dict_inner(d, seen_lists, seen_dicts)
    Set(s) => repr_set_inner(s, seen_lists, seen_dicts)
    Range(r) => repr_range(r)
    Function(f) => "<function \{f.name}>"
    Builtin(f) => "<built-in function \{f.name}>"
    BoundMethod(m) =>
      "<built-in method \{m.method_name} of \{m.recv.type_name()} value>"
    Module(m) => "<module \"\{m.name}\">"
    StringElems(e) => {
      let suffix = if e.ords { "elem_ords()" } else { "elems()" }
      repr_string_val(e.s) + "." + suffix
    }
    StringCodepoints(c) => {
      let suffix = if c.ords { "codepoint_ords()" } else { "codepoints()" }
      repr_string_val(c.s) + "." + suffix
    }
    BytesElems(e) => repr_bytes_val(e.b) + ".elems()"
    ExtVal(c) => c.get_repr()
  }
}

///|
fn repr_range(r : StarlarkRange) -> String {
  if r.step == 1L {
    if r.start == 0L {
      "range(\{r.stop})"
    } else {
      "range(\{r.start}, \{r.stop})"
    }
  } else {
    "range(\{r.start}, \{r.stop}, \{r.step})"
  }
}

///|
fn repr_dict_inner(
  d : StarlarkDict,
  seen_lists : Array[StarlarkList],
  seen_dicts : Array[StarlarkDict],
) -> String {
  if seen_dicts.iter().any(fn(sd) { d.is_same_storage(sd) }) {
    return "{...}"
  }
  if d.length() == 0 {
    return "{}"
  }
  seen_dicts.push(d)
  let buf = StringBuilder::new()
  buf.write_char('{')
  let mut first = true
  d.each(fn(k, v) {
    if first == false {
      buf.write_string(", ")
    }
    first = false
    buf.write_string(repr_inner(k, seen_lists, seen_dicts))
    buf.write_string(": ")
    buf.write_string(repr_inner(v, seen_lists, seen_dicts))
  })
  buf.write_char('}')
  let _ = seen_dicts.pop()
  buf.to_string()
}

///|
fn repr_set_inner(
  s : StarlarkSet,
  seen_lists : Array[StarlarkList],
  seen_dicts : Array[StarlarkDict],
) -> String {
  let buf = StringBuilder::new()
  buf.write_string("set([")
  let mut first = true
  s.each(fn(k) {
    if first == false {
      buf.write_string(", ")
    }
    first = false
    buf.write_string(repr_inner(k, seen_lists, seen_dicts))
  })
  buf.write_string("])")
  buf.to_string()
}

///|
fn repr_list_inner(
  l : StarlarkList,
  seen_lists : Array[StarlarkList],
  seen_dicts : Array[StarlarkDict],
) -> String {
  if seen_lists.iter().any(fn(sl) { l.is_same_storage(sl) }) {
    return "[...]"
  }
  seen_lists.push(l)
  let buf = StringBuilder::new()
  buf.write_char('[')
  for i in 0..<l.items.length() {
    if i > 0 {
      buf.write_string(", ")
    }
    buf.write_string(repr_inner(l.items[i], seen_lists, seen_dicts))
  }
  buf.write_char(']')
  let _ = seen_lists.pop()
  buf.to_string()
}

///|
fn repr_tuple_inner(
  t : Array[Value],
  seen_lists : Array[StarlarkList],
  seen_dicts : Array[StarlarkDict],
) -> String {
  repr_tuple_with(t, fn(v) { repr_inner(v, seen_lists, seen_dicts) })
}

///|
fn repr_tuple(t : Array[Value]) -> String {
  repr_tuple_with(t, fn(v) { v.repr() })
}

///|
fn repr_tuple_with(t : Array[Value], f : (Value) -> String) -> String {
  let buf = StringBuilder::new()
  buf.write_char('(')
  for i in 0..<t.length() {
    if i > 0 {
      buf.write_string(", ")
    }
    buf.write_string(f(t[i]))
  }
  if t.length() == 1 {
    buf.write_char(',')
  }
  buf.write_char(')')
  buf.to_string()
}
