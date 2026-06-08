///|
fn main {
  let args = @sys.get_cli_args()
  match @cli.parse_cli_args(args) {
    Err(msg) => {
      println("starlark: \{msg}")
      @sys.exit(2)
    }
    Ok((filepath, opts)) =>
      match filepath {
        None => @cli.run_repl(opts)
        Some(fp) => {
          let exit_code = @cli.run_file(fp, opts)
          if exit_code != 0 {
            @sys.exit(exit_code)
          }
        }
      }
  }
}
