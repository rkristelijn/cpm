#!/usr/bin/env bash
# scripts/doc-quality.sh — Analyze documentation quality: freshness, coverage, dead links
# Usage: bash scripts/doc-quality.sh [path]
set -o nounset -o pipefail

REPO="${1:-.}"
EXCLUDE="node_modules|\.next|dist|build|\.git|coverage|vendor|target"

echo ""
echo "  ■ Documentation Quality: $(basename "$(cd "$REPO" && pwd)")"
echo ""

# Find source and doc files
SRC_FILES=$(find "$REPO" -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \
  -o -name "*.cpp" -o -name "*.c" -o -name "*.h" -o -name "*.py" -o -name "*.go" 2>/dev/null |
  grep -vE "$EXCLUDE|\.test\.|\.spec\." || true)
MD_FILES=$(find "$REPO" -name "*.md" 2>/dev/null | grep -vE "$EXCLUDE" || true)

# === 1. Documentation presence ===
echo "  Presence:"
[ -f "$REPO/README.md" ] && printf "    ✓ README.md (%s lines)\n" "$(wc -l <"$REPO/README.md" | tr -d ' ')" || echo "    · No README.md"
[ -f "$REPO/CONTRIBUTING.md" ] && echo "    ✓ CONTRIBUTING.md" || echo "    · No CONTRIBUTING.md"
[ -f "$REPO/CHANGELOG.md" ] && echo "    ✓ CHANGELOG.md" || echo "    · No CHANGELOG.md"
[ -d "$REPO/docs" ] && printf "    ✓ docs/ (%s files)\n" "$(find "$REPO/docs" -type f | wc -l | tr -d ' ')" || echo "    · No docs/ folder"
MD_COUNT=$(echo "$MD_FILES" | grep -c "." 2>/dev/null || echo 0)
printf "    Total markdown files: %s\n" "$MD_COUNT"
echo ""

# === 2. Comment-to-code ratio ===
echo "  Comment Ratio:"
if [ -n "$SRC_FILES" ]; then
  TOTAL_LINES=$(echo "$SRC_FILES" | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}')
  COMMENT_LINES=$(echo "$SRC_FILES" | xargs grep -c "^\s*//\|^\s*/\*\|^\s*\*\|^\s*#" 2>/dev/null | awk -F: '{s+=$2} END{print s+0}')
  if [ "${TOTAL_LINES:-0}" -gt 0 ]; then
    PCT=$((COMMENT_LINES * 100 / TOTAL_LINES))
    printf "    %s comment lines / %s total (%s%%)\n" "$COMMENT_LINES" "$TOTAL_LINES" "$PCT"
    [ "$PCT" -lt 5 ] && echo "    ⚠ Very low (<5%) — complex logic likely undocumented"
    [ "$PCT" -gt 40 ] && echo "    ⚠ Very high (>40%) — code may be unclear, compensating with comments"
  fi
fi
echo ""

# === 3. JSDoc/Docstring coverage ===
echo "  API Documentation (JSDoc/Docstrings):"
if [ -n "$SRC_FILES" ]; then
  FUNCS=$(echo "$SRC_FILES" | xargs grep -c "^export function\|^export async function\|^export class\|^def \|^func " 2>/dev/null | awk -F: '{s+=$2} END{print s+0}')
  DOCUMENTED=$(echo "$SRC_FILES" | xargs grep -B1 "^export function\|^export async function\|^export class" 2>/dev/null | grep -c "/\*\*\|///" || echo 0)
  if [ "${FUNCS:-0}" -gt 0 ]; then
    DOC_PCT=$((DOCUMENTED * 100 / FUNCS))
    printf "    Exported functions/classes: %s\n" "$FUNCS"
    printf "    With JSDoc/docstring:       %s (%s%%)\n" "$DOCUMENTED" "$DOC_PCT"
    [ "$DOC_PCT" -lt 20 ] && echo "    ⚠ Most public API is undocumented"
  fi
fi
echo ""

# === 4. Stale documentation (docs not updated when code changes) ===
echo "  Freshness (stale docs detection):"
if [ -d "$REPO/.git" ] || git -C "$REPO" rev-parse 2>/dev/null; then
  # Find docs that haven't been touched in 6+ months but related code has
  STALE=0
  for md in $(echo "$MD_FILES" | head -20); do
    [ -z "$md" ] && continue
    MD_AGE=$(git -C "$REPO" log -1 --format="%at" -- "$md" 2>/dev/null || echo 0)
    NOW=$(date +%s)
    DAYS_OLD=$(((NOW - MD_AGE) / 86400))
    [ "$DAYS_OLD" -gt 180 ] && {
      STALE=$((STALE + 1))
      [ "$STALE" -le 5 ] && printf "    ⚠ %s (%s days old)\n" "$(echo "$md" | sed "s|$REPO/||")" "$DAYS_OLD"
    }
  done
  [ "$STALE" -gt 5 ] && printf "    ... and %s more stale docs\n" "$((STALE - 5))"
  [ "$STALE" -eq 0 ] && echo "    ✓ All docs updated within 6 months"
fi
echo ""

# === 5. Dead links in markdown ===
echo "  Dead Links (broken references):"
DEAD_LINKS=0
if [ -n "$MD_FILES" ]; then
  # Check relative file links
  echo "$MD_FILES" | head -20 | while read -r md; do
    [ -z "$md" ] && continue
    DIR=$(dirname "$md")
    grep -oE "\]\([^)]+\)" "$md" 2>/dev/null | grep -v "http\|#\|mailto:" | sed 's/\](//;s/)//' | while read -r link; do
      [ -z "$link" ] && continue
      TARGET="$DIR/$link"
      [ ! -e "$TARGET" ] && [ ! -e "$REPO/$link" ] && printf "    ✗ %s → %s\n" "$(basename "$md")" "$link" && DEAD_LINKS=$((DEAD_LINKS + 1))
    done
  done | head -8
fi
echo ""

# === 6. Useless comments (noise) ===
echo "  Comment Quality:"
if [ -n "$SRC_FILES" ]; then
  # Comments that just repeat the code
  NOISE=$(echo "$SRC_FILES" | xargs grep -n "// \(set\|get\|return\|increment\|decrement\|initialize\|init\|constructor\|create\|delete\|update\|import\)" 2>/dev/null | wc -l | tr -d ' ')
  printf "    Likely noise comments (repeat code): ~%s\n" "$NOISE"
  [ "$NOISE" -gt 20 ] && echo "    ⚠ Many comments just describe what code does, not why"

  # TODO/FIXME as documentation debt
  TODOS=$(echo "$SRC_FILES" | xargs grep -c "TODO\|FIXME\|HACK\|XXX" 2>/dev/null | awk -F: '{s+=$2} END{print s+0}')
  printf "    TODO/FIXME markers: %s\n" "$TODOS"
fi
echo ""
