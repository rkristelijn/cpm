#!/usr/bin/env bash
# run-e2e.sh — Run all end-to-end tests.
# Usage: bash scripts/test/run-e2e.sh [binary]

set -o errexit
set -o nounset
set -o pipefail

BINARY="${1:-./cpm}"

if [[ ! -x "$BINARY" ]]; then
  echo "ERROR: binary not found at $BINARY — run make build first"
  exit 1
fi

echo "==> running e2e tests against $BINARY..."
PASS=0
FAIL=0

for t in tests/e2e/test_*.sh; do
  echo "  [test] $t"
  if bash "$t" "$BINARY" >/dev/null 2>&1; then
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $t"
    # Re-run with output for debugging
    bash "$t" "$BINARY" 2>&1 | tail -5 || true
    FAIL=$((FAIL + 1))
  fi
done

echo ""
echo "  Results: $PASS passed, $FAIL failed (total $((PASS + FAIL)))"
[[ $FAIL -eq 0 ]] || exit 1
