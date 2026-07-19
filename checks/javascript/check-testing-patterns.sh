#!/usr/bin/env bash
# checks/javascript/check-testing-patterns.sh
# @see ADR-129
# Test quality: anti-patterns in test files, missing patterns, flaky indicators
set -o nounset -o pipefail

REPO="${1:-.}"
[ -f "$REPO/package.json" ] || exit 0

FINDINGS=0
finding() { printf "  \033[33mwarning\033[0m  %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }

SRC=""
[ -d "$REPO/src" ] && SRC="$REPO/src"
[ -d "$REPO/app" ] && SRC="${SRC:+$SRC }$REPO/app"
[ -z "$SRC" ] && exit 0

# Find test files
TESTS=$(find $SRC "$REPO/tests" "$REPO/__tests__" -name "*.test.*" -o -name "*.spec.*" 2>/dev/null | grep -v node_modules || true)
[ -z "$TESTS" ] && exit 0

# 1. Test without assertions (empty test)
NO_ASSERT=$(echo "$TESTS" | xargs grep -L "expect\|assert\|should\|toBe\|toEqual\|toHave\|toMatch\|toThrow" 2>/dev/null | head -1 || true)
[ -n "$NO_ASSERT" ] && finding "test-no-assertion" "Test without assertions: $(basename "$NO_ASSERT") — test proves nothing"

# 2. Test with implementation details (querying by className/id)
if echo "$TESTS" | xargs grep -n "getByClassName\|querySelector\|getElementById\|\.className\b" 2>/dev/null | head -1 | grep -q .; then
  finding "test-impl-detail" "Test queries by className/id — use getByRole/getByText for resilient tests"
fi

# 3. snapshot testing overuse (>5 snapshot tests)
SNAP_COUNT=$(echo "$TESTS" | xargs grep -c "toMatchSnapshot\|toMatchInlineSnapshot" 2>/dev/null | awk -F: '{s+=$2}END{print s+0}')
[ "${SNAP_COUNT:-0}" -gt 5 ] && finding "test-snapshot-overuse" "$SNAP_COUNT snapshot tests — brittle, prefer explicit assertions"

# 4. setTimeout/setInterval in tests (flaky)
if echo "$TESTS" | xargs grep -n "setTimeout\|setInterval\|sleep(" 2>/dev/null | grep -v "jest.useFakeTimers\|vi.useFakeTimers\|fakeTimers" | head -1 | grep -q .; then
  finding "test-real-timers" "Real setTimeout in tests — flaky! Use fake timers or waitFor"
fi

# 5. No async waitFor/findBy for async operations
if echo "$TESTS" | xargs grep -l "useQuery\|fetch\|async" 2>/dev/null | \
  xargs grep -L "waitFor\|findBy\|waitForElementToBeRemoved\|act(" 2>/dev/null | head -1 | grep -q . 2>/dev/null; then
  finding "test-no-waitfor" "Async test without waitFor/findBy — test may pass before data loads"
fi

# 6. Mocking everything (over-mocking)
MOCK_HEAVY=$(echo "$TESTS" | xargs grep -c "jest.mock\|vi.mock\|mock(" 2>/dev/null | awk -F: '$2>5{print $1}' | head -1 || true)
[ -n "$MOCK_HEAVY" ] && finding "test-over-mocking" "$(basename "$MOCK_HEAVY") has >5 mocks — test is testing mocks, not code"

# 7. Test file doesn't match source file naming
# Convention: src/Foo.tsx → src/Foo.test.tsx or __tests__/Foo.test.tsx
ORPHAN=$(echo "$TESTS" | while read -r t; do
  BASE=$(basename "$t" | sed 's/\.test\.\|\.spec\././; s/\.[^.]*$//')
  if ! find $SRC -name "${BASE}.*" -not -name "*.test.*" -not -name "*.spec.*" 2>/dev/null | grep -q .; then
    echo "$t" && break
  fi
done | head -1)
[ -n "${ORPHAN:-}" ] && finding "test-orphan" "Test $(basename "$ORPHAN") has no matching source file — dead test?"

# 8. it.skip / describe.skip / xtest left in
if echo "$TESTS" | xargs grep -n "\.skip\|xtest\|xit\|xdescribe" 2>/dev/null | head -1 | grep -q .; then
  finding "test-skipped" "Skipped tests found (it.skip/xtest) — fix or remove, don't leave disabled"
fi

# 9. Hardcoded test data that could be stale
if echo "$TESTS" | xargs grep -n "2024\|2023\|2022" 2>/dev/null | head -1 | grep -q .; then
  finding "test-hardcoded-date" "Hardcoded year in test — use relative dates or freeze time"
fi

# 10. No test setup/teardown (global state leaks)
if echo "$TESTS" | xargs grep -l "render(" 2>/dev/null | \
  xargs grep -L "beforeEach\|afterEach\|beforeAll\|cleanup" 2>/dev/null | head -1 | grep -q . 2>/dev/null; then
  finding "test-no-cleanup" "Render tests without cleanup/afterEach — state leaks between tests"
fi

# 11. Testing library import issues
if echo "$TESTS" | xargs grep -n "from '@testing-library/react'" 2>/dev/null | head -1 | grep -q .; then
  # Check for cleanup import when not using vitest with auto-cleanup
  if ! grep -q "globals.*true\|setupFilesAfterFramework" "$REPO/vitest.config"* 2>/dev/null; then
    if echo "$TESTS" | xargs grep -L "cleanup" 2>/dev/null | head -1 | grep -q . 2>/dev/null; then
      finding "test-no-auto-cleanup" "Testing Library without auto-cleanup config — import cleanup or configure vitest globals"
    fi
  fi
fi

# 12. No test for error states
if echo "$TESTS" | xargs grep -L "error\|Error\|reject\|throw\|fail" 2>/dev/null | wc -l | tr -d ' ' | grep -qE "^[3-9]|^[1-9][0-9]"; then
  finding "test-no-error-cases" "Most tests don't cover error states — add tests for failures/edge cases"
fi

[ "$FINDINGS" -eq 0 ] && printf "  \033[32m✓\033[0m  Testing patterns: all checks passed\n"
exit 0
