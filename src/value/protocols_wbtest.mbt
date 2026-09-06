///|
struct SimpleMap {
  data : Array[(Value, Value)]
}

///|
impl Mapping for SimpleMap with fn mapping_get(self, key) {
  for kv in self.data {
    let (k, v) = kv
    if k.starlark_equals(key) {
      return Ok(Some(v))
    }
  }
  Ok(None)
}

///|
impl Mapping for SimpleMap with fn mapping_keys(self) {
  Ok(self.data.map(fn(kv) { kv.0 }))
}

///|
impl Mapping for SimpleMap with fn mapping_len(self) {
  self.data.length()
}

///|
impl IterableMapping for SimpleMap with fn items(self) {
  Ok(self.data)
}

///|
extend SimpleMap with Mapping::{mapping_get, mapping_keys, mapping_len}

///|
extend SimpleMap with IterableMapping::{items}

///|
test "Mapping protocol: get returns value for existing key" {
  let m : SimpleMap = { data: [(Value::Int(1N), Value::Bool(true))], }
  let result = m.mapping_get(Value::Int(1N))
  assert_true(result is Ok(Some(Value::Bool(true))))
}

///|
test "Mapping protocol: get returns None for missing key" {
  let m : SimpleMap = { data: [], }
  let result = m.mapping_get(Value::Int(42N))
  assert_true(result is Ok(None))
}

///|
test "Mapping protocol: keys returns all keys" {
  let m : SimpleMap = {
    data: [(Value::Int(1N), Value::None), (Value::Int(2N), Value::None)],
  }
  match m.mapping_keys() {
    Ok(keys) => assert_eq(keys.length(), 2)
    Err(e) => fail("unexpected error: \{e}")
  }
}

///|
test "Mapping protocol: len returns entry count" {
  let m : SimpleMap = {
    data: [(Value::Int(1N), Value::None), (Value::Int(2N), Value::None)],
  }
  assert_eq(m.mapping_len(), 2)
}

///|
struct SimpleSeq {
  items : Array[Value]
}

///|
impl Indexable for SimpleSeq with fn indexable_get(self, i) {
  Ok(self.items[i])
}

///|
impl Indexable for SimpleSeq with fn indexable_len(self) {
  self.items.length()
}

///|
impl HasSetIndex for SimpleSeq with fn set_index(self, i, v) {
  self.items[i] = v
  Ok(())
}

///|
impl Sliceable for SimpleSeq with fn slice(self, start, stop, step) {
  let result : Array[Value] = []
  if step > 0 {
    let mut i = start
    while i < stop {
      result.push(self.items[i])
      i += step
    }
  } else {
    let mut i = start
    while i > stop {
      result.push(self.items[i])
      i += step
    }
  }
  Ok(Value::Tuple(result))
}

///|
extend SimpleSeq with Indexable::{indexable_get, indexable_len}

///|
extend SimpleSeq with HasSetIndex::{set_index}

///|
extend SimpleSeq with Sliceable::{slice}

///|
struct SimpleInt {
  val : Int
}

///|
impl TotallyOrdered for SimpleInt with fn cmp(self, other) {
  match other {
    Value::Int(n) => Some(BigInt::from_int64(self.val.to_int64()).compare(n))
    _ => None
  }
}

///|
extend SimpleInt with TotallyOrdered::{cmp}

///|
test "Indexable protocol: get returns element at index" {
  let s : SimpleSeq = { items: [Value::Int(10N), Value::Int(20N)], }
  assert_true(s.indexable_get(0) is Ok(Value::Int(10N)))
  assert_true(s.indexable_get(1) is Ok(Value::Int(20N)))
}

///|
test "Indexable protocol: len returns sequence length" {
  let s : SimpleSeq = { items: [Value::None, Value::None, Value::None], }
  assert_eq(s.indexable_len(), 3)
}

///|
test "CustomValue: type_name delegates to type_name_fn" {
  let cv = CustomValue::new(fn() { "my_type" }, fn() { true }, fn() {
    "<my_type>"
  })
  assert_eq(cv.get_type_name(), "my_type")
}

///|
test "CustomValue: truth delegates to truth_fn" {
  let cv_true = CustomValue::new(fn() { "t" }, fn() { true }, fn() { "" })
  let cv_false = CustomValue::new(fn() { "f" }, fn() { false }, fn() { "" })
  assert_eq(cv_true.get_truth(), true)
  assert_eq(cv_false.get_truth(), false)
}

