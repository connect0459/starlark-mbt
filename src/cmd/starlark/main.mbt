///|
#cfg(target="js")
fn cli_args() -> Array[String] {
  let args = @env.args()
  if args.is_empty() {
    []
  } else {
    args[1:].to_owned()
  }
}

///|
#cfg(not(target="js"))
fn cli_args() -> Array[String] {
  @env.args()
}

///|
fn main {
  let args = cli_args()
  match @cli.parse_cli_args(args) {
    Err(msg) => {
      println("starlark: \{msg}")
      @sys.exit(2)
    }
    Ok((filepath, expr, opts)) => {
      let exit_code = match (expr, filepath) {
        (Some(e), _) => @cli.run_expr(e, opts)
        (None, Some(fp)) => @cli.run_file(fp, opts)
        (None, None) => @cli.run_repl(opts)
      }
      if exit_code != 0 {
        @sys.exit(exit_code)
      }
    }
  }
}
