// Argument unpacking helpers for Starlark built-in function implementations.
// Provides unpack_args and unpack_positional to reduce boilerplate in
// built-ins that need to validate and extract positional + keyword arguments.

///|
/// Parsed representation of a single parameter specification string.
///
/// - `name` : the bare parameter name (suffix sigils stripped)
/// - `optional` : `true` when the parameter may be absent
/// - `skip_none` : `true` when a caller-supplied `None` value is treated as absent
priv struct ParamInfo {
  name : String
  optional : Bool
  skip_none : Bool
}

///|
/// Parses a parameter specification string into a `ParamInfo`.
///
/// The suffix sigils control optionality:
/// - no suffix — required parameter
/// - `"?"` suffix — optional; a missing argument yields `None`
/// - `"??"` suffix — optional; a caller-supplied `None` value is also treated as absent
fn parse_param_spec(s : String) -> ParamInfo {
  if s.has_suffix("??") {
    { name: s[0:s.length() - 2].to_owned(), optional: true, skip_none: true }
  } else if s.has_suffix("?") {
    { name: s[0:s.length() - 1].to_owned(), optional: true, skip_none: false }
  } else {
    { name: s, optional: false, skip_none: false }
  }
}

///|
/// Extracts positional and keyword arguments into a result array whose indices
/// correspond to the entries in `param_specs`.
///
/// Each entry in `param_specs` is one of:
/// - `"name"` — required parameter
/// - `"name?"` — optional parameter (`None` when absent)
/// - `"name??"` — optional; if the caller passes `None`, treat it as absent
///
/// Parameters:
///
/// - `fn_name` : Name of the built-in function, used in error messages.
/// - `pos_args` : Positional arguments passed by the caller.
/// - `kw_args` : Keyword arguments passed by the caller, as `(name, value)` pairs.
/// - `param_specs` : Parameter specification strings describing each accepted parameter.
///
/// Returns `Ok(Array[Value?])` where `result[i]` is `Some(v)` when the
/// parameter was provided, or `None` when an optional parameter was absent.
/// Returns `Err` with a descriptive message on any mismatch.
pub fn unpack_args(
  fn_name : String,
  pos_args : Array[@value.Value],
  kw_args : Array[(String, @value.Value)],
  param_specs : Array[String],
) -> Result[Array[@value.Value?], String] {
  let n = param_specs.length()
  let infos : Array[ParamInfo] = param_specs.map(parse_param_spec)
  let mut seen_optional = false
  for i in 0..<n {
    if infos[i].optional {
      seen_optional = true
    } else if seen_optional {
      infos[i] = { ..infos[i], optional: true }
    }
  }
  let result : Array[@value.Value?] = Array::make(n, None)
  let defined : Array[Bool] = Array::make(n, false)
  if pos_args.length() > n {
    return Err(
      "\{fn_name}: got \{pos_args.length()} arguments, want at most \{n}",
    )
  }
  for i in 0..<pos_args.length() {
    let arg = pos_args[i]
    let info = infos[i]
    if info.skip_none && arg is @value.Value::None {
      continue
    }
    result[i] = Some(arg)
    defined[i] = true
  }
  for kv in kw_args {
    let (kw_name, arg) = kv
    let mut found = false
    for i in 0..<n {
      if infos[i].name == kw_name {
        if defined[i] {
          return Err(
            "\{fn_name}: got multiple values for keyword argument \"\{kw_name}\"",
          )
        }
        if infos[i].skip_none && arg is @value.Value::None {
          found = true
          break
        }
        result[i] = Some(arg)
        defined[i] = true
        found = true
        break
      }
    }
    if !found {
      return Err("\{fn_name}: unexpected keyword argument \"\{kw_name}\"")
    }
  }
  for i in 0..<n {
    if !infos[i].optional && !defined[i] {
      return Err("\{fn_name}: missing argument for \{infos[i].name}")
    }
  }
  Ok(result)
}

///|
/// Like `unpack_args`, but dispatches each matched argument to a custom
/// `Unpacker` target instead of returning the raw values. Mirrors how
/// starlark-go's `UnpackArgs` drives `Unpacker` targets: for every parameter
/// whose value was supplied, the corresponding target's `unpack` is invoked so
/// it can validate and absorb the value; absent optional parameters are
/// skipped.
///
/// Parameters:
///
/// - `fn_name` : Name of the built-in function, used in error messages.
/// - `pos_args` : Positional arguments passed by the caller.
/// - `kw_args` : Keyword arguments passed by the caller, as `(name, value)` pairs.
/// - `specs` : One `(param_spec, target)` pair per parameter, where `param_spec`
///   uses the same `"name"` / `"name?"` / `"name??"` syntax as `unpack_args`
///   and `target` receives the matched value via `Unpacker::unpack`.
///
/// Returns `Ok(())` once every supplied argument has been unpacked into its
/// target, or `Err` with a descriptive message on any argument mismatch or if
/// a target rejects its value.
pub fn unpack_args_with(
  fn_name : String,
  pos_args : Array[@value.Value],
  kw_args : Array[(String, @value.Value)],
  specs : Array[(String, &@value.Unpacker)],
) -> Result[Unit, String] {
  let param_specs = specs.map(fn(s) { s.0 })
  let values = match unpack_args(fn_name, pos_args, kw_args, param_specs) {
    Ok(vs) => vs
    Err(e) => return Err(e)
  }
  for i in 0..<specs.length() {
    match values[i] {
      Some(v) =>
        match specs[i].1.unpack(v) {
          Ok(_) => ()
          Err(e) => return Err(e)
        }
      None => ()
    }
  }
  Ok(())
}

///|
/// Extracts positional-only arguments, rejecting keyword arguments.
/// Requires between `min` and `max` positional args.
///
/// Parameters:
///
/// - `fn_name` : Name of the built-in function, used in error messages.
/// - `pos_args` : Positional arguments passed by the caller.
/// - `kw_args` : Keyword arguments passed by the caller; any non-empty list is rejected.
/// - `min` : Minimum number of positional arguments required.
/// - `max` : Maximum number of positional arguments accepted.
///
/// Returns `Ok(Array[Value?])` of length `max`; slots beyond the actual count
/// are `None`.
pub fn unpack_positional(
  fn_name : String,
  pos_args : Array[@value.Value],
  kw_args : Array[(String, @value.Value)],
  min : Int,
  max : Int,
) -> Result[Array[@value.Value?], String] {
  if !kw_args.is_empty() {
    return Err("\{fn_name}: unexpected keyword arguments")
  }
  let got = pos_args.length()
  if got < min {
    let atleast = if min < max { "at least " } else { "" }
    return Err("\{fn_name}: got \{got} arguments, want \{atleast}\{min}")
  }
  if got > max {
    let atmost = if max > min { "at most " } else { "" }
    return Err("\{fn_name}: got \{got} arguments, want \{atmost}\{max}")
  }
  let result : Array[@value.Value?] = Array::make(max, None)
  for i in 0..<got {
    result[i] = Some(pos_args[i])
  }
  Ok(result)
}
