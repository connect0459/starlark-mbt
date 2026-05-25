// Generic insertion-ordered hash table for Starlark Dict and Set values.
// Keys and values are generic types K and V.
// Hash and equality are provided at construction time as function parameters.
//
// Design: separate chaining via slot_next links in the entries array.
// Insertion order is tracked via a doubly-linked list (ord_next / ord_prev).
// Deleted entries are recycled through a free list (free_head).

///|
let empty_idx : Int = -1

///|
let hash_zero_sentinel : UInt = 1U

///|
struct HEntry[K, V] {
  mut hash : UInt // 0 = free (unused or deleted)
  mut key : K
  mut value : V
  mut slot_next : Int // next entry in same hash chain, empty_idx = end
  mut ord_next : Int // next in insertion order, empty_idx = end
  mut ord_prev : Int // prev in insertion order, empty_idx = head
}

///|
pub(all) struct Hashtable[K, V] {
  mut slots : Array[Int]
  mut entries : Array[HEntry[K, V]]
  mut free_head : Int
  mut head : Int
  mut tail : Int
  mut live_count : Int
  mut itercount : Int
  mut frozen : Bool
  hash_fn : (K) -> Result[UInt, String]
  eq_fn : (K, K) -> Bool
  zero_key : K
  zero_val : V
}

///|
pub fn[K, V] Hashtable::new(
  hash_fn : (K) -> Result[UInt, String],
  eq_fn : (K, K) -> Bool,
  zero_key : K,
  zero_val : V,
) -> Hashtable[K, V] {
  {
    slots: Array::make(8, empty_idx),
    entries: [],
    free_head: empty_idx,
    head: empty_idx,
    tail: empty_idx,
    live_count: 0,
    itercount: 0,
    frozen: false,
    hash_fn,
    eq_fn,
    zero_key,
    zero_val,
  }
}

///|
pub fn[K, V] Hashtable::length(self : Hashtable[K, V]) -> Int {
  self.live_count
}

///|
pub fn[K, V] Hashtable::is_frozen(self : Hashtable[K, V]) -> Bool {
  self.frozen
}

///|
pub fn[K, V] Hashtable::freeze(self : Hashtable[K, V]) -> Unit {
  self.frozen = true
}

///|
fn normalize_hash(h : UInt) -> UInt {
  if h == 0U {
    hash_zero_sentinel
  } else {
    h
  }
}

///|
fn slot_of(h : UInt, cap : Int) -> Int {
  (h & (cap - 1).reinterpret_as_uint()).reinterpret_as_int()
}

///|
fn[K, V] Hashtable::alloc_entry(self : Hashtable[K, V]) -> Int {
  if self.free_head != empty_idx {
    let idx = self.free_head
    self.free_head = self.entries[idx].slot_next
    idx
  } else {
    let idx = self.entries.length()
    self.entries.push(HEntry::{
      hash: 0U,
      key: self.zero_key,
      value: self.zero_val,
      slot_next: empty_idx,
      ord_next: empty_idx,
      ord_prev: empty_idx,
    })
    idx
  }
}

///|
fn[K, V] Hashtable::maybe_grow(self : Hashtable[K, V]) -> Unit {
  let cap = self.slots.length()
  if self.live_count * 3 >= cap * 2 {
    let new_cap = cap * 2
    let new_slots = Array::make(new_cap, empty_idx)
    let mut i = self.head
    while i != empty_idx {
      let s = slot_of(self.entries[i].hash, new_cap)
      self.entries[i].slot_next = new_slots[s]
      new_slots[s] = i
      i = self.entries[i].ord_next
    }
    self.slots = new_slots
  }
}

///|
pub fn[K, V] Hashtable::iter_begin(self : Hashtable[K, V]) -> Unit {
  if !self.frozen {
    self.itercount += 1
  }
}

///|
pub fn[K, V] Hashtable::iter_end(self : Hashtable[K, V]) -> Unit {
  if !self.frozen && self.itercount > 0 {
    self.itercount -= 1
  }
}

