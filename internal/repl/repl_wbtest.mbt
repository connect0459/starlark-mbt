///|
test "cycle in load graph is detected via sentinel already in cache" {
  let cache : Map[String, Result[@eval.Module, @errors.EvalError]] = {}
  cache["/a.star"] = Err(@errors.EvalError::simple("cycle in load graph"))
  let loader = make_load_with_cache(".", cache)
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
  let loader = make_load_with_cache(".", cache)
  let thread = @eval.Thread::new("test")
  let r1 = loader(thread, "/missing.star")
  let r2 = loader(thread, "/missing.star")
  assert_true(r1 is Err(_))
  assert_true(r2 is Err(_))
}

///|
test "inner loader shares same cache as outer loader" {
  // A cache pre-populated for an absolute path is visible
  // to a loader rooted at any directory, confirming cache sharing.
  let cache : Map[String, Result[@eval.Module, @errors.EvalError]] = {}
  cache["/dir/a.star"] = Err(@errors.EvalError::simple("cycle in load graph"))
  let loader = make_load_with_cache("/other", cache)
  let thread = @eval.Thread::new("test")
  match loader(thread, "/dir/a.star") {
    Err(e) => assert_true(e.msg().contains("cycle in load graph"))
    Ok(_) => fail("expected cycle error from shared cache")
  }
}
