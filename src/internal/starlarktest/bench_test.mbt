// Benchmark suite for the Starlark evaluator.

///|
fn exec(src : String) -> Unit {
  let thread = @eval.Thread::new("bench")
  match @eval.exec_file(thread, "<bench>", src, @eval.Options::default()) {
    Ok(_) => ()
    Err(e) => abort("bench exec error: \{e.msg()}")
  }
}

///|
test "bench: range construction" (it : @bench.T) {
  let src = "for _ in range(1000):\n  range(200)\n"
  it.bench(fn() { exec(src) })
}

///|
test "bench: range iteration" (it : @bench.T) {
  let src =
    #|for _ in range(200):
    #|  for x in range(200):
    #|    pass
  it.bench(fn() { exec(src) })
}

///|
test "bench: nested function calls" (it : @bench.T) {
  let src =
    #|def g(lst):
    #|  for x in lst:
    #|    pass
    #|def f(lst):
    #|  for x in lst:
    #|    g(lst)
    #|lst = range(20)
    #|f(lst)
  it.bench(fn() { exec(src) })
}

///|
test "bench: builtin method call" (it : @bench.T) {
  let src =
    #|d = {}
    #|for _ in range(1000):
    #|  d.get(None)
  it.bench(fn() { exec(src) })
}

///|
test "bench: integer arithmetic" (it : @bench.T) {
  let src =
    #|a = 0
    #|for _ in range(1000):
    #|  a += 1
  it.bench(fn() { exec(src) })
}

///|
test "bench: Gauss sum" (it : @bench.T) {
  let src =
    #|acc = 0
    #|for x in range(5000):
    #|  acc += x
  it.bench(fn() { exec(src) })
}

///|
test "bench: mixed computation" (it : @bench.T) {
  let src =
    #|x = 0
    #|for i in range(50):
    #|  if i:
    #|    x += 1
    #|  a = [v for v in range(i)]
  it.bench(fn() { exec(src) })
}

///|
test "bench: dict equality" (it : @bench.T) {
  let src =
    #|d = {str(v): v for v in range(100)}
    #|for _ in range(20):
    #|  if d != d:
    #|    fail("invalid")
  it.bench(fn() { exec(src) })
}

///|
test "bench: set operations" (it : @bench.T) {
  let src =
    #|s = set([v for v in range(100)])
    #|for _ in range(20):
    #|  if s != s:
    #|    fail("invalid")
  it.bench(fn() { exec(src) })
}

///|
test "bench: string operations" (it : @bench.T) {
  let src =
    #|s = "hello world"
    #|for _ in range(500):
    #|  s.upper()
    #|  s.split(" ")
    #|  s.replace("world", "starlark")
  it.bench(fn() { exec(src) })
}

///|
test "bench: list comprehension" (it : @bench.T) {
  let src =
    #|for _ in range(200):
    #|  a = [x * x for x in range(50)]
  it.bench(fn() { exec(src) })
}

///|
test "bench: parse and eval pipeline" (it : @bench.T) {
  let src =
    #|def fib(n):
    #|  if n <= 1:
    #|    return n
    #|  return fib(n - 1) + fib(n - 2)
    #|fib(10)
  it.bench(fn() { exec(src) })
}
