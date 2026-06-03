///|
/// A name the VM resolves as predeclared but that has no binding in the base
/// environment must raise the same undefined-name error the walker reports,
/// rather than silently resolving to a fabricated (body-less) builtin.
test "vm reports an undefined predeclared name instead of fabricating a builtin" {
  let file = match @parser.parse_file("t.star", "x = ghost") {
    Ok(f) => f
    Err(e) => fail("parse failed: \{e.to_string()}")
  }
  let prog = @compile.compile(
    file,
    fn(name) { name == "ghost" },
    fn(name) { name == "None" || name == "True" || name == "False" },
    true,
  ) catch {
    @compile.CompileErr(msg) => fail("compile failed: \{msg}")
  }
  let ctx = EvalContext::new(Thread::new("t"), Options::default())
  match run_program_vm(ctx, prog, "t.star") {
    Err(e) => assert_eq(e.to_string(), "t.star:1:5: undefined: ghost")
    Ok(_) =>
      fail("expected an undefined-name error for the unbound predeclared name")
  }
}
