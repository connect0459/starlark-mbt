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
- `src/internal/format/` — `%`-formatting and `str.format` engine
- `src/internal/unpack/` — argument binding helper for built-ins
- `src/internal/starlarktest/` — test harness for executing `.star` scripts as
  MoonBit tests; embeds `assert.star` as a `const` string; not part of the
  public API (internal only). Created in Phase 6 before porting `.star` files.
- `src/main/` — CLI entry point (deferred until Phase 8)

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
- [ ] Update `src/starlark/moon.pkg` to import each internal package as needed
- [x] Verify `moon check` passes on the empty skeleton before Phase 0.5 coding
      begins (confirm no broken imports or missing package declarations)
- **Decision**: MoonBit `Map[K,V]` is a sorted tree map (NOT insertion-ordered);
  `src/internal/hashtable/` is required (see package layout note above)
- [ ] Design the `Hashable` trait / key-hash protocol for hashtable, Dict, and Set;
      define hash functions for each primitive type (None, Bool, Int, Float, String, Bytes, Tuple)
- **Design decision**: `Position` column convention — use 1-based line AND 1-based column
      to match starlark-go (`Position{Line: 1, Col: 1}` for start of file). Document in
      `src/internal/errors/`.
- **CI**: `.github/workflows/ci.yml` already runs `moon check` + `moon test` on
  `js`, `wasm`, `wasm-gc`, `native`; expand to add `moon coverage analyze` in
  Phase 7 (the WPT step must be removed first — see Fix task above).

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

## Phase 0.75: Public API & Embedding Surface

Settle the public API shape before bulk implementation, so subsequent
phases don't churn the `.mbti`.

- [ ] `Thread` — print callback, load callback, call stack, recursion depth limit, max execution steps
- [ ] `Module` — execution result; `globals` dict; frozen after `exec_file` returns
- [ ] `Universe` — predeclared bindings (built-ins) injected into modules
- [ ] `Options` — feature flags. All default to **true** unless noted:
      `allow_set`, `allow_recursion`, `allow_lambda`, `allow_while`,
      `allow_bytes`, `allow_float`, `allow_global_reassign`,
      `allow_top_level_control` (top-level `if` / `for` / `while`),
      `load_binds_globally` (deprecated starlark-go flag; kept for parity)
- [ ] `Predeclared` / `Universe` distinction — `Universe` is the built-in
      set (frozen, shared across threads); `Predeclared` is per-execution
      extra bindings injected before user globals
- [ ] `exec_file(thread, filename, src, options) -> Module` — top-level entry point
- [ ] `eval(thread, filename, expr, env) -> Value` — single-expression entry point
- [ ] Loader contract — `(Thread, module_path) -> Result[Module, EvalError]`
      (the loader receives the active `Thread` so it can make nested calls)
- [ ] Wire up `src/starlark/` as a thin public façade: re-export `Thread`, `Module`,
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
      hash (`hash(1.0) == hash(1)`, `hash(0.0) == hash(0)`). (hash not yet implemented)
- [x] `String` — `StarlarkString { raw: String, bytes: Bytes }` with UTF-8 byte backing.
      `byte_len()`, `byte_at(i)`, `equals()` implemented. MoonBit UTF-16 divergence resolved.
- [x] `Bytes` — `BytesVal(Bytes)`; `repr` produces `b"..."` with `\xNN` escapes.
- [x] `List` — `StarlarkList { mut items, mut frozen }`; `truth`, `repr` implemented (stub)
- [x] `Tuple` — `TupleVal(Array[Value])`; `repr` includes trailing comma for singleton
- [ ] `Dict` — mutable mapping (insertion-ordered); keys are any hashable
      Starlark value (not just `String`) — use `src/internal/hashtable/`
- [ ] `Set` — mutable hash-set (gated by `allow_set`); keys are any hashable value.
      Sets maintain **insertion order** (same as Dict).
- [ ] `Function` — user-defined (Starlark source)
- [ ] `BuiltinFunction` — host-provided callable
- [ ] `BoundMethod` — method bound to a receiver (e.g., `"abc".upper`)
- [ ] `Range` — lazy iterable returned by `range()`; not a List

### Traits / protocols

