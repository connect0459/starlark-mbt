# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.0] - 2026-06-15

### Added

- `lexer`, `parser`: reclassify `True` / `False` / `None` as pre-declared
  identifiers rather than reserved words, matching starlark-go semantics (#167)
- `eval`: extend `str.isdigit` and `str.isalnum` to recognise Unicode decimal
  digits (category `Nd`), not just ASCII `0`–`9` (#169)

### Removed

- **BREAKING** `syntax`: remove `LiteralVal::LitNone` and
  `LiteralVal::LitBool(Bool)` from the public `syntax` API (#167).
  `True`, `False`, and `None` are now pre-declared identifiers and can no
  longer appear as `ELiteral` AST nodes. Downstream code that
  pattern-matches on these variants must be updated.

### Fixed

#### Crashes and stack-overflow guards

- `parser`: add expression-nesting depth guard to prevent SIGSEGV on deeply
  nested input on the native backend (#178)
- `parser`: lower `max_expr_depth` to 80 to also prevent wasm call-stack
  overflow (#190)
- `value`: guard `repr` / `str` recursive traversal against native stack
  overflow; now raises `repr exceeded maximum recursion depth` (#179)

#### Conformance: eval / value

- `eval`: resolver now surfaces only the first error per file to match
  starlark-go behaviour (#186)
- `eval`: `float()` now accepts hex-float string literals (e.g. `"0x1.8p+1"`)
  (#206)
- `eval`: iteration-lock errors from `list.append` and `dict.update` now carry
  the expected `append:` / `update:` prefix (#207)
- `eval`: `str.format` reports the correct error message when `{` appears in
  the format-spec part of a replacement field (#208)
- `struct`: hide synthetic `__*` internal attributes from user-facing attribute
  access (#209)

#### Conformance: parser

- `parser`: missing separator error now reports the closing bracket as the
  expected token, matching starlark-go (#187)
- `parser`: error positions anchor at the correct token (position captured
  before `advance()` call) (#188)
- `parser`, `lexer`: reserved-word and operator rejection messages aligned with
  starlark-go phrasing (#189)

#### Conformance: json

- `json`: reduce `json.indent` to a syntax-only re-formatter; document
  `json.decode` RFC compliance (#168)
- `json`: validate separator characters and reject empty input in `json.indent`
  (#181)

#### Conformance: lib/time

- `time`: timezone now preserved through `time ± duration` arithmetic (#180)
- `time`: `in_location` resolves UTC correctly at extreme timestamps;
  `parse_duration` now accepts `Int64::min` (#195)
- `time`: `parse_duration`, `parse_time`, and `time()` error messages aligned
  with Go format strings (#196)
- `time`: `in_location` handles named timezone zones at extreme timestamps
  (#199)
- `time`: `parse_time` errors now include the remaining unparsed input and the
  expected layout token (#200)

#### lib/math

- `lib/math`: replace Lanczos `gamma` with higher-precision Cephes
  coefficients; drop doubled `log:` error prefix (#198)

#### CLI / test harness

- `cli`: traceback output, library-module pre-declaration, and load-error
  double-wrapping fixed (#165)
- `starlarktest`: harden `###`-annotation matching harness (#166)

### Documentation

- Document set-literal / set-comprehension as a MoonBit extension, depth-guard
  policy across traversal paths, and the `Error:` prefix on CLI error output
  (#210)

## [0.2.1] - 2026-06-12

### Fixed

#### HIGH severity — crashes and silent wrong results (#112)

- `eval`: fix VM abort (SIGABRT) on top-level lambda capture in list
  comprehension (#91)
- `eval`: add recursion depth limit to `in`, `list.index`, and `list.remove`
  to prevent stack overflow on deeply nested containers (#90)
- `eval`: iterator stack not drained on early `return` from `for` loop, causing
  the container's freeze lock to leak and subsequent mutations to fail (#125)
- `eval`: `BigInt` / `float` arguments not validated against `Int64` range
  before numeric operations; `in range(...)` containment check unguarded (#127)
- `eval`, `lib/json`: surrogate codepoints (U+D800–U+DFFF) in `chr()` and
  `json.decode` now mapped to U+FFFD instead of producing invalid UTF-8 (#123)
- `value`: freeze propagation failed through same-name closures and
  `BoundMethod` / builtin receivers (#93)
- `value`: identity equality returned wrong results for functions, modules, and
  iterator views (#89)
- `value`: `range` length truncated to 32 bits; wrong results for wide ranges
  (#98)
- `value`: `bytes` values iterable directly, bypassing the required `.elems()`
  method (#107)
- `lib/json`: no nesting depth limit; deeply nested input could exhaust the
  call stack (#124)
- `lib/math`: `math.remainder` violated IEEE 754 round-half-to-even;
  reimplemented via exact `Mod`-based reduction (#102, #126)
- `parser`: ternary expression starting with an identifier rejected as a call
  argument (#92)
- `parser`: trailing comma accepted in subscript, lambda params, and `for`
  target (#106)
- `parser`: bare tuple rejected as `for`-loop iterable (#128)
- `cli`, `repl`: no shared load cache or cycle detection — loading the same
  module twice ran it twice; circular `load` caused infinite recursion (#95)
- `repl`, `cli`: relative load paths not resolved against the loading script's
  directory (#97)
- `time`: `Int64` overflow in `time + duration` arithmetic; `from_timestamp`
  nanosecond field not normalised to `[0, 999_999_999]` (#99)
- `time`: out-of-range `time.time()` fields (e.g. month 13) not normalised;
  RFC 3339 strings with trailing garbage accepted (#108)

#### MEDIUM severity — conformance gaps (#113)

- `eval`: five collection-semantics divergences from starlark-go, including
  `dict.update` iteration order and augmented assignment to frozen subscript
  (#139)
- `value`, `eval`: `StarlarkRange::length()` overflow for very large ranges
  (#141, #142)
- `value`: recursion depth limit not enforced on `dict` / `set` / `struct` /
  iterator equality (#136)
- `value`: `CustomValue` equality callback did not receive recursion depth
  (#143)
- `parser`: slice subscript with missing middle colon and comprehension
  `if`-clause used as a binary expression incorrectly parsed (#144)
- `json`, `struct`: keys sorted by length before content (MoonBit's default
  `String::compare`); now sorted lexicographically (#100)
- `json`, `struct`: lexicographic key sort used UTF-16 code-unit order, causing
  supplementary-plane characters (U+10000+) to sort before high-BMP code points;
  now uses Unicode codepoint order (#145)
- `lib/math`: IEEE 754 edge cases in `fabs`, `sqrt`, `pow`, `hypot`, and
  `gamma` corrected to match Go's `math` package (#146)
- `eval`, `resolver`, `json`: seven error-message and edge-case divergences
  from starlark-go corrected (#147)

#### `lib/time` conformance (#114)

- `time`: formatting `time.duration_min` produced a double minus sign (#153)
- `time`: year numbers outside 1–9999 formatted without sign or padding; now
  uses 4-digit zero-padding with `+`/`-` prefix (#154)
- `time`: `time.parse_time` used a fixed UTC offset instead of the host local
  timezone; zone abbreviations now surfaced via the `zone` attribute (#155)
- `time`: RFC 3339 strings without a timezone component silently parsed as UTC;
  now raise a parse error (#156)
- `time`: layout-token gaps in `format` / `parse_time` — `002`, `Z07`, `-07`,
  `_2`, `PM` / `pm`, case-insensitive names, comma fractional separator (#157)
- `time`: duration string used integer division, dropping sub-second precision
  (#101)
- `time`: `time − time` overflow now saturates; `parse_duration` and `time.time`
  constructor validate `BigInt` keyword arguments; timezone threaded through
  arithmetic (#129)

### Documentation

- `value/README.mbt.md`: correct return types of `len_of`, `length_of`, and
  `StarlarkRange::length` to `Int64`; add missing `StarlarkDict::pop_entry`
  entry (#158)

## [0.2.0] - 2026-06-10

### Added

- **REPL**: multi-line input with continuation prompt (`...`), Ctrl-C line
  interruption, and errors routed to stderr (#68)
- **REPL**: readline-style line editing and in-session history at a terminal on
  native targets via vendored isocline; non-terminal stdin uses plain line
  reading (#69)

### Fixed

- `cmd/starlark`: requesting the interactive REPL on a backend where the reader
  is unavailable (e.g. `wasm-gc`) now prints a diagnostic instead of exiting
  silently (#72)

### Changed

- `cmd` package reorganised to `cmd/starlark/` to match starlark-go conventions;
  run with `moon run cmd/starlark -- <file>` (#64)

### Documentation

- Remove broken relative package links from root `README.mbt.md` (#66)

## [0.1.1] - 2026-06-08

### Fixed

- `lib/time`: correct fractional-seconds and colon-separated timezone offset
  formatting (#57)

### Documentation

- Add per-package `README.mbt.md` files for mooncakes.io display; add docs
  badge to root README (#52, #55)
- Fix literate MoonBit code-fence syntax in all `README.mbt.md` files (#59, #60)
- Correct API description drift and add missing entries across `value`,
  `errors`, `eval`, `syntax`, `unpack`, and `lib/json` packages (#53, #61)
- Improve test coverage across `eval`, `value`, `time`, `json`, `struct`,
  `numeric`, and `utf8util` packages (#54, #58)

## [0.1.0] - 2026-06-07

### Added

#### Interpreter core

- Complete Starlark language interpreter targeting starlark-go semantics
- Bytecode compiler and VM execution engine (modeled on starlark-go's `internal/compile` / `interp.go`)
- Lexer with full Starlark token support — integer/float/string/bytes literals, all operators,
  indentation (`INDENT`/`DEDENT`), explicit and implicit line continuation
- Recursive-descent parser producing a full AST with position information on every node
- Name resolver with scope classification (`local`, `cell`, `free`, `global`, `predeclared`, `universal`)
- Sixteen-pass gap analysis against starlark-go — behavioral and error-message parity
  for all tested constructs including Unicode-aware string methods, cross-type arithmetic,
  freeze semantics, comprehension scoping, and recursion detection

#### Value types (`connect0459/starlark/value`)

- Primitive types: `NoneType`, `Bool`, `Int` (arbitrary-precision BigInt), `Float`,
  `String` (byte-indexed, UTF-8 backed with `bytes` array cache), `Bytes`
- Container types: `List`, `Tuple`, `Dict` (insertion-ordered), `Set` (insertion-ordered)
- Callable types: `Function`, `BuiltinFunction`, `BoundMethod`
- Sequence type: `Range` (lazy iterable)
- Freeze semantics with transitive propagation and iterator-safety enforcement
- `CustomValue` vtable for embedder-defined types with 12 protocol traits: `HasAttrs`,
  `HasSetField`, `StarlarkComparable`, `Mapping`, `Indexable`, `Container`, `HasBinary`,
  `HasUnary`, `HasSetIndex`, `TotallyOrdered`, `Sliceable`, `IterableMapping`

#### Built-in functions

All standard Starlark built-in functions:
`abs`, `all`, `any`, `bool`, `bytes`, `chr`, `dict`, `dir`, `enumerate`, `fail`, `float`,
`getattr`, `hasattr`, `hash`, `int`, `len`, `list`, `max`, `min`, `ord`, `print`,
`range`, `repr`, `reversed`, `set`, `sorted`, `str`, `tuple`, `type`, `zip`

Built-in methods:

- **string** (35 methods): `capitalize`, `count`, `elem_ords`, `elems`, `endswith`, `find`,
  `format`, `index`, `isalnum`, `isalpha`, `isdigit`, `islower`, `isspace`, `istitle`,
  `isupper`, `join`, `lower`, `lstrip`, `partition`, `removeprefix`, `removesuffix`,
  `replace`, `rfind`, `rindex`, `rpartition`, `rsplit`, `rstrip`, `split`, `splitlines`,
  `startswith`, `strip`, `title`, `upper`, `codepoints`, `codepoint_ords`
- **bytes** (1 method): `elems`
- **list** (7 methods): `append`, `clear`, `extend`, `index`, `insert`, `pop`, `remove`
- **dict** (9 methods): `clear`, `get`, `items`, `keys`, `pop`, `popitem`,
  `setdefault`, `update`, `values`
- **set** (12 methods): `add`, `clear`, `difference`, `discard`, `intersection`,
  `issubset`, `issuperset`, `pop`, `remove`, `symmetric_difference`, `union`, `update`

#### Extension libraries

- **`connect0459/starlark/lib/json`** — `json.encode`, `json.encode_indent`, `json.decode`,
  `json.indent`; Go-faithful Unicode quoting (raw UTF-8 for non-ASCII, `\uXXXX` for
  control characters and HTML-special sequences)
- **`connect0459/starlark/lib/math`** — 28 functions: `acos`, `acosh`, `asin`, `asinh`,
  `atan`, `atan2`, `atanh`, `ceil`, `copysign`, `cos`, `cosh`, `degrees`, `exp`, `fabs`,
  `floor`, `gamma`, `hypot`, `log`, `mod`, `pow`, `radians`, `remainder`, `round`, `sin`,
  `sinh`, `sqrt`, `tan`, `tanh`; constants `math.e`, `math.pi`
- **`connect0459/starlark/lib/struct`** — `struct(field=value, ...)` constructor,
  `module(name, ...)` named module constructor, `gensym()` callable symbol factory
- **`connect0459/starlark/lib/time`** — `time.now`, `time.from_timestamp`,
  `time.parse_duration`, `time.parse_time`; `time.time` and `time.duration` value types;
  thread-local clock override for deterministic testing

#### Embedder API (`connect0459/starlark/eval`)

- `Thread` — configurable execution context: print callback, loader callback,
  step budget, recursion depth limit, cancellation (`cancel` / `uncancel`),
  thread-local storage (`set_local` / `get_local`), debug frame access (`debug_frame`)
- `Module` — execution result with frozen global bindings; `get`, `global_names`,
  `globals_count`, `predeclared_names`, `is_frozen`
- `Options` — nine dialect flags with fluent `with_allow_*` setters
- `Program` — pre-parsed compiled program; serializable to `Bytes` via `write()`;
  `compiled_program(data)` deserializes without re-compilation; `init` executes without freezing
- `Universe` / `Predeclared` — named-value registries; `new`, `from_map`, `set`, `get`,
  `has`, `keys`, `values`, `each`, `delete`
- `DebugFrame` — snapshot of an active call frame; `callable`, `num_locals`, `frame_local`,
  `local_by_name`, `position`

Entry functions: `exec_file`, `eval_expr`, `eval_expr_with_opts`, `eval_parsed_expr`,
`exec_file_with_universe`, `exec_file_with_predeclared`, `exec_repl_chunk`, `call`,
`parse_file`, `parse_expr`, `source_program`, `source_program_with_file`, `file_program`,
`compiled_program`

#### Argument unpacking (`connect0459/starlark/unpack`)

- `unpack_args` — positional + keyword argument binding with type coercion for
  host-defined built-ins
- `unpack_positional` — positional-only variant
- `unpack_args_with` — `Unpacker` protocol dispatch, mirroring starlark-go `UnpackArgs`

#### Error types (`connect0459/starlark/errors`)

- `EvalError` — runtime error with message, position, call stack, and optional cause chain
  (`with_cause` / `cause` for nested load errors)
- `SyntaxError` — lexer/parser error with position
- `ResolveError` — resolver error with position
- `Position`, `Binding`, `CallFrame`, `CallStack` — structured error context types

#### AST types (`connect0459/starlark/syntax`)

- `File`, `Expr`, `Stmt` — AST root types and all node variants
- `walk_file`, `walk_expr`, `walk_stmt` — depth-first AST traversal

#### Quick-start helpers (`connect0459/starlark`)

- `exec(src, filename~)` — run a Starlark script with default thread and options
- `eval(src, filename~)` — evaluate a Starlark expression with default thread and options
- Re-exported types: `Value`, `Module`, `EvalError`

#### CLI and REPL

- `cmd/starlark` package — run `.star` files from the command line (`moon run cmd/starlark -- <file>`)
- REPL support via `exec_repl_chunk` in `eval` — incremental state is maintained in
  a `StringDict` passed across calls

#### Dialect options

| Option | Default | Description |
| :--- | :--- | :--- |
| `allow_set` | `true` | Set literals and comprehensions |
| `allow_lambda` | `true` | `lambda` expressions |
| `allow_bytes` | `true` | `b"..."` bytes literals |
| `allow_float` | `true` | Float type and true division |
| `allow_recursion` | `false` | User-defined function recursion |
| `allow_while` | `false` | `while` loops |
| `allow_top_level_control` | `false` | Top-level `if`/`for`/`while` |
| `allow_global_reassign` | `false` | Module-level variable reassignment |
| `load_binds_globally` | `false` | `load`-imported names visible globally |

---

[Unreleased]: <https://github.com/connect0459/starlark-mbt/compare/v0.3.0...HEAD>
[0.3.0]: <https://github.com/connect0459/starlark-mbt/compare/v0.2.1...v0.3.0>
[0.2.1]: <https://github.com/connect0459/starlark-mbt/compare/v0.2.0...v0.2.1>
[0.2.0]: <https://github.com/connect0459/starlark-mbt/compare/v0.1.1...v0.2.0>
[0.1.1]: <https://github.com/connect0459/starlark-mbt/compare/v0.1.0...v0.1.1>
[0.1.0]: <https://github.com/connect0459/starlark-mbt/releases/tag/v0.1.0>
