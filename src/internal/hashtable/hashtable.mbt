// Generic insertion-ordered hash table for Starlark Dict and Set values.
// Keys and values are generic types K and V.
// Hash and equality are provided at construction time as function parameters.
//
// Design: separate chaining via slot_next links in the entries array.
// Insertion order is tracked via a doubly-linked list (ord_next / ord_prev).
// Deleted entries are recycled through a free list (free_head).

///|
let empty_idx : Int = -1

// Hash 0 is reserved as the "deleted entry" marker in the entries array.
// Any key that actually hashes to 0 is remapped to this sentinel so it
// can never be confused with a recycled slot.

///|
let hash_zero_sentinel : UInt = 1U

///|
let initial_capacity : Int = 8

///|
let load_factor_num : Int = 2

///|
let load_factor_den : Int = 3

///|
priv struct HEntry[K, V] {
  mut hash : UInt
  mut key : K
  mut value : V
  mut slot_next : Int
  mut ord_next : Int
  mut ord_prev : Int
}

///|
/// An insertion-ordered hash table used by `StarlarkDict` and `StarlarkSet`.
/// Uses open-addressing per slot and a doubly-linked list to preserve
/// insertion order. Deleted entries are recycled through a free list.
/// Mutation is rejected when the table is frozen or has active iterators.
pub struct Hashtable[K, V] {
  priv mut slots : Array[Int]
  priv mut entries : Array[HEntry[K, V]]
  priv mut free_head : Int
  priv mut head : Int
  priv mut tail : Int
  priv mut live_count : Int
  priv mut itercount : Int
  priv mut frozen : Bool
  priv hash_fn : (K) -> Result[UInt, String]
  priv eq_fn : (K, K) -> Bool
  priv zero_key : K
  priv zero_val : V
}

///|
/// Creates an empty `Hashtable` with the given hash/equality functions and
/// zero values used to initialise recycled entry slots.
pub fn[K, V] Hashtable::new(
  hash_fn : (K) -> Result[UInt, String],
  eq_fn : (K, K) -> Bool,
  zero_key : K,
  zero_val : V,
) -> Hashtable[K, V] {
  {
    slots: Array::make(initial_capacity, empty_idx),
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
/// Returns the number of live entries.
pub fn[K, V] Hashtable::length(self : Hashtable[K, V]) -> Int {
  self.live_count
}

///|
/// Returns `true` if the table has been frozen.
pub fn[K, V] Hashtable::is_frozen(self : Hashtable[K, V]) -> Bool {
  self.frozen
}

///|
/// Marks the table as frozen; subsequent mutation attempts return `Err`.
pub fn[K, V] Hashtable::freeze(self : Hashtable[K, V]) -> Unit {
  self.frozen = true
}

///|
/// Removes all entries and resets to `initial_capacity`. Fails if frozen or
/// being iterated.
pub fn[K, V] Hashtable::clear(self : Hashtable[K, V]) -> Result[Unit, String] {
  if self.frozen {
    return Err("cannot clear frozen hash table")
  }
  if self.itercount > 0 {
    return Err("cannot clear hash table during iteration")
  }
  self.slots = Array::make(initial_capacity, empty_idx)
  self.entries = []
  self.free_head = empty_idx
  self.head = empty_idx
  self.tail = empty_idx
  self.live_count = 0
  Ok(())
}

///|
/// Removes and returns the first (oldest) entry in insertion order, or `None`
/// if empty. Fails if the table is frozen or being iterated.
pub fn[K, V] Hashtable::pop_first(
  self : Hashtable[K, V],
) -> Result[(K, V)?, String] {
  if self.frozen {
    return Err("cannot delete from frozen hash table")
  }
  if self.itercount > 0 {
    return Err("cannot delete from hash table during iteration")
  }
  if self.head == empty_idx {
    return Ok(None)
  }
  let idx = self.head
  let key = self.entries[idx].key
  let val = self.entries[idx].value
  let h = self.entries[idx].hash
  let s = slot_of(h, self.slots.length())
  let mut prev_chain = empty_idx
  let mut chain_idx = self.slots[s]
  while chain_idx != empty_idx {
    if chain_idx == idx {
      let next_chain = self.entries[chain_idx].slot_next
      if prev_chain == empty_idx {
        self.slots[s] = next_chain
      } else {
        self.entries[prev_chain].slot_next = next_chain
      }
      break
    }
    prev_chain = chain_idx
    chain_idx = self.entries[chain_idx].slot_next
  }
  let on = self.entries[idx].ord_next
  self.head = on
  if on != empty_idx {
    self.entries[on].ord_prev = empty_idx
  } else {
    self.tail = empty_idx
  }
  self.entries[idx].hash = 0U
  self.entries[idx].slot_next = self.free_head
  self.free_head = idx
  self.live_count -= 1
  Ok(Some((key, val)))
}

// Maps a raw hash to a stored hash, replacing 0 with the sentinel value
// so that stored 0U always means "deleted entry" in the entries array.

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
  if self.live_count * load_factor_den >= cap * load_factor_num {
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
/// Marks the start of an iteration. Unfrozen tables increment the iterator
/// count, preventing mutation until `iter_end` is called.
pub fn[K, V] Hashtable::iter_begin(self : Hashtable[K, V]) -> Unit {
  if !self.frozen {
    self.itercount += 1
  }
}

///|
/// Marks the end of an iteration, decrementing the iterator count. Must be
/// called even if iteration exits early.
pub fn[K, V] Hashtable::iter_end(self : Hashtable[K, V]) -> Unit {
  if !self.frozen && self.itercount > 0 {
    self.itercount -= 1
  }
}

///|
/// Inserts or replaces the entry for `key`. Fails if the table is frozen or
/// being iterated, or if `hash_fn(key)` returns an error.
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
/// Returns `Ok(Some(v))` if `key` is present, `Ok(None)` if absent, or
/// `Err` if hashing fails.
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
/// Returns `Ok(true)` if `key` is present, `Ok(false)` if absent, or
/// `Err` if hashing fails.
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
/// Removes `key` from the table. Returns `Ok(true)` if the key was present,
/// `Ok(false)` if absent. Fails if the table is frozen or being iterated.
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
/// Calls `f(key)` for each key in insertion order.
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
/// Calls `f(key, value)` for each entry in insertion order.
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
