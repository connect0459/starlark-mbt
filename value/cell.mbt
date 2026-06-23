///|
/// A mutable box shared between a closure and the function that defines the
/// captured variable.
///
/// A local variable captured by a nested function is promoted to a `Cell`:
/// the defining frame and every capturing closure hold the same instance,
/// so assignments are visible across all of them. `None` means the variable
/// has not been assigned yet.
pub struct Cell {
  priv mut v : Value?
}

///|
/// Creates an empty (unassigned) cell.
#internal(unsafe, "closure machinery; not part of the public embedding API")
pub fn Cell::new() -> Cell {
  { v: None }
}

///|
/// Returns the cell's current value, or `None` if it has not been assigned.
#internal(unsafe, "closure machinery; not part of the public embedding API")
pub fn Cell::get(self : Cell) -> Value? {
  self.v
}

///|
/// Stores `value` into the cell.
#internal(unsafe, "closure machinery; not part of the public embedding API")
pub fn Cell::set(self : Cell, value : Value) -> Unit {
  self.v = Some(value)
}
