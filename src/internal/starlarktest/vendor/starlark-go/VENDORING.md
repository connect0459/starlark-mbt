# Vendored: starlark-go testdata

[starlark-go](https://github.com/google/starlark-go) is the reference Go
implementation of the Starlark language. The files under
`starlark/testdata/` are the upstream conformance test suite consumed by
`internal/starlarktest`.

- **Upstream**: <https://github.com/google/starlark-go>
- **License**: BSD-3-Clause (see `LICENSE`)
- **Pinned commit**: `ec58d4b459e2866ed51124596d888ed7aa4f90b8`

## Layout

Only the 19 `.star` files actively consumed by `internal/starlarktest` are
vendored. The path mirrors the upstream layout verbatim so that
`diff -r upstream/starlark/testdata vendor/starlark-go/starlark/testdata`
produces a path-symmetric drift report.

Upstream files intentionally **not** vendored (not consumed):

| File | Reason |
| :--- | :----- |
| `benchmark.star` | Performance tests; not part of conformance suite |
| `function_param.star` | Requires non-standard parameter features |
| `paths.star` | Requires application-defined `path` module |
| `proto.star` | Requires application-defined `proto` module |
| `time.star` | Requires application-defined `time` module (we have our own `lib/time` tests) |

## Updating

1. Copy the new `.star` files from the upstream repository at the target
   commit into `starlark/testdata/`.
2. Update the pinned commit above.
3. Run `just verify` to confirm all four backends pass.
4. If new chunks rely on application-defined builtins not in the standard
   test dialect, add `skip_chunks_containing` calls in the corresponding
   `*_test.mbt` file.

Do not edit the vendored `.star` files; all local integration lives in the
`*_test.mbt` files in the parent directory.
