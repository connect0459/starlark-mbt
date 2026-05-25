<!-- # PULL_REQUEST_TEMPLATE -->

<!-- Remove unnecessary sections to keep the review focused -->

## Related Links

- Issues:
  - <!-- <https://github.com/connect0459/urllib.mbt/issues/xxx> -->
- specs/WPT tests:
  - <!-- URL or path -->

## [Required] Overview

- Describe the problem being solved, its background, and what changes when this PR is merged.
- Links to WHATWG specs, WPT test suites, or design documents are welcome.

```txt
It is difficult to review without knowing the specifications and background.
```

## Scope of Change

- [ ] `src/url` package
- [ ] `src/urlpattern` package
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
- If WPT test cases were added or updated, list them.

## Quality Checklist (Required)

### Please check all items before merging

- [ ] **CI Workflow Execution**: Full quality check completed by manually running `Run workflow` in [Actions](../actions/workflows/ci.yml)

> **Important**: Since this is a private repository, this checklist ensures quality. Please verify all items before requesting review.
