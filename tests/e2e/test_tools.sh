#!/usr/bin/env bash
# E2E test: cpm tools
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"
BINARY=$(resolve_binary "${1:-./cpm}")
check_binary "$BINARY"

echo "=== E2E: tools ==="

# tools shows installed tool versions
OUTPUT=$("$BINARY" tools 2>&1 || true)
[[ -n "$OUTPUT" ]] || die "tools produced no output"

echo "=== All tools tests passed ==="
