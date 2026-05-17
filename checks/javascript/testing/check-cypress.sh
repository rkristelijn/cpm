#!/usr/bin/env bash
# checks/javascript/testing/check-cypress.sh
# Cypress E2E testing anti-patterns: hardcoded waits, deprecated APIs, config issues
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../../lib/shell/init.sh" 2>/dev/null || true
cpm_check_enabled "js-cypress" || exit 0
set -o nounset -o pipefail

REPO="${1:-.}"
# Detect Cypress project
[ -f "$REPO/cypress.config.ts" ] || [ -f "$REPO/cypress.config.js" ] || \
  [ -d "$REPO/cypress" ] || exit 0

FINDINGS=0
finding() { printf "  \033[33mwarning\033[0m  %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }

CY_DIR="$REPO/cypress"

# --- cy.wait(number) hardcoded waits ---
if cpm_grep -rn "cy\.wait([0-9]" "$CY_DIR/" 2>/dev/null | head -1 | grep -q .; then
  finding "cy-hardcoded-wait" "cy.wait(ms) — use cy.intercept() + cy.wait('@alias') instead"
fi

# --- await cy.* (doesn't work with Cypress command queue) ---
if cpm_grep -rn "await cy\." "$CY_DIR/" 2>/dev/null | head -1 | grep -q .; then
  finding "cy-await-commands" "await cy.* — Cypress commands aren't Promises, remove await"
fi

# --- Deprecated cy.route() ---
if cpm_grep -rn "cy\.route(" "$CY_DIR/" 2>/dev/null | head -1 | grep -q .; then
  finding "cy-deprecated-route" "cy.route() is deprecated since Cypress 6 — use cy.intercept()"
fi

# --- No baseUrl configured ---
CFG=""
[ -f "$REPO/cypress.config.ts" ] && CFG="$REPO/cypress.config.ts"
[ -f "$REPO/cypress.config.js" ] && CFG="$REPO/cypress.config.js"
if [ -n "$CFG" ]; then
  grep -q "baseUrl" "$CFG" || finding "cy-no-baseurl" "No baseUrl in cypress config — hardcoded URLs in every test"
  # Video recording (expensive in CI)
  if ! grep -q "video.*false" "$CFG"; then
    finding "cy-video-on" "Video recording not disabled — slows CI and wastes storage"
  fi
fi

# --- .only left in cypress tests ---
if cpm_grep -rn "\.only(" "$CY_DIR/" 2>/dev/null | head -1 | grep -q .; then
  finding "cy-only-left" ".only() left in Cypress tests — CI will skip other tests"
fi

# --- Fragile selectors (no data-cy/data-testid) ---
if cpm_grep -rn "cy\.get('[.#][a-z]" "$CY_DIR/" 2>/dev/null | grep -v "data-\|\\[" | head -1 | grep -q . 2>/dev/null; then
  finding "cy-fragile-selectors" "CSS class/id selectors in cy.get() — use data-cy or data-testid attributes"
fi

[ "$FINDINGS" -eq 0 ] && echo "  ✓ Cypress setup OK"
exit 0
