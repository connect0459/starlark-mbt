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
  - **Bytes literal Unicode escapes**: `b"..."` accepts `\uNNNN` and `\UNNNNNNNN`
    and encodes the codepoint as UTF-8 bytes, matching starlark-go behavior
    (earlier implementation rejected them — changed in MISSING-61 fix).
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
- [x] **BUG-9** (bugfix.md BUG-5): `%(name)s` dict-keyed `%` string formatting not
      implemented — fixed in `eval/ops.mbt`: `percent_format` now detects `%(key)spec`
      syntax, looks up key in a Dict arg, and skips "too many arguments" check when the
      arg is a Mapping. Commit: `f3ecb44`
- [x] **BUG-10** (bugfix.md BUG-6): `%e` and `%f` format specifiers used
      `f.to_string()` (shortest repr) instead of 6-decimal printf precision — fixed in
      `eval/ops.mbt`: `format_float_e` now uses `@math.log10` + adjustment loop for
      `"1.230000e+02"` output; `format_float_f` added for `"123.000000"` output; error
      message changed to `"%e format requires float, not string"`. Commit: `f3ecb44`
- [x] **MISSING-7**: `%e`/`%f` test cases from `float.star` lines 410–434 — enabled in
      `starlarktest/float_test.mbt`. Commit: `f3ecb44`
- [x] **MISSING-8**: Dict-keyed `%` format test cases from `string.star` lines 177–178
      — added to `starlarktest/string_test.mbt`. Commit: `f3ecb44`
- [x] **BUG-11**: Step budget exceeded message differs from starlark-go — fixed in
      `eval/env.mbt`: no-callback overflow path now calls `thread.cancel("too many steps")`
      and raises `"Starlark computation cancelled: too many steps"` to match starlark-go.
      Commit: `ad4541c`
- [x] **BUG-12**: `Thread::set_max_steps()` does not reset step counter — fixed by
      having `set_max_steps` call the new `Thread::reset_steps()` method.
      Commit: `ad4541c`
- [x] **BUG-13**: `fail()` silently ignores unknown keyword arguments — fixed in
      `eval/expr.mbt`: unknown kwargs raise `"fail: unexpected keyword argument X"`;
      non-string `sep` raises `"fail: for parameter sep: got T, want string"`.
      Commit: `e2ce568`
- [x] **BUG-14**: `list.count()` / `list.reverse()` / `list.sort()` callable but absent
      from `dir([])` — removed from `call_list_method`; these are Python-only methods
      absent from the Starlark spec. Commit: `0f0df20`
- [x] **MISSING-9**: `Thread::call_frame(n)` single-frame accessor — added to `eval.mbt`;
      returns `call_stack[length-1-n]` or `None` if out of range. Commit: `ad4541c`
- [x] **MISSING-10**: `Thread::reset_steps()` public method — added to `eval.mbt`.
      Commit: `ad4541c`
- [x] **MISSING-11**: `str.format()` edge-case tests from `string.star` lines 206–215 —
      added to `starlarktest/string_test.mbt`. Commit: `6823ad6`
- [x] **MISSING-12**: `str_format` conv/spec split diverges for `{name!conv:spec}` — fixed
      in `eval/expr.mbt`: post-`!` portion split on `:` to separate conv from spec; empty
      conv raises `"format: unknown conversion"` (no value). Commit: `6823ad6`
- [x] **BUG-15**: `hasattr`/attribute access on built-in types returned a `BoundMethod` for
      any name — fixed in `eval/expr.mbt`: `eval_getattr` now validates attribute names
      against each type's method set and raises with spell-check hint for unknowns.
      `dir(string)` also extended with `rsplit`, `codepoints`, `codepoint_ords`.
      Commit: `67191bb`
- [x] **BUG-16**: `chr()` error messages did not match starlark-go format — fixed in
      `eval/expr.mbt`: two branches for `n<0` and `n>0x10FFFF` with exact format.
      Commit: `67191bb`
- [x] **BUG-17**: Index out-of-range error format differed from starlark-go — fixed in
      `eval/ops.mbt`: `adjust_index` now accepts `type_name` and produces
      `"T index N out of range [-len:len-1]"` / `"index N out of range: empty T"`.
      Commit: `2b2ac82`
- [x] **BUG-18**: `'in <string>'` error missing `, not {type}` suffix — fixed in
      `eval/ops.mbt`. Commit: `67191bb`
- [x] **BUG-19**: `bytes()` constructor errors missing `"bytes: "` prefix — fixed in
      `eval/expr.mbt`. Commit: `67191bb`
- [x] **MISSING-13**: Method spell-check tests for built-in string type — added to
      `starlarktest/string_test.mbt`. Commit: `2b2ac82`
- [x] **MISSING-14**: `int("0o123")` / `int("-0o123")` base-10 error tests — added to
      `starlarktest/int_test.mbt`. Commit: `2b2ac82`
- [x] **MISSING-15**: `"abc" * (1000000 * 1000000)` repeat-count-too-large test — added to
      `starlarktest/string_test.mbt`. Commit: `2b2ac82`
- [x] **MISSING-16**: `abs(+/-123 * maxint32)` BigInt test — added to
      `starlarktest/builtins_test.mbt`. Commit: `2b2ac82`
- [x] **MISSING-17**: `"%c" % 0x3b1` and `"%c" % "α"` non-ASCII tests — added to
      `starlarktest/string_test.mbt`. Commit: `2b2ac82`
- [x] **MISSING-18**: `%g` format for normal float/int values — fixed `format_float_g` to
      match starlark-go (negative zero, integer `.0` append, >= 1e6 → scientific notation);
      tests added to `starlarktest/float_test.mbt`. Commit: `2b2ac82`
- [x] **MISSING-19**: `%e`/`%f`/`%d` with edge-case large/tiny floats — fixed `%d`/`%o`/
      `%x`/`%X` for Float to use `double_to_bigint` (full BigInt precision); tests added.
      Commit: `2b2ac82`
- [x] **MISSING-20**: Float `%` modulo with negative operands — tests added to
      `starlarktest/float_test.mbt`. Commit: `2b2ac82`
- [x] **MISSING-21**: `int()` from 20-digit decimal string — tests added to
      `starlarktest/int_test.mbt`. Commit: `2b2ac82`
- [x] **BUG-20**: `number_to_int` silently returned wrong values for BigInt overflow
      and NaN/Inf — fixed in `src/starlark.mbt`: added `compare_int64` bounds check
      for BigInt and `is_nan()`/`is_inf()` guard for Float; added `int64` import to
      `src/moon.pkg`. Commit: `7e27117`
- [x] **MISSING-22**: `number_to_int` edge-case tests — added four tests covering
      BigInt overflow, NaN, positive Inf, and negative Inf. Commit: `7e27117`
- [x] **BUG-21**: Backtrace non-toplevel frame positions showed call-site instead of
      position within the caller — fixed in `eval/expr.mbt`: `call_value` now stamps
      the current top-of-stack frame with the call expression's position before
      dispatching to the callee, so intermediate frames show where within the caller
      the next call was made. Commit: `c79a41c`
- [x] **MISSING-23**: Backtrace exact position assertions — added two snapshot tests in
      `starlarktest/error_format_test.mbt`: one for the simple `f→g` chain verifying
      `f` shows 4:4 (fixed), and one for the deep `i→h→min→g→f` chain verifying each
      intermediate frame shows the call-site within that function. Commit: `c79a41c`
