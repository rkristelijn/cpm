#!/usr/bin/env bash
# =============================================================================
# check-magic-literals.sh — Detect repeated magic strings and numbers
#
# When the same literal appears 3+ times, it should be a named constant.
# Benefits: single source of truth, easier refactoring, self-documenting.
#
# Ignores: object keys, imports, test files, short strings (<4 chars).
#
# Usage: bash checks/check-magic-literals.sh [dir] [threshold]
# =============================================================================

set -o pipefail

DIR="${1:-src}"
THRESHOLD="${2:-3}"
ISSUES=0

echo "  Magic literals audit ($DIR/, threshold: ${THRESHOLD}x)"

# --- Magic strings (repeated string literals) ---
REPEATED_STRINGS=$(find "$DIR" -name "*.js" -not -name "*test*" -not -name "*.spec.js" -not -path "*/node_modules/*" -not -path "*/shared/constants*" \
  -exec grep -ohP "'[^']{4,}'" {} + 2>/dev/null \
  | grep -v "^\./\|^'node:\|^'from " \
  | sort | uniq -c | sort -rn \
  | awk -v t="$THRESHOLD" '$1 >= t {print}')

if [[ -n "$REPEATED_STRINGS" ]]; then
  # Filter out imports, requires, object keys
  REAL_ISSUES=$(echo "$REPEATED_STRINGS" | grep -v "import\|require\|from '\|\.js'" || true)
  if [[ -n "$REAL_ISSUES" ]]; then
    echo ""
    echo "  Repeated strings (${THRESHOLD}+ occurrences):"
    echo "$REAL_ISSUES" | head -10 | sed 's/^/    /'
    ISSUES=$((ISSUES + 1))
  fi
fi

# --- Magic numbers (repeated numeric literals, not 0/1/2) ---
REPEATED_NUMBERS=$(find "$DIR" -name "*.js" -not -name "*test*" -not -name "*.spec.js" -not -path "*/node_modules/*" -not -path "*/shared/constants*" \
  -exec grep -ohP '(?<![.\w"'"'"'])([3-9]\d{2,}|\d{4,})(?![.\w])' {} + 2>/dev/null \
  | sort | uniq -c | sort -rn \
  | awk -v t="$THRESHOLD" '$1 >= t {print}')

if [[ -n "$REPEATED_NUMBERS" ]]; then
  echo ""
  echo "  Repeated numbers (${THRESHOLD}+ occurrences):"
  echo "$REPEATED_NUMBERS" | head -10 | sed 's/^/    /'
  ISSUES=$((ISSUES + 1))
fi

echo ""
if [[ $ISSUES -gt 0 ]]; then
  echo "  ✗ Found repeated literals. Extract to src/shared/constants.js:"
  echo ""
  echo "    export const STATUS_PASS = 'pass';"
  echo "    export const STATUS_FAIL = 'fail';"
  echo "    export const DEFAULT_PORT = 443;"
  echo "    export const HTTP_NOT_FOUND = 404;"
  exit 1
else
  echo "  ✓ No magic literals above threshold"
fi
