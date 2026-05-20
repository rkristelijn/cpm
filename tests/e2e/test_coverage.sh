#!/usr/bin/env bash
# E2E test: cpm coverage
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"
BINARY=$(resolve_binary "${1:-./cpm}")
check_binary "$BINARY"

echo "=== E2E: coverage ==="

# coverage runs (may fail if no gcov, but shouldn't crash)
OUTPUT=$("$BINARY" coverage 2>&1 || true)
[[ -n "$OUTPUT" ]] || die "coverage produced no output"

echo "=== All coverage tests passed ==="
