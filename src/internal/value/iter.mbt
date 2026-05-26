// Iterator protocol for Starlark values.
// Supports: List, Tuple, String (bytes), Bytes (ints), Dict (keys),
//           Set (keys), Range.

///|
priv struct IterCursor {
  mut pos : Int
}

///|
pub struct StarlarkIterator {
  next_fn : () -> Value?
  done_fn : () -> Unit
}

///|
pub fn StarlarkIterator::next(self : StarlarkIterator) -> Value? {
  (self.next_fn)()
}

///|
pub fn StarlarkIterator::done(self : StarlarkIterator) -> Unit {
  (self.done_fn)()
}

///|
pub fn iterate(v : Value) -> Result[StarlarkIterator, String] {
  match v {
    ListVal(l) => Ok(list_iter(l))
    TupleVal(t) => Ok(tuple_iter(t))
    BytesVal(b) => Ok(bytes_elem_iter(b))
    DictVal(d) => Ok(dict_key_iter(d))
    SetVal(s) => Ok(set_key_iter(s))
    RangeVal(r) => Ok(range_iter(r))
    _ => Err("'\{type_name(v)}' object is not iterable")
  }
}

///|
pub fn length_of(v : Value) -> Result[Int, String] {
  match v {
    StrVal(s) => Ok(s.byte_len())
    BytesVal(b) => Ok(b.length())
    ListVal(l) => Ok(l.items.length())
    TupleVal(t) => Ok(t.length())
    DictVal(d) => Ok(d.length())
    SetVal(s) => Ok(s.length())
    RangeVal(r) => Ok(r.length())
    _ => Err("object of type '\{type_name(v)}' has no len()")
  }
}

///|
fn list_iter(l : StarlarkList) -> StarlarkIterator {
  if !l.frozen {
    l.itercount += 1
  }
  let cur = IterCursor::{ pos: 0 }
  {
    next_fn: fn() -> Value? {
      if cur.pos < l.items.length() {
        let v = l.items[cur.pos]
        cur.pos += 1
        Some(v)
      } else {
        None
      }
    },
    done_fn: fn() { if !l.frozen && l.itercount > 0 { l.itercount -= 1 } },
  }
}

///|
fn tuple_iter(t : Array[Value]) -> StarlarkIterator {
  let cur = IterCursor::{ pos: 0 }
  {
    next_fn: fn() -> Value? {
      if cur.pos < t.length() {
        let v = t[cur.pos]
        cur.pos += 1
        Some(v)
      } else {
        None
      }
    },
    done_fn: fn() { () },
  }
}

///|
fn bytes_elem_iter(b : Bytes) -> StarlarkIterator {
  let cur = IterCursor::{ pos: 0 }
  {
    next_fn: fn() -> Value? {
      if cur.pos < b.length() {
        let byte_int = b[cur.pos].to_int().to_int64()
        cur.pos += 1
        Some(IntVal(byte_int))
      } else {
        None
      }
    },
    done_fn: fn() { () },
  }
}

///|
fn dict_key_iter(d : StarlarkDict) -> StarlarkIterator {
  d.iter_begin()
  let snap = d.keys()
  let cur = IterCursor::{ pos: 0 }
  {
    next_fn: fn() -> Value? {
      if cur.pos < snap.length() {
        let k = snap[cur.pos]
        cur.pos += 1
        Some(k)
      } else {
        None
      }
    },
    done_fn: fn() { d.iter_end() },
  }
}

///|
fn set_key_iter(s : StarlarkSet) -> StarlarkIterator {
  s.iter_begin()
  let snap : Array[Value] = []
  s.each(fn(k) { snap.push(k) })
  let cur = IterCursor::{ pos: 0 }
  {
    next_fn: fn() -> Value? {
      if cur.pos < snap.length() {
        let k = snap[cur.pos]
        cur.pos += 1
        Some(k)
      } else {
        None
      }
    },
    done_fn: fn() { s.iter_end() },
  }
}

///|
fn range_iter(r : StarlarkRange) -> StarlarkIterator {
  let cur = IterCursor::{ pos: 0 }
  let len = r.length()
  {
    next_fn: fn() -> Value? {
      if cur.pos < len {
        let v = r.index_at(cur.pos)
        cur.pos += 1
        Some(IntVal(v))
      } else {
        None
      }
    },
    done_fn: fn() { () },
  }
}
