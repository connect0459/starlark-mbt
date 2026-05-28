///|
priv struct ActiveCallFrame {
  func_val : @value.Value
  all_local_names : Array[String]
  locals_map : Map[String, @value.Value]
}

///|
fn collect_all_local_names(
  f : @value.StarlarkFunction,
  body_locals : Array[String],
) -> Array[String] {
  let all : Array[String] = []
  for i in 0..<f.num_params() {
    let (name, _) = f.param(i)
    if !all.contains(name) {
      all.push(name)
    }
  }
  for name in body_locals {
    if !all.contains(name) {
      all.push(name)
    }
  }
  all
}

///|
pub struct DebugFrame {
  priv callable_val : @value.Value
  priv all_local_names : Array[String]
  priv locals_map : Map[String, @value.Value]
}

///|
fn DebugFrame::from_active(af : ActiveCallFrame) -> DebugFrame {
  {
    callable_val: af.func_val,
    all_local_names: af.all_local_names,
    locals_map: af.locals_map,
  }
}

///|
pub fn DebugFrame::callable(self : DebugFrame) -> @value.Value {
  self.callable_val
}

///|
pub fn DebugFrame::num_locals(self : DebugFrame) -> Int {
  self.all_local_names.length()
}

///|
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
pub fn DebugFrame::local_by_name(
  self : DebugFrame,
  name : String,
) -> @value.Value? {
  self.locals_map.get(name)
}

///|
pub fn DebugFrame::position(self : DebugFrame) -> @errors.Position {
  ignore(self)
  @errors.Position::new("", 0, 0)
}