///|
test "CustomValue: repr delegates to repr_fn" {
  let cv = CustomValue::new(fn() { "t" }, fn() { true }, fn() { "custom_repr" })
  assert_eq(cv.get_repr(), "custom_repr")
}

///|
test "CustomValue: hash returns Err when no hash_fn" {
  let cv = CustomValue::new(fn() { "t" }, fn() { true }, fn() { "" })
  assert_true(cv.get_hash() is Err(_))
}

///|
test "CustomValue: hash delegates to hash_fn" {
  let cv = CustomValue::new(fn() { "t" }, fn() { true }, fn() { "" }).with_hash(fn() {
      Ok(42U)
    },
  )
  assert_true(cv.get_hash() is Ok(42U))
}

///|
test "CustomValue: equals returns false by default" {
  let cv = CustomValue::new(fn() { "t" }, fn() { true }, fn() { "" })
  assert_true(cv.get_equals(Value::None, compare_limit) is Ok(false))
}

///|
test "CustomValue: equals delegates to equals_fn" {
  let cv = CustomValue::new(fn() { "t" }, fn() { true }, fn() { "" }).with_equals(fn(
      other,
      _depth,
    ) {
      Ok(other is Value::None)
    },
  )
  assert_true(cv.get_equals(Value::None, compare_limit) is Ok(true))
  assert_true(cv.get_equals(Value::Bool(true), compare_limit) is Ok(false))
}

///|
test "CustomValue: attr_names returns None when no attr_names_fn" {
  let cv = CustomValue::new(fn() { "t" }, fn() { true }, fn() { "" })
  assert_true(cv.get_attr_names() is None)
}

///|
test "CustomValue: attr_names delegates to attr_names_fn" {
  let cv = CustomValue::new(fn() { "t" }, fn() { true }, fn() { "" }).with_attrs(
    fn(_name) { Ok(None) },
    fn() { ["a", "b"] },
  )
  match cv.get_attr_names() {
    Some(names) => {
      assert_eq(names.length(), 2)
      assert_eq(names[0], "a")
      assert_eq(names[1], "b")
    }
    None => fail("expected Some")
  }
}

///|
test "CustomValue: get_attr returns Ok(None) when no get_attr_fn" {
  let cv = CustomValue::new(fn() { "t" }, fn() { true }, fn() { "" })
  assert_true(cv.get_attr("x") is Ok(None))
}

///|
test "CustomValue: get_attr delegates to get_attr_fn" {
  let cv = CustomValue::new(fn() { "t" }, fn() { true }, fn() { "" }).with_attrs(
    fn(name) { if name == "x" { Ok(Some(Value::Int(42N))) } else { Ok(None) } },
    fn() { ["x"] },
  )
  assert_true(cv.get_attr("x") is Ok(Some(Value::Int(42N))))
  assert_true(cv.get_attr("y") is Ok(None))
}

///|
test "CustomValue: contains returns None when no contains_fn" {
  let cv = CustomValue::new(fn() { "t" }, fn() { true }, fn() { "" })
  assert_true(cv.get_contains(Value::None) is None)
}

///|
test "CustomValue: contains delegates to contains_fn" {
  let items = [Value::Int(1N), Value::Int(2N)]
  let cv = CustomValue::new(fn() { "t" }, fn() { true }, fn() { "" }).with_contains(fn(
      v,
    ) {
      for item in items {
        if item.starlark_equals(v) {
          return Ok(true)
        }
      }
      Ok(false)
    },
  )
  assert_true(cv.get_contains(Value::Int(1N)) is Some(Ok(true)))
  assert_true(cv.get_contains(Value::Int(3N)) is Some(Ok(false)))
}

///|
test "Value::ExtVal type_name" {
  let cv = CustomValue::new(fn() { "my_type" }, fn() { true }, fn() { "<obj>" })
  let v = Value::ExtVal(cv)
  assert_eq(v.type_name(), "my_type")
}

///|
test "Value::ExtVal truth" {
  let cv_true = CustomValue::new(fn() { "t" }, fn() { true }, fn() { "" })
  let cv_false = CustomValue::new(fn() { "f" }, fn() { false }, fn() { "" })
  assert_eq(Value::ExtVal(cv_true).truth(), true)
  assert_eq(Value::ExtVal(cv_false).truth(), false)
}

