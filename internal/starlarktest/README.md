# internal/starlarktest

Test harness and integration tests for the Starlark interpreter.

## File conventions

This package contains two distinct kinds of files:

**Verbatim-embed files** hold a `let <name>_star : String = …` constant that
is a verbatim copy of an upstream starlark-go testdata file. They are
identified by a `// ref:` comment at the top recording the exact GitHub URL
and commit hash at the time of the last sync. Do not edit the string literals
in these files — update them by copy-pasting from the upstream source and
refreshing the `// ref:` comment.

**Project-specific files** cover behaviour beyond what upstream tests exercise,
or provide test infrastructure. They have no `// ref:` comment and can be
freely edited.

---

## Working with verbatim-embed files

### Syncing with upstream

1. Fetch the new `.star` file from the upstream repository.
2. Replace the entire string constant with the new content.
3. Update the commit hash in the `// ref:` comment.
4. Adjust `skip_chunks_containing()` calls if new chunks rely on
   application-defined builtins.

### Handling skipped chunks

Some upstream chunks rely on application-defined builtins (`hasfields()`,
`struct(…)`, `fibonacci`) that are not part of the standard test dialect. Use
`skip_chunks_containing(string, keywords)` in the test function to filter them
out — never delete or modify the upstream chunk itself.

### Adding project-specific coverage

If additional coverage is needed beyond what the upstream string provides, add
a **separate `test` function** in the same file. Do not append extra chunks to
the `<name>_star` string constant — that would diverge it from the upstream
source and break future syncs.
