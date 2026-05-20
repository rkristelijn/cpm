#!/usr/bin/env bash
# E2E test: cpm commit (interactive — test that it starts without crash)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"
BINARY=$(resolve_binary "${1:-./cpm}")
check_binary "$BINARY"

echo "=== E2E: commit ==="

# commit with nothing staged shows message (not a crash)
DIR=$(setup_project)
cd "$DIR" && git init -q
OUTPUT=$(cd "$DIR" && "$BINARY" commit 2>&1 || true)
[[ -n "$OUTPUT" ]] || die "commit produced no output"
teardown_project "$DIR"

echo "=== All commit tests passed ==="
