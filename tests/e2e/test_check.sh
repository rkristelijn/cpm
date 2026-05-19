#!/usr/bin/env bash
# E2E test: cpm check
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"
BINARY=$(resolve_binary "${1:-./cpm}")
check_binary "$BINARY"

echo "=== E2E: check ==="

# check runs without crash (may fail checks, but shouldn't segfault)
OUTPUT=$("$BINARY" check 2>&1 || true)
# Should produce some output (not empty)
[[ -n "$OUTPUT" ]] || die "check produced no output"

# check --fast runs
OUTPUT=$("$BINARY" check --fast 2>&1 || true)
[[ -n "$OUTPUT" ]] || die "check --fast produced no output"

# check in empty dir still runs (uses defaults, no cpm.toml required)
DIR=$(setup_project)
OUTPUT=$(cd "$DIR" && "$BINARY" check 2>&1 || true)
[[ -n "$OUTPUT" ]] || die "check in empty dir produced no output"
teardown_project "$DIR"

echo "=== All check tests passed ==="
