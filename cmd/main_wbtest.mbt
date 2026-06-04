///|
test "parse_cli_args returns the script path with recursion off by default" {
  let (filepath, opts) = parse_cli_args(["starlark", "script.star"])
  assert_true(filepath is Some("script.star"))
  assert_eq(opts.allow_recursion(), false)
}

///|
test "parse_cli_args enables recursion when --recursion is given" {
  let (filepath, opts) = parse_cli_args([
    "starlark", "--recursion", "script.star",
  ])
  assert_true(filepath is Some("script.star"))
  assert_eq(opts.allow_recursion(), true)
}

///|
test "parse_cli_args accepts the flag after the script path" {
  let (filepath, opts) = parse_cli_args([
    "starlark", "script.star", "--recursion",
  ])
  assert_true(filepath is Some("script.star"))
  assert_eq(opts.allow_recursion(), true)
}

///|
test "parse_cli_args returns no path when only the program name is given" {
  let (filepath, _) = parse_cli_args(["starlark"])
  assert_true(filepath is None)
}
