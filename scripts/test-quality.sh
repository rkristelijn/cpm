#!/usr/bin/env bash
# scripts/test-quality.sh — Analyze test quality: anti-patterns, liar tests, coverage gaps
# Usage: bash scripts/test-quality.sh [path]
set -o nounset -o pipefail

REPO="${1:-.}"
EXCLUDE="node_modules|\.next|dist|build|\.git|coverage|vendor|target"

# Find test files
TEST_FILES=$(find "$REPO" -name "*.test.*" -o -name "*.spec.*" -o -name "*_test.*" 2>/dev/null | grep -vE "$EXCLUDE" || true)
[ -z "$TEST_FILES" ] && { echo "  No test files found"; exit 0; }

SRC_FILES=$(find "$REPO" -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \
  -o -name "*.py" -o -name "*.go" -o -name "*.cpp" 2>/dev/null | \
  grep -vE "$EXCLUDE|\.test\.|\.spec\.|_test\." || true)

echo ""
echo "  ■ Test Quality: $(basename "$(cd "$REPO" && pwd)")"
echo ""

TEST_COUNT=$(echo "$TEST_FILES" | wc -l | tr -d ' ')
SRC_COUNT=$(echo "$SRC_FILES" | grep -c "." || echo 0)

# === 1. Basic metrics ===
echo "  Metrics:"
printf "    Test files:     %s\n" "$TEST_COUNT"
printf "    Source files:   %s\n" "$SRC_COUNT"
if [ "$SRC_COUNT" -gt 0 ]; then
  RATIO=$((TEST_COUNT * 100 / SRC_COUNT))
  printf "    Test ratio:     %s%% (test files / source files)\n" "$RATIO"
  [ "$RATIO" -lt 20 ] && printf "    ⚠ Very low test ratio — most code is untested\n"
fi
echo ""

# === 2. Assertionless tests (Liar Tests) ===
echo "  Liar Tests (no assertions):"
LIARS=$(echo "$TEST_FILES" | xargs grep -L "expect\|assert\|should\|toBe\|toEqual\|toHaveBeenCalled\|toThrow\|toMatch\|toContain\|verify\|check" 2>/dev/null || true)
LIAR_COUNT=$(echo "$LIARS" | grep -c "." 2>/dev/null || echo 0)
if [ "$LIAR_COUNT" -gt 0 ]; then
  printf "    ⚠ %s test file(s) without any assertions:\n" "$LIAR_COUNT"
  echo "$LIARS" | head -5 | sed "s|$REPO/||" | sed 's/^/      /'
else
  echo "    ✓ All test files contain assertions"
fi
echo ""

# === 3. Test anti-patterns ===
echo "  Anti-patterns:"

# The Giant (tests > 100 lines)
GIANTS=$(echo "$TEST_FILES" | while read -r f; do
  LINES=$(wc -l < "$f" | tr -d ' ')
  [ "$LINES" -gt 200 ] && printf "%s (%s lines)\n" "$(basename "$f")" "$LINES"
done)
GIANT_COUNT=$(echo "$GIANTS" | grep -c "." 2>/dev/null || echo 0)
[ "$GIANT_COUNT" -gt 0 ] && printf "    ⚠ Giant tests (>200 lines): %s\n" "$GIANT_COUNT" && echo "$GIANTS" | head -3 | sed 's/^/      /'

# The Slow Poke (setTimeout/sleep in tests)
SLEEPERS=$(echo "$TEST_FILES" | xargs grep -l "setTimeout\|sleep(\|waitFor.*[0-9]\{4\}\|cy\.wait([0-9]" 2>/dev/null | wc -l | tr -d ' ')
[ "$SLEEPERS" -gt 0 ] && printf "    ⚠ Slow tests (hardcoded waits): %s file(s)\n" "$SLEEPERS"

# Happy Path Only (no error/edge case testing)
ERROR_TESTS=$(echo "$TEST_FILES" | xargs grep -l "error\|throw\|reject\|invalid\|fail\|empty\|null\|undefined\|edge\|boundary\|negative" 2>/dev/null | wc -l | tr -d ' ')
ERROR_PCT=$((ERROR_TESTS * 100 / TEST_COUNT))
printf "    Error/edge case tests: %s/%s (%s%%)\n" "$ERROR_TESTS" "$TEST_COUNT" "$ERROR_PCT"
[ "$ERROR_PCT" -lt 30 ] && printf "    ⚠ Mostly happy-path tests — add error/edge case coverage\n"

# .only and .skip left behind
ONLY=$(echo "$TEST_FILES" | xargs grep -l "\.only\|fdescribe\|fit(" 2>/dev/null | wc -l | tr -d ' ')
SKIP=$(echo "$TEST_FILES" | xargs grep -l "\.skip\|xdescribe\|xit(" 2>/dev/null | wc -l | tr -d ' ')
[ "$ONLY" -gt 0 ] && printf "    ⚠ .only() left in %s file(s) — blocks CI\n" "$ONLY"
[ "$SKIP" -gt 0 ] && printf "    ⚠ .skip() in %s file(s) — dead tests hiding regressions\n" "$SKIP"

# Mocking everything (over-mocking)
MOCK_HEAVY=$(echo "$TEST_FILES" | xargs grep -c "mock\|Mock\|jest\.fn\|vi\.fn\|spyOn\|stub" 2>/dev/null | awk -F: '$2>10' | wc -l | tr -d ' ')
[ "$MOCK_HEAVY" -gt 3 ] && printf "    ⚠ Heavy mocking: %s test files with >10 mocks — testing mocks, not code?\n" "$MOCK_HEAVY"

echo ""

# === 4. Test-to-code alignment ===
echo "  Coverage gaps (source files without corresponding test):"
UNTESTED=0
echo "$SRC_FILES" | while read -r src; do
  [ -z "$src" ] && continue
  BASE=$(basename "$src" | sed 's/\.[^.]*$//')
  # Skip index, main, config files
  echo "$BASE" | grep -qiE "^(index|main|app|config|environment|polyfill|style)" && continue
  # Check if a test file exists for this source
  echo "$TEST_FILES" | grep -qi "$BASE" || { echo "    · $BASE"; UNTESTED=$((UNTESTED+1)); }
done | head -10
echo ""

# === 5. Mutation testing readiness ===
echo "  Mutation Testing:"
if grep -q "stryker\|@stryker-mutator" "$REPO/package.json" 2>/dev/null; then
  echo "    ✓ Stryker configured"
elif grep -q "pitest\|pit-maven" "$REPO/pom.xml" 2>/dev/null; then
  echo "    ✓ PIT configured (Java)"
else
  echo "    · Not configured — consider:"
  [ -f "$REPO/package.json" ] && echo "      npx stryker init  (JS/TS)"
  [ -f "$REPO/pom.xml" ] && echo "      Add pitest plugin (Java)"
  [ -f "$REPO/requirements.txt" ] && echo "      pip install mutmut (Python)"
fi
echo ""
