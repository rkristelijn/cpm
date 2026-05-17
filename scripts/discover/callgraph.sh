#!/usr/bin/env bash
# scripts/callgraph.sh — Full call graph analysis: complexity, depth, custom vs standard
# Usage: bash scripts/callgraph.sh [path]
set -o nounset -o pipefail

REPO="${1:-.}"
EXCLUDE="node_modules|\.next|dist|build|\.git|coverage|vendor|target|__pycache__|\.test\.|\.spec\."

echo ""
echo "  ■ Call graph analysis: $(basename "$(cd "$REPO" && pwd)")"
echo ""

# Find all source files
FILES=$(find "$REPO" -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \
  -o -name "*.cpp" -o -name "*.c" -o -name "*.h" -o -name "*.py" -o -name "*.go" 2>/dev/null |
  grep -vE "$EXCLUDE" || true)
[ -z "$FILES" ] && {
  echo "  No source files found"
  exit 0
}

# === 1. Extract all function definitions ===
DEFS=$(echo "$FILES" | xargs grep -hnE \
  "^(export )?(async )?(function |const |let |class )[A-Za-z_]|^[a-zA-Z_*&]+ [a-zA-Z_]+\s*\(" 2>/dev/null |
  grep -vE "^.*:(import|require|from|//|/\*|\*)" |
  grep -oE "(function |const |class |async function )?[A-Za-z_][A-Za-z0-9_]*\s*[\(={]" |
  sed 's/[\(={]//; s/^\s*//; s/\s*$//' |
  grep -vE "^(if|for|while|return|switch|case|else|new|export|import|const|let|var|async|function|class|require)$" |
  sort -u)

TOTAL_DEFS=$(echo "$DEFS" | grep -c . || echo 0)

# === 2. Extract all function calls ===
CALLS=$(echo "$FILES" | xargs grep -ohE "[A-Za-z_][A-Za-z0-9_]*\s*\(" 2>/dev/null |
  sed 's/\s*($//' |
  grep -vE "^(if|for|while|return|switch|case|else|new|export|import|const|let|var|async|function|class|require|typeof|instanceof|throw|catch|try|do|super|this|console|log|warn|error|debug|info|JSON|Math|Object|Array|String|Number|Date|Promise|Set|Map|RegExp|Error|parseInt|parseFloat|setTimeout|setInterval|clearTimeout|clearInterval|fetch|alert|confirm|prompt)$" |
  sort | uniq -c | sort -rn)

TOTAL_CALLS=$(echo "$CALLS" | awk '{s+=$1} END{print s+0}')
UNIQUE_CALLS=$(echo "$CALLS" | wc -l | tr -d ' ')

# === 3. Identify custom vs standard/library calls ===
CUSTOM_CALLS=$(echo "$CALLS" | while read -r count name; do
  echo "$DEFS" | grep -qx "$name" && echo "$count $name"
done)
CUSTOM_COUNT=$(echo "$CUSTOM_CALLS" | awk '{s+=$1} END{print s+0}')
STDLIB_COUNT=$((TOTAL_CALLS - CUSTOM_COUNT))

# === 4. Most called functions (hotspots) ===
echo "  Metrics:"
printf "    Functions defined:    %d\n" "$TOTAL_DEFS"
printf "    Total call sites:    %d\n" "$TOTAL_CALLS"
printf "    Unique functions:    %d\n" "$UNIQUE_CALLS"
echo ""

# Custom vs standard ratio
if [ "$TOTAL_CALLS" -gt 0 ]; then
  CUSTOM_PCT=$((CUSTOM_COUNT * 100 / TOTAL_CALLS))
  STDLIB_PCT=$((100 - CUSTOM_PCT))
  echo "  Composition:"
  printf "    Custom code calls:   %d (%d%%)\n" "$CUSTOM_COUNT" "$CUSTOM_PCT"
  printf "    Library/stdlib calls: %d (%d%%)\n" "$STDLIB_COUNT" "$STDLIB_PCT"
  echo ""
  if [ "$CUSTOM_PCT" -gt 70 ]; then
    echo "    → Highly custom codebase (bespoke logic dominates)"
  elif [ "$CUSTOM_PCT" -gt 40 ]; then
    echo "    → Balanced (mix of custom logic and library usage)"
  else
    echo "    → Framework-heavy (relies heavily on libraries/stdlib)"
  fi
fi
echo ""

# === 5. Most called custom functions (internal hotspots) ===
echo "  Top internal hotspots (most called custom functions):"
echo "$CUSTOM_CALLS" | sort -rn | head -10 | while read -r count name; do
  [ -z "$name" ] && continue
  printf "    %4d calls  %s\n" "$count" "$name"
done
echo ""

# === 6. Fan-out (functions that call the most other functions) ===
echo "  Fan-out (most complex functions — call many others):"
echo "$FILES" | while read -r file; do
  grep -hnE "^(export )?(async )?(function |const )[A-Za-z_]|^[a-zA-Z_*&]+ [a-zA-z_]+\s*\(" "$file" 2>/dev/null |
    grep -vE "import|require" | while IFS=: read -r line content; do
    fname=$(echo "$content" | grep -oE "[A-Za-z_][A-Za-z0-9_]*\s*[\(=]" | head -1 | sed 's/[\(=]//')
    [ -z "$fname" ] && continue
    BODY=$(tail -n +"$line" "$file" | head -40)
    FANOUT=$(echo "$BODY" | grep -oE "[A-Za-z_][A-Za-z0-9_]*\s*\(" | sed 's/\s*($//' | sort -u | wc -l | tr -d ' ')
    [ "$FANOUT" -gt 6 ] && printf "%d %s (%s)\n" "$FANOUT" "$fname" "$(basename "$file")"
  done
done | sort -rn | head -8 | while read -r fanout rest; do
  printf "    %2d calls → %s\n" "$fanout" "$rest"
done
echo ""

# === 7. Orphan functions (defined but never called) ===
ORPHANS=$(echo "$DEFS" | while read -r name; do
  [ -z "$name" ] && continue
  echo "$CALLS" | grep -qw "$name" || echo "$name"
done | head -10)
ORPHAN_COUNT=$(echo "$ORPHANS" | grep -c "." 2>/dev/null || echo 0)
echo "  Orphan functions (defined, never called internally): ~$ORPHAN_COUNT"
[ "$ORPHAN_COUNT" -gt 0 ] && echo "$ORPHANS" | head -8 | sed 's/^/    /'
echo ""
