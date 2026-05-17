#!/usr/bin/env bash
# checks/javascript/testing/check-testing.sh
# Testing best practices: config, coverage, .only, snapshots
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../../lib/shell/init.sh" 2>/dev/null || true
cpm_check_enabled "js-testing" || exit 0
set -o nounset -o pipefail

REPO="${1:-.}"
[ -f "$REPO/package.json" ] || exit 0
grep -qE '"jest"|"vitest"|"@jest"|"@testing-library"' "$REPO/package.json" || exit 0

FINDINGS=0
finding() { printf "  \033[33mwarning\033[0m  %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }

# --- No test script ---
grep -q '"test"' "$REPO/package.json" || finding "no-test-script" "No test script in package.json"

# --- .only left in test files (blocks other tests in CI) ---
if cpm_grep -rn "\.only(" "$REPO/src/" "$REPO/tests/" "$REPO/test/" "$REPO/__tests__/" 2>/dev/null | \
  grep -E "\.(test|spec)\.(ts|tsx|js|jsx):" | head -1 | grep -q .; then
  finding "test-only-left" ".only() left in test file — blocks other tests from running in CI"
fi

# --- .skip left in test files (dead tests) ---
if cpm_grep -rn "\.skip(" "$REPO/src/" "$REPO/tests/" "$REPO/test/" "$REPO/__tests__/" 2>/dev/null | \
  grep -E "\.(test|spec)\.(ts|tsx|js|jsx):" | grep -v "// cpm:ignore" | head -1 | grep -q .; then
  finding "test-skip-left" ".skip() in test files — dead tests that may hide regressions"
fi

# --- No coverage threshold configured ---
HAS_THRESHOLD=false
if [ -f "$REPO/jest.config.js" ] || [ -f "$REPO/jest.config.ts" ]; then
  grep -q "coverageThreshold" "$REPO/jest.config.js" "$REPO/jest.config.ts" 2>/dev/null && HAS_THRESHOLD=true
fi
if [ -f "$REPO/vitest.config.ts" ] || [ -f "$REPO/vitest.config.js" ]; then
  grep -q "thresholds\|coverage" "$REPO/vitest.config.ts" "$REPO/vitest.config.js" 2>/dev/null && HAS_THRESHOLD=true
fi
grep -q "coverageThreshold" "$REPO/package.json" 2>/dev/null && HAS_THRESHOLD=true
[ "$HAS_THRESHOLD" = false ] && finding "no-coverage-threshold" "No coverage threshold — coverage can silently drop"

# --- Large snapshot files (>50KB = likely auto-generated noise) ---
LARGE_SNAPS=$(find "$REPO" -name "*.snap" -size +50k 2>/dev/null | head -1)
[ -n "$LARGE_SNAPS" ] && finding "large-snapshots" "Snapshot files >50KB — consider inline snapshots or more targeted tests"

# --- No test files at all ---
TEST_COUNT=$(find "$REPO/src" "$REPO/tests" "$REPO/test" "$REPO/__tests__" \
  -name "*.test.*" -o -name "*.spec.*" 2>/dev/null | wc -l | tr -d ' ')
[ "${TEST_COUNT:-0}" -eq 0 ] && finding "no-test-files" "No test files found — testing framework installed but no tests written"

# --- fireEvent instead of userEvent (Kent C. Dodds best practice) ---
if [ -d "$REPO/src" ] || [ -d "$REPO/tests" ]; then
  if cpm_grep -rl "fireEvent\." "$REPO/src/" "$REPO/tests/" "$REPO/test/" "$REPO/__tests__/" 2>/dev/null | \
    grep -E "\.(test|spec)\." | head -1 | grep -q .; then
    if grep -q '"@testing-library/user-event"\|"@testing-library/react"' "$REPO/package.json" 2>/dev/null; then
      finding "prefer-user-event" "fireEvent used in tests — prefer @testing-library/user-event for realistic interactions"
    fi
  fi
fi

# --- getByTestId overuse (prefer getByRole/getByLabelText) ---
if [ -d "$REPO/src" ] || [ -d "$REPO/tests" ]; then
  TESTID_COUNT=$(cpm_grep -rn "getByTestId\|queryByTestId\|findByTestId" "$REPO/src/" "$REPO/tests/" "$REPO/test/" "$REPO/__tests__/" 2>/dev/null | \
    grep -E "\.(test|spec)\." | wc -l | tr -d ' ')
  [ "${TESTID_COUNT:-0}" -gt 10 ] && finding "overuse-testid" "Heavy use of *ByTestId ($TESTID_COUNT) — prefer getByRole/getByLabelText for accessible queries"
fi

# --- Vitest-specific: jest.fn() used instead of vi.fn() ---
if grep -q '"vitest"' "$REPO/package.json" 2>/dev/null; then
  if cpm_grep -rl "jest\.\|jest\.fn\|jest\.mock\|jest\.spyOn" "$REPO/src/" "$REPO/tests/" "$REPO/test/" 2>/dev/null | \
    grep -E "\.(test|spec)\." | head -1 | grep -q . 2>/dev/null; then
    finding "vitest-uses-jest-api" "jest.* used in Vitest project — use vi.fn(), vi.mock(), vi.spyOn()"
  fi
  # Coverage provider not installed
  if grep -q '"coverage"' "$REPO/vitest.config.ts" "$REPO/vitest.config.js" "$REPO/vite.config.ts" 2>/dev/null; then
    if ! grep -q '"@vitest/coverage-v8"\|"@vitest/coverage-istanbul"' "$REPO/package.json"; then
      finding "vitest-no-coverage-pkg" "Coverage configured but @vitest/coverage-v8 not installed"
    fi
  fi
fi

# --- Dynamic data in snapshots (dates, UUIDs that change every run) ---
SNAPS_WITH_DATES=$(find "$REPO" -name "*.snap" -exec grep -l "202[0-9]-\|T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]\|[0-9a-f]\{8\}-[0-9a-f]\{4\}-" {} \; 2>/dev/null | head -1)
[ -n "$SNAPS_WITH_DATES" ] && finding "snapshot-dynamic-data" "Snapshot contains dates/UUIDs — will fail on next run. Use expect.any()"

# --- Tests without any expect (always pass, give false confidence) ---
if [ "${TEST_COUNT:-0}" -gt 0 ]; then
  NO_EXPECT=$(find "$REPO/src" "$REPO/tests" "$REPO/test" "$REPO/__tests__" \
    -name "*.test.*" -o -name "*.spec.*" 2>/dev/null | \
    xargs grep -L "expect\|assert\|toMatch\|toThrow\|toHaveBeenCalled" 2>/dev/null | head -1 || true)
  [ -n "$NO_EXPECT" ] && finding "test-no-assertion" "Test file without assertions — always passes, gives false confidence"
fi

[ "$FINDINGS" -eq 0 ] && echo "  ✓ Testing setup OK"
exit 0
