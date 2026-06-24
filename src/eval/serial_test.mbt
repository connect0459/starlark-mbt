///|
fn compile_feature_program() -> Program raise Error {
  // A program that exercises the serialization-sensitive corners of the
  // bytecode: boolean constants, closures that capture free variables, and
  // variadic / keyword-only parameter specs.
  let src =
    #|flag = True
    #|missing = False
    #|
    #|def make_adder(n):
    #|    def add(x):
    #|        return x + n
    #|    return add
    #|
    #|result = make_adder(10)(5)
    #|
    #|def variadic(a, *args, **kwargs):
    #|    return a
    #|
    #|def kwonly(a, *, b):
    #|    return a + b
    #|
    #|kw_result = kwonly(1, b=2)
  match
    source_program("features.star", src, Options::default(), fn(_) { false }) {
    Ok(p) => p
    Err(e) => fail("source_program failed: \{e.to_string()}")
  }
}

///|
fn run_module(prog : Program) -> Module raise Error {
  match prog.init(Thread::new("test"), Predeclared::new()) {
    Ok(m) => m
    Err(e) => fail("init failed: \{e.to_string()}")
  }
}

///|
test "serialization: a decoded program re-encodes to identical bytes" {
  let prog = compile_feature_program()
  let bytes = prog.write()
  let decoded = match compiled_program(bytes) {
    Ok(p) => p
    Err(e) => fail("compiled_program failed: \{e.to_string()}")
  }
  assert_eq(decoded.write(), bytes)
}

///|
test "serialization: a decoded program preserves runtime behavior" {
  let original = compile_feature_program()
  let decoded = match compiled_program(original.write()) {
    Ok(p) => p
    Err(e) => fail("compiled_program failed: \{e.to_string()}")
  }
  let from_original = run_module(original)
  let from_decoded = run_module(decoded)
  for name in ["flag", "missing", "result", "kw_result"] {
    let a = from_original.get(name)
    let b = from_decoded.get(name)
    match (a, b) {
      (Some(av), Some(bv)) => assert_eq(av.repr(), bv.repr())
      _ => fail("missing module binding: \{name}")
    }
  }
}

///|
test "serialization: the closure free variable survives a round trip" {
  let decoded = match compiled_program(compile_feature_program().write()) {
    Ok(p) => p
    Err(e) => fail("compiled_program failed: \{e.to_string()}")
  }
  let result_module = run_module(decoded)
  // make_adder(10)(5) closes over n=10 and adds 5.
  match result_module.get("result") {
    Some(v) => assert_eq(v.repr(), "15")
    None => fail("missing result binding")
  }
  // The keyword-only parameter is also reconstructed and callable.
  match result_module.get("kw_result") {
    Some(v) => assert_eq(v.repr(), "3")
    None => fail("missing kw_result binding")
  }
}
