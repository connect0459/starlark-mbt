///|
/// Native builds link in the isocline-backed reader, so they advertise an
/// interactive REPL.
test "repl_available reports true on native builds" {
  assert_eq(repl_available(), true)
}
