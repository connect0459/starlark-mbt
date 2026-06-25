///|
/// Conservative pre-allocation cap for the native backend. Native cannot catch
/// OS-level overcommit faults (SIGSEGV), so large allocations that JS/wasm-gc
/// handle gracefully must be rejected here before the OS request is issued.
/// On non-native backends this equals `max_alloc` (the shared starlark-go
/// overflow guard), preserving identical reject semantics on those targets.
let max_alloc_native : Int = 134_217_728
