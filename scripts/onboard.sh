#!/usr/bin/env bash
# scripts/onboard.sh — Instant codebase understanding in one command
# Usage: bash scripts/onboard.sh [path]
# Combines: overview + howtorun + tree + exports into one onboarding report
set -o nounset -o pipefail

REPO="${1:-.}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo "  ╔═══════════════════════════════════════════════════╗"
echo "  ║     cpm onboard — understand any codebase        ║"
echo "  ╚═══════════════════════════════════════════════════╝"

# 1. Overview
bash "$SCRIPT_DIR/overview.sh" "$REPO"

# 2. How to run
bash "$SCRIPT_DIR/howtorun.sh" "$REPO"

# 3. Tree (depth 2, with details)
echo "  ■ Project tree"
echo ""
bash "$SCRIPT_DIR/tree.sh" "$REPO" --depth 2 --details 2>/dev/null | head -30
echo ""

# 4. Public API
bash "$SCRIPT_DIR/exports.sh" "$REPO" 2>/dev/null | head -30

# 5. Quick health check
echo "  ■ Quick health"
ISSUES=0
[ -f "$REPO/README.md" ] || {
  echo "    ⚠ No README.md"
  ISSUES=$((ISSUES + 1))
}
[ -f "$REPO/LICENSE" ] || [ -f "$REPO/LICENSE.md" ] || {
  echo "    ⚠ No LICENSE"
  ISSUES=$((ISSUES + 1))
}
[ -f "$REPO/.gitignore" ] || {
  echo "    ⚠ No .gitignore"
  ISSUES=$((ISSUES + 1))
}
if [ -f "$REPO/package.json" ]; then
  grep -q '"test"' "$REPO/package.json" || {
    echo "    ⚠ No test script"
    ISSUES=$((ISSUES + 1))
  }
  grep -q '"lint"' "$REPO/package.json" || {
    echo "    ⚠ No lint script"
    ISSUES=$((ISSUES + 1))
  }
fi
[ "$ISSUES" -eq 0 ] && echo "    ✓ Basics covered"
echo ""

# 6. Next steps
echo "  ■ Next steps"
echo "    1. bash scripts/howtorun.sh $REPO    # install & run it"
echo "    2. bash scripts/tree.sh $REPO --depth 3 --details"
echo "    3. bash scripts/trace.sh <function> $REPO"
echo "    4. bash scripts/classdiagram.sh $REPO/src"
echo ""
