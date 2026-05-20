#!/usr/bin/env bash
# E2E test: cpm findings
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"
BINARY=$(resolve_binary "${1:-./cpm}")
check_binary "$BINARY"

echo "=== E2E: findings ==="

# findings without args lists or shows usage
OUTPUT=$("$BINARY" findings 2>&1 || true)
[[ -n "$OUTPUT" ]] || die "findings produced no output"

echo "=== All findings tests passed ==="