- [x] `repr` — implemented for primitives + List/Tuple (cycle detection deferred)
- [x] `truth` — truthiness for `if`, `while`, `and`, `or` (all current variants)
- [ ] `to_string` — `str()` output (unquoted string for Str, repr for others)
- [ ] `equals` — structural equality (with cycle detection)
- [ ] `hash` — for dict/set keys (None, Bool, Int, Float, String, Bytes, Tuple)
  - Tuple is only hashable if all elements are hashable
  - Unhashable use raises `EvalError`
- [ ] `compare` — total ordering for `<`, `<=`, `>`, `>=`; **same-type only** (mixed types → TypeError)
- [ ] `Comparable` trait — total ordering protocol needed by `sorted()`, `min()`, `max()`
- [ ] `Attr` trait — attribute access protocol for `getattr()`, `hasattr()`, `dir()`
      (required by custom extension types; built-in types handle this internally)
- [ ] `type_name` — `type()` built-in support; canonical names are:
      `"NoneType"`, `"bool"`, `"int"`, `"float"`, `"string"`, `"bytes"`,
      `"list"`, `"tuple"`, `"dict"`, `"set"`, `"function"`,
      `"builtin_function_or_method"`

### Iterator / sequence / mapping protocols

- [ ] `Iterable` — types that support `for x in ...`
- [ ] `Iterator` — stateful iterator (next / done); `Done()` **must** be called to release
      iterator slot — it decrements `itercount` on the container and must be called even
      if iteration was aborted mid-way (e.g., via `break`). Reference:
      `starlark-go/starlark/value.go` `Iterator` interface.
- [ ] `IterableMapping` — combined `Iterable + Mapping` for dict/set iteration over keys
      (used by `for k in d` and `for k, v in d.items()`). Reference:
      `starlark-go/starlark/value.go` line ~311.
- [ ] `Sequence` — `Iterable` + length + indexing (`List`, `Tuple`, `String`, `Bytes`, `Range`)
- [ ] `Mapping` — `Dict` key/value access protocol
- [ ] `Indexable` — supports `a[i]` (Sequence + Mapping)

### Frozen value semantics

- [ ] `freeze()` operation on mutable types (List, Dict, Set, Function closure cells)
- [ ] Mutation after freeze raises `EvalError`
- [ ] Freezing propagates transitively through contained values
- [ ] Module dict frozen automatically when `exec_file` returns
- [ ] **Iterator freezing**: iterating a mutable container (List, Dict, Set) with a `for`
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

## Phase 2: Lexer / Scanner

Tokenise Starlark source into a flat token stream.

### Tokens to handle

- [ ] Literals
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
- [ ] Keywords: `and`, `break`, `continue`, `def`, `elif`, `else`, `for`, `if`, `in`, `lambda`, `load`, `not`, `or`, `pass`, `return`, `while`
- [ ] Keyword literals: `None`, `True`, `False` — scanned as keywords and produce
      `Literal` tokens (not `Ident`), matching starlark-go scanner behavior
- [ ] Note: old-style octal (`0755`) is **NOT** supported; only `0o755` is valid
- [ ] Identifiers (including leading `_`)
- [ ] Operators: `+`, `-`, `*`, `/`, `//`, `%`, `**`, `~`, `&`, `|`, `^`, `<<`, `>>`, `==`, `!=`, `<`, `<=`, `>`, `>=`, `=`, `+=`, `-=`, `*=`, `/=`, `//=`, `%=`, `&=`, `|=`, `^=`, `<<=`, `>>=`
- [ ] Delimiters: `(`, `)`, `[`, `]`, `{`, `}`, `,`, `;`, `:`, `.`, `*`, `**`
- [ ] Indentation: `INDENT` / `DEDENT` tokens (tab/space rules)
- [ ] Comments: `#` to end-of-line (skipped)
- [ ] Newlines (logical vs physical)
- [ ] **Explicit line continuation** `\<newline>`
- [ ] **Implicit line continuation** inside `(`, `[`, `{`
- [ ] Attach `Position` to every token

### String literal quoting helper

- [ ] `unquote(literal) -> (String, is_bytes)` — decode source-level escapes
- [ ] `quote(string, double_quote) -> String` — produce a Starlark-safe literal
      with appropriate escapes (used by `repr`, error messages)
