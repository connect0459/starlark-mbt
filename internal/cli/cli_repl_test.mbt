///|
/// On backends that do not ship an interactive REPL (every non-native target),
/// requesting the REPL must report the limitation and exit nonzero rather than
/// returning silently as if a session had run.
test "run_repl reports unavailability and exits nonzero on builds without a REPL" {
  match parse_cli_args(["starlark"]) {
    Ok((filepath, opts)) => {
      assert_true(filepath is None)
      assert_eq(run_repl(opts), 1)
    }
    Err(msg) => fail(msg)
  }
}
