#!/usr/bin/env bash
# scripts/exports.sh — Show the public API surface of a codebase
# Usage: bash scripts/exports.sh [path] [--unused]
# Shows all exported functions, classes, types, constants
set -o nounset -o pipefail

REPO="${1:-.}"
SHOW_UNUSED=false
[[ "${2:-}" == "--unused" ]] && SHOW_UNUSED=true

EXCLUDE="node_modules|\.next|dist|build|\.git|coverage|vendor|target|__pycache__|\.test\.|\.spec\."

echo ""
echo "  ■ Public API surface: $(basename "$(cd "$REPO" && pwd)")"
echo ""

# Find source files
FILES=$(find "$REPO" -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" 2>/dev/null | grep -vE "$EXCLUDE" || true)

if [ -n "$FILES" ]; then
  # Extract all named exports
  EXPORTS=$(echo "$FILES" | xargs grep -hn "^export " 2>/dev/null |
    grep -vE "export default|export \{" |
    sed 's/.*export //' |
    grep -oE "(function|const|class|interface|type|enum|let|var)\s+[a-zA-Z_][a-zA-Z0-9_]*" |
    sort -u)

  # Group by type
  for kind in "function" "class" "interface" "type" "const" "enum"; do
    ITEMS=$(echo "$EXPORTS" | grep "^$kind " | sed "s/^$kind //" | sort)
    [ -z "$ITEMS" ] && continue
    COUNT=$(echo "$ITEMS" | wc -l | tr -d ' ')
    echo "  $kind ($COUNT):"
    echo "$ITEMS" | sed 's/^/    /' | head -15
    [ "$COUNT" -gt 15 ] && echo "    ... and $((COUNT - 15)) more"
    echo ""
  done

  # Re-exports (barrel files)
  BARRELS=$(echo "$FILES" | xargs grep -l "^export \* from\|^export {" 2>/dev/null | wc -l | tr -d ' ')
  [ "$BARRELS" -gt 0 ] && echo "  Barrel files (re-exports): $BARRELS"

  # Unused exports (exported but never imported anywhere)
  if [ "$SHOW_UNUSED" = true ]; then
    echo ""
    echo "  ■ Potentially unused exports:"
    echo "$EXPORTS" | grep -oE "[a-zA-Z_][a-zA-Z0-9_]*$" | while read -r name; do
      # Check if this name is imported anywhere
      USED=$(echo "$FILES" | xargs grep -l "import.*${name}\|require.*${name}" 2>/dev/null | wc -l | tr -d ' ')
      [ "$USED" -eq 0 ] && echo "    ⚠ $name (exported but never imported)"
    done | head -20
  fi
fi

# C/C++ header exports
H_FILES=$(find "$REPO" -name "*.h" -o -name "*.hpp" 2>/dev/null | grep -vE "$EXCLUDE" || true)
if [ -n "$H_FILES" ] && [ -z "$FILES" ]; then
  echo "  Functions (from headers):"
  echo "$H_FILES" | xargs grep -hE "^[a-zA-Z_].*\(.*\);" 2>/dev/null |
    grep -v "^#\|^//\|typedef\|^}" |
    sed 's/;$//; s/^/    /' | sort -u | head -20
  echo ""
  echo "  Structs/Types:"
  echo "$H_FILES" | xargs grep -hE "^(typedef struct|struct [A-Z]|} [A-Z])" 2>/dev/null |
    grep -oE "[A-Z][a-zA-Z0-9_]*" | sort -u | sed 's/^/    /'
fi

echo ""
