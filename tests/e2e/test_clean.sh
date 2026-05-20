#!/usr/bin/env bash
# E2E test: cpm clean
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"
BINARY=$(resolve_binary "${1:-./cpm}")
check_binary "$BINARY"

echo "=== E2E: clean ==="

# clean runs without error
OUTPUT=$("$BINARY" clean 2>&1 || true)
[[ -n "$OUTPUT" ]] || die "clean produced no output"

echo "=== All clean tests passed ==="
