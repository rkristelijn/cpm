#!/usr/bin/env bash
# scripts/git-timeline.sh — Visual commit activity timeline (ASCII bar chart)
# Usage: bash scripts/git-timeline.sh [path]
set -o nounset -o pipefail

REPO="${1:-.}"
cd "$REPO" || exit 1
git rev-parse --git-dir >/dev/null 2>&1 || {
  echo "  Not a git repo"
  exit 0
}

echo ""
echo "  ■ Commit Timeline: $(basename "$(pwd)")"
echo ""

# Get monthly commit counts for the last 24 months
git log --format="%ad" --date=format:"%Y-%m" 2>/dev/null | sort | uniq -c | tail -24 |
  while read -r count month; do
    # Scale bar: 1 char per 2 commits, max 40
    BAR_LEN=$((count / 2))
    [ "$BAR_LEN" -gt 40 ] && BAR_LEN=40
    [ "$BAR_LEN" -eq 0 ] && [ "$count" -gt 0 ] && BAR_LEN=1
    BAR=$(printf '%*s' "$BAR_LEN" '' | tr ' ' '█')
    printf "    %s │%s %s\n" "$month" "$BAR" "$count"
  done

echo ""
# Gaps detection
echo "  Gaps (months with 0 commits):"
FIRST=$(git log --reverse --format="%ad" --date=format:"%Y-%m" | head -1)
LAST=$(git log -1 --format="%ad" --date=format:"%Y-%m")
# Generate all months between first and last, find gaps
ALL_MONTHS=$(git log --format="%ad" --date=format:"%Y-%m" | sort -u)
CURRENT="$FIRST"
GAPS=0
while [[ "$CURRENT" < "$LAST" ]] || [[ "$CURRENT" == "$LAST" ]]; do
  echo "$ALL_MONTHS" | grep -q "^$CURRENT$" || {
    printf "    · %s (no commits)\n" "$CURRENT"
    GAPS=$((GAPS + 1))
  }
  # Increment month
  YEAR=${CURRENT%-*}
  MONTH=${CURRENT#*-}
  MONTH=$((10#$MONTH + 1))
  [ "$MONTH" -gt 12 ] && MONTH=1 && YEAR=$((YEAR + 1))
  CURRENT=$(printf "%d-%02d" "$YEAR" "$MONTH")
  [ "$GAPS" -gt 10 ] && echo "    ... (more gaps)" && break
done
[ "$GAPS" -eq 0 ] && echo "    ✓ No gaps — continuous development"
echo ""
