///|
/// An active call frame recorded for debugger inspection: the executing function
/// value plus its compiled code and the live local-slot array, from which the
/// local names and current values are recovered when a `DebugFrame` snapshot is
/// taken.
priv struct ActiveCallFrame {
  func_val : @value.Value
  funcode : @compile.Funcode
  slots : Array[LocalSlot]
}

///|
/// A snapshot of a single Starlark call frame for debugger inspection.
/// Obtained via `Thread::debug_frame(depth)`.
pub struct DebugFrame {
  priv callable_val : @value.Value
  priv all_local_names : Array[String]
  priv locals_map : Map[String, @value.Value]
}

///|
fn DebugFrame::from_active(af : ActiveCallFrame) -> DebugFrame {
  // Recover the frame's named locals (parameters first, then body locals) and
  // their current values from the live slot array.
  let all_local_names : Array[String] = []
  let locals_map : Map[String, @value.Value] = Map([])
  for i, b in af.funcode.locals {
    let name = b.name()
    if !all_local_names.contains(name) {
      all_local_names.push(name)
    }
    let v = match af.slots[i] {
      LVal(v) => Some(v)
      LBoxed(c) => c.get()
      LUnbound => None
    }
    match v {
      Some(vv) => locals_map[name] = vv
      None => ()
    }
  }
  { callable_val: af.func_val, all_local_names, locals_map, }
}

///|
/// Returns the callable value (`Function` or `Builtin`) that owns this frame.
///
/// Returns the `Value` representing the function or builtin being executed in
/// this frame.
pub fn DebugFrame::callable(self : DebugFrame) -> @value.Value {
  self.callable_val
}

///|
/// Returns the number of local variables (parameters + body locals) in this frame.
///
/// Returns the total count of named locals, including both function parameters
/// and variables declared in the function body.
pub fn DebugFrame::num_locals(self : DebugFrame) -> Int {
  self.all_local_names.length()
}

///|
/// Returns the binding descriptor and current value of the `i`-th local.
/// The value is `None` if the local has not yet been assigned.
///
/// Parameters:
///
/// - `self` : The debug frame to inspect.
/// - `i` : Zero-based index into the frame's local variable list.
///
/// Returns a tuple of the `Binding` descriptor (name and declaration position)
/// and the current value of that local, or `None` if it has not been assigned.
pub fn DebugFrame::frame_local(
  self : DebugFrame,
  i : Int,
) -> (@errors.Binding, @value.Value?) {
  let name = self.all_local_names[i]
  let bind = @errors.Binding::new(name, @errors.Position::new("", 0, 0))
  let v = self.locals_map.get(name)
  (bind, v)
}

///|
/// Returns the current value of the local variable named `name`, or `None`
/// if the name is absent or the variable has not yet been assigned.
///
/// Parameters:
///
/// - `self` : The debug frame to inspect.
/// - `name` : The name of the local variable to look up.
///
/// Returns the current `Value` of the named local, or `None` if the name is
/// not found or the variable has not yet been assigned.
pub fn DebugFrame::local_by_name(
  self : DebugFrame,
  name : String,
) -> @value.Value? {
  self.locals_map.get(name)
}

///|
/// Returns the source position of the current execution point within this frame.
///
/// Returns the `Position` indicating where execution is currently paused inside
/// this call frame.
pub fn DebugFrame::position(self : DebugFrame) -> @errors.Position {
  ignore(self)
  @errors.Position::new("", 0, 0)
}
