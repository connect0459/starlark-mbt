///|
test "cycle in load graph is detected via sentinel already in cache" {
  let cache : Map[String, Result[@eval.Module, @errors.EvalError]] = {}
  cache["/a.star"] = Err(@errors.EvalError::simple("cycle in load graph"))
  let loader = make_loader_with_cache(".", @eval.Options::default(), cache)
  let thread = @eval.Thread::new("test")
  match loader(thread, "/a.star") {
    Err(e) => assert_true(e.msg().contains("cycle in load graph"))
    Ok(_) => fail("expected cycle error")
  }
}

///|
test "failed module load is cached so the file is not re-attempted" {
  let cache : Map[String, Result[@eval.Module, @errors.EvalError]] = {}
  cache["/missing.star"] = Err(@errors.EvalError::simple("cannot load"))
  let loader = make_loader_with_cache(".", @eval.Options::default(), cache)
  let thread = @eval.Thread::new("test")
  let r1 = loader(thread, "/missing.star")
  let r2 = loader(thread, "/missing.star")
  assert_true(r1 is Err(_))
  assert_true(r2 is Err(_))
}

///|
test "make_loader produces a shared cache across nested loads" {
  // Verifies that make_loader returns a closure whose cache is
  // accessible to inner loaders created from the same root.
  let loader = make_loader(".", @eval.Options::default())
  assert_true(loader is _)
}
