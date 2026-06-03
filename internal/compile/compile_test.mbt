///|
/// Every opcode survives a byte encode/decode round-trip, and the byte values
/// are dense and unique across the whole set.
test "opcode byte encoding round-trips and is dense" {
  let ops = @compile.all_opcodes()
  let seen : Array[Bool] = Array::make(ops.length(), false)
  for i, op in ops {
    let b = op.to_byte()
    // byte value equals the declaration index (dense, gap-free, ordered)
    assert_eq(b.to_int(), i)
    // unique
    assert_true(!seen[b.to_int()])
    seen[b.to_int()] = true
    // decode recovers the same opcode (compared by byte; Opcode has no Show)
    match @compile.Opcode::from_byte(b) {
      Some(decoded) => assert_eq(decoded.to_byte(), b)
      None => fail("opcode \{i} failed to decode")
    }
  }
}

///|
/// `from_byte` rejects byte values that are not opcodes.
test "from_byte rejects out-of-range bytes" {
  assert_true(@compile.Opcode::from_byte(b'\xFF') is None)
  assert_true(@compile.Opcode::from_byte(b'\x68') is None) // one past CallVarKw
}

///|
/// The argument boundary matches the documented `op_arg_min`: `Jmp` and beyond
/// carry an operand; everything below does not.
test "has_arg follows the op_arg_min boundary" {
  assert_true(!@compile.Opcode::Pop.has_arg())
  assert_true(!@compile.Opcode::MakeDict.has_arg())
  assert_true(@compile.Opcode::Jmp.has_arg())
  assert_true(@compile.Opcode::Constant.has_arg())
  assert_true(@compile.Opcode::CallVarKw.has_arg())
  assert_eq(@compile.Opcode::Jmp.to_byte().to_int(), @compile.op_arg_min)
}

///|
/// `Funcode::position` finds the last line-table entry at or before the queried
/// pc, and falls back to the definition position before the first entry.
test "funcode position recovers source line and column from pc" {
  let def_pos = @errors.Position::new("f.star", 1, 1)
  let fc = @compile.Funcode::{
    pos: def_pos,
    name: "f",
    doc: "",
    code: Bytes::from_array([]),
    pclinetab: [
      @compile.PcLine::{ pc: 0, line: 2, col: 3 },
      @compile.PcLine::{ pc: 5, line: 4, col: 1 },
      @compile.PcLine::{ pc: 9, line: 7, col: 8 },
    ],
    locals: [],
    cells: [],
    freevars: [],
    max_stack: 0,
    num_params: 0,
    num_kwonly_params: 0,
    has_varargs: false,
    has_kwargs: false,
    params: [],
  }
  // exact hits
  assert_eq(fc.position(0).line(), 2)
  assert_eq(fc.position(0).col(), 3)
  assert_eq(fc.position(5).line(), 4)
  assert_eq(fc.position(9).line(), 7)
  assert_eq(fc.position(9).col(), 8)
  // between entries -> last entry at or before pc
  assert_eq(fc.position(4).line(), 2)
  assert_eq(fc.position(8).line(), 4)
  assert_eq(fc.position(100).line(), 7)
  // filename always from the definition position
  assert_eq(fc.position(5).filename(), "f.star")
}

///|
/// An empty line table falls back to the definition position for any pc.
test "funcode position falls back to def position with empty line table" {
  let def_pos = @errors.Position::new("g.star", 10, 2)
  let fc = @compile.Funcode::{
    pos: def_pos,
    name: "g",
    doc: "",
    code: Bytes::from_array([]),
    pclinetab: [],
    locals: [],
    cells: [],
    freevars: [],
    max_stack: 0,
    num_params: 0,
    num_kwonly_params: 0,
    has_varargs: false,
    has_kwargs: false,
    params: [],
  }
  assert_eq(fc.position(0).line(), 10)
  assert_eq(fc.position(50).col(), 2)
}
