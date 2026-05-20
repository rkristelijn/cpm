#!/usr/bin/env bash
# E2E test: cpm install / uninstall
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"
BINARY=$(resolve_binary "${1:-./cpm}")
check_binary "$BINARY"

echo "=== E2E: install/uninstall ==="

# install shows what it would install (or installs tools)
OUTPUT=$("$BINARY" install 2>&1 || true)
[[ -n "$OUTPUT" ]] || die "install produced no output"

# uninstall without --all shows usage or confirmation
OUTPUT=$("$BINARY" uninstall 2>&1 || true)
[[ -n "$OUTPUT" ]] || die "uninstall produced no output"

echo "=== All install/uninstall tests passed ==="
