///|
test "ExtVal Container: `in` operator works on custom container" {
  let items = @value.Value::List(
    @value.StarlarkList::new([
      @value.Value::Int(1L),
      @value.Value::Int(2L),
      @value.Value::Int(3L),
    ]),
  )
  let cv = @value.CustomValue::new(fn() { "my_container" }, fn() { true }, fn() {
    "<my_container>"
  }).with_contains(fn(v) {
    match items {
      @value.Value::List(l) => {
        for item in l.iter() {
          if @value.starlark_equals(item, v) {
            return Ok(true)
          }
        }
        Ok(false)
      }
      _ => Ok(false)
    }
  })
  let predeclared = @eval.Predeclared::new()
  predeclared.set("my_cont", @value.Value::ExtVal(cv))
  let errs = run_with_predeclared(
    predeclared,
    (
      #|load("assert.star", "assert")
      #|assert.eq(1 in my_cont, True)
      #|assert.eq(4 in my_cont, False)
      #|assert.eq(1 not in my_cont, False)
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "ExtVal HasAttrs: dir() returns attr_names for custom value" {
  let cv = @value.CustomValue::new(fn() { "my_obj" }, fn() { true }, fn() {
    "<my_obj>"
  }).with_attrs(
    fn(name) {
      if name == "x" {
        Ok(Some(@value.Value::Int(42L)))
      } else {
        Ok(None)
      }
    },
    fn() { ["x", "y"] },
  )
  let predeclared = @eval.Predeclared::new()
  predeclared.set("my_obj_val", @value.Value::ExtVal(cv))
  let errs = run_with_predeclared(
    predeclared,
    (
      #|load("assert.star", "assert")
      #|assert.eq(dir(my_obj_val), ["x", "y"])
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "ExtVal HasAttrs: getattr works on custom value" {
  let cv = @value.CustomValue::new(fn() { "my_obj" }, fn() { true }, fn() {
    "<my_obj>"
  }).with_attrs(
    fn(name) {
      if name == "x" {
        Ok(Some(@value.Value::Int(42L)))
      } else {
        Ok(None)
      }
    },
    fn() { ["x"] },
  )
  let predeclared = @eval.Predeclared::new()
  predeclared.set("my_obj_val", @value.Value::ExtVal(cv))
  let errs = run_with_predeclared(
    predeclared,
    (
      #|load("assert.star", "assert")
      #|assert.eq(getattr(my_obj_val, "x"), 42)
      #|assert.fails(lambda: getattr(my_obj_val, "z"), "has no attribute")
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "ExtVal: type() returns custom type name" {
  let cv = @value.CustomValue::new(fn() { "my_type" }, fn() { true }, fn() {
    "<my_type>"
  })
  let predeclared = @eval.Predeclared::new()
  predeclared.set("cv", @value.Value::ExtVal(cv))
  let errs = run_with_predeclared(
    predeclared,
    (
      #|load("assert.star", "assert")
      #|assert.eq(type(cv), "my_type")
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}
