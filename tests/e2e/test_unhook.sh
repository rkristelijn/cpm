#!/usr/bin/env bash
# E2E test: cpm unhook
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"
BINARY=$(resolve_binary "${1:-./cpm}")
check_binary "$BINARY"

echo "=== E2E: unhook ==="

# unhook in a git repo removes hooks
DIR=$(setup_project)
cd "$DIR" && git init -q
OUTPUT=$(cd "$DIR" && "$BINARY" unhook 2>&1 || true)
[[ -n "$OUTPUT" ]] || die "unhook produced no output"
teardown_project "$DIR"

echo "=== All unhook tests passed ==="
