// Insertion-ordered hash table for Starlark Dict and Set values.
// Keys are any Starlark hashable value.
//
// Design: open-addressing via a slots array (power-of-2 size) with separate
// chaining per slot (slot_next links). Insertion order is tracked via a
// doubly-linked list (order_next / order_prev) over the entries array.
// Deleted entries are recycled through a free list (free_head).

///|
let empty_idx : Int = -1

///|
let hash_zero_sentinel : UInt = 1U

///|
struct HEntry {
  mut hash : UInt // 0 = free (unused or deleted)
  mut key : @value.Value
  mut value : @value.Value
  mut slot_next : Int // next entry in same hash chain, empty_idx = end
  mut ord_next : Int // next in insertion order, empty_idx = end
  mut ord_prev : Int // prev in insertion order, empty_idx = head
}

///|
pub(all) struct Hashtable {
  mut slots : Array[Int] // slot index -> first entry idx, empty_idx = empty
  mut entries : Array[HEntry]
  mut free_head : Int // head of free-entry linked list, empty_idx = none
  mut head : Int // first live entry in insertion order
  mut tail : Int // last live entry in insertion order
  mut live_count : Int
  mut itercount : Int
  mut frozen : Bool
}

///|
pub fn Hashtable::new() -> Hashtable {
  let initial_slots = 8
  {
    slots: Array::make(initial_slots, empty_idx),
    entries: [],
    free_head: empty_idx,
    head: empty_idx,
    tail: empty_idx,
    live_count: 0,
    itercount: 0,
    frozen: false,
  }
}

///|
pub fn Hashtable::length(self : Hashtable) -> Int {
  self.live_count
}

///|
pub fn Hashtable::is_frozen(self : Hashtable) -> Bool {
  self.frozen
}

///|
pub fn Hashtable::freeze(self : Hashtable) -> Unit {
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
fn Hashtable::alloc_entry(self : Hashtable) -> Int {
  if self.free_head != empty_idx {
    let idx = self.free_head
    self.free_head = self.entries[idx].slot_next
    idx
  } else {
    let idx = self.entries.length()
    self.entries.push(HEntry::{
      hash: 0U,
      key: @value.Value::NoneVal,
      value: @value.Value::NoneVal,
      slot_next: empty_idx,
      ord_next: empty_idx,
      ord_prev: empty_idx,
    })
    idx
  }
}

///|
fn Hashtable::maybe_grow(self : Hashtable) -> Unit {
  let cap = self.slots.length()
  // Grow when load factor exceeds 2/3
  if self.live_count * 3 >= cap * 2 {
    let new_cap = cap * 2
    let new_slots = Array::make(new_cap, empty_idx)
    // Re-chain all live entries into new slots
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
pub fn Hashtable::insert(
  self : Hashtable,
  key : @value.Value,
  value : @value.Value,
) -> Result[Unit, String] {
  if self.frozen {
    return Err("cannot insert into frozen hash table")
  }
  let h = match @value.starlark_hash(key) {
    Err(e) => return Err(e)
    Ok(h) => normalize_hash(h)
  }

  // Check for existing key and update in place
  let s = slot_of(h, self.slots.length())
  let mut idx = self.slots[s]
  while idx != empty_idx {
    if self.entries[idx].hash == h &&
      @value.starlark_equals(self.entries[idx].key, key) {
      self.entries[idx].value = value
      return Ok(())
    }
    idx = self.entries[idx].slot_next
  }

  // Grow if needed, then recompute slot
  self.maybe_grow()
  let s2 = slot_of(h, self.slots.length())

  // Allocate and initialize new entry
  let new_idx = self.alloc_entry()
  self.entries[new_idx].hash = h
  self.entries[new_idx].key = key
  self.entries[new_idx].value = value
  self.entries[new_idx].slot_next = self.slots[s2]
  self.entries[new_idx].ord_next = empty_idx
  self.entries[new_idx].ord_prev = self.tail
  self.slots[s2] = new_idx

  // Append to insertion-order list
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
pub fn Hashtable::lookup(
  self : Hashtable,
  key : @value.Value,
) -> Result[@value.Value?, String] {
  let h = match @value.starlark_hash(key) {
    Err(e) => return Err(e)
    Ok(h) => normalize_hash(h)
  }
  let s = slot_of(h, self.slots.length())
  let mut idx = self.slots[s]
  while idx != empty_idx {
    if self.entries[idx].hash == h &&
      @value.starlark_equals(self.entries[idx].key, key) {
      return Ok(Some(self.entries[idx].value))
    }
    idx = self.entries[idx].slot_next
  }
  Ok(None)
}

///|
pub fn Hashtable::contains(
  self : Hashtable,
  key : @value.Value,
) -> Result[Bool, String] {
  match self.lookup(key) {
    Err(e) => Err(e)
    Ok(None) => Ok(false)
    Ok(Some(_)) => Ok(true)
  }
}

///|
pub fn Hashtable::delete(
  self : Hashtable,
  key : @value.Value,
) -> Result[Bool, String] {
  if self.frozen {
    return Err("cannot delete from frozen hash table")
  }
  let h = match @value.starlark_hash(key) {
    Err(e) => return Err(e)
    Ok(h) => normalize_hash(h)
  }
  let s = slot_of(h, self.slots.length())

  // Find entry in hash chain and track predecessor
  let mut prev_chain = empty_idx
  let mut idx = self.slots[s]
  while idx != empty_idx {
    if self.entries[idx].hash == h &&
      @value.starlark_equals(self.entries[idx].key, key) {
      // Remove from slot chain
      let next_chain = self.entries[idx].slot_next
      if prev_chain == empty_idx {
        self.slots[s] = next_chain
      } else {
        self.entries[prev_chain].slot_next = next_chain
      }

      // Remove from insertion-order list
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

      // Recycle entry into free list
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
pub fn Hashtable::each_key(
  self : Hashtable,
  f : (@value.Value) -> Unit,
) -> Unit {
  let mut idx = self.head
  while idx != empty_idx {
    f(self.entries[idx].key)
    idx = self.entries[idx].ord_next
  }
}

///|
pub fn Hashtable::each(
  self : Hashtable,
  f : (@value.Value, @value.Value) -> Unit,
) -> Unit {
  let mut idx = self.head
  while idx != empty_idx {
    f(self.entries[idx].key, self.entries[idx].value)
    idx = self.entries[idx].ord_next
  }
}