///|
pub fn[K, V] Hashtable::insert(
  self : Hashtable[K, V],
  key : K,
  value : V,
) -> Result[Unit, String] {
  if self.frozen {
    return Err("cannot insert into frozen hash table")
  }
  if self.itercount > 0 {
    return Err("cannot insert into hash table during iteration")
  }
  let h = match (self.hash_fn)(key) {
    Err(e) => return Err(e)
    Ok(h) => normalize_hash(h)
  }
  let s = slot_of(h, self.slots.length())
  let mut idx = self.slots[s]
  while idx != empty_idx {
    if self.entries[idx].hash == h && (self.eq_fn)(self.entries[idx].key, key) {
      self.entries[idx].value = value
      return Ok(())
    }
    idx = self.entries[idx].slot_next
  }
  self.maybe_grow()
  let s2 = slot_of(h, self.slots.length())
  let new_idx = self.alloc_entry()
  self.entries[new_idx].hash = h
  self.entries[new_idx].key = key
  self.entries[new_idx].value = value
  self.entries[new_idx].slot_next = self.slots[s2]
  self.entries[new_idx].ord_next = empty_idx
  self.entries[new_idx].ord_prev = self.tail
  self.slots[s2] = new_idx
  if self.tail != empty_idx {
    self.entries[self.tail].ord_next = new_idx
  } else {
    self.head = new_idx
  }
  self.tail = new_idx
  self.live_count += 1
  Ok(())
}

///|
pub fn[K, V] Hashtable::lookup(
  self : Hashtable[K, V],
  key : K,
) -> Result[V?, String] {
  let h = match (self.hash_fn)(key) {
    Err(e) => return Err(e)
    Ok(h) => normalize_hash(h)
  }
  let s = slot_of(h, self.slots.length())
  let mut idx = self.slots[s]
  while idx != empty_idx {
    if self.entries[idx].hash == h && (self.eq_fn)(self.entries[idx].key, key) {
      return Ok(Some(self.entries[idx].value))
    }
    idx = self.entries[idx].slot_next
  }
  Ok(None)
}

///|
pub fn[K, V] Hashtable::contains(
  self : Hashtable[K, V],
  key : K,
) -> Result[Bool, String] {
  match self.lookup(key) {
    Err(e) => Err(e)
    Ok(None) => Ok(false)
    Ok(Some(_)) => Ok(true)
  }
}

///|
pub fn[K, V] Hashtable::delete(
  self : Hashtable[K, V],
  key : K,
) -> Result[Bool, String] {
  if self.frozen {
    return Err("cannot delete from frozen hash table")
  }
  if self.itercount > 0 {
    return Err("cannot delete from hash table during iteration")
  }
  let h = match (self.hash_fn)(key) {
    Err(e) => return Err(e)
    Ok(h) => normalize_hash(h)
  }
  let s = slot_of(h, self.slots.length())
  let mut prev_chain = empty_idx
  let mut idx = self.slots[s]
  while idx != empty_idx {
    if self.entries[idx].hash == h && (self.eq_fn)(self.entries[idx].key, key) {
      let next_chain = self.entries[idx].slot_next
      if prev_chain == empty_idx {
        self.slots[s] = next_chain
      } else {
        self.entries[prev_chain].slot_next = next_chain
      }
      let op = self.entries[idx].ord_prev
      let on = self.entries[idx].ord_next
      if op != empty_idx {
        self.entries[op].ord_next = on
      } else {
        self.head = on
      }
      if on != empty_idx {
        self.entries[on].ord_prev = op
      } else {
        self.tail = op
      }
      self.entries[idx].hash = 0U
      self.entries[idx].slot_next = self.free_head
      self.free_head = idx
      self.live_count -= 1
      return Ok(true)
    }
    prev_chain = idx
    idx = self.entries[idx].slot_next
  }
  Ok(false)
}

///|
pub fn[K, V] Hashtable::each_key(
  self : Hashtable[K, V],
  f : (K) -> Unit,
) -> Unit {
  let mut idx = self.head
  while idx != empty_idx {
    f(self.entries[idx].key)
    idx = self.entries[idx].ord_next
  }
}

///|
pub fn[K, V] Hashtable::each(
  self : Hashtable[K, V],
  f : (K, V) -> Unit,
) -> Unit {
  let mut idx = self.head
  while idx != empty_idx {
    f(self.entries[idx].key, self.entries[idx].value)
    idx = self.entries[idx].ord_next
  }
}
