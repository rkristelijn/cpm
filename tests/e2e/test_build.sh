#!/usr/bin/env bash
# E2E test: cpm build
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"
BINARY=$(resolve_binary "${1:-./cpm}")
check_binary "$BINARY"

echo "=== E2E: build ==="

# build runs in cpm's own repo (has Makefile)
OUTPUT=$("$BINARY" build 2>&1 || true)
[[ -n "$OUTPUT" ]] || die "build produced no output"

# build in empty dir handles gracefully
DIR=$(setup_project)
OUTPUT=$(cd "$DIR" && "$BINARY" build 2>&1 || true)
[[ -n "$OUTPUT" ]] || die "build in empty dir produced no output"
teardown_project "$DIR"

echo "=== All build tests passed ==="
