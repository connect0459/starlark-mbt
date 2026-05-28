// Tests for unpack_args / unpack_positional argument helpers.

///|
fn val_eq(a : @value.Value?, b : @value.Value?) -> Bool {
  match (a, b) {
    (None, None) => true
    (Some(x), Some(y)) => @value.starlark_equals(x, y)
    _ => false
  }
}

// --- unpack_args: positional binding ---

///|
test "unpack_args: required positional args are bound in order" {
  let pos = [@value.Value::Int(1N), @value.Value::Int(2N)]
  let kw : Array[(String, @value.Value)] = []
  match unpack_args("f", pos, kw, ["a", "b"]) {
    Ok(r) => {
      assert_true(val_eq(r[0], Some(@value.Value::Int(1N))))
      assert_true(val_eq(r[1], Some(@value.Value::Int(2N))))
    }
    Err(e) => fail("expected Ok, got Err: \{e}")
  }
}

///|
test "unpack_args: missing required arg returns error with param name" {
  let pos : Array[@value.Value] = []
  let kw : Array[(String, @value.Value)] = []
  match unpack_args("f", pos, kw, ["a"]) {
    Err(e) =>
      if !(e.contains("missing") && e.contains("a")) {
        fail("expected error mentioning 'a', got: \{e}")
      }
    Ok(_) => panic()
  }
}

///|
test "unpack_args: too many positional args returns error mentioning fn name" {
  let pos = [
    @value.Value::Int(1N),
    @value.Value::Int(2N),
    @value.Value::Int(3N),
  ]
  let kw : Array[(String, @value.Value)] = []
  match unpack_args("f", pos, kw, ["a", "b"]) {
    Err(e) =>
      if !e.contains("f") {
        fail("expected fn name in error, got: \{e}")
      }
    Ok(_) => panic()
  }
}

// --- unpack_args: optional params ---

///|
test "unpack_args: optional param is None when not provided" {
  let pos = [@value.Value::Int(1N)]
  let kw : Array[(String, @value.Value)] = []
  match unpack_args("f", pos, kw, ["a", "b?"]) {
    Ok(r) => {
      assert_true(val_eq(r[0], Some(@value.Value::Int(1N))))
      assert_true(val_eq(r[1], None))
    }
    Err(e) => fail("expected Ok, got Err: \{e}")
  }
}

///|
test "unpack_args: optional param is bound when provided positionally" {
  let pos = [@value.Value::Int(1N), @value.Value::Int(42N)]
  let kw : Array[(String, @value.Value)] = []
  match unpack_args("f", pos, kw, ["a", "b?"]) {
    Ok(r) => {
      assert_true(val_eq(r[0], Some(@value.Value::Int(1N))))
      assert_true(val_eq(r[1], Some(@value.Value::Int(42N))))
    }
    Err(e) => fail("expected Ok, got Err: \{e}")
  }
}

// --- unpack_args: keyword args ---

///|
test "unpack_args: keyword arg binds to named param" {
  let pos : Array[@value.Value] = []
  let kw = [("a", @value.Value::Int(99N))]
  match unpack_args("f", pos, kw, ["a"]) {
    Ok(r) => assert_true(val_eq(r[0], Some(@value.Value::Int(99N))))
    Err(e) => fail("expected Ok, got Err: \{e}")
  }
}

///|
test "unpack_args: unexpected keyword arg returns error mentioning the name" {
  let pos : Array[@value.Value] = []
  let kw = [("z", @value.Value::Int(1N))]
  match unpack_args("f", pos, kw, ["a"]) {
    Err(e) =>
      if !(e.contains("unexpected") && e.contains("z")) {
        fail("expected error about 'z', got: \{e}")
      }
    Ok(_) => panic()
  }
}

///|
test "unpack_args: duplicate keyword arg returns error" {
  let pos = [@value.Value::Int(1N)]
  let kw = [("a", @value.Value::Int(2N))]
  match unpack_args("f", pos, kw, ["a"]) {
    Err(e) =>
      if !(e.contains("multiple") || e.contains("duplicate")) {
        fail("expected error about duplicate, got: \{e}")
      }
    Ok(_) => panic()
  }
}

// --- unpack_args: skip_none (??) ---

///|
test "unpack_args: skip_none param ignores None as if absent" {
  let pos : Array[@value.Value] = []
  let kw = [("a", @value.Value::None)]
  match unpack_args("f", pos, kw, ["a??"]) {
    Ok(r) => assert_true(val_eq(r[0], None))
    Err(e) => fail("expected Ok, got Err: \{e}")
  }
}

///|
test "unpack_args: skip_none param binds non-None value normally" {
  let pos = [@value.Value::Int(5N)]
  let kw : Array[(String, @value.Value)] = []
  match unpack_args("f", pos, kw, ["a??"]) {
    Ok(r) => assert_true(val_eq(r[0], Some(@value.Value::Int(5N))))
    Err(e) => fail("expected Ok, got Err: \{e}")
  }
}

// --- unpack_positional ---

///|
test "unpack_positional: binds args within range" {
  let pos = [@value.Value::Int(1N), @value.Value::Int(2N)]
  let kw : Array[(String, @value.Value)] = []
  match unpack_positional("f", pos, kw, 1, 3) {
    Ok(r) => {
      assert_true(val_eq(r[0], Some(@value.Value::Int(1N))))
      assert_true(val_eq(r[1], Some(@value.Value::Int(2N))))
      assert_true(val_eq(r[2], None))
    }
    Err(e) => fail("expected Ok, got Err: \{e}")
  }
}

///|
test "unpack_positional: rejects keyword args" {
  let pos : Array[@value.Value] = []
  let kw = [("x", @value.Value::Int(1N))]
  match unpack_positional("f", pos, kw, 0, 1) {
    Err(e) =>
      if !e.contains("keyword") {
        fail("expected keyword error, got: \{e}")
      }
    Ok(_) => panic()
  }
}

///|
test "unpack_positional: too few args returns error mentioning fn name" {
  let pos : Array[@value.Value] = []
  let kw : Array[(String, @value.Value)] = []
  match unpack_positional("f", pos, kw, 2, 3) {
    Err(e) =>
      if !e.contains("f") {
        fail("expected fn name in error, got: \{e}")
      }
    Ok(_) => panic()
  }
}

///|
test "unpack_positional: too many args returns error mentioning fn name" {
  let pos = [
    @value.Value::Int(1N),
    @value.Value::Int(2N),
    @value.Value::Int(3N),
  ]
  let kw : Array[(String, @value.Value)] = []
  match unpack_positional("f", pos, kw, 1, 2) {
    Err(e) =>
      if !e.contains("f") {
        fail("expected fn name in error, got: \{e}")
      }
    Ok(_) => panic()
  }
}
