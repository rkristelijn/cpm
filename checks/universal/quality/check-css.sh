#!/usr/bin/env bash
# checks/universal/quality/check-css.sh
# @see ADR-129
# CSS anti-patterns: !important abuse, transition:all, missing reduced-motion, calc() syntax
source "$(dirname "$0")/../../../lib/shell/check.sh"
cpm_check_enabled "css-quality" || exit 0
set -o nounset -o pipefail

REPO="${1:-.}"

# Find CSS/SCSS files (skip node_modules etc via cpm_grep)
CSS_FILES=$(find "$REPO" -name "*.css" -o -name "*.scss" -o -name "*.less" 2>/dev/null | \
  grep -v "node_modules\|\.next\|dist\|build\|vendor\|\.min\." || true)
[ -z "$CSS_FILES" ] && exit 0

FINDINGS=0
finding() { printf "  \033[33mwarning\033[0m  %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }

# --- !important overuse ---
IMPORTANT_COUNT=$(echo "$CSS_FILES" | xargs grep -c "!important" 2>/dev/null | \
  awk -F: '{s+=$2} END {print s+0}')
[ "$IMPORTANT_COUNT" -gt 20 ] && finding "css-important-abuse" "$IMPORTANT_COUNT uses of !important — sign of specificity wars"

# --- transition: all (performance issue) ---
echo "$CSS_FILES" | xargs grep -l "transition.*:.*all\|transition: all" 2>/dev/null | head -1 | grep -q . && \
  finding "css-transition-all" "transition: all — specify exact properties for better performance"

# --- Animating layout properties (top/left/width/height) ---
echo "$CSS_FILES" | xargs grep -n "animation\|@keyframes" 2>/dev/null | head -1 | grep -q . && {
  LAYOUT_ANIM=$(echo "$CSS_FILES" | xargs grep -A5 "@keyframes" 2>/dev/null | \
    grep -E "^\s*(top|left|right|bottom|width|height)\s*:" | head -1 || true)
  [ -n "$LAYOUT_ANIM" ] && finding "css-animate-layout" "Animating top/left/width/height — use transform for smooth 60fps"
}

# --- No prefers-reduced-motion ---
if echo "$CSS_FILES" | xargs grep -q "animation\|@keyframes\|transition" 2>/dev/null; then
  echo "$CSS_FILES" | xargs grep -l "prefers-reduced-motion" 2>/dev/null | head -1 | grep -q . || \
    finding "css-no-reduced-motion" "Animations without @media (prefers-reduced-motion) — accessibility issue"
fi

# --- calc() without spaces around operators ---
echo "$CSS_FILES" | xargs grep -n "calc(" 2>/dev/null | \
  grep -E "calc\([^)]*[0-9]([-+])[0-9]" | head -1 | grep -q . && \
  finding "css-calc-no-spaces" "calc() without spaces around +/- — browser will ignore the expression"

# --- No box-sizing reset (check for global reset) ---
HAS_RESET=$(echo "$CSS_FILES" | xargs grep -l "box-sizing.*border-box" 2>/dev/null | head -1 || true)
[ -z "$HAS_RESET" ] && finding "css-no-box-sizing" "No box-sizing: border-box reset — padding/border will break layouts"

[ "$FINDINGS" -eq 0 ] && echo "  ✓ CSS quality OK"
exit 0
