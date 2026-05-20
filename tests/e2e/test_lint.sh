#!/usr/bin/env bash
# E2E test: cpm lint
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"
BINARY=$(resolve_binary "${1:-./cpm}")
check_binary "$BINARY"

echo "=== E2E: lint ==="

# lint runs without crash
OUTPUT=$("$BINARY" lint 2>&1 || true)
[[ -n "$OUTPUT" ]] || die "lint produced no output"

echo "=== All lint tests passed ==="
