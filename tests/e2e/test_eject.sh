#!/usr/bin/env bash
# E2E test: cpm eject
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"
BINARY=$(resolve_binary "${1:-./cpm}")
check_binary "$BINARY"

echo "=== E2E: eject ==="

# eject generates build files (disable mock — eject is file-based, not tool-based)
DIR=$(setup_project)
cd "$DIR"
unset CPM_MOCK
"$BINARY" init >/dev/null 2>&1
OUTPUT=$("$BINARY" eject 2>&1 || true)
[[ -n "$OUTPUT" ]] || die "eject produced no output"
assert_contains "$OUTPUT" "Makefile" "generates Makefile"
cd "$SCRIPT_DIR/../.."
teardown_project "$DIR"

echo "=== All eject tests passed ==="
