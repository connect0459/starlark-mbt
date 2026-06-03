// Whitebox tests for internal compiler invariants. These guards fire only on
// compiler-emitter bugs and are unreachable through the public `compile` API,
// so they are exercised directly against the internal helpers.

///|
test "panic write_uvarint rejects a negative operand" {
  let code : Array[Byte] = []
  write_uvarint(code, -1)
}

///|
fn empty_pcomp() -> Pcomp {
  {
    constants: [],
    names: [],
    name_index: {},
    functions: [],
    globals: [],
    global_index: {},
    loads: [],
    is_predeclared: fn(_) { false },
    is_universal: fn(_) { false },
  }
}

///|
test "panic operand-stack underflow aborts" {
  let fc = Fcomp::new(empty_pcomp(), "<test>", @errors.Position::new("t", 1, 1))
  fc.stack(1, 0)
}