- [ ] Reference: `starlark-go/syntax/quote.go`

### TDD scope

Reference: `starlark-go/syntax/scan_test.go`, `starlark-go/syntax/quote_test.go`.

---

## Phase 3: Parser / AST

Build an AST from the token stream. Each node carries a `Position`.

### Expressions

- [ ] `Literal` — None, bool, int, float, string, bytes
- [ ] `Ident` — identifier reference
- [ ] `UnaryExpr` — `-`, `+`, `~`, `not`
- [ ] `BinaryExpr` — all binary operators incl. `in`, `not in`, `%` (string format)
- [ ] `ChainedComparison` — `a < b < c` is a single AST node (not a nested `And`);
      the middle operand (`b`) is evaluated exactly once. Reference:
      `starlark-go/syntax/syntax.go` (`BinaryExpr` with chained ops list)
- [ ] `IfExpr` — `x if cond else y`
- [ ] `IndexExpr` — `a[i]`
- [ ] `SliceExpr` — `a[start:end:step]`
- [ ] `DotExpr` — `x.attr`
- [ ] `CallExpr` — `f(args…)` with positional, keyword, `*args`, `**kwargs`
- [ ] `ListExpr` — `[…]` (trailing comma allowed)
- [ ] `TupleExpr` — `(a, b, …)`; single-element tuple `(x,)` distinguished from grouping `(x)`
- [ ] `DictExpr` — `{k: v, …}` (trailing comma allowed)
- [ ] `SetExpr` — `{x, …}` (gated by `allow_set`)
- [ ] `Comprehension` — list/dict/set comp with multiple `for`-clauses and nested
      `if`-guards: `[x+y for x in xs for y in ys if p(x,y)]`. Each `for`-clause
      introduces a new scope; inner variables shadow outer ones.
- [ ] `LambdaExpr` — `lambda params: expr` (body restricted to single Test; gated by `allow_lambda`)

### Statements

- [ ] `AssignStmt` — `=`, `+=`, `-=`, … augmented assigns; tuple unpacking LHS
- [ ] `ExprStmt` — bare expression statement
- [ ] `IfStmt` — `if / elif / else`
- [ ] `ForStmt` — `for x in iterable:`
- [ ] `WhileStmt` — `while cond:` (gated by `allow_while`)
- [ ] `ReturnStmt` — `return [expr]`
- [ ] `BreakStmt` / `ContinueStmt` / `PassStmt`
- [ ] `DefStmt` — `def name(params): body` with default args, `*args`, `**kwargs`; trailing comma in params
- [ ] `LoadStmt` — `load("path", …)` with optional aliasing; **only at module scope**

### Unsupported Python constructs (parser must reject)

The parser must emit a `SyntaxError` for these Python features absent from Starlark:

- [ ] `global` / `nonlocal` statements
- [ ] `del` statement
- [ ] `import` statement (only `load` is valid)
- [ ] `raise` statement
- [ ] `try` / `except` / `finally` / `else` blocks
- [ ] `class` definitions
- [ ] `with` / `as` statements
- [ ] `async` / `await`
- [ ] Walrus operator `:=`
- [ ] `*rest` in LHS tuple unpacking (`a, *b, c = ...`) — Starlark does not support this
- [ ] `is` / `is not` operators
- [ ] Type annotations in function parameters (`def f(x: int)`) and assignments (`x: int = 1`)
- [ ] `yield` / `yield from`
- [ ] `print` as a statement (it is a built-in function, not a keyword)

### AST walker

- [ ] `walk(node, visit)` — depth-first traversal visiting every child node;
      used by the resolver and any future linter / tooling
- [ ] Reference: `starlark-go/syntax/walk.go`

### TDD scope

Reference: `starlark-go/syntax/parse_test.go`, `starlark-go/syntax/walk_test.go`.

---

## Phase 4: Name Resolution

Resolve variable scopes before evaluation.