- [x] **BUG-22**: `int()` error message for unsupported types changed from
      `"int() argument must be a number or string, not 'T'"` to
      `"int: cannot convert T to int"`, matching starlark-go `NumberToInt` format.
      Commit: `022b898`
- [x] **MISSING-24**: BigInt arithmetic boundary tests — ported starlark-go `TestIntOpts`
      coverage: Add/Mul/Div/And/Or/Xor/Not/Shift at MaxInt32/MinInt32/MaxUint32 boundaries
      verifying results that cross int32 range. Tests pass immediately since MoonBit uses
      native BigInt. Commit: `45ae3e2`
- [x] **BUG-23**: `str.format()` rejected `{name:}` (empty spec) as invalid — fixed in
      `eval/expr.mbt`: the no-`!` branch now splits `field` on `:` to extract name and
      spec; an empty spec is valid and returns the value unchanged. Commit: `9c02894`
- [x] **BUG-24**: `str.format()` error message for non-empty spec omitted the spec value
      — fixed in `eval/expr.mbt`: both the `!` and no-`!` branches now include the spec
      string in the error: "format spec features not supported in replacement fields: X",
      matching starlark-go. Commit: `9c02894`
- [x] **MISSING-25**: Load error outer backtrace not tested — added snapshot test in
      `starlarktest/error_format_test.mbt` asserting the `<toplevel>` frame appears at
      the load statement position. Commit: `e812479`
- [x] **MISSING-26**: Load error inner backtrace inaccessible — added `cause: EvalError?`
      field to `EvalError` with `with_cause()` constructor and `cause()` accessor;
      `exec_load` now uses `with_cause()` so callers can unwrap the inner error's full
      call stack. Snapshot test verifies both outer and inner backtraces. Commit: `9be5e86`
