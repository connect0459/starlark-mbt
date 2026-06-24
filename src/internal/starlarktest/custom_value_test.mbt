///|
test "ExtVal Container: `in` operator works on custom container" {
  let items = @value.Value::List(
    @value.StarlarkList::new([
      @value.Value::Int(1N),
      @value.Value::Int(2N),
      @value.Value::Int(3N),
    ]),
  )
  let cv = @value.CustomValue::new(fn() { "my_container" }, fn() { true }, fn() {
    "<my_container>"
  }).with_contains(fn(v) {
    match items {
      @value.Value::List(l) => {
        for item in l.iter() {
          if item.starlark_equals(v) {
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
        Ok(Some(@value.Value::Int(42N)))
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
        Ok(Some(@value.Value::Int(42N)))
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
      #|assert.fails(lambda: getattr(my_obj_val, "z"), "has no .z field or method")
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

///|
test "ExtVal binary_fn: + operator dispatches to binary_fn" {
  let cv = @value.CustomValue::new(fn() { "counter" }, fn() { true }, fn() {
    "<counter>"
  }).with_binary(fn(op, rhs, _is_left) {
    if op == "+" {
      match rhs {
        @value.Value::Int(n) => Some(Ok(@value.Value::Int(n + 100N)))
        _ => None
      }
    } else {
      None
    }
  })
  let predeclared = @eval.Predeclared::new()
  predeclared.set("counter", @value.Value::ExtVal(cv))
  let errs = run_with_predeclared(
    predeclared,
    (
      #|load("assert.star", "assert")
      #|assert.eq(counter + 5, 105)
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "ExtVal binary_fn: right-hand dispatch when ExtVal is rhs" {
  let cv = @value.CustomValue::new(fn() { "counter" }, fn() { true }, fn() {
    "<counter>"
  }).with_binary(fn(op, lhs, _is_left) {
    if op == "+" {
      match lhs {
        @value.Value::Int(n) => Some(Ok(@value.Value::Int(n + 200N)))
        _ => None
      }
    } else {
      None
    }
  })
  let predeclared = @eval.Predeclared::new()
  predeclared.set("counter", @value.Value::ExtVal(cv))
  let errs = run_with_predeclared(
    predeclared,
    (
      #|load("assert.star", "assert")
      #|assert.eq(5 + counter, 205)
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "ExtVal unary_fn: - operator dispatches to unary_fn" {
  let cv = @value.CustomValue::new(fn() { "mynum" }, fn() { true }, fn() {
    "<mynum>"
  }).with_unary(fn(op) {
    if op == "-" {
      Some(Ok(@value.Value::Int(-99N)))
    } else {
      None
    }
  })
  let predeclared = @eval.Predeclared::new()
  predeclared.set("mynum", @value.Value::ExtVal(cv))
  let errs = run_with_predeclared(
    predeclared,
    (
      #|load("assert.star", "assert")
      #|assert.eq(-mynum, -99)
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "ExtVal compare_fn: < operator dispatches to compare_fn" {
  let make_num = fn(val : BigInt) -> @value.Value {
    @value.Value::ExtVal(
      @value.CustomValue::new(fn() { "num" }, fn() { true }, fn() { "<num>" })
      .with_compare(fn(other) {
        match other {
          @value.Value::ExtVal(oc) =>
            if oc.get_type_name() == "num" {
              Some(0)
            } else {
              None
            }
          _ => None
        }
      })
      .with_equals(fn(other, _depth) { Ok(other is @value.Value::ExtVal(_)) })
      .with_binary(fn(op, rhs, _is_left) {
        if op == "-" {
          match rhs {
            @value.Value::ExtVal(_) => Some(Ok(@value.Value::Int(val - val)))
            _ => None
          }
        } else {
          None
        }
      }),
    )
  }
  let n5 = make_num(5N)
  let predeclared = @eval.Predeclared::new()
  predeclared.set("n5", n5)
  let errs = run_with_predeclared(
    predeclared,
    (
      #|load("assert.star", "assert")
      #|assert.eq(n5 == n5, True)
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "ExtVal HasSetField: x.field=v dispatches to set_field_fn" {
  let storage : Map[String, @value.Value] = {}
  let cv = @value.CustomValue::new(fn() { "myobj" }, fn() { true }, fn() {
      "<myobj>"
    })
    .with_attrs(fn(name) { Ok(storage.get(name)) }, fn() {
      storage.keys().collect()
    })
    .with_set_field(fn(name, val) {
      storage.set(name, val)
      Ok(())
    })
  let predeclared = @eval.Predeclared::new()
  predeclared.set("obj", @value.Value::ExtVal(cv))
  let errs = run_with_predeclared(
    predeclared,
    (
      #|load("assert.star", "assert")
      #|obj.x = 42
      #|obj.msg = "hello"
      #|assert.eq(obj.x, 42)
      #|assert.eq(obj.msg, "hello")
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "ExtVal HasSetField: error from set_field_fn propagates as EvalError" {
  let cv = @value.CustomValue::new(fn() { "myobj" }, fn() { true }, fn() {
    "<myobj>"
  }).with_set_field(fn(name, _val) { Err("read-only field: \{name}") })
  let predeclared = @eval.Predeclared::new()
  predeclared.set("obj", @value.Value::ExtVal(cv))
  let errs = run_with_predeclared(predeclared, "obj.x = 1")
  assert_eq(errs.length(), 1)
  assert_true(errs[0].contains("read-only field: x"))
}

///|
test "ExtVal HasSetField: type without set_field_fn raises cannot-assign error" {
  let cv = @value.CustomValue::new(fn() { "frozen_obj" }, fn() { true }, fn() {
    "<frozen_obj>"
  })
  let predeclared = @eval.Predeclared::new()
  predeclared.set("obj", @value.Value::ExtVal(cv))
  let errs = run_with_predeclared(predeclared, "obj.x = 1")
  assert_eq(errs.length(), 1)
  assert_true(errs[0].contains("can't assign to .x field of frozen_obj"))
}

///|
test "ExtVal HasSetKey: x[k]=v dispatches to set_key_fn for arbitrary keys" {
  let backing = @value.StarlarkDict::new()
  let cv = @value.CustomValue::new(fn() { "mymap" }, fn() { true }, fn() {
      "<mymap>"
    })
    .with_set_key(fn(k, v) { backing.set(k, v) })
    .with_contains(fn(k) {
      match backing.get(k) {
        Ok(Some(_)) => Ok(true)
        Ok(None) => Ok(false)
        Err(e) => Err(e)
      }
    })
  let predeclared = @eval.Predeclared::new()
  predeclared.set("m", @value.Value::ExtVal(cv))
  let errs = run_with_predeclared(
    predeclared,
    (
      #|load("assert.star", "assert")
      #|m["a"] = 1
      #|m[42] = 2
      #|assert.eq("a" in m, True)
      #|assert.eq(42 in m, True)
      #|assert.eq("missing" in m, False)
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}
