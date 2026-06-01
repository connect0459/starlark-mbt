# Setup after clone
setup:
    moon update

# Run all .mbt examples (packages with is-main: true)
run-examples-mbt:
    #!/usr/bin/env bash
    set -uo pipefail
    find examples -maxdepth 2 -name 'moon.pkg' | grep -v mooncakes | while IFS= read -r pkg; do
        if grep -q '"is-main": true' "$pkg"; then
            name=$(basename "$(dirname "$pkg")")
            echo "==> examples/$name"
            (cd examples && moon run "$name")
        fi
    done

# Run all .star examples
run-examples-star:
    #!/usr/bin/env bash
    set -uo pipefail
    find examples -maxdepth 2 -name '*.star' | grep -v mooncakes | sort | while IFS= read -r f; do
        echo "==> $f"
        moon run src/cmd -- "$f"
    done

# Run all examples (.mbt and .star)
run-examples: run-examples-star run-examples-mbt
