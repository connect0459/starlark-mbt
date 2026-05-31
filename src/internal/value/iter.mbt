// Iterator protocol for Starlark values.
// Supports: List, Tuple, String (bytes), Bytes (ints), Dict (keys),
//           Set (keys), Range.

///|
priv struct IterCursor {
  mut pos : Int
}

///|
/// A forward-only cursor over a Starlark sequence or mapping.
/// Call `next()` to advance; call `done()` when iteration is finished,
/// even on early exit, to release any frozen-state hold on the container.
pub struct StarlarkIterator {
  priv next_fn : () -> Value?
  priv done_fn : () -> Unit
}

///|
/// Advances the iterator and returns the next value, or `None` when exhausted.
pub fn StarlarkIterator::next(self : StarlarkIterator) -> Value? {
  (self.next_fn)()
}

///|
/// Signals that iteration is complete, releasing any frozen-state hold on the
/// container. Must be called even on early exit (e.g. `break`).
pub fn StarlarkIterator::done(self : StarlarkIterator) -> Unit {
  (self.done_fn)()
}

///|
/// Returns a `StarlarkIterator` over `v`. Returns `Err` if `v` is not iterable.
/// Supported types: `List`, `Tuple`, `Bytes`, `Dict` (keys), `Set` (keys),
/// `Range`, string `elems`/`codepoints`, bytes `elems`, and `ExtVal` with an
/// `iterate` callback.
pub fn iterate(v : Value) -> Result[StarlarkIterator, String] {
  match v {
    List(l) => Ok(list_iter(l))
    Tuple(t) => Ok(tuple_iter(t))
    Bytes(b) => Ok(bytes_elem_iter(b))
    Dict(d) => Ok(dict_key_iter(d))
    Set(s) => Ok(set_key_iter(s))
    Range(r) => Ok(range_iter(r))
    StringElems(e) => Ok(string_elems_iter(e))
    StringCodepoints(c) => Ok(string_codepoints_iter(c))
    BytesElems(e) => Ok(bytes_elems_iter(e))
    ExtVal(c) => c.get_iterate()
    _ => Err("\{type_name(v)} value is not iterable")
  }
}

///|
/// Returns the number of elements in `v` for types that have a length
/// (`String`, `Bytes`, `List`, `Tuple`, `Dict`, `Set`, `Range`, `StringElems`,
/// `ExtVal` with a `length` callback). Returns `Err` for all other types.
pub fn length_of(v : Value) -> Result[Int, String] {
  match v {
    String(s) => Ok(s.byte_len())
    Bytes(b) => Ok(b.length())
    List(l) => Ok(l.items.length())
    Tuple(t) => Ok(t.length())
    Dict(d) => Ok(d.length())
    Set(s) => Ok(s.length())
    Range(r) => Ok(r.length())
    StringElems(e) => Ok(e.s.byte_len())
    BytesElems(_) => Err("len: value of type bytes.elems has no len")
    StringCodepoints(_) =>
      Err("len: value of type string.codepoints has no len")
    ExtVal(c) => c.get_length()
    _ => Err("len: value of type \{type_name(v)} has no len")
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
        let byte_int = BigInt::from_int(b[cur.pos].to_int())
        cur.pos += 1
        Some(Int(byte_int))
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
        let v = BigInt::from_int64(r.index_at(cur.pos))
        cur.pos += 1
        Some(Int(v))
      } else {
        None
      }
    },
    done_fn: fn() { () },
  }
}

///|
fn string_elems_iter(e : StarlarkStringElems) -> StarlarkIterator {
  let bytes = e.s.bytes
  let cur = IterCursor::{ pos: 0 }
  if e.ords {
    {
      next_fn: fn() -> Value? {
        if cur.pos < bytes.length() {
          let v = Int(BigInt::from_int(bytes[cur.pos].to_int()))
          cur.pos += 1
          Some(v)
        } else {
          None
        }
      },
      done_fn: fn() { () },
    }
  } else {
    {
      next_fn: fn() -> Value? {
        if cur.pos < bytes.length() {
          let one = Bytes::from_array([bytes[cur.pos]])
          cur.pos += 1
          Some(String(StarlarkString::from_bytes(one)))
        } else {
          None
        }
      },
      done_fn: fn() { () },
    }
  }
}

///|
fn string_codepoints_iter(c : StarlarkStringCodepoints) -> StarlarkIterator {
  let chars = c.s.raw.to_array()
  let cur = IterCursor::{ pos: 0 }
  if c.ords {
    {
      next_fn: fn() -> Value? {
        if cur.pos < chars.length() {
          let v = Int(BigInt::from_int(chars[cur.pos].to_int()))
          cur.pos += 1
          Some(v)
        } else {
          None
        }
      },
      done_fn: fn() { () },
    }
  } else {
    {
      next_fn: fn() -> Value? {
        if cur.pos < chars.length() {
          let buf = StringBuilder::new()
          buf.write_char(chars[cur.pos])
          cur.pos += 1
          Some(String(StarlarkString::new(buf.to_string())))
        } else {
          None
        }
      },
      done_fn: fn() { () },
    }
  }
}

///|
fn bytes_elems_iter(e : StarlarkBytesElems) -> StarlarkIterator {
  let b = e.b
  let cur = IterCursor::{ pos: 0 }
  {
    next_fn: fn() -> Value? {
      if cur.pos < b.length() {
        let v = Int(BigInt::from_int(b[cur.pos].to_int()))
        cur.pos += 1
        Some(v)
      } else {
        None
      }
    },
    done_fn: fn() { () },
  }
}
