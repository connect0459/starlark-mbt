///|
fn make_error_fn(errors : Array[String]) -> @value.Value {
  @value.Value::new_builtin("error", fn(_call_ctx, pos_args, _kw_args) {
    if pos_args.length() != 1 {
      return Err("error: got \{pos_args.length()} arguments, want 1")
    }
    errors.push(
      match pos_args[0].to_str_checked() {
        Ok(s) => s
        Err(_) => "<str error>"
      },
    )
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
      let xr = match x.repr_checked() {
        Ok(s) => s
        Err(_) => "<repr error>"
      }
      let yr = match y.repr_checked() {
        Ok(s) => s
        Err(_) => "<repr error>"
      }
      errors.push("\{xr} != \{yr}")
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
      let xr = match x.repr_checked() {
        Ok(s) => s
        Err(_) => "<repr error>"
      }
      let yr = match y.repr_checked() {
        Ok(s) => s
        Err(_) => "<repr error>"
      }
      errors.push("\{xr} == \{yr}")
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
          found = match kv.1.to_str_checked() {
            Ok(s) => s
            Err(_) => "<str error>"
          }
          break
        }
      }
      if pos_args.length() >= 2 {
        found = match pos_args[1].to_str_checked() {
          Ok(s) => s
          Err(_) => "<str error>"
        }
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
          let xs = match x.to_str_checked() {
            Ok(s) => s
            Err(_) => "<str error>"
          }
          let ys = match y.to_str_checked() {
            Ok(s) => s
            Err(_) => "<str error>"
          }
          errors.push("\{xs} is not less than \{ys}")
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
      let cs = match container.to_str_checked() {
        Ok(s) => s
        Err(_) => "<str error>"
      }
      let is_ = match item.to_str_checked() {
        Ok(s) => s
        Err(_) => "<str error>"
      }
      errors.push("\{cs} does not contain \{is_}")
    }
    Ok(@value.Value::None)
  })
}

