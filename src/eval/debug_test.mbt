// DebugFrame API tests.
//
// NOTE: builtin calls are not pushed onto the call stack,
// so frame numbering starts from the innermost *Starlark* function frame.
// Top-level module frames are also absent. Additionally, our captured_scope
// includes the entire enclosing scope rather than only referenced free vars,
// so free_var enumeration is not used in the env test.

///|
test "DebugFrame: trace captures param values across nested Starlark frames" {
  let thread = Thread::new("test")
  let got : Ref[String] = { val: "" }
  let trace_fn = @value.Value::new_builtin("trace", fn(_ctx, _args, _kwargs) {
    let lines : Array[String] = []
    let depth = thread.call_stack_depth()
    for i in 0..<depth {
      match thread.debug_frame(i) {
        None => ()
        Some(fr) =>
          match fr.callable() {
            @value.Value::Function(fn_) => {
              let parts : Array[String] = []
              for p_idx in 0..<fn_.num_params() {
                let (pname, _) = fn_.param(p_idx)
                let (_, v_opt) = fr.frame_local(p_idx)
                match v_opt {
                  None => parts.push("\{pname}=<unbound>")
                  Some(v) => parts.push("\{pname}=\{v.repr()}")
                }
              }
              lines.push("\{fn_.name()}(\{parts.join(", ")})")
            }
            _ => lines.push("builtin(...)")
          }
      }
    }
    got.val = lines.join("\n")
    Ok(@value.Value::None)
  })
  let pred = Predeclared::new()
  pred.set("trace", trace_fn)
  let src =
    #|def f(x, y): trace()
    #|def g(z): f(z, z*z)
    #|g(7)
  match
    exec_file_with_predeclared(
      thread,
      "foo.star",
      src,
      Options::default(),
      pred,
    ) {
    Err(e) => fail("exec failed: \{e.to_string()}")
    Ok(_) => ()
  }
  // depth 0 = f (innermost Starlark frame when trace() runs)
  // depth 1 = g
  assert_eq(got.val, "f(x=7, y=49)\ng(z=7)")
}

///|
test "DebugFrame: env builtin builds dict of own locals in calling Starlark frame" {
  let thread = Thread::new("test")
  let env_fn = @value.Value::new_builtin("env", fn(_ctx, _args, _kwargs) {
    let depth = thread.call_stack_depth()
    if depth < 1 {
      return Err("env must be called from within a Starlark function")
    }
    // depth 0 = the immediate Starlark caller (g in this test)
    let fr = match thread.debug_frame(0) {
      None => return Err("no active frame")
      Some(f) => f
    }
    let _ = match fr.callable() {
      @value.Value::Function(f) => f
      _ => return Err("env must be called from a Starlark function")
    }
    let dict = @value.StarlarkDict::new()
    for i in 0..<fr.num_locals() {
      let (bind, v_opt) = fr.frame_local(i)
      match v_opt {
        None => ()
        Some(v) => {
          let key = @value.Value::String(
            @value.StarlarkString::new(bind.name()),
          )
          ignore(dict.set(key, v))
        }
      }
    }
    dict.freeze()
    Ok(@value.Value::Dict(dict))
  })
  let pred = Predeclared::new()
  pred.set("env", env_fn)
  let src =
    #|e = [None]
    #|
    #|def f(p):
    #|    outer = 3
    #|    def g(q):
    #|        inner = outer + 1
    #|        e[0] = env()
    #|        inner2 = None
    #|    g(2)
    #|
    #|f(1)
  match
    exec_file_with_predeclared(
      thread,
      "env.star",
      src,
      Options::default(),
      pred,
    ) {
    Err(e) => fail("exec failed: \{e.to_string()}")
    Ok(m) => {
      let e_val = match m.get("e") {
        None => fail("missing 'e'")
        Some(v) => v
      }
      let env_dict = match e_val {
        @value.Value::List(lst) => lst.get(0)
        _ => fail("e is not a list")
      }
      // env() returns the own locals of g at call time: q=2, inner=4
      // (inner2 is not yet assigned; unassigned locals are skipped)
      // Keys appear in all_local_names order (params first, then body vars).
      let want = "{\"q\": 2, \"inner\": 4}"
      assert_eq(env_dict.repr(), want)
    }
  }
}
