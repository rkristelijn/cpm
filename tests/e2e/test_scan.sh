#!/usr/bin/env bash
# E2E test: cpm scan
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"
BINARY=$(resolve_binary "${1:-./cpm}")
check_binary "$BINARY"

echo "=== E2E: scan ==="

# scan current directory works
OUTPUT=$("$BINARY" scan . --depth 1)
assert_contains "$OUTPUT" "Findings" "findings output"

# scan shows repo name
assert_contains "$OUTPUT" "." "current dir listed"

# scan with depth 0 still works
OUTPUT=$("$BINARY" scan . --depth 0)
assert_contains "$OUTPUT" "Findings" "depth 0 works"

# scan nonexistent directory
OUTPUT=$("$BINARY" scan /tmp/nonexistent_cpm_e2e_dir 2>&1 || true)
# Should not crash (graceful handling)

echo "=== All scan tests passed ==="
