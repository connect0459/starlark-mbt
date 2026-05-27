///|
pub enum ReplOutput {
  Value(String)
  Empty
  EvalError(String)
}

///|
pub impl Show for ReplOutput with fn output(self, logger) {
  match self {
    Value(s) => logger.write_string("Value(\{s})")
    Empty => logger.write_string("Empty")
    EvalError(s) => logger.write_string("EvalError(\{s})")
  }
}

///|
pub fn eval_input(
  thread : @eval.Thread,
  globals : @value.StarlarkDict,
  input : String,
) -> ReplOutput {
  let file = match @parser.parse_file("<repl>", input) {
    Ok(f) => f
    Err(e) => return EvalError(e.to_string())
  }
  let stmts = file.stmts()
  if stmts.length() == 1 {
    match stmts[0] {
      @syntax.Stmt::SExpr(expr_node) => {
        ignore(expr_node)
        match @eval.eval_expr(thread, "<repl>", input, globals) {
          Ok(v) =>
            if v is @value.Value::None {
              Empty
            } else {
              let key = @value.Value::String(@value.StarlarkString::new("_"))
              globals.set(key, v) |> ignore
              Value(@value.repr(v))
            }
          Err(e) => EvalError(e.msg())
        }
      }
      _ =>
        match
          @eval.exec_repl_chunk(
            thread,
            "<repl>",
            input,
            globals,
            @eval.Options::default(),
          ) {
          Ok(_) => Empty
          Err(e) => EvalError(e.msg())
        }
    }
  } else {
    match
      @eval.exec_repl_chunk(
        thread,
        "<repl>",
        input,
        globals,
        @eval.Options::default(),
      ) {
      Ok(_) => Empty
      Err(e) => EvalError(e.msg())
    }
  }
}

///|
pub fn format_error(err : @errors.EvalError) -> String {
  err.msg()
}

///|
pub fn make_load(
  base_dir : String,
) -> (@eval.Thread, String) -> Result[@eval.Module, @errors.EvalError] {
  let cache : Map[String, Result[@eval.Module, @errors.EvalError]] = {}
  fn(_thread, load_path) {
    let resolved = if load_path.has_prefix("/") ||
      load_path.has_prefix("./") ||
      load_path.has_prefix("../") {
      load_path
    } else {
      base_dir + "/" + load_path
    }
    match cache.get(resolved) {
      Some(cached) => cached
      None => {
        cache[resolved] = Err(@errors.EvalError::simple("cycle in load graph"))
        let inner_dir = dir_of(resolved)
        let inner_thread = @eval.Thread::with_loader(
          "load:\{load_path}",
          make_load(inner_dir),
        )
        let result = load_file(inner_thread, resolved)
        cache[resolved] = result
        result
      }
    }
  }
}

///|
fn dir_of(path : String) -> String {
  match path.rev_find("/") {
    Some(i) => path[:i].to_owned()
    None => "."
  }
}

///|
pub fn run(thread : @eval.Thread, globals : @value.StarlarkDict) -> Unit {
  write_prompt(">>> ")
  while true {
    match read_line("") {
      None => break
      Some(raw) => {
        let trimmed = raw.trim_end().to_owned()
        if trimmed.is_empty() {
          write_prompt(">>> ")
          continue
        }
        match eval_input(thread, globals, trimmed) {
          Value(s) => println(s)
          Empty => ()
          EvalError(msg) => println(msg)
        }
        write_prompt(">>> ")
      }
    }
  }
}
