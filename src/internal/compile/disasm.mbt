// Disassembler: decode a Funcode's instruction stream back into a list of
// (pc, opcode, operand) triples. Used by tests to assert the compiler emits the
// expected bytecode, and as a debugging aid for the VM.

///|
/// A single decoded instruction: its byte offset, opcode, and operand (0 for
/// opcodes that take no operand).
pub(all) struct Instr {
  pc : Int
  op : Opcode
  arg : Int
} derive(Eq)

///|
priv suberror DisasmErr {
  DisasmErr(String)
}

///|
/// Reads a uvarint from `code` starting at `pc`, returning the decoded value and
/// the offset just past it.
fn read_uvarint(code : Bytes, pc : Int) -> (Int, Int) raise DisasmErr {
  let mut result = 0
  let mut shift = 0
  let mut i = pc
  for _ in 0..<5 {
    if i >= code.length() {
      raise DisasmErr("truncated operand")
    }
    let b = code[i].to_int()
    i += 1
    result = result | ((b & 0x7f) << shift)
    if (b & 0x80) == 0 {
      return (result, i)
    }
    shift += 7
  }
  raise DisasmErr("operand too long")
}

///|
/// Decodes the full instruction stream of a `Funcode` into a list of `Instr`.
/// Aborts on a malformed stream (an internal invariant violation, never expected
/// for compiler output).
pub fn Funcode::disasm(self : Funcode) -> Array[Instr] {
  decode_code(self.code) catch {
    DisasmErr(msg) => abort("disasm: \{msg}")
  }
}

///|
fn decode_code(code : Bytes) -> Array[Instr] raise DisasmErr {
  let out : Array[Instr] = []
  let mut pc = 0
  while pc < code.length() {
    let start = pc
    let op = match Opcode::from_byte(code[pc]) {
      Some(o) => o
      None =>
        raise DisasmErr("invalid opcode byte \{code[pc].to_int()} at \{pc}")
    }
    pc += 1
    let arg = if op.has_arg() {
      let (v, next) = read_uvarint(code, pc)
      pc = next
      v
    } else {
      0
    }
    out.push(Instr::{ pc: start, op, arg, })
  }
  out
}
