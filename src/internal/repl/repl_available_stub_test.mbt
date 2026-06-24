///|
/// Backends without a stdin reader (wasm, wasm-gc, js) cannot host an
/// interactive REPL, so they advertise no REPL.
test "repl_available reports false on builds without a stdin reader" {
  assert_eq(repl_available(), false)
}
