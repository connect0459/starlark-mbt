// Compile-time constant-pool element. Mirrors starlark-go's
// `Program.Constants []any` (which holds string|int64|float64|*big.Int|Bytes):
// the pool carries only primitive literal *carriers*, never runtime `Value`s,
// so this package has no dependency on the `value` package. The VM materializes
// each `Const` into a `Value` when it executes the `Constant` opcode.

///|
pub(all) enum Const {
  CNone
  CBool(Bool)
  CInt(BigInt)
  CFloat(Double)
  CStr(String)
  CBytes(Bytes)
} derive(Eq)
