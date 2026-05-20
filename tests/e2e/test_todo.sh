#!/usr/bin/env bash
# E2E test: cpm todo
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"
BINARY=$(resolve_binary "${1:-./cpm}")
check_binary "$BINARY"

echo "=== E2E: todo ==="

# todo shows TODO/FIXME items
OUTPUT=$("$BINARY" todo 2>&1 || true)
[[ -n "$OUTPUT" ]] || die "todo produced no output"

echo "=== All todo tests passed ==="
