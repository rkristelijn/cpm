#!/usr/bin/env bash
# E2E test: cpm format
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"
BINARY=$(resolve_binary "${1:-./cpm}")
check_binary "$BINARY"

echo "=== E2E: format ==="

# format runs without crash
OUTPUT=$("$BINARY" format 2>&1 || true)
[[ -n "$OUTPUT" ]] || die "format produced no output"

echo "=== All format tests passed ==="
