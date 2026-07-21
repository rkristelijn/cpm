#!/usr/bin/env bash
# =============================================================================
# check-grep-inversion.sh — Detect bare grep|head pipes in check definitions
#
# Antipattern: grep ... | head -N
#   grep returns exit 1 when no match, but piped head always returns exit 0.
#   This means cpm sees exit 0 (= pass) even when grep found nothing.
#   For "forbidden pattern" checks, this inverts the logic.
#
# Correct pattern:
#   OUT=$(grep ... | head -5); [ -n "$OUT" ] && echo "$OUT" && exit 1 || true
#
# Usage: bash check-grep-inversion.sh [path-to-checks.cpp]
# =============================================================================

set -euo pipefail

SRC="${1:-src/checks.cpp}"

if [[ ! -f "$SRC" ]]; then
  echo "  SKIP: $SRC not found"
  exit 0
fi

FINDINGS=0

# Find lines ending with: head -N", (bare pipe to head without exit logic)
# These are the end of multi-line check command strings
while IFS= read -r match; do
  line_num=$(echo "$match" | cut -d: -f1)
  line=$(echo "$match" | cut -d: -f2-)

  # Skip if the check already uses the OUT=$(...) pattern (look back a few lines)
  context=$(sed -n "$((line_num > 3 ? line_num - 3 : 1)),${line_num}p" "$SRC")
  if echo "$context" | grep -q 'OUT=\$\|exit 1'; then
    continue
  fi

  # This is the antipattern
  echo "  ✗ Line $line_num: bare grep|head pipe (exit code always 0)"
  echo "    $line"
  echo "    Fix: wrap in OUT=\$(...); [ -n \"\$OUT\" ] && echo \"\$OUT\" && exit 1 || true"
  echo ""
  FINDINGS=$((FINDINGS + 1))
done < <(grep -n 'head -[0-9]*",$' "$SRC" 2>/dev/null || true)

if [[ $FINDINGS -eq 0 ]]; then
  echo "  ✓ No bare grep|head antipatterns found"
  exit 0
else
  echo "  $FINDINGS bare grep|head pipe(s) found — these always return exit 0"
  exit 1
fi
