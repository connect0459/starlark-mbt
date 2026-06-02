# Documentation

> **Where are the API docs?**
> The verified API references live under [`src/docs/`](../src/docs/), **not**
> here. Start at [`src/docs/api/index.md`](../src/docs/api/index.md).

## Why the docs live in the source tree

The API reference pages are `.mbt.md` doc tests: their ` ```mbt check ` blocks
are compiled and executed by `moon test`, so the examples can never drift from
the real API.

`moon` discovers doc tests by scanning `.mbt.md` files **inside a package
directory** (it does not follow directory symlinks). To be picked up, the pages
must therefore live in the source tree. They are kept in a dedicated,
otherwise-empty package so they never add anything to the public API surface:

| Location | Package | Contents |
| :--- | :--- | :--- |
| [`src/docs/`](../src/docs/) | `connect0459/starlark/docs` | `README.mbt.md` (doc test for the top-level README) |
| [`src/docs/api/`](../src/docs/api/) | `connect0459/starlark/docs/api` | One `.mbt.md` page per public package, plus prose `.md` pages |

## What lives here

- [`todo.md`](./todo.md) — implementation roadmap and progress log.
