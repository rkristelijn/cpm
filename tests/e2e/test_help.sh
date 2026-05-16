#!/usr/bin/env bash
# E2E test: help and version output
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"
BINARY="${1:-./cpm}"
check_binary "$BINARY"

echo "=== E2E: help ==="

# help shows usage
OUTPUT=$("$BINARY" help)
assert_contains "$OUTPUT" "code project maturity" "banner"
assert_contains "$OUTPUT" "Commands:" "commands section"
assert_contains "$OUTPUT" "init" "init listed"
assert_contains "$OUTPUT" "check" "check listed"
assert_contains "$OUTPUT" "scan" "scan listed"

# --version flag
OUTPUT=$("$BINARY" --version)
assert_contains "$OUTPUT" "cpm" "version output"

# -V flag
OUTPUT=$("$BINARY" -V)
assert_contains "$OUTPUT" "cpm" "short version flag"

# unknown command exits non-zero
assert_exit_nonzero "$BINARY nonexistent_command_xyz"

echo "=== All help tests passed ==="
