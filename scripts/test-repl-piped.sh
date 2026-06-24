#!/usr/bin/env bash
# Integration tests for the REPL on piped (non-terminal) stdin.
#
# The interactive line editor is only used at a terminal; piped input is read
# by a separate reader. This guards that reader's contract — most importantly
# that a blank line is read as an empty line and NOT as end-of-input, so a
# multi-line compound suite terminated by a blank line is not truncated.
#
# Expects to be invoked from the repository root. Native-only (builds and runs
# the compiled CLI binary).
set -uo pipefail

moon build src/cmd/starlark --target native >/dev/null 2>&1 || {
    echo "test-repl-piped: native build failed" >&2
    exit 1
}

bin=$(find _build/native -type f -name 'starlark.exe' -path '*cmd/starlark*' | head -1)
if [[ -z "$bin" || ! -x "$bin" ]]; then
    echo "test-repl-piped: CLI binary not found under _build/native" >&2
    exit 1
fi

fail=0

# check NAME INPUT EXPECTED_STDOUT
check() {
    local name="$1" input="$2" expected="$3" got
    got=$(printf '%s' "$input" | "$bin" 2>/dev/null)
    if [[ "$got" != "$expected" ]]; then
        echo "FAIL: $name" >&2
        printf '  expected: %q\n' "$expected" >&2
        printf '  got:      %q\n' "$got" >&2
        fail=1
    else
        echo "ok: $name"
    fi
}

# A compound suite terminated by a blank line, then a call. The blank line must
# terminate the suite without being treated as end-of-input (regression guard).
check "multi-line def terminated by a blank line" \
    $'def double(n):\n  return n * 2\n\ndouble(21)\n' \
    '42'

# Bracket continuation spanning multiple physical lines.
check "bracket continuation across lines" \
    $'x = (1 +\n2)\nx\n' \
    '3'

# Consecutive expressions each produce a value line on stdout.
check "consecutive expressions" \
    $'1 + 2\n7 * 6\n' \
    $'3\n42'

# A runtime error goes to stderr, leaving stdout empty.
got_stdout=$(printf '1 // 0\n' | "$bin" 2>/dev/null)
if [[ -n "$got_stdout" ]]; then
    echo "FAIL: runtime error must not write to stdout (got: $got_stdout)" >&2
    fail=1
else
    echo "ok: runtime error stays off stdout"
fi

if [[ "$fail" -eq 0 ]]; then
    echo "test-repl-piped: all checks passed"
fi
exit "$fail"
