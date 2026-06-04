#!/usr/bin/env bash
# Run all examples under examples/, directory by directory.
#
# For each example directory, runs every .star file through the interpreter
# CLI, then runs the MoonBit entry point if the package declares "is-main".
#
# Expects to be invoked from the repository root.
set -uo pipefail

find examples -maxdepth 1 -mindepth 1 -type d -not -name '_*' -not -name 'mooncakes' | sort | while IFS= read -r dir; do
    name=$(basename "$dir")
    for star in "$dir"/*.star; do
        [[ -f "$star" ]] || continue
        bash scripts/run-star.sh "$star"
    done
    if grep -q '"is-main": true' "$dir/moon.pkg" 2>/dev/null; then
        echo "==> examples/$name (mbt)"
        (cd examples && moon run "$name")
    fi
done