// Try to match `pat` at position `ti` in `tc`.
// '.' is a single-character wildcard.  A backslash followed by any character
// matches that character literally (e.g. '\.' matches only '.').
// Returns the position after the match on success, or -1 on failure.

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
    if pc[pi] == '\\' && pi + 1 < plen {
      if tc[ti] != pc[pi + 1] {
        return -1
      }
      pi += 2
      ti += 1
    } else if pc[pi] == '.' {
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

// Returns the number of text characters consumed when matching `pc`, taking
// backslash escapes into account (each `\X` pair consumes one text char).

///|
fn effective_pattern_length(pc : Array[Char]) -> Int {
  let mut len = 0
  let mut i = 0
  while i < pc.length() {
    if pc[i] == '\\' && i + 1 < pc.length() {
      i += 2
    } else {
      i += 1
    }
    len += 1
  }
  len
}

// Find the first occurrence of `pat` (where '.' matches any single char and
// '\X' matches the literal char X) in `text` starting at `start_pos`.
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
  let eff_len = effective_pattern_length(pc)
  let max_start = tlen - eff_len + 1
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
/// Returns `true` when `text` contains a substring matching `pattern`.
/// Supports `.` as a single-character wildcard, `.*` (and `...`/`.+`) as a
/// multi-character wildcard, `[|]` as a literal `|`, a trailing `$` anchor,
/// and `\X` literal escapes. This covers the subset of patterns used in
/// `###` error annotations and `assert.fails` calls in the conformance suite.
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
    let part = parts[0].to_owned()
    if anchor_end {
      // Must match at the very end of text.
      let eff_len = effective_pattern_length(part.to_array())
      let start = text.length() - eff_len
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
      let part = parts[i].to_owned()
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
  let attrs : Map[String, @value.Value] = Map([])
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
priv enum HashAnnotation {
  NoAnnotation
  Malformed(String)
  ValidPattern(String)
}

///|
/// Parses a `### "pattern"` or `` ### `pattern` `` error-expectation
/// annotation from a single source line. Returns `ValidPattern(p)` when
/// well-formed, `Malformed(raw)` when the `###` marker is present but the
/// annotation is syntactically invalid, and `NoAnnotation` otherwise.
fn parse_hash_annotation(line : String) -> HashAnnotation {
  match line.find("###") {
    None => NoAnnotation
    Some(hash_pos) => {
      let after = trim_start(line[hash_pos + 3:].to_owned())
      let chars = after.iter().to_array()
      if chars.is_empty() {
        Malformed("(empty)")
      } else if chars[0] == '"' {
        let inner = after[1:].to_owned()
        match inner.find("\"") {
          None => Malformed(after)
          Some(end_pos) =>
            ValidPattern(unquote_double(inner[0:end_pos].to_owned()))
        }
      } else if chars[0] == '`' {
        let inner = after[1:].to_owned()
        match inner.find("`") {
          None => Malformed(after)
          Some(end_pos) => ValidPattern(inner[0:end_pos].to_owned())
        }
      } else {
        Malformed(after)
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
  // Toggle the non-standard extensions from an `option:<name>` directive
  // appearing anywhere in the chunk (mirroring starlark-go's `getOptions`). The
  // standard features (`set`, `lambda`, `bytes`, `float`) have no gate here and
  // keep their default — in particular `set` stays enabled, since this project
  // enables it by default even though starlark-go's zero value does not.
  fn has(name : String) -> Bool {
    src.contains("option:" + name)
  }

  @eval.Options::default()
  .with_allow_while(has("while"))
  .with_allow_top_level_control(has("toplevelcontrol"))
  .with_allow_global_reassign(has("globalreassign"))
  .with_load_binds_globally(has("loadbindsglobally"))
  .with_allow_recursion(has("recursion"))
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
    let storage : Map[String, @value.Value] = Map([])
    let frozen : Ref[Bool] = { val: false }
    let cv = @value.CustomValue::new(fn() { "hasfields" }, fn() { true }, fn() {
        "<hasfields>"
      })
      .with_freeze(fn() { frozen.val = true })
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
        if frozen.val {
          return Err("cannot set field on a frozen hasfields")
        }
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
fn line_of_error(err : @errors.EvalError) -> Int {
  let stack = err.call_stack()
  let n = stack.length()
  for i in 0..<n {
    let idx = n - 1 - i
    match stack.at(idx) {
      Some(frame) => {
        let pos = frame.pos()
        if pos.filename() == "<test>" && pos.line() > 0 {
          return pos.line()
        }
      }
      None => ()
    }
  }
  parse_test_line(err.msg())
}

///|
fn parse_test_line(msg : String) -> Int {
  let prefix = "<test>:"
  if !msg.has_prefix(prefix) {
    return 0
  }
  let rest = msg[prefix.length():]
  let chars = rest.iter().to_array()
  let mut i = 0
  while i < chars.length() && chars[i] >= '0' && chars[i] <= '9' {
    i += 1
  }
  if i == 0 {
    return 0
  }
  let mut n = 0
  for j in 0..<i {
    n = n * 10 + (chars[j].to_int() - '0'.to_int())
  }
  n
}

///|
/// Executes a single source chunk with the full test environment: the `assert`
/// module, standard extension loaders (`assert.star`, `json.star`, etc.), and
/// the `hasfields`/`struct`/`fibonacci` predeclared names. Returns
/// `Ok(assert_errors)` on clean execution, or `Err((eval_error, assert_errors))`
/// if the script raises an evaluation error.
fn exec_chunk_raw(
  src : String,
) -> Result[Array[String], (@errors.EvalError, Array[String])] {
  let opts = parse_chunk_options(src)
  let assert_errors : Array[String] = []
  let assert_module = build_assert_module(assert_errors)
  let loader : (@eval.Thread, String) -> Result[@eval.Module, @errors.EvalError] = fn(
    _thread,
    path,
  ) {
    if path == "assert.star" {
      let exports : Map[String, @value.Value] = Map([])
      exports["assert"] = assert_module
      exports["freeze"] = make_freeze_fn()
      Ok(@eval.Module::from_map(exports))
    } else if path == "json.star" {
      let exports : Map[String, @value.Value] = Map([])
      exports["json"] = @json.json_module()
      Ok(@eval.Module::from_map(exports))
    } else if path == "math.star" {
      let exports : Map[String, @value.Value] = Map([])
      exports["math"] = @math.math_module()
      Ok(@eval.Module::from_map(exports))
    } else if path == "time.star" {
      let exports : Map[String, @value.Value] = Map([])
      exports["time"] = @time.time_module()
      Ok(@eval.Module::from_map(exports))
    } else if path == "struct.star" {
      let exports : Map[String, @value.Value] = Map([])
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
    Err(e) => Err((e, assert_errors))
  }
}

///|
/// Runs a multi-chunk Starlark test string and returns the failure messages.
/// The source is split on `\n---\n` separators; each chunk is executed in
/// isolation. A `### "pattern"` annotation on a line asserts that execution
/// produces an error whose message matches `pattern`; unannotated chunks must
/// complete without errors and pass all `assert.*` checks.
///
/// Parameters:
///
/// - `src` : The Starlark source text, optionally containing `\n---\n` chunk
///   separators and `### "pattern"` error annotations.
///
/// Returns a (possibly empty) array of failure descriptions.
pub fn run_chunked_string(src : String) -> Array[String] {
  let failures : Array[String] = []
  let chunks = split_chunks(src)
  for chunk in chunks {
    let want_errs : Map[Int, String] = Map([])
    let mut line_num = 1
    for line in chunk.split("\n") {
      match parse_hash_annotation(line.to_owned()) {
        NoAnnotation => ()
        Malformed(raw) => failures.push("malformed ### annotation: \{raw}")
        ValidPattern(p) => want_errs[line_num] = p
      }
      line_num += 1
    }
    if want_errs.is_empty() {
      match exec_chunk_raw(chunk) {
        Ok(assert_errs) =>
          for e in assert_errs {
            failures.push(e)
          }
        Err((eval_err, assert_errs)) => {
          failures.push("unexpected error: \{eval_err.msg()}")
          for e in assert_errs {
            failures.push(e)
          }
        }
      }
    } else {
      match exec_chunk_raw(chunk) {
        Ok(assert_errs) => {
          want_errs.each(fn(line, pattern) {
            failures.push(
              "expected error matching \"\{pattern}\" at line \{line} but none was raised",
            )
          })
          for e in assert_errs {
            failures.push(e)
          }
        }
        Err((eval_err, assert_errs)) => {
          let err_line = line_of_error(eval_err)
          let msg = eval_err.msg()
          match want_errs.get(err_line) {
            Some(pattern) => {
              want_errs.remove(err_line) |> ignore
              if !pattern_matches(pattern, msg) {
                failures.push(
                  "error \"\{msg}\" did not match pattern \"\{pattern}\"",
                )
              }
            }
            None => failures.push("unexpected error: \{msg}")
          }
          want_errs.each(fn(line, pattern) {
            failures.push(
              "expected error matching \"\{pattern}\" at line \{line} but none was raised",
            )
          })
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
/// Runs a single Starlark source string against a caller-supplied set of
/// predeclared names and returns any failure messages. The standard test
/// modules (`assert.star`, `json.star`, `math.star`, `time.star`,
/// `struct.star`) are available via `load`. Returns an empty array on success.
///
/// Parameters:
///
/// - `predeclared` : Extra names visible to the script as predeclared globals.
/// - `src` : The Starlark source text to execute.
///
/// Returns a (possibly empty) array of error or assertion-failure messages.
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
      let exports : Map[String, @value.Value] = Map([])
      exports["assert"] = assert_module
      exports["freeze"] = make_freeze_fn()
      Ok(@eval.Module::from_map(exports))
    } else if path == "json.star" {
      let exports : Map[String, @value.Value] = Map([])
      exports["json"] = @json.json_module()
      Ok(@eval.Module::from_map(exports))
    } else if path == "math.star" {
      let exports : Map[String, @value.Value] = Map([])
      exports["math"] = @math.math_module()
      Ok(@eval.Module::from_map(exports))
    } else if path == "time.star" {
      let exports : Map[String, @value.Value] = Map([])
      exports["time"] = @time.time_module()
      Ok(@eval.Module::from_map(exports))
    } else if path == "struct.star" {
      let exports : Map[String, @value.Value] = Map([])
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
      parse_chunk_options(src),
      predeclared,
    ) {
    Ok(_) => ()
    Err(e) => errors.push(e.msg())
  }
  errors
}

///|
/// Filters `src`'s `\n---\n`-delimited chunks, dropping any that contain one
/// of the given `keywords`, then re-joins and returns the surviving chunks.
/// Aborts when all chunks are filtered, which would otherwise silently pass
/// with zero assertions.
///
/// Parameters:
///
/// - `src` : A multi-chunk source string (chunks separated by `\n---\n`).
/// - `keywords` : Substrings that mark chunks to skip.
///
/// Returns the filtered source string with surviving chunks re-joined by `\n---\n`.
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
/// Runs a single Starlark `.star`-style test source string, providing the
/// standard test modules and the `fibonacci` predeclared name. Returns any
/// failure messages; an empty array indicates success.
///
/// Parameters:
///
/// - `src` : The Starlark source text to execute.
///
/// Returns a (possibly empty) array of error or assertion-failure messages.
pub fn run_star_string(src : String) -> Array[String] {
  let errors : Array[String] = []
  let assert_module = build_assert_module(errors)
  let loader : (@eval.Thread, String) -> Result[@eval.Module, @errors.EvalError] = fn(
    _thread,
    path,
  ) {
    if path == "assert.star" {
      let exports : Map[String, @value.Value] = Map([])
      exports["assert"] = assert_module
      exports["freeze"] = make_freeze_fn()
      Ok(@eval.Module::from_map(exports))
    } else if path == "json.star" {
      let exports : Map[String, @value.Value] = Map([])
      exports["json"] = @json.json_module()
      Ok(@eval.Module::from_map(exports))
    } else if path == "math.star" {
      let exports : Map[String, @value.Value] = Map([])
      exports["math"] = @math.math_module()
      Ok(@eval.Module::from_map(exports))
    } else if path == "time.star" {
      let exports : Map[String, @value.Value] = Map([])
      exports["time"] = @time.time_module()
      Ok(@eval.Module::from_map(exports))
    } else if path == "struct.star" {
      let exports : Map[String, @value.Value] = Map([])
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
      parse_chunk_options(src),
      predeclared,
    ) {
    Ok(_) => ()
    Err(e) => errors.push(e.msg())
  }
  errors
}
