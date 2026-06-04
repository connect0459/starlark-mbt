///|
fn make_error_fn(errors : Array[String]) -> @value.Value {
  @value.Value::new_builtin("error", fn(_call_ctx, pos_args, _kw_args) {
    if pos_args.length() != 1 {
      return Err("error: got \{pos_args.length()} arguments, want 1")
    }
    errors.push(pos_args[0].to_str())
    Ok(@value.Value::None)
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
    @value.Value::Float(f) => Some(f)
    @value.Value::Int(n) => Some(@numeric.bigint_to_double(n))
    _ => None
  }
  let yf : Double? = match y {
    @value.Value::Float(f) => Some(f)
    @value.Value::Int(n) => Some(@numeric.bigint_to_double(n))
    _ => None
  }
  match (xf, yf) {
    (Some(xf), Some(yf)) =>
      if x is @value.Value::Float(_) || y is @value.Value::Float(_) {
        floateq(xf, yf)
      } else {
        x.starlark_equals(y)
      }
    _ => x.starlark_equals(y)
  }
}

///|
fn make_eq_fn(errors : Array[String]) -> @value.Value {
  @value.Value::new_builtin("assert.eq", fn(_call_ctx, pos_args, _kw_args) {
    if pos_args.length() != 2 {
      return Err("assert.eq: got \{pos_args.length()} arguments, want 2")
    }
    let x = pos_args[0]
    let y = pos_args[1]
    if !assert_float_eq(x, y) {
      errors.push("\{x.repr()} != \{y.repr()}")
    }
    Ok(@value.Value::None)
  })
}

///|
fn make_ne_fn(errors : Array[String]) -> @value.Value {
  @value.Value::new_builtin("assert.ne", fn(_call_ctx, pos_args, _kw_args) {
    if pos_args.length() != 2 {
      return Err("assert.ne: got \{pos_args.length()} arguments, want 2")
    }
    let x = pos_args[0]
    let y = pos_args[1]
    if x.starlark_equals(y) {
      errors.push("\{x.repr()} == \{y.repr()}")
    }
    Ok(@value.Value::None)
  })
}

///|
fn make_true_fn(errors : Array[String]) -> @value.Value {
  @value.Value::new_builtin("assert.true", fn(_call_ctx, pos_args, kw_args) {
    let cond = if pos_args.is_empty() {
      return Err("assert.true: got 0 arguments, want at least 1")
    } else {
      pos_args[0]
    }
    let msg = {
      let mut found = "assertion failed"
      for kv in kw_args {
        if kv.0 == "msg" {
          found = kv.1.to_str()
          break
        }
      }
      if pos_args.length() >= 2 {
        found = pos_args[1].to_str()
      }
      found
    }
    if !cond.truth() {
      errors.push(msg)
    }
    Ok(@value.Value::None)
  })
}

///|
fn make_lt_fn(errors : Array[String]) -> @value.Value {
  @value.Value::new_builtin("assert.lt", fn(_call_ctx, pos_args, _kw_args) {
    if pos_args.length() != 2 {
      return Err("assert.lt: got \{pos_args.length()} arguments, want 2")
    }
    let x = pos_args[0]
    let y = pos_args[1]
    match @value.compare_values(x, y) {
      Ok(ord) =>
        if ord >= 0 {
          errors.push("\{x.to_str()} is not less than \{y.to_str()}")
        }
      Err(msg) => return Err(msg)
    }
    Ok(@value.Value::None)
  })
}

///|
fn make_contains_fn(errors : Array[String]) -> @value.Value {
  @value.Value::new_builtin("assert.contains", fn(
    _call_ctx,
    pos_args,
    _kw_args,
  ) {
    if pos_args.length() != 2 {
      return Err("assert.contains: got \{pos_args.length()} arguments, want 2")
    }
    let container = pos_args[0]
    let item = pos_args[1]
    let found = match container {
      @value.Value::List(l) => l.iter().any(fn(v) { v.starlark_equals(item) })
      @value.Value::Tuple(t) => t.iter().any(fn(v) { v.starlark_equals(item) })
      @value.Value::String(s) =>
        match item {
          @value.Value::String(n) => s.raw().contains(n.raw())
          _ => return Err("'in <string>' requires string as left operand")
        }
      @value.Value::Dict(d) =>
        match d.get(item) {
          Ok(Some(_)) => true
          _ => false
        }
      @value.Value::Set(s) =>
        match s.contains(item) {
          Ok(found) => found
          Err(_) => false
        }
      @value.Value::Range(r) =>
        match item {
          @value.Value::Int(n) => r.contains(n.to_int64())
          @value.Value::Float(f) =>
            if f.is_nan() || f.is_inf() {
              false
            } else {
              let as_int = f.to_int64()
              as_int.to_double() == f && r.contains(as_int)
            }
          _ => false
        }
      _ =>
        return Err(
          "argument of type '\{container.type_name()}' is not iterable",
        )
    }
    if !found {
      errors.push("\{container.to_str()} does not contain \{item.to_str()}")
    }
    Ok(@value.Value::None)
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

// Try to match `pat` at position `ti` in `tc`, where unescaped '.' matches any
// single char and '\X' matches literal X.  Returns the position after the match
// on success, or -1 on failure.
// pattern_unescape has already resolved \X escapes before this function is
// called.  Here, only unescaped '.' acts as a single-character wildcard; all
// other characters (including '\') are matched literally.

///|
fn try_match_at(pc : Array[Char], tc : Array[Char], ti_start : Int) -> Int {
  let plen = pc.length()
  let tlen = tc.length()
  let mut pi = 0
  let mut ti = ti_start
  while pi < plen {
    if ti >= tlen {
      return -1
    }
    if pc[pi] == '.' {
      pi += 1
      ti += 1
    } else {
      if tc[ti] != pc[pi] {
        return -1
      }
      pi += 1
      ti += 1
    }
  }
  ti
}

// Find the first occurrence of `pat` (where unescaped '.' matches any single
// char and '\X' matches literal X) in `text` starting at position `start_pos`.
// Returns the position immediately after the match, or None if not found.

///|
fn find_mini_pattern(pat : String, text : String, start_pos : Int) -> Int? {
  let pc = pat.to_array()
  let tc = text.to_array()
  let plen = pc.length()
  let tlen = tc.length()
  if plen == 0 {
    return Some(start_pos)
  }
  let max_start = tlen - plen + 1
  let mut i = start_pos
  while i < max_start {
    let end_pos = try_match_at(pc, tc, i)
    if end_pos >= 0 {
      return Some(end_pos)
    }
    i += 1
  }
  None
}

///|
fn pattern_matches(pattern : String, text : String) -> Bool {
  let anchor_end = pattern.has_suffix("$")
  let pat = if anchor_end {
    pattern[0:pattern.length() - 1].to_owned()
  } else {
    pattern
  }
  // Normalise regex subsets to the wildcards we support:
  //   "..."  → ".*"  (multi-char wildcard, already handled below)
  //   ".+"   → ".*"  (one-or-more → zero-or-more; permissive but sufficient)
  //   "[|]"  → "|"   (single-char class containing '|')
  let pat = {
    let buf = StringBuilder::new()
    let mut first = true
    for part in pat.split("...") {
      if !first {
        buf.write_string(".*")
      }
      buf.write_string(part.to_owned())
      first = false
    }
    buf.to_string()
  }
  let pat = {
    let buf = StringBuilder::new()
    let mut first = true
    for part in pat.split(".+") {
      if !first {
        buf.write_string(".*")
      }
      buf.write_string(part.to_owned())
      first = false
    }
    buf.to_string()
  }
  let pat = {
    let buf = StringBuilder::new()
    let mut first = true
    for part in pat.split("[|]") {
      if !first {
        buf.write_char('|')
      }
      buf.write_string(part.to_owned())
      first = false
    }
    buf.to_string()
  }
  let parts : Array[StringView] = pat.split(".*").collect()
  if parts.length() == 1 {
    // No multi-char wildcard: scan for the part using single-char '.' wildcards.
    let part = pattern_unescape(parts[0])
    if anchor_end {
      // Must match at the very end of text.
      let start = text.length() - part.length()
      if start < 0 {
        return false
      }
      find_mini_pattern(part, text, start) == Some(text.length())
    } else {
      find_mini_pattern(part, text, 0) != None
    }
  } else {
    let mut pos = 0
    for i in 0..<parts.length() {
      let part = pattern_unescape(parts[i])
      if part.is_empty() {
        continue
      }
      match find_mini_pattern(part, text, pos) {
        None => return false
        Some(end_pos) => pos = end_pos
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
  @value.Value::new_builtin("assert.fails", fn(call_ctx, pos_args, _kw_args) {
    if pos_args.length() != 2 {
      return Err("assert.fails: got \{pos_args.length()} arguments, want 2")
    }
    let f = pos_args[0]
    let pattern = match pos_args[1] {
      @value.Value::String(s) => s.raw()
      _ => return Err("assert.fails: pattern must be a string")
    }
    match
      call_ctx.invoke(
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
    Ok(@value.Value::None)
  })
}

///|
fn make_fibonacci_list() -> @value.Value {
  let fibs : Array[@value.Value] = []
  let mut a = 0N
  let mut b = 1N
  for _ in 0..<100 {
    fibs.push(@value.Value::Int(a))
    let c = a + b
    a = b
    b = c
  }
  @value.Value::List(@value.StarlarkList::new(fibs))
}

///|
fn make_freeze_fn() -> @value.Value {
  @value.Value::new_builtin("freeze", fn(_call_ctx, pos_args, _kw_args) {
    if pos_args.length() != 1 {
      return Err("freeze: got \{pos_args.length()} arguments, want 1")
    }
    let v = pos_args[0]
    v.freeze()
    Ok(v)
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
  @value.Value::Module(@value.StarlarkModule::new("assert", attrs))
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
fn parse_chunk_options(src : String) -> @eval.Options {
  let mut opts = @eval.Options::default()
  for line in src.split("\n") {
    let trimmed = line.trim()
    if trimmed.has_prefix("# option:") {
      let rest = trimmed[9:]
      for flag in rest.split(" ") {
        match flag.trim() {
          "globalreassign" => opts = opts.with_allow_global_reassign(true)
          "loadbindsglobally" => opts = opts.with_load_binds_globally(true)
          "norecursion" => opts = opts.with_allow_recursion(false)
          "recursion" => opts = opts.with_allow_recursion(true)
          _ => ()
        }
      }
    } else if trimmed.has_prefix("#option:") {
      let rest = trimmed[8:]
      for flag in rest.split(" ") {
        match flag.trim() {
          "globalreassign" => opts = opts.with_allow_global_reassign(true)
          "loadbindsglobally" => opts = opts.with_load_binds_globally(true)
          "norecursion" => opts = opts.with_allow_recursion(false)
          "recursion" => opts = opts.with_allow_recursion(true)
          _ => ()
        }
      }
    } else if trimmed.length() > 0 && !trimmed.has_prefix("#") {
      break
    }
  }
  opts
}

///|
fn levenshtein(a : String, b : String) -> Int {
  let m = a.length()
  let n = b.length()
  if m == 0 {
    return n
  }
  if n == 0 {
    return m
  }
  let ac = a.to_array()
  let bc = b.to_array()
  let row : Array[Int] = Array::make(n + 1, 0)
  for j in 0..<(n + 1) {
    row[j] = j
  }
  for i in 1..<(m + 1) {
    let mut prev = i - 1
    row[0] = i
    for j in 1..<(n + 1) {
      let old = row[j]
      let cost = if ac[i - 1] == bc[j - 1] { 0 } else { 1 }
      let ins = row[j - 1] + 1
      let del = old + 1
      let sub = prev + cost
      row[j] = if ins < del {
        if ins < sub {
          ins
        } else {
          sub
        }
      } else if del < sub {
        del
      } else {
        sub
      }
      prev = old
    }
  }
  row[n]
}

///|
fn norm_field_name(s : String) -> String {
  let buf = StringBuilder::new()
  for c in s.iter() {
    let code = c.to_int()
    if code >= 'A'.to_int() && code <= 'Z'.to_int() {
      buf.write_char(Int::unsafe_to_char(code + 32))
    } else if c != '_' {
      buf.write_char(c)
    }
  }
  buf.to_string()
}

///|
fn spell_suggest(name : String, candidates : Array[String]) -> String? {
  let name_norm = norm_field_name(name)
  let mut best : String? = None
  let mut best_dist = 3
  for c in candidates {
    let d = levenshtein(name_norm, norm_field_name(c))
    if d < best_dist {
      best = Some(c)
      best_dist = d
    }
  }
  best
}

///|
fn make_hasfields_fn() -> @value.Value {
  @value.Value::new_builtin("hasfields", fn(_call_ctx, _pos_args, _kw_args) {
    let storage : Map[String, @value.Value] = {}
    let cv = @value.CustomValue::new(fn() { "hasfields" }, fn() { true }, fn() {
        "<hasfields>"
      })
      .with_attrs(
        fn(name) {
          match storage.get(name) {
            Some(v) => Ok(Some(v))
            None => {
              let keys = storage.keys().collect()
              match spell_suggest(name, keys) {
                Some(s) =>
                  Err(
                    "hasfields has no .\{name} field or method (did you mean .\{s}?)",
                  )
                None => Ok(None)
              }
            }
          }
        },
        fn() { storage.keys().collect() },
      )
      .with_set_field(fn(name, val) {
        // Fields starting with "no" simulate SetField returning NoSuchField,
        // matching the starlark-go eval_test.go hasfields() helper behaviour.
        if name.has_prefix("no") && name.length() > 2 {
          let rest = name[2:].to_owned()
          match spell_suggest(rest, storage.keys().collect()) {
            Some(s) =>
              Err(
                "hasfields has no .\{name} field or method (did you mean .\{s}?)",
              )
            None => Err("hasfields has no .\{name} field or method")
          }
        } else {
          storage.set(name, val)
          Ok(())
        }
      })
      .with_binary(fn(op, _other, _is_left) {
        if op == "+" {
          Some(Ok(@value.Value::Int(42N)))
        } else {
          None
        }
      })
    Ok(@value.Value::ExtVal(cv))
  })
}

///|
fn exec_chunk_raw(
  src : String,
) -> Result[Array[String], (String, Array[String])] {
  let opts = parse_chunk_options(src)
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
    } else if path == "math.star" {
      let exports : Map[String, @value.Value] = {}
      exports["math"] = @math.math_module()
      Ok(@eval.Module::from_map(exports))
    } else if path == "time.star" {
      let exports : Map[String, @value.Value] = {}
      exports["time"] = @time.time_module()
      Ok(@eval.Module::from_map(exports))
    } else if path == "struct.star" {
      let exports : Map[String, @value.Value] = {}
      exports["struct"] = @struct.struct_builtin()
      exports["gensym"] = @struct.gensym_builtin()
      exports["module"] = @struct.module_builtin()
      Ok(@eval.Module::from_map(exports))
    } else {
      Err(@errors.EvalError::simple("no loader for \"\{path}\""))
    }
  }
  let thread = @eval.Thread::with_loader("test", loader)
  let predeclared = @eval.Predeclared::from_map({
    "hasfields": make_hasfields_fn(),
    "struct": @struct.struct_builtin(),
    "fibonacci": make_fibonacci_list(),
  })
  match
    @eval.exec_file_with_predeclared(thread, "<test>", src, opts, predeclared) {
    Ok(_) => Ok(assert_errors)
    Err(e) => Err((e.msg(), assert_errors))
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
pub fn run_with_predeclared(
  predeclared : @eval.Predeclared,
  src : String,
) -> Array[String] {
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
    } else if path == "math.star" {
      let exports : Map[String, @value.Value] = {}
      exports["math"] = @math.math_module()
      Ok(@eval.Module::from_map(exports))
    } else if path == "time.star" {
      let exports : Map[String, @value.Value] = {}
      exports["time"] = @time.time_module()
      Ok(@eval.Module::from_map(exports))
    } else if path == "struct.star" {
      let exports : Map[String, @value.Value] = {}
      exports["struct"] = @struct.struct_builtin()
      exports["gensym"] = @struct.gensym_builtin()
      exports["module"] = @struct.module_builtin()
      Ok(@eval.Module::from_map(exports))
    } else {
      Err(@errors.EvalError::simple("no loader for \"\{path}\""))
    }
  }
  let thread = @eval.Thread::with_loader("test", loader)
  match
    @eval.exec_file_with_predeclared(
      thread,
      "<test>",
      src,
      @eval.Options::default(),
      predeclared,
    ) {
    Ok(_) => ()
    Err(e) => errors.push(e.msg())
  }
  errors
}

///|
pub fn skip_chunks_containing(src : String, keywords : Array[String]) -> String {
  let kept = split_chunks(src)
    .iter()
    .filter(fn(chunk) { !keywords.iter().any(fn(kw) { chunk.contains(kw) }) })
    .to_array()
  if kept.is_empty() {
    // All chunks were filtered: surface a clear runtime failure instead of
    // silently passing with zero assertions.
    abort(
      "skip_chunks_containing: all chunks filtered — test would silently pass",
    )
  }
  kept.join("\n---\n")
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
    } else if path == "math.star" {
      let exports : Map[String, @value.Value] = {}
      exports["math"] = @math.math_module()
      Ok(@eval.Module::from_map(exports))
    } else if path == "time.star" {
      let exports : Map[String, @value.Value] = {}
      exports["time"] = @time.time_module()
      Ok(@eval.Module::from_map(exports))
    } else if path == "struct.star" {
      let exports : Map[String, @value.Value] = {}
      exports["struct"] = @struct.struct_builtin()
      exports["gensym"] = @struct.gensym_builtin()
      exports["module"] = @struct.module_builtin()
      Ok(@eval.Module::from_map(exports))
    } else {
      Err(@errors.EvalError::simple("no loader for \"\{path}\""))
    }
  }
  let thread = @eval.Thread::with_loader("test", loader)
  let predeclared = @eval.Predeclared::from_map({
    "fibonacci": make_fibonacci_list(),
  })
  match
    @eval.exec_file_with_predeclared(
      thread,
      "<test>",
      src,
      @eval.Options::default(),
      predeclared,
    ) {
    Ok(_) => ()
    Err(e) => errors.push(e.msg())
  }
  errors
}
