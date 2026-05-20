#!/usr/bin/env bash
# E2E test: cpm run
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"
BINARY=$(resolve_binary "${1:-./cpm}")
check_binary "$BINARY"

echo "=== E2E: run ==="

# run builds and executes (in cpm repo it runs cpm itself)
OUTPUT=$("$BINARY" run 2>&1 || true)
[[ -n "$OUTPUT" ]] || die "run produced no output"

echo "=== All run tests passed ==="
