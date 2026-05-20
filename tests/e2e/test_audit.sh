#!/usr/bin/env bash
# E2E test: cpm audit
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"
BINARY=$(resolve_binary "${1:-./cpm}")
check_binary "$BINARY"

echo "=== E2E: audit ==="

# audit runs in project with cpm.toml
OUTPUT=$("$BINARY" audit 2>&1 || true)
[[ -n "$OUTPUT" ]] || die "audit produced no output"

# audit in empty dir handles missing cpm.toml gracefully
DIR=$(setup_project)
OUTPUT=$(cd "$DIR" && "$BINARY" audit 2>&1 || true)
[[ -n "$OUTPUT" ]] || die "audit in empty dir produced no output"
teardown_project "$DIR"

echo "=== All audit tests passed ==="
