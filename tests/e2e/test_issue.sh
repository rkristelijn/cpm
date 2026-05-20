#!/usr/bin/env bash
# E2E test: cpm issue
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"
BINARY=$(resolve_binary "${1:-./cpm}")
check_binary "$BINARY"

echo "=== E2E: issue ==="

# issue without args lists issues
OUTPUT=$("$BINARY" issue 2>&1 || true)
[[ -n "$OUTPUT" ]] || die "issue produced no output"

echo "=== All issue tests passed ==="
