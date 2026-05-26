///|
fn make_error_fn(errors : Array[String]) -> @value.Value {
  @value.Value::BuiltinFuncVal({
    name: "error",
    body: Some(fn(_call_ctx, pos_args, _kw_args) {
      if pos_args.length() != 1 {
        return Err("error: got \{pos_args.length()} arguments, want 1")
      }
      errors.push(@value.to_str(pos_args[0]))
      Ok(@value.Value::NoneVal)
    }),
  })
}

///|
fn make_eq_fn(errors : Array[String]) -> @value.Value {
  @value.Value::BuiltinFuncVal({
    name: "assert.eq",
    body: Some(fn(_call_ctx, pos_args, _kw_args) {
      if pos_args.length() != 2 {
        return Err("assert.eq: got \{pos_args.length()} arguments, want 2")
      }
      let x = pos_args[0]
      let y = pos_args[1]
      if !@value.starlark_equals(x, y) {
        errors.push("\{@value.repr(x)} != \{@value.repr(y)}")
      }
      Ok(@value.Value::NoneVal)
    }),
  })
}

///|
fn make_ne_fn(errors : Array[String]) -> @value.Value {
  @value.Value::BuiltinFuncVal({
    name: "assert.ne",
    body: Some(fn(_call_ctx, pos_args, _kw_args) {
      if pos_args.length() != 2 {
        return Err("assert.ne: got \{pos_args.length()} arguments, want 2")
      }
      let x = pos_args[0]
      let y = pos_args[1]
      if @value.starlark_equals(x, y) {
        errors.push("\{@value.repr(x)} == \{@value.repr(y)}")
      }
      Ok(@value.Value::NoneVal)
    }),
  })
}

///|
fn make_true_fn(errors : Array[String]) -> @value.Value {
  @value.Value::BuiltinFuncVal({
    name: "assert.true",
    body: Some(fn(_call_ctx, pos_args, kw_args) {
      let cond = if pos_args.is_empty() {
        return Err("assert.true: got 0 arguments, want at least 1")
      } else {
        pos_args[0]
      }
      let msg = {
        let mut found = "assertion failed"
        for kv in kw_args {
          if kv.0 == "msg" {
            found = @value.to_str(kv.1)
            break
          }
        }
        if pos_args.length() >= 2 {
          found = @value.to_str(pos_args[1])
        }
        found
      }
      if !@value.truth(cond) {
        errors.push(msg)
      }
      Ok(@value.Value::NoneVal)
    }),
  })
}

///|
fn make_lt_fn(errors : Array[String]) -> @value.Value {
  @value.Value::BuiltinFuncVal({
    name: "assert.lt",
    body: Some(fn(_call_ctx, pos_args, _kw_args) {
      if pos_args.length() != 2 {
        return Err("assert.lt: got \{pos_args.length()} arguments, want 2")
      }
      let x = pos_args[0]
      let y = pos_args[1]
      match @value.compare_values(x, y) {
        Ok(ord) =>
          if ord >= 0 {
            errors.push(
              "\{@value.to_str(x)} is not less than \{@value.to_str(y)}",
            )
          }
        Err(msg) => return Err(msg)
      }
      Ok(@value.Value::NoneVal)
    }),
  })
}

///|
fn make_contains_fn(errors : Array[String]) -> @value.Value {
  @value.Value::BuiltinFuncVal({
    name: "assert.contains",
    body: Some(fn(_call_ctx, pos_args, _kw_args) {
      if pos_args.length() != 2 {
        return Err(
          "assert.contains: got \{pos_args.length()} arguments, want 2",
        )
      }
      let container = pos_args[0]
      let item = pos_args[1]
      let found = match container {
        @value.Value::ListVal(l) =>
          l.items.iter().any(fn(v) { @value.starlark_equals(v, item) })
        @value.Value::TupleVal(t) =>
          t.iter().any(fn(v) { @value.starlark_equals(v, item) })
        @value.Value::StrVal(s) =>
          match item {
            @value.Value::StrVal(n) => s.raw.contains(n.raw)
            _ => return Err("'in <string>' requires string as left operand")
          }
        @value.Value::DictVal(d) =>
          match d.get(item) {
            Ok(Some(_)) => true
            _ => false
          }
        _ =>
          return Err(
            "argument of type '\{@value.type_name(container)}' is not iterable",
          )
      }
      if !found {
        errors.push(
          "\{@value.to_str(container)} does not contain \{@value.to_str(item)}",
        )
      }
      Ok(@value.Value::NoneVal)
    }),
  })
}

///|
fn make_fails_fn(errors : Array[String]) -> @value.Value {
  @value.Value::BuiltinFuncVal({
    name: "assert.fails",
    body: Some(fn(call_ctx, pos_args, _kw_args) {
      if pos_args.length() != 2 {
        return Err("assert.fails: got \{pos_args.length()} arguments, want 2")
      }
      let f = pos_args[0]
      let pattern = match pos_args[1] {
        @value.Value::StrVal(s) => s.raw
        _ => return Err("assert.fails: pattern must be a string")
      }
      match
        (call_ctx.call)(
          f,
          ([] : Array[@value.Value]),
          ([] : Array[(String, @value.Value)]),
        ) {
        Ok(_) =>
          errors.push(
            "evaluation succeeded unexpectedly (want error matching \"\{pattern}\")",
          )
        Err(msg) =>
          if !msg.contains(pattern) {
            errors.push("pattern \"\{pattern}\" did not match error \"\{msg}\"")
          }
      }
      Ok(@value.Value::NoneVal)
    }),
  })
}

///|
fn make_freeze_fn() -> @value.Value {
  @value.Value::BuiltinFuncVal({
    name: "freeze",
    body: Some(fn(_call_ctx, pos_args, _kw_args) {
      if pos_args.length() != 1 {
        return Err("freeze: got \{pos_args.length()} arguments, want 1")
      }
      let v = pos_args[0]
      @value.freeze_value(v)
      Ok(v)
    }),
  })
}

///|
fn build_assert_module(errors : Array[String]) -> @value.Value {
  let attrs : Map[String, @value.Value] = {}
  attrs["fail"] = make_error_fn(errors)
  attrs["eq"] = make_eq_fn(errors)
  attrs["ne"] = make_ne_fn(errors)
  attrs["true"] = make_true_fn(errors)
  attrs["lt"] = make_lt_fn(errors)
  attrs["contains"] = make_contains_fn(errors)
  attrs["fails"] = make_fails_fn(errors)
  @value.Value::ModuleVal(@value.StarlarkModule::new("assert", attrs))
}

///|
pub fn run_star_string(src : String) -> Array[String] {
  let errors : Array[String] = []
  let assert_module = build_assert_module(errors)
  let loader : (String) -> Result[Map[String, @value.Value], String] = fn(
    path,
  ) {
    if path == "assert.star" {
      let exports : Map[String, @value.Value] = {}
      exports["assert"] = assert_module
      exports["freeze"] = make_freeze_fn()
      Ok(exports)
    } else {
      Err("no loader for \"\{path}\"")
    }
  }
  let thread = @eval.Thread::with_loader("test", loader)
  match @eval.exec_file(thread, "<test>", src, @eval.Options::default()) {
    Ok(_) => ()
    Err(e) => errors.push(e.msg)
  }
  errors
}
