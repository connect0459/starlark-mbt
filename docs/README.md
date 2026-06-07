# Documentation

> **Where are the API docs?**
> Start at [`api/README.md`](./api/README.md) — one verified reference page per
> public package.

## Verified doc tests

The API reference pages are `.mbt.md` doc tests: their ` ```mbt check ` blocks
are compiled and executed by `moon test`, so the examples can never drift from
the real API. `moon` discovers them by scanning `.mbt.md` files inside a package
directory.

| Location | Package | Contents |
| :--- | :--- | :--- |
| [`api/`](./api/) | `connect0459/starlark/docs/api` | One `.mbt.md` page per public package, plus prose `.md` pages |
| [`../README.mbt.md`](../README.mbt.md) | `connect0459/starlark` (root) | Quick-start example, also run as a doc test |

## What else lives here

- [`todo.md`](./todo.md) — implementation roadmap and progress log.
