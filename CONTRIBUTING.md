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

Before opening a pull request:

```sh
moon fmt && moon check && moon test && moon info
git diff -- '*.mbti'  # review interface changes
```

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

1. Fork the repository and create a branch: `feature/xxx`, `fix/xxx`, `docs/xxx`.
2. Follow the Red → Green → Refactor cycle.
3. Run `moon fmt && moon check && moon test && moon info` and commit any resulting diffs.
4. Open a pull request — the CI matrix tests `js`, `wasm`, `wasm-gc`, and `native`.

## Code style

- No code comments unless the **why** is genuinely non-obvious.
- Prefer immutability; avoid mutable state unless necessary.
- Internal packages under `src/internal/` are not part of the public API and
  must not be re-exported through `src/starlark/`.
- All user-facing strings (test names, error messages, doc comments) must be in **English**.
