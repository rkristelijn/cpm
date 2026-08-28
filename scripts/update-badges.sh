#!/usr/bin/env bash
# scripts/update-badges.sh — Update README.md badges with actual metrics
#
# Usage:
#   bash scripts/update-badges.sh           # live mode (updates README)
#   bash scripts/update-badges.sh --dry-run # report only, no file changes
#
# Called by CI:
#   - On PR: --dry-run (reports to job summary)
#   - On main merge: live (commits badge updates)
set -o nounset -o pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
README="$REPO/README.md"
DRY_RUN=false
CI_URL="${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY:-rkristelijn/cpm}/actions/runs/${GITHUB_RUN_ID:-0}"

[ "${1:-}" = "--dry-run" ] && DRY_RUN=true

[ -f "$README" ] || {
  echo "❌ README.md not found"
  exit 1
}
[ -x "$REPO/cpm" ] || {
  echo "❌ cpm binary not found (run make build first)"
  exit 1
}

echo "=== Badge Verification ==="
echo ""

# --- Tests ---
TESTS=0
if make -C "$REPO" test-unit 2>&1 | tee /tmp/badge-tests.log | tail -3; then
  TESTS=$(grep -oE "[0-9]+ passed" /tmp/badge-tests.log | grep -oE "[0-9]+" | paste -sd+ | bc 2>/dev/null || echo 0)
fi
echo "  ✓ tests: $TESTS passed"

# --- Score & maturity level ---
SCORE=$("$REPO/cpm" score 2>/dev/null | grep -oE "[0-9]+/100" | grep -oE "^[0-9]+" || echo 0)
if [ "$SCORE" -ge 91 ]; then
  LEVEL=5
  LEVEL_COLOR="brightgreen"
elif [ "$SCORE" -ge 76 ]; then
  LEVEL=4
  LEVEL_COLOR="green"
elif [ "$SCORE" -ge 51 ]; then
  LEVEL=3
  LEVEL_COLOR="yellow"
elif [ "$SCORE" -ge 26 ]; then
  LEVEL=2
  LEVEL_COLOR="orange"
else
  LEVEL=1
  LEVEL_COLOR="red"
fi
echo "  ✓ maturity: level $LEVEL (score: $SCORE/100)"

# --- Check count ---
CHECKS=$("$REPO/cpm" scan . --depth 1 2>/dev/null | grep -oE "[0-9]+ checks" | grep -oE "[0-9]+" || echo 0)
if [ "$CHECKS" -eq 0 ]; then
  # Fallback: count from source
  SHELL_CHECKS=$(grep -rh "finding\|blocker\|error(" "$REPO/checks/" 2>/dev/null | grep -oE '"[a-z][-a-z0-9]*"' | sort -u | wc -l | tr -d ' ')
  NATIVE_CHECKS=$(grep -rh 'rule =\|"rule":' "$REPO/src/checks/" 2>/dev/null | grep -oE '"[a-z][-a-z0-9]*"' | sort -u | wc -l | tr -d ' ')
  CHECKS=$((SHELL_CHECKS + NATIVE_CHECKS))
fi
echo "  ✓ checks: $CHECKS"

# --- Languages ---
LANGS=$(find "$REPO/checks/" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
echo "  ✓ languages: $LANGS"

# --- Distribution verification ---
HOMEBREW_OK=false
if curl -fsSL "https://raw.githubusercontent.com/rkristelijn/homebrew-tap/main/Formula/cpm.rb" >/dev/null 2>&1; then
  HOMEBREW_OK=true
fi
echo "  ✓ homebrew tap: $HOMEBREW_OK"

INSTALL_SH_OK=false
if curl -fsSL "https://raw.githubusercontent.com/rkristelijn/cpm/main/install.sh" >/dev/null 2>&1; then
  INSTALL_SH_OK=true
fi
echo "  ✓ install.sh reachable: $INSTALL_SH_OK"

echo ""
echo "=== Badge Values ==="
echo "  maturity:  level $LEVEL ($LEVEL_COLOR)"
echo "  tests:     $TESTS passed (brightgreen)"
echo "  checks:    $CHECKS (blue)"
echo "  languages: $LANGS (blue)"
echo "  homebrew:  $($HOMEBREW_OK && echo '✅' || echo '❌ tap not found')"
echo "  install:   $($INSTALL_SH_OK && echo '✅' || echo '❌ unreachable')"
echo ""

# --- Write to GitHub Step Summary (PR + main) ---
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  {
    echo "## 🏷️ Badge Report"
    echo ""
    echo "| Badge | Value | Status |"
    echo "|-------|-------|--------|"
    echo "| maturity | level $LEVEL (score $SCORE/100) | ✅ |"
    echo "| tests | $TESTS passed | $([ "$TESTS" -gt 0 ] && echo '✅' || echo '❌') |"
    echo "| checks | $CHECKS | $([ "$CHECKS" -gt 0 ] && echo '✅' || echo '❌') |"
    echo "| languages | $LANGS | ✅ |"
    echo "| homebrew | tap | $($HOMEBREW_OK && echo '✅' || echo '⚠️ tap not found') |"
    echo "| install.sh | curl \| bash | $($INSTALL_SH_OK && echo '✅' || echo '⚠️') |"
    echo "| Quality Gate | SonarCloud | ✅ (live) |"
    echo "| release | GitHub API | ✅ (live) |"
    echo "| downloads | GitHub API | ✅ (live) |"
    echo ""
    if $DRY_RUN; then
      echo "> **Dry run** — badges not updated. Values above show what would be written on merge."
    else
      echo "> **Live** — badges updated in README.md."
    fi
  } >>"$GITHUB_STEP_SUMMARY"
fi

# --- Dry run stops here ---
if $DRY_RUN; then
  echo "  🏷️  Dry run — no changes written."
  exit 0
fi

# --- Live: update README badges ---
echo "  📝 Updating README badges..."

# Maturity
sed -i "s|badge/maturity-level%20[0-9]-[a-z]*|badge/maturity-level%20${LEVEL}-${LEVEL_COLOR}|" "$README"

# Tests
sed -i "s|badge/tests-[0-9]*%20passed-brightgreen|badge/tests-${TESTS}%20passed-brightgreen|" "$README"

# Checks
sed -i "s|badge/checks-[0-9]*-blue|badge/checks-${CHECKS}-blue|" "$README"

# Languages
sed -i "s|badge/languages-[0-9]*-blue|badge/languages-${LANGS}-blue|" "$README"

# Make all badges clickable (link to CI)
# Only if not already linked (plain ![badge] without [![badge]])
sed -i "s|^\!\[maturity\](https://img.shields.io/badge/maturity-[^)]*)|[![maturity](https://img.shields.io/badge/maturity-level%20${LEVEL}-${LEVEL_COLOR})]($CI_URL)|" "$README"
sed -i "s|^\!\[tests\](https://img.shields.io/badge/tests-[^)]*)|[![tests](https://img.shields.io/badge/tests-${TESTS}%20passed-brightgreen)]($CI_URL)|" "$README"
sed -i "s|^\!\[checks\](https://img.shields.io/badge/checks-[^)]*)|[![checks](https://img.shields.io/badge/checks-${CHECKS}-blue)]($CI_URL)|" "$README"
sed -i "s|^\!\[languages\](https://img.shields.io/badge/languages-[^)]*)|[![languages](https://img.shields.io/badge/languages-${LANGS}-blue)]($CI_URL)|" "$README"

echo "  ✅ Done."
echo ""
echo "  Changes:"
git diff --stat "$README" 2>/dev/null || true
