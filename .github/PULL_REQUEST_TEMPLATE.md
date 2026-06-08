<!-- # PULL_REQUEST_TEMPLATE -->

<!-- Remove unnecessary sections to keep the review focused -->

## Related Links

- Issues
  - <!-- <https://github.com/<organization>/<repository>/issues/xxx> -->
- PRs
  - <!-- <https://github.com/<organization>/<repository>/pull/xxx> -->

## [Required] Overview

- Describe the problem being solved, its background, and what changes when this PR is merged.
- Links to specs, design documents, or other references are welcome.

```txt
It is difficult to review without knowing the specifications and background.
```

## Scope of Change

- [ ] `xxx` package
- [ ] Tooling / CI
- [ ] Documentation

## Breaking Changes

- [ ] No breaking changes
- [ ] Breaking changes (describe below)

<!--
If this changes the public API (.mbti diff), describe what breaks and why
the breakage is justified.
-->

## Deferred Items and TODOs

- Items intentionally deferred and the reasons why.

```txt
If you deferred something due to time constraints, document it here.
Reviewers cannot tell whether something was intentionally skipped or overlooked
without this information.
```

## Test Items

- Describe any test considerations beyond unit tests.
- Note which backends were validated (js / wasm / wasm-gc / native).
- If external test cases were added or updated, list them.

## [Required] Quality Checklist

**Please check all items before merging.**

- [ ] **CI Workflow Execution**: Full quality check completed by manually running `Run workflow` in [Actions](../actions/workflows/ci.yml)
- [ ] **Code Comments**: Code comments and function/method-level doc-comments are in sync with the changes
- [ ] **Reference Docs**: both documentation layers are updated for any public API change — the per-package quick-start (`README.mbt.md` in each package directory) and the comprehensive reference (`docs/api/`)

> **Important**: This checklist ensures quality. Please verify all items before requesting review.
