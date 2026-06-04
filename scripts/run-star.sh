#!/usr/bin/env bash
# Run a single .star example through the interpreter CLI.
#
# The default dialect is spec-conformant (matching starlark-go): recursion,
# `while` loops, top-level control flow, and top-level reassignment are all
# disabled by default. Scripts that genuinely use these features opt in via the
# matching CLI flag, which keeps reliance on non-standard extensions visible:
#
#   --recursion       recursive function calls
#   --globalreassign  top-level reassignment, `while` loops, and if/for/while
#                     statements at top level (mirrors starlark-go's flag)
#
# Expects to be invoked from the repository root (as the justfile recipes do),
# since `moon run cmd` resolves the package relative to the current directory.
set -euo pipefail

star="$1"
echo "==> $star"

flags=()
case "$star" in
    *fibonacci.star) flags+=(--recursion) ;;
esac
case "$star" in
    *hello_world/*.star | *builtins_tour/*.star | *config_dsl/*.star \
        | *data_pipeline/*.star | *build_system/*.star | *plugin_system/*.star)
        flags+=(--globalreassign)
        ;;
esac

moon run cmd -- ${flags[@]+"${flags[@]}"} "$star"
