///|
test "check error formats" {
  let errs = @starlarktest.run_star_string(
    (
      #|load("assert.star", "assert")
      #|def f(a, b, mm): pass
      #|assert.fails(lambda: f(1, 2), "mm")
      #|assert.fails(lambda: f(1, 2, 3, mm=4), "multiple values for parameter")
      #|def g(*args, **kwargs): return args, kwargs
      #|assert.fails(lambda: g(x=1, **{"x": 2}), "multiple values for parameter")
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}
