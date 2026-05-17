#!/usr/bin/env bash
# checks/javascript/testing/check-playwright.sh
# Playwright E2E anti-patterns: hardcoded waits, deprecated APIs, config issues
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../../lib/shell/init.sh" 2>/dev/null || true
cpm_check_enabled "js-playwright" || exit 0
set -o nounset -o pipefail

REPO="${1:-.}"
[ -f "$REPO/playwright.config.ts" ] || [ -f "$REPO/playwright.config.js" ] || exit 0

FINDINGS=0
finding() { printf "  \033[33mwarning\033[0m  %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }

# Find test dirs
PW_DIRS=""
[ -d "$REPO/tests" ] && PW_DIRS="$REPO/tests/"
[ -d "$REPO/e2e" ] && PW_DIRS="$PW_DIRS $REPO/e2e/"
[ -d "$REPO/test" ] && PW_DIRS="$PW_DIRS $REPO/test/"

CFG=""
[ -f "$REPO/playwright.config.ts" ] && CFG="$REPO/playwright.config.ts"
[ -f "$REPO/playwright.config.js" ] && CFG="$REPO/playwright.config.js"

# --- waitForTimeout (hardcoded wait) ---
if [ -n "$PW_DIRS" ]; then
  cpm_grep -rn "waitForTimeout(" $PW_DIRS 2>/dev/null | head -1 | grep -q . && \
    finding "pw-hardcoded-wait" "waitForTimeout() — use locator assertions or waitForResponse instead"
fi

# --- page.$() / page.$$() deprecated Puppeteer-style ---
if [ -n "$PW_DIRS" ]; then
  cpm_grep -rn "page\.\$\(\\|page\.\$\$(" $PW_DIRS 2>/dev/null | head -1 | grep -q . && \
    finding "pw-element-handles" "page.$() is Puppeteer-style — use page.locator() for auto-waiting"
fi

# --- Missing await before expect (common Playwright mistake) ---
if [ -n "$PW_DIRS" ]; then
  cpm_grep -rn "expect(page\.\|expect(locator" $PW_DIRS 2>/dev/null | grep -v "await " | head -1 | grep -q . && \
    finding "pw-expect-no-await" "expect() without await — assertion won't actually wait or fail"
fi

# --- No baseURL configured ---
if [ -n "$CFG" ]; then
  grep -q "baseURL" "$CFG" || finding "pw-no-baseurl" "No baseURL in playwright config — hardcoded URLs in tests"
fi

# --- No trace on failure ---
if [ -n "$CFG" ]; then
  grep -q "trace" "$CFG" || finding "pw-no-trace" "No trace configured — enable 'retain-on-failure' for CI debugging"
fi

# --- .only left in tests ---
if [ -n "$PW_DIRS" ]; then
  cpm_grep -rn "\.only(" $PW_DIRS 2>/dev/null | head -1 | grep -q . && \
    finding "pw-only-left" ".only() left in Playwright tests — CI will skip other tests"
fi

# --- localhost hardcoded in tests ---
if [ -n "$PW_DIRS" ]; then
  cpm_grep -rn "localhost:[0-9]\|127\.0\.0\.1:" $PW_DIRS 2>/dev/null | head -1 | grep -q . && \
    finding "pw-hardcoded-url" "Hardcoded localhost URL — use baseURL from config"
fi

[ "$FINDINGS" -eq 0 ] && echo "  ✓ Playwright setup OK"
exit 0
