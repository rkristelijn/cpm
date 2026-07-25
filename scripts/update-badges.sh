#!/usr/bin/env bash
# scripts/update-badges.sh — Update README.md badges with actual metrics
# Run: bash scripts/update-badges.sh
# Called by CI after merge to main
set -o nounset -o pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
README="$REPO/README.md"

[ -f "$README" ] || {
  echo "README.md not found"
  exit 1
}

echo "  Updating badges..."

# --- Count tests ---
TESTS=0
if [ -f "$REPO/build/test_checks" ]; then
  TESTS=$("$REPO/build/test_checks" 2>&1 | grep -oE "[0-9]+ passed" | grep -oE "[0-9]+" || echo 0)
fi
[ "$TESTS" -eq 0 ] && TESTS=$(grep -c "TEST_CASE\|SCENARIO" "$REPO/src/checks_test.cpp" 2>/dev/null || echo 0)
echo "    tests: $TESTS"

# --- Count check rules ---
RULES=$(grep -rh "finding\|blocker\|error(" "$REPO/checks/" 2>/dev/null | grep -oE '"[a-z][-a-z0-9]*"' | sort -u | wc -l | tr -d ' ')
# Add native check rules
NATIVE=$(grep -rh "rule =\|\"rule\":" "$REPO/src/checks/" 2>/dev/null | grep -oE '"[a-z][-a-z0-9]*"' | sort -u | wc -l | tr -d ' ')
TOTAL_CHECKS=$((RULES + NATIVE))
echo "    checks: $TOTAL_CHECKS"

# --- Count languages ---
LANGS=$(ls -d "$REPO/checks/"*/ 2>/dev/null | wc -l | tr -d ' ')
echo "    languages: $LANGS"

# --- Pasta score on self ---
HEALTH=""
if [ -f "$REPO/checks/universal/quality/check-spaghetti-score.sh" ]; then
  HEALTH=$(bash "$REPO/checks/universal/quality/check-spaghetti-score.sh" "$REPO" 2>/dev/null | grep -oE "[0-9]+/100" | head -1 || echo "")
fi
echo "    health: $HEALTH"

# --- Version ---
VERSION=$(grep "^version" "$REPO/cpm.toml" 2>/dev/null | grep -oE "[0-9]+\.[0-9]+\.[0-9]+" || echo "dev")
echo "    version: $VERSION"

# --- Update badges in README ---
sed -i "s|badge/tests-[0-9]*%20passed-brightgreen|badge/tests-${TESTS}%20passed-brightgreen|" "$README"
sed -i "s|badge/checks-[0-9]*-blue|badge/checks-${TOTAL_CHECKS}-blue|" "$README"
sed -i "s|badge/languages-[0-9]*-blue|badge/languages-${LANGS}-blue|" "$README"

# Add pasta score badge if not present
if ! grep -q "pasta.*score\|health.*score\|spaghetti" "$README" 2>/dev/null; then
  if [ -n "$HEALTH" ]; then
    SCORE=$(echo "$HEALTH" | grep -oE "^[0-9]+")
    if [ "$SCORE" -ge 90 ]; then
      COLOR="brightgreen"
    elif [ "$SCORE" -ge 75 ]; then
      COLOR="green"
    elif [ "$SCORE" -ge 50 ]; then
      COLOR="yellow"
    else COLOR="red"; fi
    # Insert after the tests badge
    sed -i "/badge\/tests/a ![health](https://img.shields.io/badge/health-${HEALTH/\//%2F}-${COLOR})" "$README"
  fi
fi

# Update health badge if already present
if grep -q "badge/health" "$README" 2>/dev/null && [ -n "$HEALTH" ]; then
  SCORE=$(echo "$HEALTH" | grep -oE "^[0-9]+")
  if [ "$SCORE" -ge 90 ]; then
    COLOR="brightgreen"
  elif [ "$SCORE" -ge 75 ]; then
    COLOR="green"
  elif [ "$SCORE" -ge 50 ]; then
    COLOR="yellow"
  else COLOR="red"; fi
  sed -i "s|badge/health-[0-9]*%2F100-[a-z]*|badge/health-${HEALTH/\//%2F}-${COLOR}|" "$README"
fi

# --- Update feature count in text ---
sed -i "s/[0-9]\+ checks across/~${TOTAL_CHECKS} checks across/" "$README"

echo "  Done. Badges updated."
echo ""
echo "  Changes:"
git diff --stat "$README" 2>/dev/null || true
