#!/usr/bin/env bash
# Run a single .star example through the interpreter CLI.
#
# Recursion is disabled by default, so only scripts that genuinely need it
# (fibonacci.star) opt in via --recursion; every other example runs under the
# real default, which keeps accidental reliance on recursion visible.
#
# Expects to be invoked from the repository root (as the justfile recipes do),
# since `moon run cmd` resolves the package relative to the current directory.
set -euo pipefail

star="$1"
echo "==> $star"
if [[ "$star" == *fibonacci.star ]]; then
    moon run cmd -- --recursion "$star"
else
    moon run cmd -- "$star"
fi
