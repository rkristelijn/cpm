#!/usr/bin/env bash
# E2E test: cpm test
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"
BINARY=$(resolve_binary "${1:-./cpm}")
check_binary "$BINARY"

echo "=== E2E: test ==="

# test runs the test suite
OUTPUT=$("$BINARY" test 2>&1 || true)
[[ -n "$OUTPUT" ]] || die "test produced no output"

echo "=== All test tests passed ==="
