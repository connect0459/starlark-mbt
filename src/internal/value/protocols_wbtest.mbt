///|
struct SimpleMap {
  data : Array[(Value, Value)]
}

///|
impl Mapping for SimpleMap with fn mapping_get(self, key) {
  for kv in self.data {
    let (k, v) = kv
    if starlark_equals(k, key) {
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
test "Mapping protocol: get returns value for existing key" {
  let m : SimpleMap = { data: [(Value::Int(1L), Value::Bool(true))] }
  let result = m.mapping_get(Value::Int(1L))
  assert_true(result is Ok(Some(Value::Bool(true))))
}

///|
test "Mapping protocol: get returns None for missing key" {
  let m : SimpleMap = { data: [] }
  let result = m.mapping_get(Value::Int(42L))
  assert_true(result is Ok(None))
}

///|
test "Mapping protocol: keys returns all keys" {
  let m : SimpleMap = {
    data: [(Value::Int(1L), Value::None), (Value::Int(2L), Value::None)],
  }
  match m.mapping_keys() {
    Ok(keys) => assert_eq(keys.length(), 2)
    Err(e) => fail("unexpected error: \{e}")
  }
}

///|
test "Mapping protocol: len returns entry count" {
  let m : SimpleMap = {
    data: [(Value::Int(1L), Value::None), (Value::Int(2L), Value::None)],
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
test "Indexable protocol: get returns element at index" {
  let s : SimpleSeq = { items: [Value::Int(10L), Value::Int(20L)] }
  assert_true(s.indexable_get(0) is Ok(Value::Int(10L)))
  assert_true(s.indexable_get(1) is Ok(Value::Int(20L)))
}

///|
test "Indexable protocol: len returns sequence length" {
  let s : SimpleSeq = { items: [Value::None, Value::None, Value::None] }
  assert_eq(s.indexable_len(), 3)
}