- [ ] Collect all binding sites (def params, for targets, assign LHS, comprehension vars)
- [ ] Classify each reference: `local`, `cell` (closure), `free`, `global`, `predeclared`, `universal`
- [ ] Assignment inside a function → local binding (Python rule)
- [ ] Forward references allowed at module scope; not inside a single block before assignment
- [ ] Error on use-before-def
- [ ] Validate function parameter order: positional → `*args` → keyword-only → `**kwargs`
- [ ] No duplicate parameter names
- [ ] **`load` must be at module scope**
- [ ] **No reassignment of `load`-imported symbols** (also gated by `allow_global_reassign`)
- [ ] **Recursion detection** — error if disallowed by `allow_recursion=false`
- [ ] **No global mutation from functions** unless `allow_global_reassign=true`
- [ ] **Top-level `if` / `for` / `while`** rejected unless `allow_top_level_control=true`
- [ ] **`load` binding scope** — file-local by default; global if `load_binds_globally=true`

### TDD scope

Reference: `starlark-go/resolve/resolve_test.go`.

---

## Phase 5: Evaluator

Execute resolved AST nodes with an environment (binding stack).

### Execution context (Thread)

- [ ] `Thread` — holds print callback, load callback, call stack, recursion depth limit (default 100), max execution steps (optional)
- [ ] Recursion depth check
- [ ] Step budget check (Halt when exceeded)
- [ ] Print output routed through `Thread.print`

### Expression evaluation

- [ ] Literals — return wrapped Value
- [ ] Identifiers — environment lookup (per resolver classification)
- [ ] Unary / binary operators — dispatch on value types:
  - Arithmetic: `+`, `-`, `*`, `//` (floor-div toward -inf), `%` (sign = divisor),
    `/` (true division → Float; requires `allow_float`), `**` (power)
  - Bitwise (Int only): `&`, `|`, `^`, `<<`, `>>`; unary `~` (bitwise NOT)
  - Comparison: `==`, `!=`, `<`, `<=`, `>`, `>=` (same-type only; mixed → TypeError)
  - Membership: `in`, `not in`
  - Boolean short-circuit: `and`, `or`; unary `not`
- [ ] **`%` string formatting** — full spec: `%s`, `%r`, `%d`, `%i`, `%o`, `%x`, `%X`, `%e`, `%f`, `%g`, `%c`, `%%`, with width/precision/flags
- [ ] Short-circuit `and` / `or`
- [ ] Conditional expression `x if c else y`
- [ ] Subscript, slice (negative indices, negative step), attribute access (returns `BoundMethod` for methods)
- [ ] Function call — full argument binding (positional, keyword, `*args`, `**kwargs`, defaults captured at def time, errors for missing/excess args)
- [ ] Lambda evaluation — create `Function` value inline
- [ ] Comprehensions (list, dict, set) with multiple `for`-clauses and nested `if`-guards
- [ ] Chained comparison evaluation — `a < b < c` evaluates left-to-right; `b` is
      evaluated exactly once; short-circuits on first false result

### Statement execution

- [ ] Simple assignment
- [ ] Augmented assignment — in-place where applicable:
  `+=`, `-=`, `*=`, `//=`, `%=`, `/=`, `**=`, `&=`, `|=`, `^=`, `<<=`, `>>=`
- [ ] Augmented assignment to subscript — `a[i] += v` must read, apply the operator,
      and write back; `d[k] += v` likewise (dict); target is evaluated once
- [ ] Tuple unpacking assignment (`a, b = 1, 2`; nested; `*rest` not supported in Starlark)
- [ ] `if / elif / else`
- [ ] `for` loop with `break` / `continue`; iteration **freezes** the iterable for the
      loop's duration (see Phase 1 frozen value semantics); mutations inside the loop body
      raise `EvalError`
- [ ] `while` loop with `break` / `continue`
- [ ] `def` — create `Function` value, capture frozen defaults & free variables
- [ ] `return` — unwind with return value
- [ ] `load` — module loading via `Thread.load` callback; cycle detection
- [ ] `pass`

### Control flow

- [ ] Implement via tagged signals (`Break`, `Continue`, `Return(value)`)

### Frozen value enforcement

- [ ] Mutation of frozen List/Dict/Set raises `EvalError`
- [ ] Module dict frozen on completion of `exec_file`

### Built-in argument binding helper

- [ ] `unpack_args(name, positional, keyword, spec) -> Result` — extract
      typed arguments for built-in implementations with explicit names,
      required/optional markers, and type checks
