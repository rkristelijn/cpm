#!/usr/bin/env bash
# E2E test: cpm check
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"
BINARY="${1:-./cpm}"
check_binary "$BINARY"

echo "=== E2E: check ==="

# check runs without crash (may fail checks, but shouldn't segfault)
OUTPUT=$("$BINARY" check 2>&1 || true)
# Should produce some output (not empty)
[[ -n "$OUTPUT" ]] || die "check produced no output"

# check --fast runs
OUTPUT=$("$BINARY" check --fast 2>&1 || true)
[[ -n "$OUTPUT" ]] || die "check --fast produced no output"

# check without cpm.toml gives error
DIR=$(setup_project)
OUTPUT=$(cd "$DIR" && "$BINARY" check 2>&1 || true)
assert_contains "$OUTPUT" "cpm.toml" "needs cpm.toml"
teardown_project "$DIR"

echo "=== All check tests passed ==="
