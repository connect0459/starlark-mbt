# Starlark.mbt Implementation Plan

Reference target: **starlark-go** semantics. All non-default features
(`AllowSet`, `AllowRecursion`, `AllowGlobalReassign`, `AllowLambda`,
`AllowBytes`, `AllowFloat`, `AllowWhile`) are implemented behind option
flags and **enabled by default**.

## Phase 0: Project Setup ✅

### Submodule: bazelbuild/starlark ✅

- [x] Add `bazelbuild/starlark` as a shallow git submodule at `testdata/bazelbuild-starlark/`
      (url: <https://github.com/bazelbuild/starlark>, shallow = true)
- [x] Update `.github/workflows/ci.yml` to sparse-clone only `test_suite/testdata/`
      instead of the WPT step. Path in repo: `testdata/bazelbuild-starlark/test_suite/testdata/`
- [x] Verified: `test_suite/testdata/go/` contains 11 official spec compliance tests:
      `assign.star`, `bool.star`, `builtins.star`, `control.star`, `dict.star`,
      `function.star`, `int.star`, `list.star`, `misc.star`, `string.star`, `tuple.star`
- Phase 7 starlarktest harness will reference these via
  `testdata/bazelbuild-starlark/test_suite/testdata/go/*.star` on native target.

- [x] Migrate to `src/` directory structure (urllib.mbt pattern)
- [x] Update `moon.mod` with `options(source: "src")`
- [x] Establish `src/starlark/` as the library package
- [x] Establish `src/main/` as the CLI entry point (kept minimal until Phase 7)

### Package layout (target)

Follow the urllib.mbt convention: keep `src/starlark/` as a thin public
façade and place implementation details under `src/internal/*` so they
are not part of the published API.

- `src/starlark/` — public façade: re-exports `Thread`, `Module`, `Value`,
  `Options`, `exec_file`, `eval`, error types
- `src/internal/errors/` — `Position`, `Span`, `SyntaxError`,
  `ResolveError`, `EvalError`, `CallFrame`, `CallStack`, `Halt`
- `src/internal/hashtable/` — insertion-ordered hashtable for `Dict` and `Set`
  (doubly-linked list + open-addressing hash table; required because Starlark
  dicts must preserve insertion order and support iteration-safe freezing).
  **Decision**: MoonBit `Map[K,V]` is a sorted tree map (NOT insertion-ordered);
  this sub-package IS required. Keys must be arbitrary Starlark hashable values
  (`None`, `Bool`, `Int`, `Float`, `String`, `Bytes`, `Tuple` of hashables) —
  not restricted to `String` as in the bitflow reference implementation.
- `src/internal/value/` — `Value` enum, traits, freeze logic
- `src/internal/lexer/` — scanner / token / quote helpers
- `src/internal/syntax/` — AST node types + walker
- `src/internal/parser/` — token-stream → AST
- `src/internal/resolver/` — name resolution & static checks
- `src/internal/eval/` — `Thread`, evaluator, control-flow signals
- `src/internal/builtins/` — predeclared functions + per-type methods
- ~~`src/internal/format/`~~ — removed (YAGNI; format logic lives in `eval/ops.mbt`)
- `src/internal/unpack/` — argument binding helper for built-ins
- `src/internal/starlarktest/` — test harness for executing `.star` scripts as
  MoonBit tests; embeds `assert.star` as a `const` string; not part of the
  public API (internal only). Created in Phase 6 before porting `.star` files.
- `src/cmd/` — CLI entry point (renamed from `src/main/` in Phase 8)
- `src/repl/` — public REPL library (eval_input, run, make_load)

Sub-packages may be added or split when any file exceeds ~600 LOC.

### Infrastructure tasks (prerequisite for Phase 0.5)

**These must be completed before any Phase 0.5+ coding begins.**

- [x] Fix `.github/workflows/ci.yml`: remove the "Setup WPT submodule" step
      that was copied from urllib.mbt — it is not needed for this project.
      Keep multi-target matrix (`js`, `wasm`, `wasm-gc`, `native`) and add a
      `moon coverage analyze` step in a follow-up (Phase 7).
      Replaced with bazelbuild/starlark sparse clone (see below).
- [x] Add `moonbitlang/x` to `moon.mod` imports (required for future BigInt
      support and other extended utilities). Pinned to `0.4.43`; verified with
      `moon check`.
- [x] Create directory skeleton for all `src/internal/*` packages:
      `errors`, `hashtable`, `value`, `lexer`, `syntax`, `parser`, `resolver`,
      `eval`, `builtins`, `format`, `unpack`. Each directory needs:
      - a `moon.pkg` file (empty or with import stubs)
      - a minimal placeholder `.mbt` file so `moon check` recognises the package
- [x] Update `src/starlark/moon.pkg` to import each internal package as needed
- [x] Verify `moon check` passes on the empty skeleton before Phase 0.5 coding
      begins (confirm no broken imports or missing package declarations)
- **Decision**: MoonBit `Map[K,V]` is a sorted tree map (NOT insertion-ordered);
  `src/internal/hashtable/` is required (see package layout note above)
- [x] Design the `Hashable` trait / key-hash protocol for hashtable, Dict, and Set;
      define hash functions for each primitive type (None, Bool, Int, Float, String, Bytes, Tuple)
      **Implementation**: generic `Hashtable[K,V]` with hash/eq fn params; no `Hashable` trait needed
- **Design decision**: `Position` column convention — use 1-based line AND 1-based column
      to match starlark-go (`Position{Line: 1, Col: 1}` for start of file). Document in
      `src/internal/errors/`.

---

## Phase 0.5: Error Infrastructure

Foundational error types and position tracking needed by all subsequent phases.

- [x] `Position` — filename, line, column. **Decision: 1-based line, 1-based col;
      0 means unknown (matches starlark-go)**. Implemented in `src/internal/errors/`.
- [x] `Span` — start + end `Position` for ranged diagnostics
- [x] `SyntaxError` — lexer/parser errors with `Position`
- [x] `ResolveError` — resolver errors with `Position`
- [x] `EvalError` — runtime errors with `Position` and call stack; `cause: String?` for chaining
- [x] `CallFrame` — function name + call site `Position`
- [x] `CallStack` — ordered list of `CallFrame` (for stack traces)
- [ ] Error severity / category enum (deferred: no use case yet)
- [x] Error chaining (carry inner cause for wrapped errors) — `cause: String?` in `EvalError`
- [x] Error formatting: `"<filename>:<line>:<col>: <message>"` plus backtrace
- [x] `Halt` / cancellation signal distinct from `EvalError`

### TDD scope

Write error formatting tests first; implementation is trivial but used everywhere.

---

## Phase 0.75: Public API & Embedding Surface ✅

Settle the public API shape before bulk implementation, so subsequent
phases don't churn the `.mbti`.

- [x] `Thread` — print callback, load callback, call stack, recursion depth limit, max execution steps
- [x] `Module` — execution result; `globals` dict; frozen after `exec_file` returns
- [x] `Universe` — predeclared bindings (built-ins) injected into modules
- [x] `Options` — feature flags. All default to **true** unless noted:
      `allow_set`, `allow_recursion`, `allow_lambda`, `allow_while`,
      `allow_bytes`, `allow_float`, `allow_global_reassign`,
      `allow_top_level_control` (top-level `if` / `for` / `while`),
      `load_binds_globally` (deprecated starlark-go flag; kept for parity)
- [x] `Predeclared` / `Universe` distinction — `Universe` is the built-in
      set (frozen, shared across threads); `Predeclared` is per-execution
      extra bindings injected before user globals
- [x] `exec_file(thread, filename, src, options) -> Module` — stub (returns Err until Phase 5)
- [x] `eval(thread, filename, expr, env) -> Value` — stub (returns Err until Phase 5)
- [x] Loader contract — `(Thread, module_path) -> Result[Module, EvalError]`
      (the loader receives the active `Thread` so it can make nested calls)
- [x] Wire up `src/starlark/` as a thin public façade: re-export `Thread`, `Module`,
      `Value`, `Options`, `exec_file`, `eval`, and error types from `src/internal/*`;
      verify `.mbti` contains only the intended public surface

### TDD scope

API shape tests (call surface, error types) — full execution tests come later.

---

## Phase 1: Value Types

Core Starlark value representation. All values share a common interface.

### Types to implement

- [x] `Value` — top-level enum covering all built-in types (primitives + List/Tuple stubs; Dict/Set/Function/Range pending)
- [x] `NoneType` — singleton `NoneVal`
- [x] `Bool` — `BoolVal(Bool)`; `truth`, `repr` implemented
      **Key semantics**: `Bool` is its own type and does NOT participate in int arithmetic.
      `True + True` raises a TypeError (unlike Python). `int(True) == 1` is valid via the
      `int()` built-in. `Bool` comparison operators (`<`, `<=`, etc.) treat False < True.
      `hash(True) == hash(1)` and `hash(False) == hash(0)` (equal values of compatible
      types must share the same hash).
- [x] `Int` — `IntVal(Int64)`; `floor_div` and `starlark_mod` implemented with
      correct negative-operand semantics (floor toward -inf, sign of divisor).
      Tests cover: `-7 // 2 == -4`, `-7 % 2 == 1`. BigInt upgrade deferred.
- [x] `Float` — `FloatVal(Double)`; `format_float` handles inf/nan/decimal-point.
      **Key semantics**: Float and Int values that compare equal must produce the same
      hash (`hash(1.0) == hash(1)`, `hash(0.0) == hash(0)`).
- [x] `String` — `StarlarkString { raw: String, bytes: Bytes }` with UTF-8 byte backing.
      `byte_len()`, `byte_at(i)`, `equals()` implemented. MoonBit UTF-16 divergence resolved.
- [x] `Bytes` — `BytesVal(Bytes)`; `repr` produces `b"..."` with `\xNN` escapes.
- [x] `List` — `StarlarkList { mut items, mut frozen }`; `truth`, `repr` implemented (stub)
- [x] `Tuple` — `TupleVal(Array[Value])`; `repr` includes trailing comma for singleton
- [x] `Dict` — mutable mapping (insertion-ordered); keys are any hashable
      Starlark value — `StarlarkDict` wraps `Hashtable[Value, Value]`
- [x] `Set` — mutable hash-set; keys are any hashable value, insertion-ordered.
      `StarlarkSet` wraps `Hashtable[Value, Value]` (value=NoneVal)
- [x] `Function` — user-defined (Starlark source); `StarlarkFunction { name, params, body, defaults, freevars }`
- [x] `BuiltinFunction` — host-provided callable; `StarlarkBuiltinFunc { name }`
- [x] `BoundMethod` — method bound to a receiver (e.g., `"abc".upper`); `StarlarkBoundMethod { recv, method_name }`
- [x] `Range` — lazy iterable returned by `range()`; not a List; `StarlarkRange { start, stop, step }`

### Traits / protocols

- [x] `repr` — implemented for primitives + List/Tuple (cycle detection deferred)
- [x] `truth` — truthiness for `if`, `while`, `and`, `or` (all current variants)
- [x] `to_str` — `str()` output (unquoted string for Str, repr for others); in `traits.mbt`
- [x] `starlark_equals` — structural equality; cross-type Int==Float supported
- [x] `starlark_hash` — FNV-1a for strings/bytes; starlark-go formula for Int/Float;
      Python tuple hash algorithm; List → `Err("unhashable type: list")`
- [x] `compare_values` — total ordering for `<`, `<=`, `>`, `>=`; same-type only
      (NaN > +Inf per starlark-go; mixed types → `Err`)
- [x] `type_name` — `type()` built-in support; canonical names implemented
- [x] `Comparable` trait — total ordering protocol needed by `sorted()`, `min()`, `max()`
      (`StarlarkComparable` stub added in `src/internal/value/protocols.mbt`)
- [x] `Attr` trait — attribute access protocol for `getattr()`, `hasattr()`, `dir()`
      (`HasAttrs`, `HasSetField` stubs added in `src/internal/value/protocols.mbt`)

### Iterator / sequence / mapping protocols

- [x] `Iterable` — `iterate(Value) -> Result[StarlarkIterator, String]` in `iter.mbt`
- [x] `Iterator` — `StarlarkIterator { next_fn, done_fn }` with `next()/done()` methods;
      `done()` decrements `itercount` on List/Dict/Set; must be called even on early exit
- [x] `IterableMapping` — dict/set iteration yields keys via `dict_key_iter`/`set_key_iter`
- [x] `Sequence` — `length_of(Value) -> Result[Int, String]` covers List/Tuple/String/Bytes/Range
- [x] `Mapping` — `Dict` key/value access protocol (embedder extension trait in `protocols.mbt`)
- [x] `Indexable` — supports `a[i]` (embedder extension trait in `protocols.mbt`)

### Frozen value semantics

- [x] `freeze()` operation on mutable types (List, Dict, Set) — `freeze_value` propagates transitively
- [x] Mutation after freeze raises `EvalError` — `check_mutable(verb)` on StarlarkList;
      Hashtable `insert`/`delete` check `itercount > 0` (enforced at eval time in Phase 5)
- [x] Freezing propagates transitively through contained values (`freeze_value` in `traits.mbt`)
- [x] Module dict frozen automatically when `exec_file` returns (wired in Phase 5)
- [x] **Iterator freezing**: iterating a mutable container (List, Dict, Set) with a `for`
      loop **freezes** it for the duration of the loop. Any mutation during iteration
      raises an `EvalError` ("cannot insert into frozen hash table", etc.).

### Implementation notes

- **MoonBit byte-string indexing**: MoonBit `String` is UTF-16 internally; `s[i]`
  must return the i-th **byte** (not UTF-16 code unit). String must be converted to
  a byte buffer (`Bytes` / `Array[Byte]`) for indexing, slicing, and length operations.
  Reference: `starlark-go/starlark/value.go` (`String` type), where `s[1]` on
  `"aΩb"` returns `"\xce"` (one byte). The internal representation in MoonBit should
  store a cached `Array[Byte]` alongside the original String for O(1) access.
  **Design decision**: `StarlarkString` is a struct `{ raw: String, bytes: Array[Byte] }`;
  the byte array is computed once at construction and never mutated (strings are immutable).
  All `len`, `s[i]`, and slice operations use `bytes`; `==` comparison and hashing also
  use the byte representation.
- **Int64 overflow tests**: write tests that trigger `Int64` overflow to establish
  the baseline before planning the BigInt upgrade. These tests must exist before
  implementing `**` (power) with large exponents.
- **`moonbitlang/x` BigInt availability**: before switching from `Int64` to BigInt,
  verify the exact package path and API with `moon ide doc '@moonbitlang/x'` after
  adding the dependency. Do not assume the API name — check first.

### TDD scope

Reference: `starlark-go/starlark/value_test.go`, `starlark-go/starlark/int_test.go`,
`starlark-go/starlark/hashtable_test.go`, `starlark-go/starlark/iterator_test.go`.

---

## Phase 2: Lexer / Scanner ✅

Tokenise Starlark source into a flat token stream.

### Tokens to handle

- [x] Literals
  - Integer: decimal, hex (`0x`), octal (`0o`), binary (`0b`) — **no underscore separators**
  - Float: `1.0`, `1e5`, `1.5e-3`
  - String: single/double/triple-quoted
  - Raw strings: `r"..."`, `r'...'`, `r"""..."""`
  - Bytes literals: `b"..."`, `b'...'`, `b"""..."""`
  - String escape sequences: `\n`, `\t`, `\r`, `\\`, `\'`, `\"`, `\a`, `\b`, `\f`, `\v`, `\0`, octal `\NNN`, hex `\xNN`, Unicode `\uNNNN`, `\UNNNNNNNN`
  - **Bytes literal escape restriction**: `b"..."` only supports byte-range escapes
    (`\xNN`, octal `\NNN`, `\n`, `\t`, etc.); Unicode escapes `\uNNNN` and `\UNNNNNNNN`
    are **not valid** inside bytes literals and must raise a `SyntaxError`.
  - Triple-quoted string termination rules
- [x] Keywords: `and`, `break`, `continue`, `def`, `elif`, `else`, `for`, `if`, `in`, `lambda`, `load`, `not`, `or`, `pass`, `return`, `while`
- [x] Keyword literals: `None`, `True`, `False` — scanned as `NoneKw`/`TrueKw`/`FalseKw`
      tokens (not `Ident`), matching starlark-go scanner behavior; parser matches
      them directly in parse_primary; rejected in identifier positions (e.g. param names)
- [x] Note: old-style octal (`0755`) is **NOT** supported; only `0o755` is valid (error emitted)
- [x] Identifiers (including leading `_`)
- [x] Operators: `+`, `-`, `*`, `/`, `//`, `%`, `**`, `~`, `&`, `|`, `^`, `<<`, `>>`, `==`, `!=`, `<`, `<=`, `>`, `>=`, `=`, `+=`, `-=`, `*=`, `/=`, `//=`, `%=`, `&=`, `|=`, `^=`, `<<=`, `>>=`
- [x] Delimiters: `(`, `)`, `[`, `]`, `{`, `}`, `,`, `;`, `:`, `.`, `*`, `**`
- [x] Indentation: `INDENT` / `DEDENT` tokens (tab = 8 spaces; starlark-go convention)
- [x] Comments: `#` to end-of-line (skipped)
- [x] Newlines (logical vs physical)
- [x] **Explicit line continuation** `\<newline>`
- [x] **Implicit line continuation** inside `(`, `[`, `{`
- [x] Attach `Position` to every token

### String literal quoting helper

- [x] `unquote(literal) -> (String, is_bytes)` — decode source-level escapes
- [x] `quote(string, is_bytes) -> String` — produce a Starlark-safe literal
      with appropriate escapes (used by `repr`, error messages)
- [x] Reference: `starlark-go/syntax/quote.go`

### TDD scope

Reference: `starlark-go/syntax/scan_test.go`, `starlark-go/syntax/quote_test.go`.

---

## Phase 3: Parser / AST ✅

Build an AST from the token stream. Each node carries a `Position`.

### Expressions

- [x] `Literal` — None, bool, int, float, string, bytes
- [x] `Ident` — identifier reference
- [x] `UnaryExpr` — `-`, `+`, `~`, `not`
- [x] `BinaryExpr` — all binary operators incl. `in`, `not in`, `%` (string format)
- [x] `ChainedComparison` — Starlark spec: comparisons are **non-associative**;
      `a < b < c` raises `SyntaxError: "< does not associate with <"`.
      Parser now rejects chained comparisons in both `parse_comparison` and
      `finish_comparison_from`.
- [x] `IfExpr` — `x if cond else y`
- [x] `IndexExpr` — `a[i]`
- [x] `SliceExpr` — `a[start:end:step]`
- [x] `DotExpr` — `x.attr`
- [x] `CallExpr` — `f(args…)` with positional, keyword, `*args`, `**kwargs`
- [x] `ListExpr` — `[…]` (trailing comma allowed)
- [x] `TupleExpr` — `(a, b, …)`; single-element tuple `(x,)` distinguished from grouping `(x)`
- [x] `DictExpr` — `{k: v, …}` (trailing comma allowed)
- [x] `SetExpr` — `{x, …}` (gated by `allow_set`)
- [x] `Comprehension` — list/dict/set comp with multiple `for`-clauses and nested
      `if`-guards: `[x+y for x in xs for y in ys if p(x,y)]`. Each `for`-clause
      introduces a new scope; inner variables shadow outer ones.
- [x] `LambdaExpr` — `lambda params: expr` (body restricted to single Test; gated by `allow_lambda`)

### Statements

- [x] `AssignStmt` — `=`, `+=`, `-=`, … augmented assigns; tuple unpacking LHS
- [x] `ExprStmt` — bare expression statement
- [x] `IfStmt` — `if / elif / else`
- [x] `ForStmt` — `for x in iterable:`
- [x] `WhileStmt` — `while cond:` (gated by `allow_while`)
- [x] `ReturnStmt` — `return [expr]`
- [x] `BreakStmt` / `ContinueStmt` / `PassStmt`
- [x] `DefStmt` — `def name(params): body` with default args, `*args`, `**kwargs`; trailing comma in params
- [x] `LoadStmt` — `load("path", …)` with optional aliasing; **only at module scope**

### Unsupported Python constructs (parser must reject)

The parser must emit a `SyntaxError` for these Python features absent from Starlark:

- [x] `global` / `nonlocal` statements
- [x] `del` statement
- [x] `import` statement (only `load` is valid)
- [x] `raise` statement
- [x] `try` / `except` / `finally` / `else` blocks
- [x] `class` definitions
- [x] `with` / `as` statements
- [x] `async` / `await`
- [x] Walrus operator `:=`
- [x] `*rest` in LHS tuple unpacking (`a, *b, c = ...`) — Starlark does not support this
- [x] `is` / `is not` operators
- [x] Type annotations in function parameters (`def f(x: int)`) and assignments (`x: int = 1`)
- [x] `yield` / `yield from`
- [x] `print` as a statement (it is a built-in function, not a keyword)

### AST walker

- [x] `walk(node, visit)` — depth-first traversal visiting every child node;
      used by the resolver and any future linter / tooling
- [x] Reference: `starlark-go/syntax/walk.go`

### TDD scope

Reference: `starlark-go/syntax/parse_test.go`, `starlark-go/syntax/walk_test.go`.

---

## Phase 4: Name Resolution ✅

Resolve variable scopes before evaluation.

- [x] Collect all binding sites (def params, for targets, assign LHS, comprehension vars)
- [x] Classify each reference: `local`, `cell` (closure), `free`, `global`, `predeclared`, `universal`
- [x] Assignment inside a function → local binding (Python rule)
- [x] Forward references allowed at module scope; not inside a single block before assignment
- [x] Error on use-before-def (undefined variable detection)
- [x] Validate function parameter order: positional → `*args` → keyword-only → `**kwargs`
- [x] No duplicate parameter names
- [x] **`load` must be at module scope**
- [x] **No reassignment of `load`-imported symbols** — always errors regardless of `allow_global_reassign`; load rebinding itself respects the flag
- [x] **Recursion detection** — error if disallowed by `allow_recursion=false`
- [x] **No global mutation from functions** unless `allow_global_reassign=true`
- [x] **Top-level `if` / `for` / `while`** rejected unless `allow_top_level_control=true`
- [x] **`load` binding scope** — file-local by default; global if `load_binds_globally=true`

### TDD scope

Reference: `starlark-go/resolve/resolve_test.go`.

---

## Phase 5: Evaluator ✅

Execute resolved AST nodes with an environment (binding stack).

### Execution context (Thread)

- [x] `Thread` — holds print callback, load callback, call stack, recursion depth limit (default 100), max execution steps (optional)
- [x] Recursion depth check — `max_recursion_depth` enforced in `call_func`
- [x] Step budget check (Halt when exceeded) — raises EvalError("step budget exceeded")
- [x] Print output routed through `Thread.print`

### Expression evaluation

- [x] Literals — return wrapped Value
- [x] Identifiers — environment lookup (per resolver classification)
- [x] Unary / binary operators — dispatch on value types:
  - Arithmetic: `+`, `-`, `*`, `//` (floor-div toward -inf), `%` (sign = divisor),
    `/` (true division → Float; requires `allow_float`), `**` (power)
  - Bitwise (Int only): `&`, `|`, `^`, `<<`, `>>`; unary `~` (bitwise NOT)
  - Comparison: `==`, `!=`, `<`, `<=`, `>`, `>=` (same-type only; mixed → TypeError)
  - Membership: `in`, `not in`
  - Boolean short-circuit: `and`, `or`; unary `not`
- [x] **`%` string formatting** — `%s`, `%r`, `%d`, `%i`, `%o`, `%x`, `%X`, `%e`, `%f`, `%g`, `%c`, `%%`
- [x] Short-circuit `and` / `or`
- [x] Conditional expression `x if c else y`
- [x] Subscript, slice (negative indices, negative step), attribute access (returns `BoundMethod` for methods)
- [x] Function call — full argument binding (positional, keyword, `*args`, `**kwargs`, defaults captured at def time, errors for missing/excess args)
- [x] Lambda evaluation — create `Function` value inline
- [x] Comprehensions (list, dict, set) with multiple `for`-clauses and nested `if`-guards
- [x] Chained comparison — non-associative per spec; parser now rejects `a < b < c`
      with SyntaxError (no evaluator change needed)

### Statement execution

- [x] Simple assignment
- [x] Augmented assignment — `+=`, `-=`, `*=`, `//=`, `%=`, `/=`, `**=`, `&=`, `|=`, `^=`, `<<=`, `>>=`
- [x] Augmented assignment to subscript — `a[i] += v` / `d[k] += v`
- [x] Tuple unpacking assignment (`a, b = 1, 2`; nested; `*rest` not supported)
- [x] `if / elif / else`
- [x] `for` loop with `break` / `continue`
- [x] `while` loop with `break` / `continue`
- [x] `def` — create `Function` value, bind defaults
- [x] `return` — unwind with return value
- [x] `load` — executes via `Thread.load_fn`; raises error when no loader is set
- [x] `pass`

### Control flow

- [x] Implement via tagged signals (`SigBreak`, `SigContinue`, `SigReturn(value)`)

### Frozen value enforcement

- [x] Mutation of frozen List/Dict/Set raises `EvalError`
- [x] Module dict frozen on completion of `exec_file`

### Built-in argument binding helper

- [x] `unpack_args(name, positional, keyword, spec) -> Result` — extract
      typed arguments for built-in implementations with explicit names,
      required/optional markers, and type checks
      (`unpack_args`, `unpack_positional` implemented in `src/internal/unpack/`)
- [x] Reference: `starlark-go/starlark/unpack.go`

### TDD scope

Reference: `starlark-go/starlark/eval_test.go`, bitflow `src/starlark/` test files.

---

## Phase 6: Built-in Functions

Implement the standard Starlark built-in functions.

| Function | Status | Notes |
| --- | --- | --- |
| `abs` | [x] | |
| `all` | [x] | |
| `any` | [x] | |
| `bool` | [x] | |
| `bytes` | [x] | constructor: accepts bytes, string, or iterable of ints |
| `chr` | [x] | |
| `dict` | [x] | |
| `dir` | [x] | returns sorted method names per type |
| `enumerate` | [x] | optional `start=` keyword arg (default 0) |
| `fail` | [x] | |
| `float` | [x] | |
| `getattr` | [x] | |
| `hasattr` | [x] | |
| `hash` | [x] | |
| `int` | [x] | optional `base=` keyword arg (2-36; 0 = auto-detect) |
| `len` | [x] | |
| `list` | [x] | |
| `max` | [x] | `key=` supported |
| `min` | [x] | `key=` supported |
| `ord` | [x] | |
| `print` | [x] | `sep=` supported; `end=` not in starlark-go spec |
| `range` | [x] | |
| `repr` | [x] | |
| `reversed` | [x] | |
| `set` | [x] | |
| `sorted` | [x] | `key=`, `reverse=` supported |
| `str` | [x] | |
| `tuple` | [x] | |
| `type` | [x] | |
| `zip` | [x] | |

### Built-in methods per type

- [x] `string`: `capitalize`, `count`, `elem_ords`, `elems`, `endswith`, `find`,
      `format` (partial: `{}` only), `index`, `isalnum`, `isalpha`, `isdigit`,
      `islower`, `isspace`, `istitle`, `isupper`, `join`, `lower`, `lstrip`,
      `partition`, `removeprefix`, `removesuffix`, `replace`, `rfind`, `rindex`,
      `rpartition`, `rstrip`, `split`, `splitlines`, `startswith`, `strip`,
      `title`, `upper`
      — all implemented including `codepoint_ords`, `codepoints`, `rsplit`
- [x] `bytes`: `elems` (returns list of int byte values); `elem_ords` not in starlark-go bytes methods
- [x] `list`: `append`, `clear`, `count`, `extend`, `index`, `insert`, `pop`, `remove`, `reverse`, `sort`
- [x] `dict`: `clear`, `get`, `items`, `keys`, `pop`, `popitem`, `setdefault`, `update`, `values`
- [x] `set`: `add`, `clear`, `difference`, `discard`, `intersection`, `issubset`,
      `issuperset`, `pop`, `remove`, `symmetric_difference`, `union`, `update`

### `str.format()` (complex)

- [x] Positional `{}`, indexed `{0}`, named `{name}` references
- [x] Conversion flags `!s`, `!r`
- [x] Format specs (width, alignment, fill, type) — raises error with message (not supported by starlark-go either)
- [x] Escaped `{{` / `}}`

### `assert` helper module

- [x] Create `src/internal/starlarktest/` package with:
      - `run_star_string(src) -> Array[String]` — executes a Starlark source
        string as a MoonBit test; collects assertion failure messages
      - Assert module built directly in MoonBit (eq, ne, true, lt, contains,
        fails, fail); injected as the `"assert.star"` load target
      - **Architecture note**: assert module implemented in MoonBit (not via
        exec of assert.star) to avoid the issue that StarlarkFunction.call_func
        uses the caller's global_env, not the defining module's global_env.
        Predeclared functions like `catch` would be invisible to `_fails` when
        called from a different module context.
- [x] `StarlarkBuiltinFunc.body` — optional callable closure with `BuiltinCallCtx`
      that allows custom built-ins to call back into the evaluator (needed for
      `assert.fails` to invoke Starlark callables and catch errors)
- [x] `exec_file_with_predeclared` — inject extra predeclared bindings before exec

### TDD scope

Reference: `starlark-go/starlark/library.go`, `starlark-go/starlark/testdata/*.star`.

---

## Phase 7: Compliance & Integration Tests

End-to-end tests that execute `.star` scripts and assert output.

- [x] Implement `starlarktest` equivalent — `run_chunked_string` in
      `src/internal/starlarktest/`. Supports `### "pattern"` and
      `` ### `pattern` `` error-comment format with `---` chunk separation;
      `pattern_matches` handles `.*` wildcards and `$` end-anchor.
      Error-comment chunks from `assign.star`, `dict.star`, `builtins.star`,
      `misc.star` added to respective `*_test.mbt` files.
- [x] Port key cases from `starlark-go/starlark/eval_test.go`
      (TestParameterPassing: positional, keyword, *args/**kwargs, keyword-only, required keyword-only)
- [x] Port key cases from `starlark-go/starlark/value_test.go`
      (TestStringMethod: covered by existing traits_test.mbt/value_test.mbt;
       TestListAppend: StarlarkList push+index tests added;
       TestParamDefault: whitebox test for StarlarkFunction.defaults in value_api_wbtest.mbt)
- [x] Port `.star` test files from `starlark-go/starlark/testdata/`
      Priority order: `int.star`, `bool.star`, `string.star`, `list.star`,
      `dict.star`, `tuple.star`, `function.star`, `control.star`, `assign.star`,
      `builtins.star`, `float.star`, `bytes.star`, `set.star`, `while.star`,
      `recursion.star`, `misc.star`, `function_param.star`
  - [x] `int.star` — bigint cases excluded; shift/int()/% formatting fixed to pass
  - [x] `bool.star` — all assertions pass
  - [x] `string.star` — all assertions pass; unicode iterable-string multi-byte tests
        now included (codepoints/elem_ords/elems for "abcЙ😿"); ord() error message
        aligned with starlark-go ("string encodes N Unicode code points, want 1");
        hash parity assertions (lines 161-170) now included after fixing hash() to
        use java.lang.String.hashCode instead of FNV-1a; string-not-iterable error
        assertions (lines 424-430) now included (enumerate/sorted/zip/dict/for/comp)
  - [x] `list.star` — all assertions pass; lambda-in-if-clause corner cases now
        included (fix: parser accepts lambda in comprehension if-clause);
        f7 (hasfields) excluded; f4 (local-var-before-assignment via +=) excluded
        (runtime does not yet distinguish unbound locals from globals)
  - [x] `tuple.star` — all assertions pass; tuple multiplication with overflow checks
  - [x] `dict.star` — all assertions pass including dict union (|, |=); hasfields-
        based tests excluded
  - [x] `control.star` — if/elif/else, for loops with break/continue, return
        semantics, scoping; fibonacci predeclared as 100-element list
  - [x] `function.star` — closures, lexical scope, stateful closures, freeze,
        mutable defaults, lambda parsing, missing/duplicate param errors, dynamic
        **kwargs checks, CALL_VAR_KW, eval order, recursive closures, forward refs,
        trailing commas; recursion detection (fib/Y-combinator), hasfields(),
        and unbound-cell detection excluded (not yet implemented); "did you mean"
        spell-check for unexpected kwargs now included (min keg→key)
  - [x] `while.star` — basic accumulation, break, continue all pass
  - [x] `recursion.star` — fibonacci (fib(5)=8) and depth-limit enforcement pass
  - [x] `set.star` — all assertions pass; covers constructor, truth, binary ops
        (|, &, ^, -), comparison, iteration, all set methods
  - [x] `builtins.star` — all assertions pass; hasfields() tests excluded
        (application-defined type not available in harness)
  - [x] `bytes.star` — all assertions pass; type(hello.elems())=="bytes.elems"
        and str(hello.elems()) now included (BytesElems type properly implemented)
  - [x] `assign.star` — all assertions pass; passing-case dialect chunks for
        option:globalreassign and option:loadbindsglobally added; error chunks
        requiring unbound-cell detection excluded; hasfields() tests excluded.
        Also fixed: resolver now allows load-imported name reassignment when
        allow_global_reassign=true (matching starlark-go semantics).
  - [x] `float.star` — all assertions pass; BigInt cases excluded. Fixes made:
        NaN equality (starlark-go semantics), -0.0 display, float literal
        parsing precision via @math.pow, int(NaN/Inf) errors, float floor-mod.
  - [x] `misc.star` — all assertions pass; cyclic data structure tests (repr
        with ellipsis, "maximum recursion" on equality) now included; "did you
        mean" typo suggestion in load errors now included.
  - [x] `function_param.star` — no assertions (only function definitions used
        by Go unit tests); no port needed.
  - [x] `module.star` — type/str/dir/hash/assign/missing-field; "did you mean"
        suggestion excluded (not implemented)
- [x] **`assert.star` embedding**: implemented as MoonBit-native builtins
      (`build_assert_module()` in `src/internal/starlarktest/starlarktest.mbt`);
      injected via the loader for `"assert.star"` in both `run_star_string` and
      `run_chunked_string`. The original `const`-string-exec approach was
      abandoned (see Phase 6 architecture note) because StarlarkFunction
      uses the caller's global_env, making predeclared helpers invisible
      inside loaded modules.
- [x] Snapshot tests for error message formats
      (9 tests in `error_format_test.mbt`: syntax/resolve/type/div-zero/index-OOB
       errors, full backtrace, no-frame backtrace, wrong-arg-count, recursion limit)
- [x] Benchmark suite — `bench_test.mbt` in `src/internal/starlarktest/` using
      `moonbitlang/core/bench` `(it : @bench.T)` API; covers range, calling,
      arithmetic, dict/set, strings, list comprehensions, Fibonacci pipeline

---

## Phase 7.5: `json` Extension Library ✅

Port `starlarkjson` so embedders can read/write JSON from Starlark.
Other starlark-go extensions (`math`, `time`, `proto`, `struct`) are
**out of scope** for the initial release — see "Future work" below.

- [x] `json.encode(value) -> string` — None/bool/int/float/str/list/tuple/dict/range;
      cycle detection via `physical_equal`; dict keys sorted; non-ASCII via `\uXXXX`
- [x] `json.encode_indent(value, prefix=, indent=)` — combines encode + indent
- [x] `json.decode(string, default=) -> value` — recursive-descent parser; surrogate-pair
      decode; `default` fallback on invalid input; numbers as Int64 or Float64
- [x] `json.indent(string, prefix=, indent=)` — pretty-print JSON; empty containers inline
- [x] Error reporting via descriptive string messages (starlark-go json also uses string errors,
      not Position-based; source Position not applicable for this extension)
- [x] Lives as a separate package: `src/lib/json/` (importable, not auto-injected; moved from `src/json/`)
- [x] Reference: `starlark-go/lib/json/json.go`

---

## Phase 8: Release Preparation

### Public API hardening (from pre-release audit)

- [x] **[HIGH]** Restrict `Thread` mutable field visibility — `mut steps` and `mut call_stack`
      are currently `pub(all)`, allowing callers to corrupt interpreter state
      (`thread.steps = 0`, `thread.call_stack = []`). Expose read-only accessors instead.
      Reference: `starlark-go/starlark/eval.go` `Thread.CallStackDepth()` / `ExecutionSteps()`.
- [x] **[MED]** Implement `Thread.cancel()` / `Thread.uncancel()` — graceful execution halt
      for timeout and quota enforcement. Without this, embedders cannot safely bound execution
      time. Reference: `starlark-go/starlark/eval.go` `Thread.Cancel`.
- [x] **[LOW]** Add `Thread.execution_steps() -> Int` read-only accessor
      (currently only the mutable `steps` field is accessible once the above is restricted).
- [x] **[LOW]** Restrict `Hashtable[K,V]` internal fields — `mut slots`, `mut entries`,
      `free_head`, `head`, `tail`, and function fields (`hash_fn`, `eq_fn`, etc.) are
      `pub(all)` in `src/internal/hashtable/`. Not re-exported through the public façade,
      but still reachable within `src/internal/*`. Scope-limit to what other internal
      packages actually need.
- [x] **[LOW]** Value convenience constructors — embedders currently construct values by
      matching on `Value` enum variants directly; helper factories (`new_builtin`,
      `new_list`, `new_dict`, `new_set`) would improve ergonomics.
      Reference: `starlark-go/starlark/value.go` `NewBuiltin`, `NewList`, `NewDict`, `NewSet`.
- [x] **[MED]** Second-pass API audit — hide `StarlarkDict.ht`, `StarlarkSet.ht`,
      `StarlarkModule.attrs`, `Module.globals/frozen`, `Universe.bindings`,
      `Predeclared.bindings`, `CallStack.frames`; add string-keyed `Module::get()`,
      `Module::globals_count()`, `Module::is_frozen()`, `StarlarkModule::attr_names()`
      accessors. Named constants for hash-algorithm magic numbers (traits.mbt),
      initial hashtable capacity, and Starlark tab width.
- [x] **[LOW]** Third-pass magic-number audit — `Hashtable::clear()` was using literal `8`
      instead of `initial_capacity`; Thread constructors used literal `100` for
      `max_recursion_depth` instead of `default_max_recursion_depth`.
- [x] **[LOW]** Fourth-pass quality audit — fixed float format specifier bugs (`%E`
      uppercase not applied; `%G` uppercased NaN/Inf; `%e`/`%f`/`%g`/`%G` returned
      `"inf"` instead of `"+inf"` for positive infinity); removed YAGNI `_unused : Bool`
      parameter from `eval_cmp` (4 call sites); extracted `float_floor_mod` helper to
      eliminate 3-way DRY violation in `eval_mod`; deduplicated `builtin_names` array in
      `EvalContext::new` (was shadowing module-level constant); fixed `check_steps` to
      always increment step counter regardless of whether a budget is set (previously
      `execution_steps()` always returned 0 on uncapped threads); added 5 tests covering
      `Thread.cancel`, `Thread.uncancel`, `Thread.execution_steps`, and
      `Thread.with_step_budget`.
- [x] **[MED]** Fifth-pass audit — restricted `pub(all)` struct fields to private on
      `StarlarkString` (`bytes`), `StarlarkRange` (`start`/`stop`/`step`), and
      `StarlarkBuiltinFunc` (`body`); added accessor methods (`to_bytes()`,
      `start()`/`stop()`/`step()`, `call_body()`) and factory constructor
      `StarlarkBuiltinFunc::dispatch()`; updated all call sites in `eval`, `json`,
      and test packages. Removed the empty `src/internal/format/` placeholder package
      (YAGNI: no exports, no dependents).
- [x] **[LOW]** Sixth-pass DRY audit — extracted `hex_char`, `utf8_decode_rune`,
      `is_unicode_printable`, and `write_hex2/4/8` from three separate packages
      (`value`, `lexer/quote`, `starlark/json`) into a single `src/internal/utf8util/`
      package (~270 lines removed). Functions had identical logic under different names
      (`hex_digit`, `utf8_decode_rune_q`, `is_unicode_print`).

- [x] **[MED]** Seventh-pass audit — restricted all remaining `pub`/`pub(all)` struct
      fields to `priv` with accessor methods across every package:
      `resolver` (`Binding.name/pos/scope`, `ResolvedFile.globals/locals/errors`,
      `ResolveOptions` all nine flags); added `with_allow_*` fluent mutators to
      `ResolveOptions` replacing struct-update syntax in tests.
      `syntax` (`File.path/stmts`); added `File::new` constructor.
      `eval` (`Options` all nine flags + `with_load_binds_globally`; `Thread.name`,
      `Thread.max_recursion_depth`, `Thread.max_steps`).
      `value` (`StarlarkFunction.name`, `StarlarkBuiltinFunc.name`,
      `StarlarkModule.name`, `StarlarkIterator.next_fn/done_fn`,
      `StarlarkString.raw`).

### Deferred API hardening (requires large eval refactoring)

- [x] **[LOW]** Restrict `StarlarkList` mutable fields — `items`, `frozen`, `itercount`
      are `pub(all)`, allowing external code to bypass freeze and mutation checks.
      Requires adding index/slice/length methods to StarlarkList and updating all
      direct field accesses in `src/internal/eval/ops.mbt` and tests (~50 sites).
- [x] **[LOW]** Restrict `StarlarkFunction` fields — `params`, `body`, `defaults`,
      `captured_scope` are `pub(all)`, exposing AST internals through the value API.
      Requires providing accessor methods and updating all direct accesses in eval.
- [x] **[LOW]** `EvalError` fields `call_stack` and `cause` — currently `pub(all)`;
      `call_stack` is exposed as a named field in starlark-go but could be hidden behind
      `backtrace()` only. Low priority since users legitimately inspect `msg` and `call_stack`.
- [x] **[LOW]** `BuiltinCallCtx` is `pub(all)`, making the `call` field publicly
      writable. Embedders receive this type in their builtin callback; they do not need
      to construct it externally. Reducing to `pub` (not `pub(all)`) closes the gap.
- [x] **[LOW]** Remove `src/internal/builtins/builtins.mbt` placeholder — the file
      contains only a comment; builtins were implemented in `eval/expr.mbt` instead.
      No package currently imports `src/internal/builtins/`; the directory is dead code.

### General release tasks

- [x] Finalise public API; review `.mbti` diff
      — Removed `Val` suffix from all `Value` enum constructors (1535 sites)
      — Added `repr`, `to_str`, `type_name`, `truth`, `starlark_equals` to public facade
      — Updated `docs/api.md` and `README.mbt.md` to match new constructor names
- [x] CLI implementation in `src/cmd/` — run `.star` files; `src/main/` renamed to `src/cmd/`
- [x] Optional REPL — interactive `read → eval → print` loop (public `src/repl/` library)
- [x] Usage examples as doc tests in `README.mbt.md`; detailed API reference in `docs/api.md`
- [ ] Mooncakes publish prep
  - [x] API docs updated (docs/api.md) — Phase 9 additions documented
  - [x] README updated with `call()` usage example
  - [ ] `moon publish` — publish to mooncakes.io

---

## Phase 9: Post-Release API Extensions

Low-cost public API additions derived from gap analysis against starlark-go.

### CallStack API (カテゴリ23)

- [x] `CallStack.length()` — frame count
- [x] `CallStack.at(i)` — index access (0 = outermost frame)
- [x] `CallStack.pop()` — remove and return last frame
- [x] `Thread.call_stack()` — snapshot of the current call stack as `CallStack`

### Public utility functions (カテゴリ11)

- [x] `equal(a, b) -> Result[Bool, EvalError]` — starlark-go `Equal` equivalent
- [x] `number_to_int(v) -> Int64?` — convert Float/Int to Int64 (starlark-go `NumberToInt`)
- [x] `as_float(v) -> (Double, Bool)` — extract float (starlark-go `AsFloat`)
- [x] `as_string(v) -> (String, Bool)` — extract raw string (starlark-go `AsString`)
- [x] `len_of(v) -> Int` — sequence length; -1 for non-sequences (starlark-go `Len`)
- [x] `iterate(v) -> Result[StarlarkIterator, EvalError]` — public iterator access
- [x] `call(thread, fn, args, kwargs) -> Result[Value, EvalError]` — host-side callable invocation
- [x] `binary(op, x, y) -> Result[Value, EvalError]` — string-keyed binary operator dispatch
- [x] `unary(op, x) -> Result[Value, EvalError]` — string-keyed unary operator dispatch
- [x] `compare(op, x, y) -> Result[Bool, EvalError]` — string-keyed comparison dispatch
- [x] `StringDict` named type — wrapper around `Map[String, Value]` with `keys()`, `has()`,
      `freeze()`, `get()`, `set()`, `from_map()` methods; `keys()` returns lexicographic order

### Additional type re-exports

- [x] `CallStack`, `CallFrame` — re-exported in public façade
- [x] `StarlarkIterator`, `StarlarkList`, `StarlarkString` — re-exported in public façade

### Remaining low-cost items (not yet implemented)

- [x] **Cycle detection** — `repr`/`str` truncates circular references as `[...]`;
      `==` / `<` on cyclic structures raises "maximum recursion" (`misc_test`)
- [x] **Unbound cell detection** — referencing a local before assignment raises an error
      (`list_test`, `function_test`)
- [x] **`BoundMethod` hash identity** — each method access creates a unique ID so
      `{x.f, x.f}` produces a 10-element set (`function_test`)
- [x] **`option:globalreassign` / `option:loadbindsglobally` test chunks** — dialect flag
      parsing added to `run_chunked_string`; passing-case chunks added (`assign_test`)
- [x] **"did you mean" suggestion** — Levenshtein-based typo hint in `load` errors
      (`misc_test`)

- [x] **Additional embedder protocols** — standalone traits `HasBinary`, `HasUnary`,
      `HasSetIndex`, `TotallyOrdered`, `Sliceable`, `IterableMapping` added to
      `protocols.mbt`; `CustomValue` vtable extended with `get_index_fn`,
      `set_index_fn`, `slice_fn`, `items_fn`; `eval_index`/`set_index`/`eval_slice`
      in `ops.mbt` now dispatch to `ExtVal` for subscript read/write and slicing.

### Debugger API (カテゴリ4, 9)

- [x] **DebugFrame API** — `Thread.debug_frame(depth)` returns a `DebugFrame` snapshot
      of an active call frame (depth 0 = innermost Starlark function); `DebugFrame`
      exposes `callable()`, `num_locals()`, `frame_local(i)`, `local_by_name(name)`,
      and `position()`. `Binding` type carries local name + position.
      `Thread.debug_stack` is maintained by `call_func` push/pop around Starlark calls.

### Program API (カテゴリ10, 20)

- [x] **Program API** — `source_program(filename, src, opts, is_predeclared)` parses and
      resolves a file without executing it, returning an immutable `Program` value.
      `Program.init(thread, predeclared)` executes the resolved AST and returns an
      unfrozen `Module`; may be called multiple times with different `predeclared`
      dictionaries. Includes `Program.filename()`, `Program.num_loads()`,
      `Program.load(i)` for inspecting load statements.
      Unlike `exec_file`, `Program.init` does NOT freeze the returned module.

---

## Post-Release Bugfixes

Fixes derived from `.connect0459/bugfix.md` comparison against starlark-go.

- [x] **BUG-1**: `hash()` used FNV-1a instead of Java `String.hashCode` for strings — fixed
      in `value/traits.mbt` (`java_string_hash`); `expr.mbt` dispatch updated. Commit: `d24583c`
- [x] **BUG-2**: String `+` corrupted bytes when operands contained invalid UTF-8 — fixed
      in `eval/ops.mbt`: concat now joins `to_bytes()` arrays directly instead of via `raw`. Commit: `21e555c`
- [x] **BUG-3**: String `*` corrupted bytes when string contained invalid UTF-8 — fixed
      in `eval/ops.mbt` `repeat_string`: now iterates over `to_bytes()` instead of `raw()`. Commit: `21e555c`
- [x] **BUG-4**: `xs.extend(xs)` / `xs += xs` raised error or silently no-op'd — fixed
      in `eval/expr.mbt` and `eval/stmt.mbt`: both paths now snapshot source items via
      `StarlarkList::copy_items()` when the argument is a `List`, bypassing iterator
      protocol to match starlark-go `listExtend` fast path. Commit: `b950f33`
- [x] **MISSING-3**: Test coverage for partial/invalid UTF-8 string operations — added
      in `starlarktest/string_test.mbt`: ord on continuation bytes, repr of single-byte
      slices, codepoint_ords/elem_ords/elems on concat with invalid bytes.
- [x] **MISSING-4**: `str(b"\xED\xB0\x80")` == U+FFFD × 3 — fixed `str(Bytes)` to re-encode
      via `from_bytes().raw() + new()`. MoonBit `decode_lossy` gives 3 U+FFFD per byte.
      Commit: `a6d20d1`
- [x] **BUG-5**: `range()` with BigInt arg overflowing Int64 silently truncated — fixed
      in `eval/expr.mbt`: `range_arg_to_int64` checks bounds via `BigInt::compare_int64`
      and raises `"N out of range (want value in signed 64-bit range)"`. Matches
      starlark-go `AsInt` error format. Commit: `6915be5`
- [x] **BUG-6** (bugfix.md BUG-2): `bigint_to_double` silently returned `+Infinity`
      for huge BigInts instead of raising "int too large to convert to float" — fixed
      in `value/traits.mbt`: added `bigint_to_finite_double` helper; replaced all
      mixed Int+Float arithmetic call sites in `eval/ops.mbt` and `float()` builtin
      in `eval/expr.mbt` via `finite_double` helper. Commit: `c23ab13`
- [x] **BUG-7** (bugfix.md BUG-3): `<toplevel>` frame missing from call stack during
      `exec_file` — fixed by pushing/popping `CallFrame("<toplevel>")` in `exec_file`,
      `exec_file_with_predeclared`, `exec_repl_chunk`, and `Program::init`;
      `exec_stmts` performs live PC tracking to update the toplevel frame position
      before each statement dispatch. Commit: `7467150`
- [x] **BUG-8** (bugfix.md BUG-4): `float()` string error messages differed from
      starlark-go — fixed in `eval/expr.mbt`: empty string → "float: empty string";
      syntactically-invalid → "invalid float literal: ..."; valid-format overflow →
      "floating-point number too large"; `is_float_syntax` helper distinguishes cases.
      Commit: `c23ab13`
- [x] **MISSING-5**: Tests for `float(huge_bigint)` overflow — added in
      `starlarktest/float_test.mbt` covering all mixed Int+Float arithmetic with huge
      int. Commit: `c23ab13`
- [x] **MISSING-6**: `set("abc")` and `set() | "abc"` error tests — added to
      `string_not_iterable_src` in `starlarktest/string_test.mbt`. Commit: `01d4b23`

---

## Future work (out of initial release scope)

- Hide `StarlarkFunction.body/params/captured_scope` from public API — these expose
  `@syntax.Stmt` / `@syntax.Param` AST types. Requires moving call dispatch logic into
  the `value` package or introducing a trait boundary to avoid circular imports.
- `math` extension library — implemented as `src/lib/math/`
- ~~`time` extension library~~ — implemented as `src/lib/time/`; non-UTC timezones via IANA tzdb (native) / static table (wasm/js); native-only DST tests in `time_tz_native_test.mbt`
- `proto` extension library (`starlark-go/lib/proto`)
- ~~`starlarkstruct`~~ — implemented as `src/lib/struct/`; `struct()` builtin, `gensym()` callable symbols, `+` merge, `make_struct` API
- Bytecode compilation / interpreter (currently AST-walking only)
- Profiling and debugging hooks (`starlark-go/starlark/profile.go`)
- ~~Big-integer `Int`~~ — implemented; `Value::Int` now uses MoonBit `BigInt` (arbitrary precision)
- Thread-local storage `Thread.set_local()` / `Thread.local()` for embedder context
  (request IDs, profiling state, etc.) — reference: `starlark-go` `Thread.SetLocal`
- Custom Unpacker protocol for user-defined `Value` types — reference:
  `starlark-go/starlark/unpack.go` `Unpacker` interface
- ~~"did you mean" for module attribute access~~ — implemented; spell_nearest called in
  eval_getattr for Module variant; module.star line 17 now covered
- ~~Print callback thread context~~ — implemented; `Thread.print_fn` changed from
  `(String) -> Unit` to `(Thread, String) -> Unit`; breaking API change to `with_print`
- Full `TestPrint` position parity — `<toplevel>` frame with live PC tracking not yet
  implemented; requires pushing `<toplevel>` at exec_file and updating current position
  as statements execute (AST walker does not track PC)

---

## Coverage Targets

**Overall target: 80%** (agreed before implementation).

Track with `moon coverage analyze > uncovered.log` after each phase.

| Phase                       | Target | Notes                              |
| :-------------------------- | :----- | :--------------------------------- |
| 0.5 Error Infrastructure    | 90%    | Small, critical, easy to cover     |
| 0.75 Public API surface     | 80%    | Mostly types & wiring              |
| 1 Value Types               | 85%    | Core; drives everything downstream |
| 2 Lexer                     | 85%    | Deterministic; straightforward     |
| 3 Parser                    | 80%    | Error paths add bulk               |
| 4 Name Resolution           | 80%    |                                    |
| 5 Evaluator                 | 75%    | Control flow complexity            |
| 6 Built-ins                 | 80%    | Many small functions               |
| 7 Integration               | 80%    | Overall gate                       |
| 7.5 json extension          | 85%    | Small, easily covered              |
| 8 Release prep              | n/a    | Manual review                      |

### Achieved coverage

- **Lexer** (`src/internal/lexer/`): ~93% — `scanner.mbt` 716/766, `quote.mbt`
  199/216, `lexer.mbt` 114/128. Added dedicated tests for `quote`/`unquote`
  escape and error paths, scanner escape/number/indentation error branches,
  and `Token::to_string` rendering. Remaining gaps are unreachable defensive
  branches (e.g. empty/invalid-digit checks in the integer parsers).
- **Syntax/AST** (`src/internal/syntax/`): ~98% — `walker.mbt` 116/119,
  `syntax.mbt` fully covered. Added a whitebox suite exercising the AST walker
  across every node kind (including visitor short-circuit), `expr_pos`/
  `stmt_pos` for all variants, and `File` accessors.

---

## Workflow Notes

- After each Green phase: `moon fmt && moon info && moon test`
- Commit after each Red→Green→Refactor cycle
- Split `src/starlark/` into sub-packages when any file exceeds ~600 LOC
- Keep `src/cmd/` thin — CLI wiring only
- All test names in English (AGENTS.md requirement)
- Use snapshot tests (`moon test --update`) for error message format tests

## Notes

- Starlark strings are **byte** strings: `s[i]` returns the i-th byte, not Unicode codepoint
- All non-default feature gates default to **enabled** (this project's choice)
- Arbitrary-precision `Int`: start with `Int64`, plan upgrade when arithmetic overflow tests fail
- `load` statement requires a pluggable loader; implement a no-op loader for testing
- Mutable containers (List, Dict, Set) can self-reference; equality / repr / hash must handle cycles
