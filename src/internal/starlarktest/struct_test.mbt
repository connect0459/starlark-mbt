///|
fn run_struct(src : String) -> Array[String] {
  let predeclared = @eval.Predeclared::from_map({
    "struct": @struct.struct_builtin(),
    "gensym": @struct.gensym_builtin(),
  })
  run_with_predeclared(predeclared, src)
}

///|
test "struct: str of struct builtin" {
  let errs = run_struct(
    (
      #|load("assert.star", "assert")
      #|assert.eq(str(struct), "<built-in function struct>")
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "struct: basic creation and type" {
  let errs = run_struct(
    (
      #|load("assert.star", "assert")
      #|s = struct(host = "localhost", port = 80)
      #|assert.eq(type(s), "struct")
      #|assert.eq(s.host, "localhost")
      #|assert.eq(s.port, 80)
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "struct: str representation" {
  let errs = run_struct(
    (
      #|load("assert.star", "assert")
      #|s = struct(host = "localhost", port = 80)
      #|assert.eq(str(s), 'struct(host = "localhost", port = 80)')
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "struct: equality" {
  let errs = run_struct(
    (
      #|load("assert.star", "assert")
      #|s = struct(host = "localhost", port = 80)
      #|assert.eq(s, s)
      #|assert.eq(s, struct(host = "localhost", port = 80))
      #|assert.ne(s, struct(host = "localhost", port = 81))
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "struct: missing field error" {
  let errs = run_struct(
    (
      #|load("assert.star", "assert")
      #|s = struct(host = "localhost", port = 80)
      #|assert.fails(lambda: s.protocol, "struct has no .protocol attribute")
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "struct: dir" {
  let errs = run_struct(
    (
      #|load("assert.star", "assert")
      #|s = struct(host = "localhost", port = 80)
      #|assert.eq(dir(s), ["host", "port"])
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "struct: hasattr and getattr" {
  let errs = run_struct(
    (
      #|load("assert.star", "assert")
      #|alice = struct(name = "alice", city = "NYC")
      #|assert.true(hasattr(alice, "city"))
      #|assert.eq(hasattr(alice, "ageaa"), False)
      #|assert.eq(getattr(alice, "city"), "NYC")
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "struct: truth value is always true" {
  let errs = run_struct(
    (
      #|load("assert.star", "assert")
      #|assert.true(struct())
      #|assert.true(struct(x = 1))
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "struct: addition merges fields (right wins)" {
  let errs = run_struct(
    (
      #|load("assert.star", "assert")
      #|bob = struct(name = "bob", age = 50)
      #|alice = struct(name = "alice", city = "NYC")
      #|assert.eq(bob + bob, bob)
      #|assert.eq(bob + alice, struct(age = 50, city = "NYC", name = "alice"))
      #|assert.eq(alice + bob, struct(age = 50, city = "NYC", name = "bob"))
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "struct: addition with non-struct fails" {
  let errs = run_struct(
    (
      #|load("assert.star", "assert")
      #|assert.fails(lambda: struct() + 1, "unknown binary op: struct \\+ int")
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "struct: branded struct via gensym" {
  let errs = run_struct(
    (
      #|load("assert.star", "assert")
      #|hostport = gensym(name = "hostport")
      #|assert.eq(type(hostport), "symbol")
      #|assert.eq(str(hostport), "hostport")
      #|http = hostport(host = "localhost", port = 80)
      #|assert.eq(type(http), "struct")
      #|assert.eq(str(http), 'hostport(host = "localhost", port = 80)')
      #|assert.eq(http, http)
      #|assert.eq(http, hostport(host = "localhost", port = 80))
      #|assert.ne(http, hostport(host = "localhost", port = 443))
      #|assert.eq(http.host, "localhost")
      #|assert.eq(http.port, 80)
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "struct: branded struct missing field error includes constructor name" {
  let errs = run_struct(
    (
      #|load("assert.star", "assert")
      #|hostport = gensym(name = "hostport")
      #|http = hostport(host = "localhost", port = 80)
      #|assert.fails(lambda: http.protocol, "hostport struct has no .protocol attribute")
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "struct: different gensym symbols are not equal" {
  let errs = run_struct(
    (
      #|load("assert.star", "assert")
      #|hostport = gensym(name = "hostport")
      #|hostport2 = gensym(name = "hostport")
      #|assert.eq(hostport, hostport)
      #|assert.ne(hostport, hostport2)
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "struct: addition fails with different constructor symbols" {
  let errs = run_struct(
    (
      #|load("assert.star", "assert")
      #|hostport = gensym(name = "hostport")
      #|person = gensym(name = "person")
      #|http = hostport(host = "localhost", port = 80)
      #|bob = person(name = "bob", age = 50)
      #|assert.fails(lambda: http + bob, "different constructors: hostport \\+ person")
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "struct: dir of branded struct" {
  let errs = run_struct(
    (
      #|load("assert.star", "assert")
      #|person = gensym(name = "person")
      #|bob = person(name = "bob", age = 50)
      #|alice = person(name = "alice", city = "NYC")
      #|assert.eq(dir(alice), ["city", "name"])
      #|assert.eq(dir(bob), ["age", "name"])
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "struct: structs with same fields but different symbols are not equal" {
  let errs = run_struct(
    (
      #|load("assert.star", "assert")
      #|hostport = gensym(name = "hostport")
      #|hostport2 = gensym(name = "hostport")
      #|a = hostport(host = "localhost", port = 80)
      #|b = hostport2(host = "localhost", port = 80)
      #|assert.ne(a, b)
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "struct: struct with circular reference can be frozen" {
  let errs = run_struct(
    (
      #|load("assert.star", "assert", "freeze")
      #|def struct_with_circular_ref():
      #|    foo = lambda: str(self)
      #|    self = struct(foo = foo)
      #|    return self
      #|s = struct_with_circular_ref()
      #|freeze(s)
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "struct: positional arguments rejected" {
  let errs = run_struct(
    (
      #|load("assert.star", "assert")
      #|assert.fails(lambda: struct(1, 2), "struct: unexpected positional arguments")
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "struct: hash is consistent for equal structs" {
  let s1 = @struct.make_struct(
    @value.Value::String(@value.StarlarkString::new("struct")),
    [
      ("a", @value.Value::Int(1N)),
      ("b", @value.Value::String(@value.StarlarkString::new("x"))),
    ],
  )
  let s2 = @struct.make_struct(
    @value.Value::String(@value.StarlarkString::new("struct")),
    [
      ("a", @value.Value::Int(1N)),
      ("b", @value.Value::String(@value.StarlarkString::new("x"))),
    ],
  )
  assert_true(@value.starlark_equals(s1, s2))
  let h1 = @value.starlark_hash(s1)
  let h2 = @value.starlark_hash(s2)
  match (h1, h2) {
    (Ok(a), Ok(b)) => assert_eq(a, b)
    _ => fail("hash failed")
  }
}
