// Whitebox tests for internal compiler invariants. These guards fire only on
// compiler-emitter bugs and are unreachable through the public `compile` API,
// so they are exercised directly against the internal helpers.

///|
test "panic write_uvarint rejects a negative operand" {
  let code : Array[Byte] = []
  write_uvarint(code, -1)
}
