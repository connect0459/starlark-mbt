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
test "failed load result is written to cache and returned on subsequent calls" {
  // load_file always returns an error on non-native targets; starting
  // from an empty cache exercises the full sentinel -> load -> cache path.
  let cache : Map[String, Result[@eval.Module, @errors.EvalError]] = {}
  let loader = make_load_with_cache(".", cache)
  let thread = @eval.Thread::new("test")
  let r1 = loader(thread, "/any.star")
  assert_true(r1 is Err(_))
  assert_true(cache.get("/any.star") is Some(Err(_)))
  let r2 = loader(thread, "/any.star")
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

///|
test "dot-slash prefix resolves to same cache key as bare name" {
  // "./foo.star" and "foo.star" loaded from the same base_dir must
  // both resolve to the same absolute cache key ("/dir/foo.star"),
  // so the module is loaded at most once.
  let cache : Map[String, Result[@eval.Module, @errors.EvalError]] = {}
  cache["/dir/foo.star"] = Err(@errors.EvalError::simple("cycle in load graph"))
  let loader = make_load_with_cache("/dir", cache)
  let thread = @eval.Thread::new("test")
  match loader(thread, "./foo.star") {
    Err(e) => assert_true(e.msg().contains("cycle in load graph"))
    Ok(_) =>
      fail("expected ./foo.star to resolve to /dir/foo.star and hit cache")
  }
}

///|
test "dot-dot prefix resolves to parent directory" {
  // "../foo.star" loaded from "/dir/sub" must resolve to "/dir/foo.star".
  let cache : Map[String, Result[@eval.Module, @errors.EvalError]] = {}
  cache["/dir/foo.star"] = Err(@errors.EvalError::simple("cycle in load graph"))
  let loader = make_load_with_cache("/dir/sub", cache)
  let thread = @eval.Thread::new("test")
  match loader(thread, "../foo.star") {
    Err(e) => assert_true(e.msg().contains("cycle in load graph"))
    Ok(_) =>
      fail("expected ../foo.star to resolve to /dir/foo.star and hit cache")
  }
}

///|
test "absolute path with dot-dot segments is normalized before use as cache key" {
  // /dir/../foo.star must resolve to /foo.star, not be stored verbatim.
  let cache : Map[String, Result[@eval.Module, @errors.EvalError]] = {}
  cache["/foo.star"] = Err(@errors.EvalError::simple("cycle in load graph"))
  let loader = make_load_with_cache("/base", cache)
  let thread = @eval.Thread::new("test")
  match loader(thread, "/dir/../foo.star") {
    Err(e) => assert_true(e.msg().contains("cycle in load graph"))
    Ok(_) =>
      fail("expected /dir/../foo.star to normalize to /foo.star and hit cache")
  }
}
