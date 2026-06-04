#!/usr/bin/env bash
# Run a single example: accepts a .star file, .mbt file, or a directory (runs both).
#
# Expects to be invoked from the repository root.
set -euo pipefail

p="$1"
if [[ -d "$p" ]]; then
    name=$(basename "$p")
    for star in "$p"/*.star; do
        [[ -f "$star" ]] || continue
        bash scripts/run-star.sh "$star"
    done
    if grep -q '"is-main": true' "$p/moon.pkg" 2>/dev/null; then
        echo "==> examples/$name (mbt)"
        (cd examples && moon run "$name")
    fi
elif [[ "$p" == *.star ]]; then
    bash scripts/run-star.sh "$p"
elif [[ "$p" == *.mbt ]]; then
    dir=$(dirname "$p")
    name=$(basename "$dir")
    echo "==> examples/$name (mbt)"
    (cd examples && moon run "$name")
else
    echo "Error: unsupported path: $p" >&2
    exit 1
fi