///|
test "Value::ExtVal repr" {
  let cv = CustomValue::new(fn() { "t" }, fn() { true }, fn() { "<custom>" })
  assert_eq(Value::ExtVal(cv).repr(), "<custom>")
}

///|
test "Value::ExtVal hash Err when no hash_fn" {
  let cv = CustomValue::new(fn() { "my_type" }, fn() { true }, fn() { "" })
  assert_true(Value::hash(Value::ExtVal(cv)) is Err(_))
}

///|
test "Value::ExtVal hash delegates to hash_fn" {
  let cv = CustomValue::new(fn() { "t" }, fn() { true }, fn() { "" }).with_hash(fn() {
      Ok(99U)
    },
  )
  assert_true(Value::hash(Value::ExtVal(cv)) is Ok(99U))
}

///|
test "CustomValue: binary_fn dispatches addition" {
  let cv = CustomValue::new(fn() { "counter" }, fn() { true }, fn() {
    "<counter>"
  }).with_binary(fn(op, rhs, _is_left) {
    if op == "+" {
      match rhs {
        Value::Int(n) => Some(Ok(Value::Int(n + 100N)))
        _ => None
      }
    } else {
      None
    }
  })
  match cv.get_binary("+", Value::Int(5N), true) {
    Some(Ok(Value::Int(105N))) => ()
    _ => fail("expected Some(Ok(105))")
  }
  assert_true(cv.get_binary("-", Value::Int(5N), true) is None)
}

///|
test "CustomValue: unary_fn dispatches negation" {
  let cv = CustomValue::new(fn() { "num" }, fn() { true }, fn() { "" }).with_unary(fn(
      op,
    ) {
      if op == "-" {
        Some(Ok(Value::Int(-42N)))
      } else {
        None
      }
    },
  )
  assert_true(cv.get_unary("-") is Some(Ok(Value::Int(-42N))))
  assert_true(cv.get_unary("+") is None)
}

///|
test "CustomValue: binary_fn returns None when no binary_fn set" {
  let cv = CustomValue::new(fn() { "t" }, fn() { true }, fn() { "" })
  assert_true(cv.get_binary("+", Value::Int(1N), true) is None)
}

///|
test "CustomValue: unary_fn returns None when no unary_fn set" {
  let cv = CustomValue::new(fn() { "t" }, fn() { true }, fn() { "" })
  assert_true(cv.get_unary("-") is None)
}

///|
test "CustomValue: compare_fn dispatches ordering" {
  let cv = CustomValue::new(fn() { "num" }, fn() { true }, fn() { "" }).with_compare(fn(
      other,
    ) {
      match other {
        Value::Int(n) => Some(if n > 5N { -1 } else if n < 5N { 1 } else { 0 })
        _ => None
      }
    },
  )
  assert_true(cv.get_compare(Value::Int(5N)) == Some(0))
  assert_true(cv.get_compare(Value::Int(6N)) == Some(-1))
  assert_true(cv.get_compare(Value::Int(4N)) == Some(1))
  assert_true(cv.get_compare(Value::None) == None)
}

///|
test "CustomValue: compare_fn returns None when no compare_fn set" {
  let cv = CustomValue::new(fn() { "t" }, fn() { true }, fn() { "" })
  assert_true(cv.get_compare(Value::Int(1N)) == None)
}

///|
test "CustomValue: get_index_fn dispatches subscript read" {
  let items = [Value::Int(10N), Value::Int(20N), Value::Int(30N)]
  let cv = CustomValue::new(fn() { "myseq" }, fn() { true }, fn() { "" })
    .with_length(fn() { items.length() })
    .with_get_index(fn(i) { Ok(items[i]) })
  assert_true(cv.get_index(0) is Ok(Value::Int(10N)))
  assert_true(cv.get_index(2) is Ok(Value::Int(30N)))
}

///|
test "CustomValue: get_index returns Err when no get_index_fn" {
  let cv = CustomValue::new(fn() { "myseq" }, fn() { true }, fn() { "" })
  assert_true(cv.get_index(0) is Err(_))
}

///|
test "CustomValue: set_index_fn dispatches subscript write" {
  let items = [Value::Int(10N), Value::Int(20N)]
  let cv = CustomValue::new(fn() { "myseq" }, fn() { true }, fn() { "" })
    .with_length(fn() { items.length() })
    .with_set_index(fn(i, v) {
      items[i] = v
      Ok(())
    })
  let result = cv.do_set_index(0, Value::Int(99N))
  assert_true(result is Some(Ok(_)))
  assert_true(items[0] == Value::Int(99N))
}

