# Setup after clone
setup:
    moon update

# Run a single example: accepts a .star file, .mbt file, or a directory (runs both)
run-example path:
    bash scripts/run-example.sh "{{path}}"

# Run all examples, directory by directory ({star, mbt} per directory)
run-examples:
    bash scripts/run-examples.sh

# Integration tests for the REPL on piped (non-terminal) stdin
test-repl-piped:
    bash scripts/test-repl-piped.sh

# Run tests for a single target (e.g. `just test-target wasm-gc`)
test-target target:
    moon check --deny-warn --target {{target}}
    moon test --target {{target}}

# Verify code quality and all targets (matches CI)
verify:
    moon fmt --check
    for t in js wasm wasm-gc native; do \
        just test-target $t; \
    done
    just run-examples > /dev/null 2>&1
    just test-repl-piped > /dev/null 2>&1
