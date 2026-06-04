# Setup after clone
setup:
    moon update

# Verify generated type definition files are up to date
info-check:
    moon info
    git diff --exit-code -- ':(glob)**/*.generated.mbti'

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
    just info-check
    just run-examples > /dev/null 2>&1
