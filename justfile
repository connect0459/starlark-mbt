# Setup after clone
setup:
    moon update

# Run a single example: accepts a .star file, .mbt file, or a directory (runs both)
run-example path:
    bash scripts/run-example.sh "{{path}}"

# Run all examples, directory by directory ({star, mbt} per directory)
run-examples:
    bash scripts/run-examples.sh

# Verify code quality and examples run without error
verify:
    moon check --deny-warn
    moon fmt --check
    moon test
    just run-examples > /dev/null 2>&1