- [ ] Reference: `starlark-go/starlark/unpack.go`

### TDD scope

Reference: `starlark-go/starlark/eval_test.go`, bitflow `src/starlark/` test files.

---

## Phase 6: Built-in Functions

Implement the standard Starlark built-in functions.

| Function | Status | Notes |
| --- | --- | --- |
| `abs` | [ ] | |
| `all` | [ ] | |
| `any` | [ ] | |
| `bool` | [ ] | |
| `bytes` | [ ] | |
| `chr` | [ ] | |
| `dict` | [ ] | |
| `dir` | [ ] | |
| `enumerate` | [ ] | optional `start=` keyword arg (default 0) |
| `fail` | [ ] | |
| `float` | [ ] | |
| `getattr` | [ ] | |
| `hasattr` | [ ] | |
| `hash` | [ ] | |
| `int` | [ ] | optional `base=` keyword arg (2-36; 0 = auto-detect) |
| `len` | [ ] | |
| `list` | [ ] | |
| `max` | [ ] | supports `key=` keyword arg |
| `min` | [ ] | supports `key=` keyword arg |
| `ord` | [ ] | |
| `print` | [ ] | supports `sep=` and `end=` keyword args |
| `range` | [ ] | |
| `repr` | [ ] | |
| `reversed` | [ ] | |
| `set` | [ ] | |
| `sorted` | [ ] | `key=`, `reverse=` keyword args; result is stable |
| `str` | [ ] | |
| `tuple` | [ ] | |
| `type` | [ ] | |
| `zip` | [ ] | 0+ iterables; 0 or 1 args valid; no keyword args |

### Built-in methods per type

- [ ] `string`: `capitalize`, `codepoint_ords`, `codepoints`, `count`,
      `elem_ords`, `elems`, `endswith`, `find`, `format`, `index`,
      `isalnum`, `isalpha`, `isdigit`, `islower`, `isspace`, `istitle`,
      `isupper`, `join`, `lower`, `lstrip`, `partition`, `removeprefix`,
      `removesuffix`, `replace`, `rfind`, `rindex`, `rpartition`, `rsplit`,
      `rstrip`, `split`, `splitlines`, `startswith`, `strip`, `title`, `upper`
- [ ] `bytes`: `elems`, `elem_ords`
- [ ] `list`: `append`, `clear`, `extend`, `index`, `insert`, `pop`, `remove`, `reverse`, `sort`
- [ ] `dict`: `clear`, `get`, `items`, `keys`, `pop`, `popitem`, `setdefault`, `update`,
      `values`; `update` accepts a positional dict arg **and/or** keyword args
      (`d.update({"a": 1}, b=2)` is valid)
- [ ] `set`: `add`, `clear`, `difference`, `discard`, `intersection`, `issubset`,
      `issuperset`, `pop`, `remove`, `symmetric_difference`, `union`, `update`

### `str.format()` (complex)

- [ ] Positional `{}`, indexed `{0}`, named `{name}` references
- [ ] Conversion flags `!s`, `!r`
- [ ] Format specs (width, alignment, fill, type) — subset supported by starlark-go
- [ ] Escaped `{{` / `}}`

### `assert` helper module

- [ ] Port `assert.star` from starlark-go testdata so that `.star` test files run unchanged
- [ ] **Decision (finalised)**: embed `assert.star` as a `const` string inside
      `src/internal/starlarktest/` and register it as a pre-loaded module before
      running any `.star` test (option a). Do **not** write it to a temp file
      (option b) — avoids filesystem dependency and works on all targets.
- [ ] Create `src/internal/starlarktest/` package with:
      - `const assert_star : String` — the full content of `assert.star`
      - `run_star_file(src, loader) -> TestResult` — executes a `.star` source
        string as a MoonBit test case; collects `fail()` errors
      - **Interception**: the `Thread.load` callback must intercept the magic
        path `"assert.star"` (or `"@starlarktest//:assert.star"`) and return
        the pre-parsed `assert.star` Module without hitting the filesystem.
        All other paths are forwarded to the caller-supplied loader.
- [ ] `fail()` built-in must raise an `EvalError` with the provided message string;
      used by `assert.star` assertions

