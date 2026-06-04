///|
test "parse_cli_args returns the script path with recursion off by default" {
  match parse_cli_args(["starlark", "script.star"]) {
    Ok((filepath, opts)) => {
      assert_true(filepath is Some("script.star"))
      assert_eq(opts.allow_recursion(), false)
    }
    Err(msg) => fail(msg)
  }
}

///|
test "parse_cli_args enables recursion when --recursion is given" {
  match parse_cli_args(["starlark", "--recursion", "script.star"]) {
    Ok((filepath, opts)) => {
      assert_true(filepath is Some("script.star"))
      assert_eq(opts.allow_recursion(), true)
    }
    Err(msg) => fail(msg)
  }
}

///|
test "parse_cli_args accepts the flag after the script path" {
  match parse_cli_args(["starlark", "script.star", "--recursion"]) {
    Ok((filepath, opts)) => {
      assert_true(filepath is Some("script.star"))
      assert_eq(opts.allow_recursion(), true)
    }
    Err(msg) => fail(msg)
  }
}

///|
test "parse_cli_args accepts -recursion and the =value form" {
  match parse_cli_args(["starlark", "-recursion=false", "script.star"]) {
    Ok((_, opts)) => assert_eq(opts.allow_recursion(), false)
    Err(msg) => fail(msg)
  }
  match parse_cli_args(["starlark", "--recursion=true", "script.star"]) {
    Ok((_, opts)) => assert_eq(opts.allow_recursion(), true)
    Err(msg) => fail(msg)
  }
}

///|
test "parse_cli_args treats arguments after -- as positional" {
  match parse_cli_args(["starlark", "--", "--recursion"]) {
    Ok((filepath, opts)) => {
      assert_true(filepath is Some("--recursion"))
      assert_eq(opts.allow_recursion(), false)
    }
    Err(msg) => fail(msg)
  }
}

///|
test "parse_cli_args rejects an invalid boolean value" {
  assert_true(parse_cli_args(["starlark", "--recursion=maybe"]) is Err(_))
}

///|
test "parse_cli_args returns no path when only the program name is given" {
  match parse_cli_args(["starlark"]) {
    Ok((filepath, _)) => assert_true(filepath is None)
    Err(msg) => fail(msg)
  }
}
