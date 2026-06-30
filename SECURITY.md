# Security Policy

## Supported Versions

Only the latest release on the `main` branch is actively maintained.
Older versions do not receive security fixes.

| Version  | Supported |
| :------- | :-------- |
| latest   | ✓         |
| < latest | ✗         |

## Reporting a Vulnerability

**Please do not open a public GitHub issue for security vulnerabilities.**

Use GitHub's [private vulnerability reporting][private-report] feature to
disclose issues confidentially. You will receive an acknowledgment within
**5 business days** and a resolution timeline once the report has been
triaged.

[private-report]: https://github.com/connect0459/starlark-mbt/security/advisories/new

## Scope

The following vulnerability classes are in scope for this project:

- **Sandbox escapes** — any path that allows Starlark code to access the host
  file system, network, environment variables, or other resources outside the
  explicitly provided `Module` / `Universe` / `Predeclared` surface.
- **Resource exhaustion** — inputs that cause unbounded memory growth, CPU
  spin, or stack overflow that bypasses the `max_steps`, `recursion_limit`, or
  allocation-guard mechanisms exposed via `Options`.
- **Parser/resolver crashes** — any input (including malformed or adversarially
  crafted source text) that causes a panic, SIGSEGV, or unhandled runtime error
  in `parse_file`, `parse_expr`, or the resolver.
- **Incorrect evaluation results** — silent data corruption or wrong output
  that violates the Starlark specification in a security-relevant way (e.g.,
  integer overflow producing a value with unexpected semantics).

The following are **out of scope**:

- Issues in third-party dependencies (report those upstream).
- Denial-of-service through resource limits that are intentionally not set by
  the embedding application (configuring `Options` is the caller's
  responsibility).
- Theoretical issues without a reproducible proof-of-concept.

## Disclosure Policy

Once a fix is ready and released, a GitHub Security Advisory will be published
with full details. The typical timeline from report to public disclosure is
**30 days**, though this may be extended by mutual agreement when a fix
requires significant changes.
