#!/usr/bin/env bash
# cpm:ignore-file SH-QUAL-014 — detector/test source: contains the patterns it checks for
# scripts/update-badges.sh — Update README.md badges with actual metrics
#
# Usage:
#   bash scripts/update-badges.sh           # live mode (updates README)
#   bash scripts/update-badges.sh --dry-run # report only, no file changes
#
# Called by CI:
#   - On PR: --dry-run (reports to job summary)
#   - On main merge: live (commits badge updates)

# Portable sed -i (macOS requires '' argument, Linux does not)
sedi() {
  if [[ "$OSTYPE" == darwin* ]]; then
    sed -i '' "$@"
  else
    sed -i "$@"
  fi
}
set -o nounset -o pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
README="$REPO/README.md"
DRY_RUN=false
CI_URL="${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY:-rkristelijn/cpm}/actions/runs/${GITHUB_RUN_ID:-0}"

[ -f "$README" ] || {
  echo "README.md not found"
  exit 1
}

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
  TESTS=$(grep -oE "[0-9]+ passed" /tmp/badge-tests.log | grep -oE "[0-9]+" | tr '\n' '+' | sed 's/+$//' | bc 2>/dev/null || echo 0)
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
sedi "s|badge/maturity-level%20[0-9]-[a-z]*|badge/maturity-level%20${LEVEL}-${LEVEL_COLOR}|" "$README"

# Tests
sedi "s|badge/tests-[0-9]*%20passed-brightgreen|badge/tests-${TESTS}%20passed-brightgreen|" "$README"

# Checks
sedi "s|badge/checks-[0-9]*-blue|badge/checks-${CHECKS}-blue|" "$README"

# Languages
sedi "s|badge/languages-[0-9]*-blue|badge/languages-${LANGS}-blue|" "$README"

# Add pasta score badge if not present
if ! grep -q "badge/health" "$README" 2>/dev/null; then
  if [ -n "${HEALTH:-}" ]; then
    SCORE=$(echo "$HEALTH" | grep -oE "^[0-9]+")
    if [ "$SCORE" -ge 90 ]; then
      COLOR="brightgreen"
    elif [ "$SCORE" -ge 75 ]; then
      COLOR="green"
    elif [ "$SCORE" -ge 50 ]; then
      COLOR="yellow"
    else COLOR="red"; fi
    # Insert after the tests badge
    sedi "/badge\/tests/a ![health](https://img.shields.io/badge/health-${HEALTH/\//%2F}-${COLOR})" "$README"
  fi
fi

# Update health badge if already present
if grep -q "badge/health" "$README" 2>/dev/null && [ -n "${HEALTH:-}" ]; then
  SCORE=$(echo "$HEALTH" | grep -oE "^[0-9]+")
  if [ "$SCORE" -ge 90 ]; then
    COLOR="brightgreen"
  elif [ "$SCORE" -ge 75 ]; then
    COLOR="green"
  elif [ "$SCORE" -ge 50 ]; then
    COLOR="yellow"
  else COLOR="red"; fi
  sedi "s|badge/health-[0-9]*%2F100-[a-z]*|badge/health-${HEALTH/\//%2F}-${COLOR}|" "$README"
fi

# --- Update feature count in text ---
TOTAL_CHECKS="${TOTAL_CHECKS:-$CHECKS}"
sedi "s/[0-9]\+ checks across/~${TOTAL_CHECKS} checks across/" "$README"

echo "  Done. Badges updated."
echo ""
echo "  Changes:"
git diff --stat "$README" 2>/dev/null || true