### TDD scope

Reference: `starlark-go/starlark/library.go`, `starlark-go/starlark/testdata/*.star`.

---

## Phase 7: Compliance & Integration Tests

End-to-end tests that execute `.star` scripts and assert output.

- [ ] Implement `starlarktest` equivalent — infrastructure to load and run `.star`
      files with chunked error-comment checking.
      **Error comment format**: a line ending with `### Error: <substring>` marks that
      the next statement/expression is expected to raise an `EvalError` (or
      `SyntaxError`) whose message contains `<substring>`. The harness must collect
      all such expected errors and assert they are produced. Lines without this
      suffix are normal statements that must not raise.
      Reference: `starlark-go/starlarktest/starlarktest.go`.
- [ ] Port key cases from `starlark-go/starlark/eval_test.go`
- [ ] Port key cases from `starlark-go/starlark/value_test.go`
- [ ] Port `.star` test files from `starlark-go/starlark/testdata/`
      Priority order: `int.star`, `bool.star`, `string.star`, `list.star`,
      `dict.star`, `tuple.star`, `function.star`, `control.star`, `assign.star`,
      `builtins.star`, `float.star`, `bytes.star`, `set.star`, `while.star`,
      `recursion.star`, `misc.star`, `function_param.star`
- [ ] **`assert.star` embedding**: use the `const` string approach decided in
      Phase 6 (`src/internal/starlarktest/`). Register `assert.star` as a
      pre-loaded module before running each `.star` test file.
- [ ] Cover all bitflow subset contract scenarios
- [ ] Snapshot tests for error message formats
- [ ] Benchmark suite (starlark-go `bench_test.go` equivalent)
- [ ] CI: Expand `.github/workflows/ci.yml` — `moon check && moon test && moon coverage analyze`
      on every push and PR; target `wasm-gc` + `native`

---

## Phase 7.5: `json` Extension Library

Port `starlarkjson` so embedders can read/write JSON from Starlark.
Other starlark-go extensions (`math`, `time`, `proto`, `struct`) are
**out of scope** for the initial release — see "Future work" below.

- [ ] `json.encode(value) -> string` — round-trip primitive values, list, dict
- [ ] `json.decode(string) -> value` — produce Starlark values
- [ ] `json.indent(string, prefix=, indent=)` — pretty-print JSON
- [ ] Error reporting with source `Position`
- [ ] Live as a separate package: `src/starlark/json/` (importable, not auto-injected)
- [ ] Reference: `starlark-go/lib/json/json.go`

---

## Phase 8: Release Preparation

- [ ] Finalise public API; review `.mbti` diff
- [ ] CLI implementation in `src/main/` — run `.star` files
- [ ] Optional REPL — interactive `read → eval → print` loop (in `src/internal/repl/`)
- [ ] Usage examples as doc tests in `README.mbt.md`
- [ ] Mooncakes publish prep

---

## Future work (out of initial release scope)

- `math` extension library (`starlark-go/lib/math`)
- `time` extension library (`starlark-go/lib/time`)
- `proto` extension library (`starlark-go/lib/proto`)
- `starlarkstruct` — Bazel-style structs and modules
- Bytecode compilation / interpreter (currently AST-walking only)
- Profiling and debugging hooks (`starlark-go/starlark/profile.go`)
- Big-integer `Int` (upgrade from `Int64` once overflow demands it)

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

---

## Workflow Notes

- After each Green phase: `moon fmt && moon info && moon test`
- Commit after each Red→Green→Refactor cycle
- Split `src/starlark/` into sub-packages when any file exceeds ~600 LOC
- Keep `src/main/` thin — CLI wiring only (deferred until Phase 8)
- All test names in English (AGENTS.md requirement)
- Use snapshot tests (`moon test --update`) for error message format tests

## Notes

- Starlark strings are **byte** strings: `s[i]` returns the i-th byte, not Unicode codepoint
- All non-default feature gates default to **enabled** (this project's choice)
- Arbitrary-precision `Int`: start with `Int64`, plan upgrade when arithmetic overflow tests fail
- `load` statement requires a pluggable loader; implement a no-op loader for testing
- Mutable containers (List, Dict, Set) can self-reference; equality / repr / hash must handle cycles