- [x] **BUG-25**: `print()` output `Bytes` in repr format instead of raw bytes — fixed in
      `eval/expr.mbt`: added `Bytes` special case inside the print loop; decodes via
      `StarlarkString::from_bytes(b).raw()` (lossy UTF-8, consistent with `str(bytes)` and
      starlark-go's `string(b)` transcoding). Commit: `a94faea`
- [x] **BUG-26**: Global/module-scope variable accessed before assignment gave wrong error
      message — fixed in `eval/env.mbt` and `eval/eval.mbt`: added `known_module_globals`
      pre-scan that collects all module-level bindings before execution; `EvalEnv::lookup`
      now returns `LUnboundModule` for names that are known-but-not-yet-assigned, raising
      "global variable X referenced before assignment" to match starlark-go. Commit: `aa4c4a8`
- [x] **BUG-27**: Built-in name shadowed by later module-level assignment returned built-in
      instead of raising "global variable X referenced before assignment" — same fix as
      BUG-26; `known_module_globals` pre-scan correctly overrides built-in lookup for names
      that are assigned anywhere in the module, even before the assignment executes.
      Commit: `aa4c4a8`
- [x] **MISSING-27**: `allow_recursion=false` recursion detection diverged from starlark-go
      in message and timing — moved from resolver-time name-based detection to runtime
      call-stack identity check using source position as funcode; error message changed from
      "recursion not allowed: f" to "function f called recursively"; Y-combinator and mutual
      recursion now detected; lambda renamed from "<lambda>" to "lambda";
      `option:norecursion` flag added to `run_chunked_string`. Commit: `2b971c8`
- [x] **BUG-28**: Comprehension scope: subsequent for-clause target variables were bound
      AFTER their iterable was walked (in both resolver and evaluator), causing
      `[x for _ in [3] for x in x]` to silently succeed instead of raising
      "local variable x referenced before assignment". Fixed by: (1) resolver now walks
      first clause's iterable in the outer scope before pushing the comp block, then for
      subsequent clauses binds the target variable BEFORE walking the iterable (matching
      starlark-go `resolve.go` lines 686–711); (2) evaluator now creates a single shared
      `comp_env` with all for-clause target names as `known_locals`, evaluates the first
      clause's iterable in the outer env, and evaluates subsequent iterables in the comp
      env (where the target is known-but-unassigned → `LUnbound`). Removed dead
      `EvalEnv::with_parent`. Commit: `262c2ae`
- [x] **MISSING-28**: `assign.star` lines 337–343 load-binding-used-before-load-stmt error
      tests added to `assign_test.mbt`. Commit: `41d5a81`
- [x] **MISSING-29**: `assign.star` line 253 comprehension scope unbound variable test
      added to `assign_test.mbt` (unblocked by BUG-28 fix). Commit: `41d5a81`
- [x] **BUG-30**: Right-shift count wrongly capped at 512 — fixed in `eval/ops.mbt`:
      only left shift is capped at 512; right shift by any non-negative count now works
      (`1 >> 1000 == 0`, `(-1) >> 1000 == -1`). Error messages now include the shift
      count value. Commit: `0e3aeec`
- [x] **BUG-31**: `str()`/`repr()` float formatting threshold differed from starlark-go —
      `format_float` in `value/value.mbt` now uses Go-compatible 'g' format: scientific
      notation for integer-form strings with 7+ digits (e.g. `str(1e20)` → "1e+20") and
      for small decimals with exp < -4 (e.g. `str(1e-5)` → "1e-05"); normalizes exponent
      format to "e+XX"/"e-XX". `format_float_g` in `eval/ops.mbt` now delegates to
      `@value.format_float` for consistency. Commit: `680c1e9`
- [x] **BUG-32**: `float("  1.0  ")` was accepted by `float()` builtin (`.trim()` call
      in `expr.mbt`); now raises "invalid float literal" matching starlark-go. Commit: `0e3aeec`
- [x] **BUG-33**: `%c` format rejected astral codepoints (UTF-16 length == 2) — fixed in
      `eval/ops.mbt`: now uses `utf8_decode_rune` on UTF-8 bytes to verify exactly one
      rune spans the whole string. Commit: `5ab5df8`
- [x] **BUG-34**: `int(s, base)` accepted out-of-range base without error — fixed in
      `eval/expr.mbt`: validates `base == 0 || 2 <= base <= 36` before parsing. Commit: `0e3aeec`
- [x] **BUG-29**: String search methods used UTF-16 char indices instead of UTF-8
      byte offsets — fixed in `eval/expr.mbt`: `find`/`rfind`/`index`/`rindex`/`count`/
      `partition`/`rpartition` and the slice form of `startswith`/`endswith` now operate
      on byte offsets into the UTF-8 representation (via new `bytes_index_in`/
      `bytes_last_index_in`/`bytes_count_in`/`bytes_has_prefix`/`bytes_has_suffix`/
      `str_byte_slice`/`clamp_byte_index` helpers), consistent with subscript and
      `len()`. Removed the now-unused String-based `rfind_substr`/`count_substr`.
      Commit: `e4d407c`
- [x] **MISSING-30/31/32/33**: String methods silently ignored excess positional
      args, unknown keyword args, and wrong-typed optionals — fixed in `eval/expr.mbt`
      with shared `check_positional`/`arg_as_string`/`arg_as_int` helpers mirroring
      starlark-go `UnpackPositionalArgs`. `find`/`count`/`index`/`rindex`/`rfind`/
      `startswith`/`endswith` reject excess/keyword args; `strip`/`lstrip`/`rstrip`
      reject non-string chars; `replace` rejects a non-int count; `split`/`rsplit`
      reject keyword args and validate separator/maxsplit types. Commit: `5db0691`
- [x] **MISSING-34/35/36**: Builtins silently ignored argument errors — fixed in
      `eval/expr.mbt`: `dict.update` rejects >1 positional arg and reports element
      index/length in bad-pair errors; `enumerate`/`range` report the offending
      parameter and reject keyword/excess args instead of defaulting non-int values;
      `bytes`/`chr` reject keyword arguments and `abs`/`hash` route arity through
      `check_positional`. Commit: `48918c7`
- [x] **MISSING-37/40**: Division/modulo/slice-step error messages now match
      starlark-go: `/` → "floating-point division by zero", `//` → "floored division
      by zero", `%` → "integer modulo by zero" / "floating-point modulo by zero",
      zero slice step → "zero is not a valid slice step" (`eval/ops.mbt`,
      `value/value.mbt`). Commits: `f0972a2`
- [x] **MISSING-38/39**: Unsupported `*`/`/`/`//`/`%`/`**` now use the uniform
      "unknown binary op: LT OP RT" form (matching `+`/`-`); shift errors already
      carried the count value and fell through to "unknown binary op" on type
      mismatch (BUG-30). Commit: `3145218`
- [x] **MISSING-41**: Builtin/method error messages use starlark-go's nameErr
      prefix — `min`/`max` empty/not-iterable, `list.index`, the `getattr` builtin,
      `float` non-convertible, and `startswith`/`endswith` tuple-element errors
      (with the real element index) all aligned (`eval/expr.mbt`). Commit: `e5be4b5`
- [x] **MISSING-42**: Indentation tabs now expand by source column (rune position),
      not accumulated width, matching `scan.go` for mixed space+tab indentation
      (`lexer/scanner.mbt`). Commit: `27ec7c5`
- [x] **MISSING-43/44**: Parser rejects `load("m")` with no symbols ("load statement
      must import at least 1 symbol") and unparenthesized trailing-comma tuples
      ("unparenthesized tuple with trailing comma"); `(x,)` still allowed
      (`parser/parser.mbt`). Commit: `a63d8af`
- [x] **MISSING-45**: For-loop / comprehension targets parsed with `parse_primary`
      (primary-with-suffix) instead of a full test, rejecting `for a + b in xs`
      (`parser/parser.mbt`). Commit: `a956cda`
- [x] **MISSING-46/47/48**: Resolver walks index/dot assignment targets as uses
      (`undef[0]=1` → undefined), rejects non-assignable LHS ("can't assign to
      <kind>"), and rejects augmented assignment to tuple/list LHS
      (`resolver/resolver.mbt`). Commit: `da34349`
- [x] **MISSING-49**: Resolver validates call-argument ordering — multiple
      `*args`/`**kwargs`, `*args` after `**kwargs`, keyword/positional after
      `*args`/`**kwargs`, positional after named, repeated keyword, 255-arg limits
      (`resolver/resolver.mbt`). Commit: `1d35a1f`
- [x] **MISSING-50**: Resolver enforces full parameter-ordering rules — required
      after optional, bare `*` must be followed by keyword-only, a `*` or parameter
      following `**kwargs`, multiple `*` or `**` parameters
      (`resolver/resolver.mbt`). Commit: `a653ef1`
- [x] **MISSING-51**: Set literals/comprehensions gated on `allow_set` in the
      resolver ("this Starlark dialect does not support sets"); the flag is now wired
      from `Options` through to `ResolveOptions` (`resolver/resolver.mbt`,
      `eval/eval.mbt`, `eval/program.mbt`). Commit: `5cbcfd2`
- [x] **MISSING-52**: `load` rejects empty / leading-underscore source identifiers
      ("load: empty identifier" / "load: names with leading underscores are not
      exported: NAME") (`resolver/resolver.mbt`). Commit: `3fe9c9e`
- [x] **MISSING-53**: `Thread.set_print` / `set_loader` allow a single thread to
      carry print, loader, and step budget together instead of mutually-exclusive
      constructors (`eval/eval.mbt`). Commit: `1368603`
- [x] **MISSING-56**: `exec_repl_chunk` re-exported from the public façade
      (`src/starlark.mbt`). Commit: `1368603`
- [x] **MISSING-57**: `HasSetKey` hook — `CustomValue.with_set_key` lets embedders
      implement `x[k]=v` for arbitrary keys; `set_index` dispatch tries it before the
      integer-indexed hook (`value/protocols.mbt`, `eval/ops.mbt`). Commit: `7c55622`
- [x] **MISSING-59**: `set_max_steps` no longer resets the accumulated step counter
      (matching starlark-go `SetMaxExecutionSteps`); reverts the incorrect BUG-12
      side effect. Use `reset_steps` to zero it (`eval/eval.mbt`). Commit: `1368603`
- [x] **MISSING-65**: `sorted` is now stable via an explicit original-index
      tie-break (never reversed), independent of `Array::sort_by` stability
      (`eval/expr.mbt`). Commit: `20553a7`
- [x] **MISSING-67**: `Function` and `Builtin` are now usable as dict/set keys —
      `starlark_hash` returns `Ok(fnv1a(name))` for both; `Function` equality
      uses `physical_equal` (identity). Commit: `8544f61`
- [x] **MISSING-68**: `<float> in range(...)` now truncates toward zero (matching
      starlark-go `NumberToInt`); NaN/Inf raise error instead of silently
      returning `false`. Commit: `8544f61`
- [x] **MISSING-74**: `list`/`tuple`/`set`/`reversed`/`zip`/`any`/`all`/`bool`/
      `type`/`len`/`repr` now reject keyword arguments via `reject_kwargs`.
      Commit: `8544f61`
- [x] **MISSING-75**: `str()` with zero arguments now raises
      "str: got 0 arguments, want exactly 1" instead of returning `""`.
      Commit: `8544f61`
- [x] **MISSING-76**: `string.index`/`rindex` "not found" error now has the
      method-name prefix: "index: substring not found" / "rindex: substring not
      found". Commit: `8544f61`
- [x] **MISSING-77**: `loops` counter now saved/restored (set to 0) when entering
      a `def` or `lambda` body, so `break`/`continue` inside a nested function
      within a loop correctly raise "not in a loop". Commit: `d32f18b`
- [x] **MISSING-79**: `\uXXXX` (4-digit) surrogate escapes now rejected in
      strings and bytes literals with "invalid Unicode surrogate code point".
      Commit: `b7f1c2f`
- [x] **MISSING-82** (partial): resolver messages aligned with starlark-go:
      "break/continue not in a loop", "return statement not within a function",
      "if/for/while loop not within a function";
      parser messages: "conditional expression without else clause",
      "original name of loaded symbol must be quoted: NAME=\"originalname\"".
      Commits: `d32f18b`, `30f77e9`

### Deferred second-pass items (MISSING-69..86)

- [x] **MISSING-69**: `%e`/`%E`/`%f`/`%F` now round the six fractional digits
      with round-half-to-even on the exact binary value (mantissa*2^exp
      decomposed and `mantissa * 10^scale` rounded via big-integer division),
      matching Go's correctly-rounded `strconv.FormatFloat`. Replaces the
      previous half-up-on-inexact-`frac*1e6`-intermediate algorithm; e.g.
      `"%f" % 5e-07` → `0.000000` (was `0.000001`). Commit: `da5b01a`
- [x] **MISSING-70**: `hash_bigint` now uses the low 32 bits of the absolute
      value (magnitude) for BigInts outside the Int64 range, matching
      starlark-go's `iBig.Bits()[0]` formula. Int64-range values remain
      unchanged (two's-complement, same as before). Commit: `433beae`
- [x] **MISSING-71**: String/list/tuple/bytes repeat checks now use multiplication
      (`elem_len * count >= max_alloc`) matching starlark-go's `len*i >= 1<<30`.
      The integer-division form allowed products of exactly 2^30 that Go rejects.
      Commit: `d0c8187`
- [x] **MISSING-72**: Unicode-aware `capitalize`/`islower`/`isupper`/`title`/
      `istitle`/`isspace` — `capitalize`/`title` now use a small digraph table
      (U+01C4..U+01CC, U+01F1..U+01F3) for `to_title`, `islower`/`isupper` use
      string-level `to_lower()`/`to_upper()` comparison with digraph-aware
      `has_cased` detection, `isspace` delegates to `Char::is_whitespace()` (full
      Unicode White_Space property), and `istitle` extends with `unicode_is_title_codepoint`
      / `unicode_is_upper/lower_codepoint_strict` for the four digraph triples.
      `isalpha`/`isdigit`/`isalnum` remain ASCII-only (no Unicode test coverage in
      reference test suite). Commit: `b477d5e`
- [x] **MISSING-73**: String search methods (`find`/`count`/`index`/`rfind`/
      `rindex`/`startswith`/`endswith`) silently default a non-int / non-None
      `start`/`end` argument instead of erroring. Fixed via `parse_search_index`
      helper; raises "METHOD: invalid start/end index: got T, want int".
      Commit: `a673113`
- [x] **MISSING-76** (part 2): `rindex() argument must be a string` — also
      needs "rindex:" prefix (only the not-found branch was fixed). Fixed by
      refactoring to use `arg_as_string` for find/count/index/rfind/rindex.
      Commit: `a673113`
- [x] **MISSING-78**: `load` nested inside a top-level `if`/`for`/`while` not
      rejected; Go emits "load statement within a loop/conditional". Fixed by
      adding `ifstmts` counter to Resolver; load now emits context-specific
      error. Commit: `70d8e1a`
- [x] **MISSING-80**: Undefined-variable error appends "(did you mean X?)"
      when a module global is within edit distance of the misspelled name.
      Function-local candidates are not included (deferred uses lose block
      context); covers the most common module-level typo case.
      Commit: `0761989`
- [x] **MISSING-81**: Non-ASCII identifier-start now decodes the full UTF-8
      rune and checks `is_unicode_letter_rune` (explicit Unicode letter-block
      ranges matching `unicode.IsLetter`); `→` (U+2192, So) now produces
      "unexpected input character"; cased letters (é, α) and CJK ideographs
      remain valid. `collect_ident_bytes` validates continuation runes the
      same way. Commit: `6a2afe3`
- [x] **MISSING-82** (remaining): `"load statement within a function"` vs
      `"load statement must be at module level"` distinction for load inside a
      function vs loop/conditional; `"dialect does not support while loops"`
      message when `allow_while=false`. Both fixed in `70d8e1a`.
- [x] **MISSING-83**: Pre-parsed expression eval entry point added:
      `SyntaxExpr` type alias, `parse_expr(filename, src)`, and
      `eval_parsed_expr(thread, expr, opts, env)` re-exported in the
      public façade. Mirrors starlark-go `EvalExpr`. Commit: `238d4fb`
- [ ] **MISSING-84** [INTENTIONAL]: `Module` does not retain originating
      `Program`. Architectural divergence, WONTFIX.
- [ ] **MISSING-85** [out of scope]: No global profiler `StartProfile/StopProfile`.

### Third-pass gap analysis (MISSING-86..101)

Fresh four-axis comparison against starlark-go after MISSING-1..85 closed.
Behavioral and message-only divergences fixed via TDD; design-decision items
resolved with the user.

- [x] **MISSING-86**: `splitlines()` now splits on `\n` only (carriage return is
      an ordinary character), matching starlark-go. Commit: `splitlines \n only`.
- [x] **MISSING-87**: `sorted()` accepts `key`/`reverse` positionally, rejects a
      4th positional arg, type-errors a non-bool `reverse`, and rejects duplicate /
      unknown keyword arguments (UnpackArgs parity).
- [x] **MISSING-88**: `list.index` rejects more than three positional args
      ("index: got N arguments, want at most 3").
- [x] **MISSING-89**: `enumerate(non_iterable)` error now carries the
      "enumerate:" name prefix.
- [x] **MISSING-90**: Integer format verbs `%d/%i/%o/%x/%X` wrap the NumberToInt
      cause as "%<verb> format requires integer: <cause>".
- [x] **MISSING-91**: `%c` reports the offending value when out of range and the
      "int or single-character string" requirement for non-int/non-string args.
- [x] **MISSING-92**: Unknown conversion verb → "unknown conversion %<c>".
- [x] **MISSING-93**: Trailing `%` checks argument availability before reporting
      the missing verb ("not enough arguments for format string" / "incomplete
      format").
- [x] **MISSING-94**: Unary-op type error → "unknown unary op: <op> <type>".
- [x] **MISSING-95**: Tuple-unpack mismatch uses "(got M, want N)" order with no
      inline position prefix.
- [x] **MISSING-96**: Item assignment → "<type> value does not support item
      assignment".
- [x] **MISSING-97**: Float `**` with a non-integral exponent now computes the real
      power via `@math.pow` (was NaN).
- [x] **MISSING-98**: `**` power operator removed. It was a MoonBit extension
      absent from starlark-go (where `**` is kwargs/params syntax only). With no
      clear use case it was dropped for strict starlark-go parity: `2 ** 10` is
      now a syntax error. `OpPow` removed from `@syntax.BinaryOp`; `eval_pow`/
      `float_pow` and the `binary("**")` dispatch removed; the `**` token is
      retained for `**kwargs`. MISSING-97 (Float `**`) is now moot.
- [x] **MISSING-99**: Adjacent string-literal concatenation (`"a" "b"`) removed;
      now a syntax error, matching starlark-go (decision: Go parity).
- [x] **MISSING-100**: Malformed keyword argument (`f(a.b=1)`) → "keyword argument
      must have form name=expr".
- [x] **MISSING-101**: Parser/lexer error *positions* now match starlark-go,
      which points diagnostics at `scanner.pos` (one column past the last
      consumed byte). Number-literal errors (obsolete octal, invalid float/int)
      report at the scanner's `current_pos()` instead of the literal start; the
      non-associative chained-comparison error reports one column past the
      operator via a new `Scanner::position()` accessor / `Parser::scanner_error`.

All earlier-pass deferrals now closed: MISSING-69 (%e/%f round-half-to-even),
70 (hash neg bigint), 71 (repeat boundary), 72 (Unicode is*/title/capitalize),
80 (undefined "did you mean"), 81 (non-ASCII ident `unicode.IsLetter`),
83 (pre-parsed expr eval entry point).

### Fourth-pass gap analysis (MISSING-102..116)

Fresh four-axis comparison against starlark-go plus first comparison of the
extension libraries (`json`, `math`, `time`, `struct`). Each fixed via TDD.

- [x] **MISSING-102** / **MISSING-111** / **MISSING-115**: `dict()` and
      `dict.update` now share a single `update_dict` helper mirroring
      starlark-go's `updateDict`. `dict.update` accepts any iterable of
      two-element pairs (e.g. `range`), not just tuple/list elements; both
      paths report "dictionary update sequence element #N has length M, want 2"
      with a `dict:`/`update:` prefix. `dict.popitem` empty error now reads
      "popitem: empty dict".
- [x] **MISSING-103**: `int(x, base)` validates the base argument's type in the
      string branch ("int: for base, got T, want int") instead of silently
      defaulting to base 10; a non-string `x` with any explicit base reports
      "int: can't convert non-string with explicit base".
- [x] **MISSING-104**: `dict.get`/`pop`/`setdefault` route through
      `check_positional`, rejecting excess positional args ("got N arguments,
      want at most 2") and keyword args.
- [x] **MISSING-105**: `format_float` switches a decimal-form value with a
      7-or-more-digit integer part (decimal exponent >= 6) to scientific
      notation, matching Go's `strconv.FormatFloat('g')`; e.g.
      `str(9999999.9)` → `"9.9999999e+06"`.
- [x] **MISSING-106**: a name bound only by an augmented assignment inside a
      function is pre-collected as a local, so a nested closure referencing it
      resolves cleanly instead of raising a false "undefined".
- [x] **MISSING-107**: `time.parse_time(x, format=...)` honors the layout via a
      Go reference-time parser (`parse_go_layout`) instead of discarding it and
      always parsing RFC3339; supports date/time verbs, 12-hour + AM/PM, month
      and weekday names, fractional seconds, and numeric/Z timezone tokens.
- [x] **MISSING-112**: `list.pop`/`insert`/`remove`/`index` use the nameErr style
      ("pop: got T, want int", "pop: index -1 out of range: empty list",
      "insert: got N arguments, want 2", "remove: got N arguments, want 1",
      "index: invalid start/end index: got T, want int").
- [x] **MISSING-113**: `int()` error messages carry the `int:` prefix
      ("int: missing argument for x", "int: cannot convert float NaN/infinity
      to integer").
- [x] **MISSING-114**: `chr`/`ord` arity and type messages use the nameErr style;
      `ord` also rejects keyword arguments and prefixes the codepoint-count error.
- [x] **MISSING-116**: `removeprefix`/`removesuffix` arity/type messages match
      starlark-go's UnpackPositionalArgs wording.
- [x] **MISSING-109**: added the `module(name, **kwargs)` builtin to
      `src/lib/struct/` (port of starlarkstruct's `MakeModule`): a "module"-typed
      value with `<module "name">` repr, member attributes, unhashable, frozen
      transitively. Wired into the `struct.star` load target.
- [x] **MISSING-110**: `struct + non_struct` now returns unhandled (None) so the
      evaluator emits the standard "unknown binary op: struct + T" message,
      matching starlark-go's `Binary` returning nil.
- [x] **MISSING-108**: thread-local clock override for `time.now()` (Go's
      `SetNow`). `BuiltinCallCtx` now exposes `get_local` (wired to the active
      thread's thread-local store); `time.now()` returns an embedder-provided
      fixed `time.time` stored under `now_override_key`, else the real clock.
      Public helpers `time_value(sec, nsec)` and `now_override_key` added.

### Fifth-pass gap analysis (MISSING-117..128)

Fresh four-axis comparison against starlark-go after MISSING-1..116 closed.
Each behavioral item confirmed empirically; fixed via TDD (Red test first).

- [x] **MISSING-117** [HIGH]: Module/load freeze was **shallow** — contained
      List/Dict/Set values stayed mutable after `exec_file`/`load`. `Module::freeze`
      only set the container's own frozen flag (`StarlarkDict::freeze` →
      `Hashtable::freeze`) and never recursed into the values. starlark-go
      deep-freezes loaded globals per value. Fixed by driving the recursive
      `@value.freeze_value` over each global value from `Module::freeze` (the
      generic `Hashtable` cannot reach it). Now mutating a loaded
      list/dict/set raises a frozen error. Commit: `ef5d9ac`
- [x] **MISSING-118**: `len(b"...".elems())` returned the byte count; Go's
      `bytesIterable` is only `Iterable` (not `Indexable`/`Sequence`) so `len()`
      errors `"object of type 'bytes.elems' has no len()"`. `length_of`
      (`value/iter.mbt`) now errors for `BytesElems`; `string.elems` stays
      `Indexable`. Commit: `0a94cf6`
- [x] **MISSING-119**: Single-element trailing-comma for/comprehension target
      (`for a, in ...`) bound the whole iterated value instead of unpacking the
      one-tuple. `parse_expr_list_as_expr` (`parser.mbt`) collapsed a one-element
      target list to the bare identifier; Go returns a `TupleExpr` whenever a
      comma was seen. Now always yields an `ETuple` once a comma is consumed.
      Commit: `a588176`
- [x] **MISSING-120**: `math.round` used `floor(x+0.5)`/`ceil(x-0.5)`, losing
      precision near the halfway point (`round(0.49999999999999994)`→`1.0`) and
      for large integral mantissas. Reimplemented as Go's `math.Round` via
      `trunc` + half-away-from-zero on the fractional remainder (exact, preserves
      `-0.0`) in `src/lib/math/math.mbt`. Commit: `5136144`
- [x] **MISSING-121** [low]: `math.pow(-1.0, ±Inf)` returned `nan`; C99/IEEE-754
      mandates `1`. Added a `float_pow` wrapper guarding the special case before
      delegating to `@std_math.pow` (`src/lib/math/math.mbt`). Commit: `99364ef`
- [x] **MISSING-122** [low-med]: `is_unicode_letter_rune` block ranges diverged
      from Go's `unicode.IsLetter` in both directions (under-accepted µ/ª/º/Vai/
      most SMP letters; over-accepted Devanagari digits Nd, currency Sc). Replaced
      with an exact, sorted L-category range table (`unicode_letters.mbt`, 677
      ranges from the UCD) looked up by binary search in `scanner.mbt`.
      Commit: `6303838`
- [x] **MISSING-123** [message]: `string.partition`/`rpartition` arity & type
      errors used Python style; routed through `check_positional`/`arg_as_string`
      for the nameErr form (`partition: got N arguments, want 1` /
      `partition: for parameter 1: got int, want string`). Commit: `e9ba873`
- [x] **MISSING-124** [message]: `string.join` arity & non-iterable errors used
      Python style; arity via `check_positional`, iterable type via inline
      `join: for parameter iterable: got int, want iterable`. Commit: `4cfd1dd`
- [x] **MISSING-125** [message]: set ops `intersection`/`difference`/`issubset`/
      `issuperset`/`symmetric_difference` arity & non-iterable errors; Go declares
      min=0 so >1 args → `want at most 1` and non-iterable → `for parameter 1: got
      int, want iterable`. Extracted shared `set_other_iter` helper. Commit: `eef12c5`
- [x] **MISSING-126** [message]: `str.format` divergences — unknown conversion
      uses `%q` double quotes; unmatched-brace gains `format:` prefix; attribute/
      element syntax errors match Go phrasing and append the field name.
      Commit: `be9f2d2`
- [x] **MISSING-127** [message]: non-integer subscript — getIndex form
      `<type> index: got <type>, want int` for reads; bare `got <type>, want int`
      for `setIndex` writes (`ops.mbt`). Commit: `172b9a8`
- [x] **MISSING-128** [message]: `*`/`**` in a non-assignment expression
      position used to report the assignment-target error regardless of context.
      Now routed through `parse_atom`'s default error as
      `got '*'/'**', want primary expression`, matching starlark-go's
      `parsePrimary` (`parse.go:868`). Added `Token::go_string` to single-quote
      punctuation tokens like Go's `GoString`. The incomplete-expression case
      (`x = (`) now also reads `got end of file, want primary expression`.

### Sixth-pass gap analysis (MISSING-129..131)

Fresh comparison against starlark-go focused on the call/argument-expansion
path (`*args`/`**kwargs` splat error handling), which earlier passes did not
cover. Each fixed via TDD (Red test first).

- [x] **MISSING-129** [MED]: `**kwargs` expansion with a non-string key silently
      dropped the entry instead of erroring. `eval_args` (`eval/expr.mbt`) now
      iterates the mapping and raises `"keywords must be strings, not <type>"`
      for any non-string key (matching `interp.go:330`), checking every key
      before binding. Commit: `aa87d3b`
- [x] **MISSING-130** [message]: `*`/`**` splat-operand type errors now match Go's
      wording. `f(*5)` / `f(*"abc")` → `"argument after * must be iterable, not
      <type>"`; `f(**5)` → `"argument after ** must be a mapping, not <type>"`
      (`interp.go:324,358`). The non-iterable `*` path now routes the generic
      `iterate` failure through the uniform message. Commit: `aa87d3b`
- [x] **MISSING-131** [message]: calling a non-callable value reported the Python
      style `"'<type>' object is not callable"`; now `"invalid call of
      non-function (<type>)"` (`eval.go:1197`) for both the `ExtVal` and generic
      branches of `call_value` (`eval/expr.mbt`). Commit: `aa87d3b`

### Seventh-pass gap analysis (MISSING-132..)

Fresh comparison against starlark-go focused on Unicode-aware string methods
and builtin argument-error wording. Each fixed via TDD (Red test first).

- [x] **MISSING-132** [behavioral]: `str.upper`/`lower`/`title`/`capitalize`
      used MoonBit's ASCII-only `String::to_upper`/`to_lower` plus a small
      digraph table, so non-ASCII letters were never recased
      (`"café".upper()` → `"CAFé"`, `"αβγ".upper()` → `"αβγ"`). starlark-go
      uses Go's `unicode.ToUpper`/`ToLower`/`ToTitle` (full simple case
      mapping). Added `src/internal/utf8util/case_mapping.mbt` carrying the
      `unicode.CaseRanges` table (328 entries) and Go's per-rune `to()` lookup
      (including the alternating Upper/Lower sequence delta); routed the four
      string methods through `to_upper_rune`/`to_lower_rune`/`to_title_rune`.
      Commit: `afe64a8`
- [x] **MISSING-133** [message]: `list`/`tuple`/`reversed`/`enumerate`/`any`/
      `all`/`set` and `list.extend` bind their iterable argument via
      starlark-go's `UnpackPositionalArgs`, which reports `"NAME: for parameter
      1: got T, want iterable"`. The previous messages dropped the prefix
      (`list`/`tuple`/`reversed`/`set` → bare `"got string, want iterable"`) or
      carried only the name (`enumerate`). Threaded the builtin name through
      `require_seq` (`eval/env.mbt`) and aligned the `enumerate`/`set` inline
      errors. Behavior unchanged. Commit: `0eae31b`
- [x] **MISSING-134** [behavioral]: `str.islower`/`isupper` derived "is cased"
      from MoonBit's ASCII-only case folding plus a digraph table, so
      `"é".islower()` and `"αβγ".islower()` returned false. Reimplemented via
      `utf8util` Unicode case mapping as starlark-go's `isCasedString(s) && s ==
      ToLower(s)` / `ToUpper(s)`; refined `is_cased_rune` to match Go's
      `isCasedRune` for the three fold-orbit special cases (ß cased; U+0130/
      U+0131 not). Commit: `cb99d8e`
- [x] **MISSING-135** [behavioral]: `str.istitle` only recognized the eight
      digraph codepoints, so non-ASCII letters were treated as uncased
      (`"Greek: Αβγ".istitle()` wrongly true, `"Hello Wörld".istitle()` wrongly
      false). Added Lu/Ll/Lt category range tables (stride-encoded, from Go's
      `unicode` rangetables) + `is_upper`/`lower`/`title_letter` to `utf8util`,
      then rewrote `istitle` to mirror starlark-go's exact branch structure
      (ASCII A-Z or Lt leads; any other Lu disqualifies; Ll must follow a cased
      letter). Commit: `af78161`

### Eighth-pass gap analysis (MISSING-136..155)

Fresh four-axis comparison against starlark-go after MISSING-1..135 / BUG-1..34
closed. Each fixed via TDD (Red test first).

- [x] **MISSING-136** [message + behavioral]: `bind_args` positional-argument-count
      errors diverged from Go in four ways: singular/plural (1 "argument" vs "arguments"),
      missing "at most" prefix for optional params, nullary message ("no arguments" vs
      "0 positional arguments"), and nullary not counting kwargs in total. Fixed in
      `eval/expr.mbt`: added nullary check, `has_optional_pos` helper for "at most"
      detection, `pos_arg_count_msg` helper for consistent formatting.
- [x] **MISSING-137** [behavioral]: list methods silently ignored keyword arguments.
      Fixed by threading `kw_args` into `call_list_method` and routing
      `append`/`extend`/`remove`/`insert`/`index`/`clear` through `check_positional`.
- [x] **MISSING-138** [message]: `list.append`/`list.extend` arity used ad-hoc text
      ("takes exactly one argument"); now uses nameErr form ("got N arguments, want 1").
- [x] **MISSING-139** [behavioral]: zero-arg dict/list/set methods ignored excess
      positional args. Fixed via `check_positional` with min=max=0 for `list.clear`,
      `dict.keys/values/items/clear/popitem`, `set.clear/pop`.
- [x] **MISSING-140** [behavioral]: set methods `add`/`discard`/`remove` ignored
      keyword arguments. `union` silently accepted kwargs. Fixed via `check_positional`
      for one-arg methods; `union` now emits "does not accept keyword arguments".
- [x] **MISSING-141** [message]: `min`/`max`/`sorted` accepted a non-callable `key`
      and failed only at call time. Fixed by validating key is callable before iteration:
      emits "<name>: for parameter key: got T, want callable".
- [x] **MISSING-142** [behavioral + message]: string search-index args (`find`/`rfind`/
      `index`/`rindex`/`count`/`startswith`/`endswith`) used `BigInt::to_int()` (32-bit
      wraparound) instead of `to_int64()`. Fixed in `parse_search_index`: use int64 range
      check and raise "METHOD: invalid N index: M out of range" for out-of-int64 BigInts.
- [x] **MISSING-143** [message + behavioral]: string-escape error messages diverged from
      Go's `unquote` (`quote.go`). Fixed: octal checks n > 127 before n >= 256; non-ASCII
      octal message includes sequence and hex encoding; `\x` with valid h1 and visible non-hex
      h2 gives "invalid" not "truncated"; `\uNNNN`/`\UNNNNNNNN` track partial sequence for
      truncated vs invalid distinction; surrogate → "invalid Unicode code point U+XXXX";
      out-of-range → "code point out of range: \UXXXXXXXX (max \U0010ffff)".
- [x] **MISSING-144** [message]: `Parser::expect`/`expect_ident` and newline paths used
      `tok.to_string()` instead of `go_string()` (which single-quotes punctuation), and some
      messages reversed the `got X, want Y` order. Fixed: `expect` uses `go_string()`; newline
      path changed to "got X, want newline".
- [x] **MISSING-145** [message]: `not an identifier` cases used "expected identifier, got X"
      / "expected parameter, got X". Fixed: `expect_ident` and param parser emit "not an
      identifier" for any non-Ident token.
- [x] **MISSING-146** [message]: comprehension-clause error dropped the "for, or if"
      alternatives. Fixed: `parse_comp_clauses` emits "got X, want ']', for, or if" when
      breaking on an unexpected non-bracket token.
- [x] **MISSING-147** [message]: `not` not followed by `in` used "'not' in comparison must
      be followed by 'in'". Fixed: emits "got X, want in" using `go_string()`.
- [x] **MISSING-149** [position]: `invalid int literal` was reported at the end column
      instead of the start. Fixed: use `start` position in the `invalid int literal` branch.
- [x] **MISSING-150** [message]: `load` operand errors used different text than Go's
      `parse.go`. Fixed: non-string first arg → "first operand of load statement must be
      a string literal"; non-string operand → "load operand must be \"name\" or
      localname=\"name\" (got T)"; ident without `=` → "load operand must be \"x\" or
      x=\"originalname\"".
- [x] **MISSING-151** [behavioral + message]: math builtins used prefixed names
      (`math.sqrt`). Fixed: all builtins registered with bare names (`sqrt`, `log`, etc.)
      so `repr(math.sqrt)` → `"<built-in function sqrt>"`.
- [x] **MISSING-152** [message]: math arity/type error wording differed from Go.
      Fixed: arity says "got N arguments, want 1" (no "positional"); type errors include
      "for parameter N:" prefix via updated `to_float_param`; `math.log` uses "at least 1"
      / "at most 2" arity messages.
- [x] **MISSING-153** [behavioral + message]: time builtins used prefixed names
      (`time.now`, `time.from_timestamp`, etc.). Fixed: all registered with bare names.
- [x] **MISSING-154** [behavioral + message]: `time.parse_duration` only accepted a string;
      Go's `Duration.Unpack` also accepts an existing `time.duration` (returns it unchanged).
      Fixed: check for `time.duration` ExtVal before string; type-mismatch error now uses
      "parse_duration: for parameter 1: got T, want a duration, string, or int".
- [x] **MISSING-155** [message]: `time.time()` positional-arg rejection used "time.time:
      unexpected positional argument" (singular, prefixed name); Go uses "time: unexpected
      positional arguments". Fixed.

### Ninth-pass gap analysis (MISSING-156..167)

Fresh comparison against starlark-go covering slicing/indexing semantics,
`repr`/`str` escape tables, comparison-operator error wording, and the
json/struct extension libraries. Each fixed via TDD (Red test first).

- [x] **MISSING-158** [message]: non-int slice index/step errors now read
      "invalid start/end index: got T, want int" and "invalid slice step: got T,
      want int" (was "slice indices must be integers" / "slice step must be an
      integer"), matching `eval.go:1265,1330,1341`. Fixed in `eval/expr.mbt`.
- [x] **MISSING-159** [message]: the unhandled-index fallback now names both
      operand types — "unhandled index operation int[int]" (was "unhandled index
      operation: int"), matching `eval.go:707`. Fixed in `eval/ops.mbt`.
- [x] **MISSING-160** [message]: non-sliceable operand now reports "invalid slice
      operand bool" (was "'bool' object is not sliceable"), matching
      `eval.go:1256`. Fixed in `eval/ops.mbt` (three sites).
- [x] **MISSING-161** [message]: `repr` emits named escapes `\a`/`\b`/`\f`/`\v`
      for 0x07/0x08/0x0c/0x0b instead of `\xNN`, matching `quote.go:271-285`.
      Affects string and bytes repr (shared `repr_bytes_inner`).
- [x] **MISSING-163** [message]: ordered-comparison type errors now carry the
      actual operator ("int <= string not implemented", etc.) instead of always
      "<". Threaded an `op` label through `compare_values`/`compare_values_depth`/
      `slice_cmp_depth` (`value/traits.mbt`); `eval_cmp` (`eval/ops.mbt`) derives
      the operator from the comparison direction. Matches `value.go:1529,1573`.
- [x] **MISSING-156** [message]: BigInt subscript index now produces the
      conversion-error format `"<type> index: N out of range"` when the value
      exceeds int32 range (matching Go's `AsInt32` path via `eval.go:697`).
      Added int32 range check in `adjust_index` (`eval/ops.mbt`).
- [x] **MISSING-157** [behavioral + message]: BigInt slice bounds and step
      outside int32 range now raise `"invalid start/end index: N out of range"`
      / `"invalid slice step: N out of range"` instead of silently truncating.
      Added int32 guards in slice parsing in `eval/expr.mbt`.
- [x] **MISSING-162** [message]: `is_unicode_printable` extended to exclude
      C1 controls (U+0080-U+009F), NBSP (U+00A0), private-use BMP (U+E000-U+F8FF),
      noncharacters (FDD0-FDEF, FFFE, FFFF), and supplemental private-use planes
      (U+F0000+), matching Go's `strconv.IsPrint` for repr escaping.
- [x] **MISSING-148** [behavioral]: unbalanced closing brackets `)`, `]`, `}`
      at scanner depth 0 now produce `"unexpected '<c>'"` error, matching
      starlark-go `scan.go:728-729`.
- [x] **MISSING-164** [message]: `json.decode` now reports the actual consumed
      offset for parse errors instead of always 0. All parse functions carry
      `(Int, String)` errors; `decode_from_json` uses the offset from failures.
      Matches starlark-go `json.go:543`.
- [x] **MISSING-165** [message]: `json.decode` now parses an object key as a
      value and reports "got T for object key, want string" for a non-string key,
      matching `json.go:461-463` (was a generic unexpected-character error).
- [x] **MISSING-166** [behavioral]: `json.encode` escapes the DEL byte (0x7f) as
      `\x7f` via the AppendQuote path instead of writing it raw (`json.go:101-110`).
- [x] **MISSING-167** [message]: dot access on a custom value (e.g. `module()`)
      whose `get_attr` returns no value now reports "T has no .x field or method"
      (was "T has no attribute 'x'"), matching `eval.go:649`. Fixed in
      `eval/expr.mbt` ExtVal branch.
- [x] **json non-ASCII encoding** (was `bugfix.md` M.5): `json.encode` now mirrors
      starlark-go's two-branch quoting — printable-ASCII strings use a
      `strconv.AppendQuote` emulation, while any string with a control or
      non-ASCII byte uses an `encoding/json.Marshal` emulation that emits raw
      UTF-8, replaces invalid bytes with U+FFFD, escapes `<`/`>`/`&` and
      U+2028/U+2029, and uses `\n`/`\r`/`\t` shortcuts. Previously all non-ASCII
      was escaped as `\uXXXX`. (Reverses the earlier Phase 7.5 "non-ASCII via
      `\uXXXX`" choice, per user decision to prefer Go parity.)

### Eleventh-pass gap analysis (MISSING-168..180)

Fresh five-area parallel comparison against starlark-go after MISSING-1..167 /
BUG-1..34 closed. Each fixed via TDD (Red test first).

- [x] **MISSING-168** [behavioral]: set intersection (`&` and `.intersection()`)
      now iterates the other/RHS operand and keeps elements present in the
      receiver, so the result follows the other operand's order (e.g.
      `{1,2,3} & {3,2,4}` → `set([3, 2])`), matching `value.go`/`eval.go`.
- [x] **MISSING-169** [behavioral]: `int(string)` no longer trims surrounding
      whitespace (`int(" 10")` raises), matching Go's `big.Int.SetString`.
- [x] **MISSING-170** [message]: `int()` invalid-literal error now carries the
      `int:` name prefix (`int: invalid literal with base 10: xyz`).
- [x] **MISSING-171** [message]: `len()` on a non-sized value reports
      `len: value of type T has no len` instead of the CPython form; covers the
      generic, bytes.elems, string.codepoints, and custom-value paths.
- [x] **MISSING-172** [behavioral]: an all-digit `str.format` field name that
      overflows the int range is treated as a keyword (`keyword N not found`)
      rather than a tuple index, matching Go's `decimal()`.
- [x] **MISSING-173** [message]: nested-replacement-field error now carries the
      `format:` prefix.
- [x] **MISSING-174** [behavioral + message]: `getattr` (2..3 args) and `hasattr`
      (exactly 2) route through `check_positional`/`arg_as_string`, rejecting
      excess args, keyword args, and non-string attribute names with the
      UnpackPositionalArgs wording.
- [x] **MISSING-175** [message]: unpacking a non-iterable reports
      `got T in sequence assignment` with no inline position prefix.
- [x] **MISSING-176** [behavioral]: `json.encode` formats floats via the shared
      Go-faithful `format_float` (`1234567.0` → `1.234567e+06`, `1e-7` → `1e-07`).
- [x] **MISSING-177** [message]: `math.ceil`/`floor` errors drop the name and
      `for parameter 1:` prefix (Go unpacks them into a plain Value).
- [x] **MISSING-178** [behavioral]: `json.indent`/`encode_indent` validate their
      input and reject malformed JSON instead of silently reformatting.
- [x] **MISSING-179** [message]: `time.parse_duration` reports
      `time: invalid duration "<orig>"` with the full original string instead of
      the invented `invalid duration component`/`number` stems.
- [x] **MISSING-180** [message]: `json.indent`/`encode_indent` report a non-string
      `prefix`/`indent` with `for parameter X: got T, want string`.

### Twelfth-pass gap analysis (MISSING-181..191)

Fresh five-area comparison against starlark-go after MISSING-1..180 closed.

- [x] **MISSING-181** [behavioral + message]: `int()` builtin now accepts `x`
      as a keyword argument, rejects unknown kwargs ("int: unexpected keyword
      argument NAME"), rejects >2 positional args ("int: got N arguments, want
      at most 2"), and detects duplicate values for `x` ("int: got multiple
      values for keyword argument x"). Source: `eval/expr.mbt`. Commit: `bae53ba`
- [x] **MISSING-182** [behavioral + message]: `float()` builtin now rejects all
      keyword arguments with "float does not accept keyword arguments" (not silently
      ignored) and reports the arity error as "float got N arguments, wants 1" (not
      "float() takes at most one argument"). Commit: `bae53ba`
- [x] **MISSING-183** [message]: `list.pop` and `list.insert` with a non-int
      argument now include "for parameter 1:" prefix: "pop: for parameter 1: got
      T, want int" / "insert: for parameter 1: got T, want int". Commit: `638146c`
- [x] **MISSING-184** [behavioral + message]: `list.insert` / `list.pop` with a
      BigInt index outside the signed 64-bit range now raise "for parameter 1: N
      out of range (want value in signed 64-bit range)" instead of silently clamping
      (insert) or reporting a misleading index-range error (pop). Commit: `638146c`
- [x] **MISSING-185** [message]: `\U` code-point-out-of-range error now feeds the
      offending value into both slots of the message ("code point out of range:
      \\U00110000 (max \\U00110000)"), matching Go's format where both %s and %08x
      receive the same value n. Commit: `557f5ec`
- [x] **MISSING-186** [message]: `\x` followed by two present-but-non-hex chars
      now reports "invalid escape sequence \xNN" (not "truncated"). "truncated" is
      reserved for when a required digit slot is occupied by EOF or a string
      delimiter. Commit: `557f5ec`
- [x] **MISSING-187** [position]: escape-sequence errors inside prefixed string/bytes
      literals (`b"..."`, `r"..."`) are now reported at the opening-quote column
      rather than the prefix-character column, matching Go's `sc.pos` capture after
      consuming the prefix. Commit: `557f5ec`
- [x] **MISSING-188** [message]: a bare `*` parameter followed by a non-comma token
      now reports "want ','" instead of "want ')'". Added check inside the param loop
      that the next token is `,` or `)`, mirroring Go's unconditional consume(COMMA)
      loop. Source: `parser/parser.mbt`. Commit: `f051940`
- [ ] **MISSING-189** [position]: `load` per-symbol errors (empty identifier,
      leading-underscore) reported at load-keyword position instead of each symbol's
      position. Requires AST change to thread per-symbol positions through `SLoad`.
      Deferred — larger fix.
- [x] **MISSING-190** [message]: `math` unary/binary builtins (`make_unary`,
      `make_binary`, `make_ceil`, `make_floor`) now check `kw_args.length() != 0`
      first and return "NAME: unexpected keyword arguments", matching Go's
      `UnpackPositionalArgs` kwargs-before-arity check. Commit: `1565b69`
- [x] **MISSING-191** [behavioral]: `time.duration * int` with a multiplier outside
      the signed 64-bit range now raises "int value out of range (want signed 64-bit
      value)" instead of silently wrapping. Commit: `84cdb6f`

### Resolved post-release API additions

- [x] **MISSING-54**: `eval_expr_with_opts(thread, filename, src, opts, env)` added;
      `eval_expr` delegates to it with default options. Re-exported in public façade.
- [x] **MISSING-55**: `file_program(file, opts, is_predeclared)` and
      `source_program_with_file` added; `SyntaxFile` type alias and `parse_file`
      re-exported in public façade. Enables parse-once-exec-many pattern.
- [x] **MISSING-58**: `Universe::set(name, value)` added; `exec_file_with_universe`
      wires a custom universe into both the resolver and eval env.
- [x] **MISSING-60**: Closed — closed `Value` enum via `ExtVal(CustomValue)` is
      the confirmed design.
- [x] **MISSING-61**: `\u`/`\U` accepted in bytes literals; encodes as UTF-8 bytes.
- [x] **MISSING-63**: `br"..."` now rejected; only `rb"..."` is valid raw-bytes.
- [x] **MISSING-66**: `hash_float` uses `double_to_bigint` ensuring cross-type
      hash parity for large integers (e.g. `hash(1e20) == hash(10**20)`).

### Deferred public-API gaps

- [ ] **MISSING-62**: No bytecode `CompiledProgram`/`Program.Write` — tree-walking
      interpreter only. Tracked as a future major milestone.
- [ ] **MISSING-64**: Thread-local storage, public `Unpacker`/`UnpackArgs`, separate
      `FileOptions` entry points — future work.

---

## Future work (out of initial release scope)

- Hide `StarlarkFunction.body/params/captured_scope` from public API — these expose
  `@syntax.Stmt` / `@syntax.Param` AST types. Requires moving call dispatch logic into
  the `value` package or introducing a trait boundary to avoid circular imports.
- `math` extension library — implemented as `src/lib/math/`
- ~~`time` extension library~~ — implemented as `src/lib/time/`; non-UTC timezones via IANA tzdb (native) / static table (wasm/js); native-only DST tests in `time_tz_native_test.mbt`
- `proto` extension library (`starlark-go/lib/proto`)
- ~~`starlarkstruct`~~ — implemented as `src/lib/struct/`; `struct()` builtin, `gensym()` callable symbols, `+` merge, `make_struct` API
- Bytecode compilation / interpreter (currently AST-walking only) — MISSING-62
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
