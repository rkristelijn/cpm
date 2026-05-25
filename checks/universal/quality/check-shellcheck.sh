#!/usr/bin/env bash
# checks/universal/quality/check-shellcheck.sh
# @see ADR-129
# Runs shellcheck on all shell scripts — catches what SonarCloud flags.
set -o nounset -o pipefail

REPO="${1:-.}"

command -v shellcheck >/dev/null 2>&1 || exit 0

FILES=$(find "$REPO" -name "*.sh" -type f \
  \( -name node_modules -o -name .git -o -name dist -o -name .tmp \) -prune \
  -o -name "*.sh" -type f -print 2>/dev/null)

[ -z "$FILES" ] && exit 0

ERRORS=0
WARNINGS=0

while IFS= read -r script; do
  [ -z "$script" ] && continue
  # Only report errors (severity: error) — warnings are too noisy for now
  output=$(shellcheck -S error -f gcc "$script" 2>/dev/null)
  if [ -n "$output" ]; then
    count=$(echo "$output" | wc -l | tr -d ' ')
    ERRORS=$((ERRORS + count))
    printf "  \033[31merror\033[0m    %-50s %d issue(s)\n" "$script" "$count"
  fi
done <<< "$FILES"

if [ "$ERRORS" -gt 0 ]; then
  echo ""
  echo "  $ERRORS shellcheck error(s). Fix: shellcheck -S error <file>"
  exit 1
fi
exit 0
