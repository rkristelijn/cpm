#!/usr/bin/env bash
# E2E test: validate rule engine finds expected patterns in fixtures
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

RULE_SCAN="./build/rule-scan"
FIXTURE="tests/e2e/fixtures/rule-test"

if [[ ! -f "$RULE_SCAN" ]]; then
  echo "SKIP: build/rule-scan not found (needs RE2)"
  exit 0
fi

echo "Running rule-scan on fixtures..."
OUTPUT=$($RULE_SCAN "$FIXTURE" 2>&1 | sed 's/\x1B\[[0-9;]*m//g') || true

ERRORS=0

expect() {
  local rule="$1" desc="$2"
  if echo "$OUTPUT" | grep -q "$rule"; then
    echo "  ✓ $rule: $desc"
  else
    echo "  ✗ $rule: $desc — NOT FOUND"
    ERRORS=$((ERRORS + 1))
  fi
}

expect "SEC-010" "AWS key detection"
expect "SEC-011" "eval() detection"
expect "QUAL-011" "console.log detection"
expect "QUAL-014" "TODO marker detection"
expect "STYLE-010" ".then() detection"
expect "STYLE-011" "deep import detection"

echo ""
if [[ "$ERRORS" -eq 0 ]]; then
  echo "✅ All rule assertions passed"
else
  echo "❌ $ERRORS rule assertion(s) failed"
  exit 1
fi
