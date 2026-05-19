#!/usr/bin/env bash
# check-feature-coverage.sh — Report which cpm commands have test coverage.
source "$(dirname "$0")/../../../lib/shell/check.sh"
BINARY="${1:-./cpm}"

COVERED="check:tests/e2e/test_check.sh
get:tests/e2e/test_config.sh
set:tests/e2e/test_config.sh
help:tests/e2e/test_help.sh
hook:tests/e2e/test_hooks.sh
unhook:tests/e2e/test_hooks.sh
init:tests/e2e/test_init.sh
new:tests/e2e/test_new.sh
scan:tests/e2e/test_scan.sh
version:tests/e2e/test_version.sh
bump:tests/e2e/test_version.sh"

COMMANDS=$("$BINARY" help | grep -oE '^\s+[a-z]+' | awk '{print $1}' | sort -u)
PASS=0; MISS=0; TOTAL=0

echo "Feature Coverage Report"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
printf "  %-12s %-8s %s\n" "Command" "Status" "Test file"
echo "  ─────────────────────────────────────────"

for cmd in $COMMANDS; do
  TOTAL=$((TOTAL + 1))
  test_file=$(echo "$COVERED" | grep "^${cmd}:" | cut -d: -f2 | head -1)
  if [ -n "$test_file" ] && [ -f "$test_file" ]; then
    printf "  %-12s \033[32m✓\033[0m       %s\n" "$cmd" "$test_file"
    PASS=$((PASS + 1))
  else
    printf "  %-12s \033[31m✗\033[0m       missing\n" "$cmd"
    MISS=$((MISS + 1))
  fi
done

echo ""
PCT=$((PASS * 100 / TOTAL))
echo "  $PASS/$TOTAL commands covered ($PCT%)"
echo "  $MISS commands without e2e test"
