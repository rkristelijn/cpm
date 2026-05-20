#!/usr/bin/env bash
# E2E test: cpm new (project, test, module)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"
BINARY=$(resolve_binary "${1:-./cpm}")
check_binary "$BINARY"

echo "=== E2E: new ==="

# new project creates directory structure
DIR=$(setup_project)
(cd "$DIR" && "$BINARY" new code-cpp-test-demo)
assert_file_exists "$DIR/code-cpp-test-demo/cpm.toml"
assert_file_exists "$DIR/code-cpp-test-demo/src/main.cpp"

# new test creates test file
(cd "$DIR/code-cpp-test-demo" && "$BINARY" new test parser)
assert_file_exists "$DIR/code-cpp-test-demo/src/parser_test.cpp"

# new module creates cpp + hpp
(cd "$DIR/code-cpp-test-demo" && "$BINARY" new module utils)
assert_file_exists "$DIR/code-cpp-test-demo/src/utils.cpp"
assert_file_exists "$DIR/code-cpp-test-demo/src/utils.hpp"

# new without args shows usage
OUTPUT=$("$BINARY" new 2>&1 || true)
assert_contains "$OUTPUT" "Usage" "usage shown"

teardown_project "$DIR"
echo "=== All new tests passed ==="
