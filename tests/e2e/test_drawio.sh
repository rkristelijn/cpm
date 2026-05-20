#!/usr/bin/env bash
# E2E test: cpm drawio
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"
BINARY=$(resolve_binary "${1:-./cpm}")
check_binary "$BINARY"

echo "=== E2E: drawio ==="

# drawio without args shows usage or error
OUTPUT=$("$BINARY" drawio 2>&1 || true)
[[ -n "$OUTPUT" ]] || die "drawio produced no output"

# drawio with nonexistent file handles gracefully
OUTPUT=$("$BINARY" drawio /tmp/nonexistent.drawio 2>&1 || true)
[[ -n "$OUTPUT" ]] || die "drawio with bad file produced no output"

echo "=== All drawio tests passed ==="
