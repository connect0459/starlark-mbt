# Contributing

## Prerequisites

- [MoonBit toolchain](https://www.moonbitlang.com/download/) — `moon` CLI
- [just](https://just.systems/) — task runner

## Setup

```sh
git clone https://github.com/connect0459/starlark-mbt
cd starlark-mbt
just setup
```

`just setup` runs `moon update` to fetch package dependencies.

### pre-commit hooks

Install [pre-commit](https://pre-commit.com/) and set up the hooks:

```sh
pip install pre-commit   # or: brew install pre-commit
pre-commit install
```

To run all hooks manually:

```sh
pre-commit run --all-files
```

## Development workflow

| Command | Purpose |
| :--- | :--- |
| `moon test` | Run all tests |
| `moon test --target wasm-gc` | Run tests on a specific backend |
| `moon fmt` | Format all source files |
| `moon check` | Type-check without building |
| `moon info` | Regenerate `.mbti` interface files |
| `just verify` | Run the full CI-equivalent check locally |

The pre-commit hooks enforce formatting and lint checks on every commit. To
run them manually across all files:

```sh
pre-commit run --all-files
```

Before opening a pull request, run the full verification suite:

```sh
just verify
```

This mirrors the CI matrix: it checks all four backends (`js`, `wasm`,
`wasm-gc`, `native`) and runs the example suite.

## Testing guidelines

This project follows **Red → Green → Refactor** (Detroit-school TDD):

- Write a failing test first, then implement.
- Use real objects; mocks are only permitted at external boundaries.
- Test names describe **what business rule** is verified, not how.

Run tests across all backends to confirm cross-target compatibility:

```sh
moon test --target js
moon test --target wasm
moon test --target wasm-gc
moon test --target native
```

## Commit format

```text
<type>(<scope>): <subject>
```

**Types**: `feat`, `fix`, `docs`, `style`, `refactor`, `tidy`, `test`, `chore`, `ci`, `perf`

**Scope**: package name when the change targets a specific package (`lexer`,
`parser`, `eval`, `value`, `json`, etc.); omit for project-wide changes.

**Subject**: imperative mood, 72 characters max, no trailing period.

Examples:

```text
feat(eval): add Thread.set_print for dynamic print callback
fix(lexer): reject \u surrogate escapes in string literals
tidy(hashtable): name initial_capacity constant
```

## Pull request process

1. Fork the repository and create a branch: `feat/xxx`, `fix/xxx`, `docs/xxx`.
2. Follow the Red → Green → Refactor cycle.
3. Run `just verify` and commit any resulting diffs.
4. If the change touches the public API, update documentation so it reflects
   the new behaviour:
   - **Per-package `README.mbt.md`** — the sole documentation source for each public
     package; update the API reference tables, key types, or examples as needed.
   - Run `moon info` and verify the `.mbti` diff is expected (it is the authoritative
     formal spec for signatures).
5. Open a pull request — the CI matrix tests `js`, `wasm`, `wasm-gc`, and `native`.

## Code style

- No code comments unless the **why** is genuinely non-obvious.
- Prefer immutability; avoid mutable state unless necessary.
- Internal packages under `internal/` are not part of the public API and
  must not be re-exported through the root `connect0459/starlark` package.
- All user-facing strings (test names, error messages, doc comments) must be in **English**.