///|
test "CustomValue: do_set_index returns None when no set_index_fn" {
  let cv = CustomValue::new(fn() { "myseq" }, fn() { true }, fn() { "" })
  assert_true(cv.do_set_index(0, Value::Int(1N)) is None)
}

///|
test "CustomValue: slice_fn dispatches slice operation" {
  let items = [Value::Int(0N), Value::Int(1N), Value::Int(2N), Value::Int(3N)]
  let cv = CustomValue::new(fn() { "myseq" }, fn() { true }, fn() { "" })
    .with_length(fn() { items.length() })
    .with_slice(fn(start, stop, step) {
      let result : Array[Value] = []
      let mut i = start
      while i < stop {
        result.push(items[i])
        i += step
      }
      Ok(Value::Tuple(result))
    })
  match cv.do_slice(1, 3, 1) {
    Some(Ok(Value::Tuple(t))) => assert_eq(t.length(), 2)
    _ => fail("expected Some(Ok(Tuple))")
  }
}

///|
test "CustomValue: do_slice returns None when no slice_fn" {
  let cv = CustomValue::new(fn() { "myseq" }, fn() { true }, fn() { "" })
  assert_true(cv.do_slice(0, 1, 1) is None)
}

///|
test "CustomValue: items_fn dispatches items retrieval" {
  let key = Value::String(StarlarkString::new("a"))
  let val = Value::Int(1N)
  let cv = CustomValue::new(fn() { "mymap" }, fn() { true }, fn() { "" }).with_items(fn() {
      Ok([(key, val)])
    },
  )
  match cv.get_items() {
    Some(Ok(items)) => assert_eq(items.length(), 1)
    _ => fail("expected Some(Ok)")
  }
}

///|
test "CustomValue: get_items returns None when no items_fn" {
  let cv = CustomValue::new(fn() { "mymap" }, fn() { true }, fn() { "" })
  assert_true(cv.get_items() is None)
}

///|
test "HasSetIndex protocol: set_index updates element" {
  let items = [Value::Int(1N), Value::Int(2N), Value::Int(3N)]
  let seq : SimpleSeq = { items, }
  assert_true(seq.set_index(1, Value::Int(99N)) is Ok(_))
  assert_true(items[1] == Value::Int(99N))
}

///|
test "TotallyOrdered protocol: cmp returns negative when less" {
  let a : SimpleInt = { val: 3, }
  match a.cmp(Value::Int(5N)) {
    Some(n) => assert_true(n < 0)
    None => fail("expected Some")
  }
}

///|
test "TotallyOrdered protocol: cmp returns zero when equal" {
  let a : SimpleInt = { val: 5, }
  match a.cmp(Value::Int(5N)) {
    Some(n) => assert_eq(n, 0)
    None => fail("expected Some")
  }
}

///|
test "TotallyOrdered protocol: cmp returns positive when greater" {
  let a : SimpleInt = { val: 7, }
  match a.cmp(Value::Int(5N)) {
    Some(n) => assert_true(n > 0)
    None => fail("expected Some")
  }
}

///|
test "TotallyOrdered protocol: cmp returns None for incompatible type" {
  let a : SimpleInt = { val: 3, }
  assert_true(a.cmp(Value::None) == None)
}

///|
test "Sliceable protocol: slice returns sub-sequence" {
  let s : SimpleSeq = {
    items: [Value::Int(0N), Value::Int(1N), Value::Int(2N)],
  }
  match s.slice(0, 2, 1) {
    Ok(Value::Tuple(t)) => assert_eq(t.length(), 2)
    _ => fail("expected Ok(Tuple)")
  }
}

///|
test "IterableMapping protocol: items returns all key-value pairs" {
  let m : SimpleMap = {
    data: [
      (Value::Int(1N), Value::Bool(true)),
      (Value::Int(2N), Value::Bool(false)),
    ],
  }
  match m.items() {
    Ok(pairs) => {
      assert_eq(pairs.length(), 2)
      assert_true(pairs[0] == (Value::Int(1N), Value::Bool(true)))
    }
    Err(e) => fail("unexpected error: \{e}")
  }
}
