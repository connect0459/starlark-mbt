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
test "pre-populated failure in cache is returned without re-loading" {
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
test "failed load result is written to cache and returned on subsequent calls" {
  // @fs.read_file_to_string raises IOError for missing files on all targets;
  // starting from an empty cache exercises the full
  // sentinel -> IOError -> cache write path.
  let cache : Map[String, Result[@eval.Module, @errors.EvalError]] = {}
  let loader = make_loader_with_cache(".", @eval.Options::default(), cache)
  let thread = @eval.Thread::new("test")
  let r1 = loader(thread, "/any.star")
  assert_true(r1 is Err(_))
  assert_true(cache.get("/any.star") is Some(Err(_)))
  let r2 = loader(thread, "/any.star")
  assert_true(r2 is Err(_))
}

///|
test "absolute path with dot-dot segments is normalized before use as cache key" {
  // /dir/../foo.star must resolve to /foo.star, not be stored verbatim.
  let cache : Map[String, Result[@eval.Module, @errors.EvalError]] = {}
  cache["/foo.star"] = Err(@errors.EvalError::simple("cycle in load graph"))
  let loader = make_loader_with_cache("/base", @eval.Options::default(), cache)
  let thread = @eval.Thread::new("test")
  match loader(thread, "/dir/../foo.star") {
    Err(e) => assert_true(e.msg().contains("cycle in load graph"))
    Ok(_) =>
      fail("expected /dir/../foo.star to normalize to /foo.star and hit cache")
  }
}
