# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: <https://github.com/connect0459/starlark-mbt/compare/v0.1.1...HEAD>
[0.1.1]: <https://github.com/connect0459/starlark-mbt/compare/v0.1.0...v0.1.1>
[0.1.0]: <https://github.com/connect0459/starlark-mbt/releases/tag/v0.1.0>
