// Iterator protocol for Starlark values.
// Supports: List, Tuple, Dict (keys), Set (keys), Range,
//           StringElems, StringCodepoints, BytesElems, ExtVal.

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
///
/// Returns `Some(v)` with the next element, or `None` when iteration is
/// complete.
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
/// Drains the iterator into a fresh array, calling `done()` once exhausted.
///
/// Returns every remaining element in iteration order.
pub fn StarlarkIterator::collect(self : StarlarkIterator) -> Array[Value] {
  let items : Array[Value] = []
  while true {
    match self.next() {
      None => {
        self.done()
        break
      }
      Some(v) => items.push(v)
    }
  }
  items
}

///|
/// Returns a `StarlarkIterator` over `v`. Returns `Err` if `v` is not iterable.
/// Supported types: `List`, `Tuple`, `Dict` (keys), `Set` (keys),
/// `Range`, string `elems`/`codepoints`, bytes `elems`, and `ExtVal` with an
/// `iterate` callback.
///
/// Parameters:
///
/// - `v` : The Starlark value to iterate over.
///
/// Returns `Ok(iterator)` for iterable values, or `Err` with a message like
/// `"int value is not iterable"` for non-iterable types.
pub fn iterate(v : Value) -> Result[StarlarkIterator, String] {
  match v {
    List(l) => Ok(list_iter(l))
    Tuple(t) => Ok(tuple_iter(t))
    Dict(d) => Ok(dict_key_iter(d))
    Set(s) => Ok(set_key_iter(s))
    Range(r) => {
      let n = r.length()
      if n < 0L {
        Err("range has no len")
      } else {
        Ok(range_iter(r))
      }
    }
    StringElems(e) => Ok(string_elems_iter(e))
    StringCodepoints(c) => Ok(string_codepoints_iter(c))
    BytesElems(e) => Ok(bytes_elems_iter(e))
    ExtVal(c) => c.get_iterate()
    _ => Err("\{v.type_name()} value is not iterable")
  }
}

///|
/// Returns the number of elements in `v` for types that have a length
/// (`String`, `Bytes`, `List`, `Tuple`, `Dict`, `Set`, `Range`, `StringElems`,
/// `ExtVal` with a `length` callback). Returns `Err` for all other types.
///
/// Parameters:
///
/// - `v` : The Starlark value to measure.
///
/// Returns `Ok(n)` with the element count, or `Err` with a message like
/// `"len: value of type int has no len"` for types without a length.
#internal(unsafe, "eval engine only; embedders use len_of")
pub fn length_of(v : Value) -> Result[Int64, String] {
  match v {
    String(s) => Ok(s.byte_len().to_int64())
    Bytes(b) => Ok(b.length().to_int64())
    List(l) => Ok(l.items.length().to_int64())
    Tuple(t) => Ok(t.length().to_int64())
    Dict(d) => Ok(d.length().to_int64())
    Set(s) => Ok(s.length().to_int64())
    Range(r) => {
      let n = r.length()
      if n < 0L {
        Err("len: value of type range has no len")
      } else {
        Ok(n)
      }
    }
    StringElems(e) => Ok(e.s.byte_len().to_int64())
    BytesElems(_) => Err("len: value of type bytes.elems has no len")
    StringCodepoints(_) =>
      Err("len: value of type string.codepoints has no len")
    ExtVal(c) => c.get_length().map(fn(n) { n.to_int64() })
    _ => Err("len: value of type \{v.type_name()} has no len")
  }
}

///|
fn list_iter(l : StarlarkList) -> StarlarkIterator {
  if !l.frozen {
    l.itercount += 1
  }
  let cur = IterCursor::{ pos: 0, }
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
  let cur = IterCursor::{ pos: 0, }
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
fn dict_key_iter(d : StarlarkDict) -> StarlarkIterator {
  d.iter_begin()
  let snap = d.keys()
  let cur = IterCursor::{ pos: 0, }
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
  let cur = IterCursor::{ pos: 0, }
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
  let len = r.length()
  let mut pos = 0L
  {
    next_fn: fn() -> Value? {
      if pos < len {
        let v = BigInt::from_int64(r.index_at(pos))
        pos += 1L
        Some(Int(v))
      } else {
        None
      }
    },
    done_fn: fn() { () },
  }
}

///|
/// Builds a `StarlarkIterator` over the byte elements of a string.
///
/// When `e.ords` is `true`, yields each byte value as an `Int`; otherwise
/// yields each byte as a one-byte `String`.
fn string_elems_iter(e : StarlarkStringElems) -> StarlarkIterator {
  let bytes = e.s.bytes
  let cur = IterCursor::{ pos: 0, }
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
/// Builds a `StarlarkIterator` over the Unicode codepoints of a string.
///
/// When `c.ords` is `true`, yields each codepoint as an `Int`; otherwise
/// yields each codepoint as a single-character `String`.
fn string_codepoints_iter(c : StarlarkStringCodepoints) -> StarlarkIterator {
  let chars = c.s.raw.to_array()
  let cur = IterCursor::{ pos: 0, }
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
          let buf = StringBuilder()
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
  let cur = IterCursor::{ pos: 0, }
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
