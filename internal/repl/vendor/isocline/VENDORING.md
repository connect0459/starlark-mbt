# Vendored: isocline

[isocline](https://github.com/daanx/isocline) is a portable, dependency-free
readline-style line editor (line editing, history, UTF-8, and native Windows
console support) used by the REPL on native targets.

- **Upstream**: <https://github.com/daanx/isocline>
- **License**: MIT (see `LICENSE`)
- **Pinned commit**: `8d6dc1ef95b1b46711e66eb23d39d4467a0fcdac`

## Layout

Only `src/` (the C sources and private headers), `include/isocline.h` (the
public API), and `LICENSE` are vendored. isocline compiles as a single
translation unit: `src/isocline.c` `#include`s every other `src/*.c`, so the
build lists only that one file in `native-stub`. Quoted includes resolve
relative to the including file, so the directory layout is preserved unchanged
from upstream — no include rewriting is performed.

## Updating

Replace `src/`, `include/`, and `LICENSE` from a new upstream commit, update the
pinned commit above, and re-run `just verify`. Do not edit the vendored sources;
keep local integration in `../../repl_native.c`.
