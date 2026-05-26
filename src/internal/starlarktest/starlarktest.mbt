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
fn floateq(xf : Double, yf : Double) -> Bool {
  if xf == yf {
    true
  } else if xf.is_nan() {
    yf.is_nan()
  } else if yf.is_nan() {
    false
  } else {
    let x = xf.reinterpret_as_int64()
    let y = yf.reinterpret_as_int64()
    x == y + 1L || y == x + 1L
  }
}

///|
fn assert_float_eq(x : @value.Value, y : @value.Value) -> Bool {
  let xf : Double? = match x {
    @value.Value::FloatVal(f) => Some(f)
    @value.Value::IntVal(n) => Some(n.to_double())
    _ => None
  }
  let yf : Double? = match y {
    @value.Value::FloatVal(f) => Some(f)
    @value.Value::IntVal(n) => Some(n.to_double())
    _ => None
  }
  match (xf, yf) {
    (Some(xf), Some(yf)) =>
      if x is @value.Value::FloatVal(_) || y is @value.Value::FloatVal(_) {
        floateq(xf, yf)
      } else {
        @value.starlark_equals(x, y)
      }
    _ => @value.starlark_equals(x, y)
  }
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
      if !assert_float_eq(x, y) {
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
        @value.Value::SetVal(s) =>
          match s.contains(item) {
            Ok(found) => found
            Err(_) => false
          }
        @value.Value::RangeVal(r) =>
          match item {
            @value.Value::IntVal(n) => r.contains(n)
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
fn pattern_unescape(pat : StringView) -> String {
  let buf = StringBuilder::new()
  let chars = pat.to_array()
  let mut i = 0
  while i < chars.length() {
    if chars[i] == '\\' && i + 1 < chars.length() {
      buf.write_char(chars[i + 1])
      i += 2
    } else {
      buf.write_char(chars[i])
      i += 1
    }
  }
  buf.to_string()
}

///|
fn pattern_matches(pattern : String, text : String) -> Bool {
  let anchor_end = pattern.has_suffix("$")
  let pat = if anchor_end {
    pattern[0:pattern.length() - 1].to_owned()
  } else {
    pattern
  }
  let parts : Array[StringView] = pat.split(".*").collect()
  if parts.length() == 1 {
    let s = pattern_unescape(parts[0])
    if anchor_end {
      text.has_suffix(s)
    } else {
      text.contains(s)
    }
  } else {
    let mut pos = 0
    for i in 0..<parts.length() {
      let part = pattern_unescape(parts[i])
      if part.is_empty() {
        continue
      }
      match text[pos:].find(part) {
        None => return false
        Some(idx) => pos = pos + idx + part.length()
      }
    }
    if anchor_end {
      pos == text.length()
    } else {
      true
    }
  }
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
          if !pattern_matches(pattern, msg) {
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
fn trim_start(s : String) -> String {
  let chars = s.iter().to_array()
  let mut i = 0
  while i < chars.length() {
    let c = chars[i]
    if c == ' ' || c == '\t' || c == '\r' || c == '\n' {
      i += 1
    } else {
      break
    }
  }
  s[i:].to_owned()
}

///|
fn unquote_double(s : String) -> String {
  let buf = StringBuilder::new()
  let chars = s.iter().to_array()
  let mut i = 0
  while i < chars.length() {
    if chars[i] == '\\' && i + 1 < chars.length() {
      match chars[i + 1] {
        '"' => buf.write_char('"')
        '\\' => buf.write_char('\\')
        'n' => buf.write_char('\n')
        't' => buf.write_char('\t')
        'r' => buf.write_char('\r')
        c => {
          buf.write_char('\\')
          buf.write_char(c)
        }
      }
      i += 2
    } else {
      buf.write_char(chars[i])
      i += 1
    }
  }
  buf.to_string()
}

///|
fn parse_hash_pattern(line : String) -> String? {
  match line.find("###") {
    None => None
    Some(hash_pos) => {
      let after = trim_start(line[hash_pos + 3:].to_owned())
      if after.length() >= 2 && after.iter().to_array()[0] == '"' {
        let inner = after[1:].to_owned()
        match inner.find("\"") {
          None => None
          Some(end_pos) => Some(unquote_double(inner[0:end_pos].to_owned()))
        }
      } else if after.length() >= 2 && after.iter().to_array()[0] == '`' {
        let inner = after[1:].to_owned()
        match inner.find("`") {
          None => None
          Some(end_pos) => Some(inner[0:end_pos].to_owned())
        }
      } else {
        None
      }
    }
  }
}

///|
fn split_chunks(src : String) -> Array[String] {
  let sep = "\n---\n"
  let result : Array[String] = []
  let mut rest = src
  while true {
    match rest.find(sep) {
      None => {
        result.push(rest)
        break
      }
      Some(idx) => {
        result.push(rest[0:idx].to_owned())
        rest = rest[idx + sep.length():].to_owned()
      }
    }
  }
  result
}

///|
fn exec_chunk_raw(
  src : String,
) -> Result[Array[String], (String, Array[String])] {
  let assert_errors : Array[String] = []
  let assert_module = build_assert_module(assert_errors)
  let loader : (@eval.Thread, String) -> Result[@eval.Module, @errors.EvalError] = fn(
    _thread,
    path,
  ) {
    if path == "assert.star" {
      let exports : Map[String, @value.Value] = {}
      exports["assert"] = assert_module
      exports["freeze"] = make_freeze_fn()
      Ok(@eval.Module::from_map(exports))
    } else if path == "json.star" {
      let exports : Map[String, @value.Value] = {}
      exports["json"] = @json.json_module()
      Ok(@eval.Module::from_map(exports))
    } else {
      Err(@errors.EvalError::simple("no loader for \"\{path}\""))
    }
  }
  let thread = @eval.Thread::with_loader("test", loader)
  match @eval.exec_file(thread, "<test>", src, @eval.Options::default()) {
    Ok(_) => Ok(assert_errors)
    Err(e) => Err((e.msg, assert_errors))
  }
}

///|
pub fn run_chunked_string(src : String) -> Array[String] {
  let failures : Array[String] = []
  let chunks = split_chunks(src)
  for chunk in chunks {
    let want_patterns : Array[String] = []
    for line in chunk.split("\n") {
      match parse_hash_pattern(line.to_owned()) {
        None => ()
        Some(p) => want_patterns.push(p)
      }
    }
    if want_patterns.is_empty() {
      match exec_chunk_raw(chunk) {
        Ok(assert_errs) =>
          for e in assert_errs {
            failures.push(e)
          }
        Err((msg, assert_errs)) => {
          failures.push("unexpected error: \{msg}")
          for e in assert_errs {
            failures.push(e)
          }
        }
      }
    } else {
      match exec_chunk_raw(chunk) {
        Ok(_) =>
          for p in want_patterns {
            failures.push(
              "expected error matching \"\{p}\" but none was raised",
            )
          }
        Err((msg, assert_errs)) => {
          let matched = want_patterns
            .iter()
            .any(fn(p) { pattern_matches(p, msg) })
          if !matched {
            let pat = want_patterns[0]
            failures.push("error \"\{msg}\" did not match pattern \"\{pat}\"")
          }
          for e in assert_errs {
            failures.push(e)
          }
        }
      }
    }
  }
  failures
}

///|
pub fn run_star_string(src : String) -> Array[String] {
  let errors : Array[String] = []
  let assert_module = build_assert_module(errors)
  let loader : (@eval.Thread, String) -> Result[@eval.Module, @errors.EvalError] = fn(
    _thread,
    path,
  ) {
    if path == "assert.star" {
      let exports : Map[String, @value.Value] = {}
      exports["assert"] = assert_module
      exports["freeze"] = make_freeze_fn()
      Ok(@eval.Module::from_map(exports))
    } else if path == "json.star" {
      let exports : Map[String, @value.Value] = {}
      exports["json"] = @json.json_module()
      Ok(@eval.Module::from_map(exports))
    } else {
      Err(@errors.EvalError::simple("no loader for \"\{path}\""))
    }
  }
  let thread = @eval.Thread::with_loader("test", loader)
  match @eval.exec_file(thread, "<test>", src, @eval.Options::default()) {
    Ok(_) => ()
    Err(e) => errors.push(e.msg)
  }
  errors
}
