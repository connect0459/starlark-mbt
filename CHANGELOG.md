# Changelog

<!--
When cutting a new release, update THREE places in this file:

1. Rename [Unreleased] to [X.Y.Z] with today's date (above), and add a fresh
   empty [Unreleased] section above it.
2. Update the reference links at the very bottom of this file:
    - Change [Unreleased] to compare the new tag against HEAD.
    - Add [X.Y.Z] comparing the new tag against the previous tag.
3. After the PR is merged, push the release tag. Pull main first so HEAD is
   the merge commit:

    ```console
    git checkout main && git pull origin main
    git tag vX.Y.Z && git push origin vX.Y.Z
    ```

   Pushing the tag triggers `.github/workflows/publish.yml`, which publishes
   to mooncakes.io, extracts this file's `[X.Y.Z]` section, and creates the
   GitHub Release from it automatically. Do not run `gh release create`
   manually; it would create the tag/Release ahead of the workflow with
   hand-pasted notes instead of the CHANGELOG-derived ones.
-->

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.4.1] - 2026-07-12

### Changed

- `eval`: skip the `contains` probe in `SetAdd` / `SetDict` while the
  container is below the allocation cap, letting `add`/`set`'s own probe
  decide new-vs-existing instead of paying two hash-table lookups per
  element (#369)

### Fixed

#### Conformance: eval

- `eval`: guard `>>` shift count against int32-range overflow, sharing the
  same bound as `<<` instead of silently clamping an oversized count to `0`
  or `-1` (#373)
- `eval`: guard `int()`'s `base` parameter against duplicate binding
  (positional and keyword), matching the existing check on `x` (#374)
- `eval`: name a bare-expression REPL eval frame `<expr>` instead of
  `<toplevel>`, matching starlark-go's `compile.Expr` (#375)
- `eval`: include the offending call's own frame in a rejected recursive
  call's traceback (#376)
- `eval`: match starlark-go's split-then-merge algorithm for `str.rsplit` so
  results agree with `split` once `maxsplit` truncates output from a
  self-overlapping separator (#378)

#### Conformance: resolver

- `resolver`: anchor the "cannot reassign global" error for augmented
  assignment (`+=` etc.) at the LHS identifier instead of the operator
  token, matching plain assignment (#379)

#### Conformance: lib/time

- `lib/time`: re-derive `time.time` / `time.parse_time`'s display offset
  from the final resolved instant, fixing self-contradictory output for
  local times inside a DST spring-forward gap (#377)

## [0.4.0] - 2026-06-27

### Added

- `value`: add `StarlarkDict::contains` for key membership testing (#347)
- `syntax`: add `flatten_left_chain` iterative left-spine helper for
  `Expr` chains (#345)
- `syntax`: add `start` helper returning the leftmost position of an `Expr`
  (#329)

### Changed

#### BREAKING: `syntax.Expr` variant shape changes

- `syntax`: `EDict` payload tuple extended from `(Expr, Expr)` to
  `(Expr, Expr, @errors.Position)`; the new third element carries the colon
  position used for error anchoring. Pattern matches and constructors of
  `EDict` must be updated (#329)
- `syntax`: `EDictComp` extended with a fifth `@errors.Position` field (the
  opening-brace position). Pattern matches and constructors of `EDictComp`
  must be updated (#329)

### Fixed

#### Crashes and allocation guards

- `eval`: cap list/set/dict comprehension accumulators and `range`-materialization
  paths (`builtin_set`, `enumerate`, `reversed`, `sorted`, `list.extend`,
  `star-args`) to prevent native SIGSEGV on oversized allocations (#321)
- `resolver`, `compile`: walk `binary` / `index` / `dot` / `and` / `or` chains
  iteratively to prevent stack overflow on deeply nested ASTs (#322)

#### Conformance: alloc-guard priority

- `eval`: skip alloc guard in `SetDict` / `SetAdd` when the key already exists
  in the container, preventing a spurious allocation-cap error on key updates
  (#347)
- `eval`: prioritize alloc guard over unhashable-element errors in `SetAdd` /
  `SetDict` so the allocation limit is always the first observable error (#353)
- `eval`: prioritize duplicate-key check over alloc guard in `SetDictUniq` so
  a duplicate key wins over the allocation limit (#355)

#### Conformance: error messages

- `eval`, `json`, `time`, `unpack`: add did-you-mean suggestion to unexpected
  keyword-argument errors across all argument binders (#337)
- `eval`: prefix `list.clear` mutation-guard errors with `clear:` (#330)
- `eval`: report the original `base` argument in `int(s, 0)` error messages
  (#331)
- `time`: quote keyword parameter names in `time()` and `parse_time` type
  errors (#336)
- `json`: double-quote known keyword names in `indent` type error messages;
  quote the `x` parameter name in `decode` keyword-path type errors (#335, #336)

#### Conformance: error positions

- `syntax`, `parser`, `compile`: anchor unhashable dict-key errors and dict
  comprehension key errors at the colon (#329)
- `syntax`, `resolver`: anchor assign-LHS errors at the leftmost token (#329)
- `parser`: anchor `not an identifier` errors in `def` params and
  `expect_ident` at the token end (#329)
- `resolver`, `compile`: use `syntax.start` for positional-argument ordering
  errors (#329)

#### Conformance: resolver

- `resolver`: report `comprehension` instead of `listcomp` / `setcomp` /
  `dictcomp` for all comprehension assign-target errors (#332)

#### Conformance: json

- `json`: align `encode_indent` arg binder with Go's `UnpackArgs` — validate
  keyword types before checking positional arity (#335)
- `json`: wire `json.encode` binder through `unpack_positional` (#338)

#### Conformance: lib/time

- `time`: wire positional-only binders (`parse_duration`, `now`,
  `from_timestamp`, `is_valid_timezone`, `in_location`, `format`) through
  `unpack_positional`; aligns `parse_duration` unexpected-keyword-argument
  errors with Go's `UnpackPositionalArgs` (#338)
- `time`: guard `from_timestamp` sec / nsec fields and `duration` / `Int`
  arithmetic against out-of-int64 values (#323)

#### Conformance: string methods

- `eval`, `utf8util`: fix `isalpha` / `isalnum` to include Unicode Lo and Lm
  categories via a corrected 677-pair range table (#326)

## [0.3.2] - 2026-06-24

### Added

#### Examples

- `examples/wasm_api`: new library package exposing `exec_script`,
  `exec_script_with_env`, and `exec_script_with_options` as host-callable
  symbols for wasm-gc / js embedding (#281, #283, #284)

### Fixed

- `lib/json`: emit `\u007f` for DEL (U+007F) instead of the invalid escape
  `\x7f`, producing valid JSON output for strings containing the DEL character
  (#281)
- `lib/math`: remove `cosh` large-argument workaround; upstream
  `@math.cosh` is fixed in moonbit core `0.1.20260618` (#278)

### Changed

- Reorganise library packages under `src/` and introduce `moon.work`
  workspace file; the `examples/` module separation is now visually
  explicit (#297)
- Rename private helpers in `lib/time` and `examples/wasm_api` to remove
  stale prefixes; no public API surface affected (#303, #304)

### Documentation

- Add `///` docstrings to all public APIs and non-obvious private helpers
  across `value`, `syntax`, `unpack`, `lib/json`, `lib/math`, `lib/struct`,
  `lib/time`, `eval`, and the five internal packages (`lexer`, `parser`,
  `resolver`, `compile`, `starlarktest`) (#290, #291, #292)
- Add `mbt check` executable examples to all targeted public functions
  across `value`, `syntax`, `unpack`, `eval`, `lib/json`, `lib/math`,
  `lib/struct`, and `lib/time` (#293, #294)

## [0.3.1] - 2026-06-19

### Fixed

#### Crashes and stack-overflow guards

- `value`: guard `Value::hash` / `hash_tuple` against native stack overflow on
  deeply nested containers (#222)
- `value`: guard `freeze_value_inner` against native stack overflow; deep-freeze
  errors now propagate as `EvalError` from `exec_file` and related entry points
  (#223)

#### Conformance: eval / value

- `value`: `starlark_equals` and `impl Eq for Value` now route through the
  depth-guarded path, preventing silent divergence on cyclic or deeply nested
  structures (#270)
- `value`: align `dict` / `set` hash-depth limit with `compare_limit` to prevent
  silent key-not-found on deeply nested keys (#274)
- `eval`: fix set `in` operator to propagate hash-depth errors instead of
  silencing them to `False`; dict `in` retains error-silencing behavior
  matching starlark-go's intentional design (#275)
- `eval`: route string output through the faithful byte representation to prevent
  spurious U+FFFD substitution; fix `%c` rune-write semantics; fix `str.format`
  CESU-8 regression when the template contains non-ASCII bytes (#266)
- `eval`: prefix `min` / `max` / `set` builtin errors with the builtin name; fix
  `max` operator result when operands are equal (#267)
- `eval`: use `.x field` or `.x method` wording for all dotted-attribute errors
  (#268)
- `eval`: quote keyword argument name in "got multiple values" errors (#259)
- `unpack`: double-quote keyword argument name in `unpack_args` error messages
  (#255)
- `eval`: double-quote unknown keyword argument name in `int()` error message
  (#255)
- `struct`: align `module` member sort to codepoint-aware `str_lex_cmp` (#270)

#### Conformance: compiler / runtime positions

- `compile`: anchor `EBinary` at the operator position; anchor `Unpack` at the
  `=` sign (#272)
- `compile`: anchor comprehension `IterPush` and `Unpack` at the `for`-clause
  position (#272)

#### Conformance: parser / lexer

- `parser`: parse tuple RHS in augmented assignment statements (#241)
- `parser`: unify `ECond` field order to `cond`-first to match starlark-go AST
  layout (#236)
- `parser`: align load-statement diagnostics with starlark-go; extend
  `scanner_error` anchoring to all load-statement error sites (#240)
- `parser`: emit Go-conformant message and position for missing indented block
  (#238)
- `syntax`, `parser`, `resolver`, `compile`: anchor `*args` / `**kwargs` errors
  at the operator position; anchor `def` errors at the function name (#237)
- `lexer`: align three error-message paths with starlark-go; anchor
  unterminated-string and newline-in-string errors at the token start position
  (#239)
- `lexer`: classify `\x` / `\u` / `\U` escape sequences using starlark-go's
  fixed-width slot semantics (#239)
- `lexer`: decode the full UTF-8 rune in the "unexpected input character" message
  (#239)
- `lexer`: accumulate `\U` hex digits in `Int64` to prevent signed overflow for
  high code points (#228)
- `lexer`: lowercase second slot of the code-point-out-of-range error message
  (#228)

#### Conformance: json

- `json`: complete `json.decode` argument binder — reject surplus positional
  arguments, unknown keywords, and duplicate `default`; preserve positional-first
  error order (#225)
- `json`: detect `json.encode` keyword arguments separately from arity; report
  the first bad character in `\u` hexadecimal escape errors; align `json.indent`
  invalid-token error wording with Go (#269)
- `json`: double-quote unknown keyword argument name in `encode_indent` and
  `indent` error messages (#255)

#### Conformance: lib/math

- `lib/math`: work around `@math.cosh` large-argument branch returning
  `exp(x/2)`; clamp the workaround to the finite-`exp` range so `cosh(710)`
  still overflows to `+Inf` correctly (#224)

#### Conformance: lib/time

- `lib/time`: reject space / lowercase separators and sub-4-digit years in
  `parse_rfc3339` to match starlark-go's strict RFC 3339 parser (#226)
- `lib/time`: reject out-of-range `hour` / `minute` / `second` fields; add
  range checks for timezone offset fields; emit field-specific error messages
  (#250)
- `time`: remove year-range guard from `parse_time` to accept extreme years,
  matching starlark-go behaviour (#249)
- `time`: align argument error messages with `starlark.UnpackArgs` shape; check
  unknown keywords before arity; reject more than 3 positional arguments; align
  unknown-timezone error with Go's `LoadLocation` message; drop the layout
  segment and quote trailing text in extra-text errors (#251)
- `time`: distinguish Z UTC marker from numeric `+00:00` offset in
  `parse_rfc3339` and the go-layout path; correct `decompose_unix_sec`
  overflow-range boundary; replicate Go `uint64` normalization at `Int64::min`
  (#253, #254)
- `time`: apply `time_quote` (matching Go's `time.quote()`) to extra-text in
  `parse_time` error messages; extend passthrough to include DEL (0x7F) (#258)
- `time`: double-quote unknown keyword argument name in error messages (#255)

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

[Unreleased]: <https://github.com/connect0459/starlark-mbt/compare/v0.4.1...HEAD>
[0.4.1]: <https://github.com/connect0459/starlark-mbt/compare/v0.4.0...v0.4.1>
[0.4.0]: <https://github.com/connect0459/starlark-mbt/compare/v0.3.2...v0.4.0>
[0.3.2]: <https://github.com/connect0459/starlark-mbt/compare/v0.3.1...v0.3.2>
[0.3.1]: <https://github.com/connect0459/starlark-mbt/compare/v0.3.0...v0.3.1>
[0.3.0]: <https://github.com/connect0459/starlark-mbt/compare/v0.2.1...v0.3.0>
[0.2.1]: <https://github.com/connect0459/starlark-mbt/compare/v0.2.0...v0.2.1>
[0.2.0]: <https://github.com/connect0459/starlark-mbt/compare/v0.1.1...v0.2.0>
[0.1.1]: <https://github.com/connect0459/starlark-mbt/compare/v0.1.0...v0.1.1>
[0.1.0]: <https://github.com/connect0459/starlark-mbt/releases/tag/v0.1.0>
