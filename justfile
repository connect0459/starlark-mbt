# Setup after clone
setup:
    moon update

# Verify generated type definition files are up to date
info-check:
    moon info
    git diff --exit-code -- ':(glob)**/*.generated.mbti'

# Run a single example: accepts a .star file, .mbt file, or a directory (runs both)
run-example path:
    #!/usr/bin/env bash
    set -euo pipefail
    # Recursion is off by default; only opt in for scripts that need it so the
    # examples still surface accidental reliance on recursion.
    run_star() {
        echo "==> $1"
        if [[ "$1" == *fibonacci.star ]]; then
            moon run cmd -- --recursion "$1"
        else
            moon run cmd -- "$1"
        fi
    }
    p="{{path}}"
    if [[ -d "$p" ]]; then
        name=$(basename "$p")
        for star in "$p"/*.star; do
            [[ -f "$star" ]] || continue
            run_star "$star"
        done
        if grep -q '"is-main": true' "$p/moon.pkg" 2>/dev/null; then
            echo "==> examples/$name (mbt)"
            (cd examples && moon run "$name")
        fi
    elif [[ "$p" == *.star ]]; then
        run_star "$p"
    elif [[ "$p" == *.mbt ]]; then
        dir=$(dirname "$p")
        name=$(basename "$dir")
        echo "==> examples/$name (mbt)"
        (cd examples && moon run "$name")
    else
        echo "Error: unsupported path: $p" >&2
        exit 1
    fi

# Run all examples, directory by directory ({star, mbt} per directory)
run-examples:
    #!/usr/bin/env bash
    set -uo pipefail
    # Recursion is off by default; only opt in for scripts that need it so the
    # examples still surface accidental reliance on recursion.
    run_star() {
        echo "==> $1"
        if [[ "$1" == *fibonacci.star ]]; then
            moon run cmd -- --recursion "$1"
        else
            moon run cmd -- "$1"
        fi
    }
    find examples -maxdepth 1 -mindepth 1 -type d -not -name '_*' -not -name 'mooncakes' | sort | while IFS= read -r dir; do
        name=$(basename "$dir")
        for star in "$dir"/*.star; do
            [[ -f "$star" ]] || continue
            run_star "$star"
        done
        if grep -q '"is-main": true' "$dir/moon.pkg" 2>/dev/null; then
            echo "==> examples/$name (mbt)"
            (cd examples && moon run "$name")
        fi
    done

# Verify code quality and examples run without error
verify:
    moon check --deny-warn
    moon fmt --check
    moon test
    just info-check
    just run-examples > /dev/null 2>&1
