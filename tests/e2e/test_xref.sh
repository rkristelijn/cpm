#!/usr/bin/env bash
# E2E test: cpm xref
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"
BINARY=$(resolve_binary "${1:-./cpm}")
check_binary "$BINARY"

echo "=== E2E: xref ==="

# xref validates cross-references
OUTPUT=$("$BINARY" xref 2>&1 || true)
[[ -n "$OUTPUT" ]] || die "xref produced no output"

echo "=== All xref tests passed ==="
