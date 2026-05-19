#!/usr/bin/env bash
# checks/universal/quality/check-clean-code.sh
# Clean Code checks based on Robert C. Martin's "Clean Code"
source "$(dirname "$0")/../../../lib/shell/check.sh"
set -o nounset -o pipefail

# Find CPM lib/shell relative to this script (works from any directory)
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_CPM_LIB="$_SCRIPT_DIR/../../../lib/shell"
cpm_check_enabled "clean-code" || exit 0

REPO="${1:-.}"
FINDINGS=0
finding() { printf "  \033[33mwarning\033[0m  %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }

# Get all source files (common extensions)
SOURCE_FILES=$(find "$REPO" -type f \( -name "*.c" -o -name "*.cpp" -o -name "*.h" -o -name "*.hpp" \
  -o -name "*.js" -o -name "*.ts" -o -name "*.jsx" -o -name "*.tsx" \
  -o -name "*.py" -o -name "*.java" -o -name "*.go" -o -name "*.rs" \
  -o -name "*.php" -o -name "*.rb" -o -name "*.swift" \
  \) -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/vendor/*" 2>/dev/null)

[ -z "$SOURCE_FILES" ] && exit 0

# --- 1. Function length (>40 lines between braces) ---
LONG_FUNCS=$(grep -rn "^{" "$SOURCE_FILES" 2>/dev/null | while read -r line; do
  file="${line%%:*}"
  linenum="${line##*:}"
  linenum=$((linenum + 1))
  # Count lines until closing brace at same indentation
  indent=$(echo "$line" | sed 's/\(^{.*\)/\1/' | sed 's/[^ ].*//' | wc -c)
  indent=$((indent - 1))
  end_line=$(awk -v s="$linenum" -v i="$indent" 'NR>=s && /^'"$(printf '%*s' $indent '')"'}/ {print NR; exit}' "$file" 2>/dev/null || true)
  if [ -n "$end_line" ]; then
    length=$((end_line - linenum))
    if [ "$length" -gt 40 ]; then
      echo "$file:$linenum:$length"
    fi
  fi
done | head -10)
if [ -n "$LONG_FUNCS" ]; then
  finding "clean-code:func-length" "Function >40 lines (found $(echo "$LONG_FUNCS" | wc -l))"
fi

# --- 2. Too many function parameters (>3 params) ---
MANY_PARAMS=$(grep -rn "([^)]*," "$SOURCE_FILES" 2>/dev/null | grep -v "for (" | head -20 | while read -r line; do
  # Extract content between first ( and last )
  content=$(echo "$line" | sed 's/.*(\(.*\)).*/\1/')
  # Count commas (params = commas + 1)
  commas=$(echo "$content" | tr -cd ',' | wc -c)
  params=$((commas + 1))
  if [ "$params" -gt 3 ]; then
    echo "$line"
  fi
done)
if [ -n "$MANY_PARAMS" ]; then
  finding "clean-code:too-many-params" "Function with >3 parameters found"
fi

# --- 3. Flag arguments (boolean params) ---
FLAG_ARGS=$(grep -rn "bool \|boolean \|Boolean \|true\|false" "$SOURCE_FILES" 2>/dev/null | \
  grep "(\s*\(bool\|boolean\|Boolean\)\s*\(is[A-Z]\|has[A-Z]\|should[A-Z]\|[a-z]\+\)\s*[,)]" | head -10)
if echo "$FLAG_ARGS" | grep -q .; then
  finding "clean-code:flag-argument" "Boolean/flag argument detected — split into separate functions"
fi

# --- 4. Commented-out code blocks ---
COMMENTED_CODE=$(grep -rn "^\s*//.*\(if\|for\|while\|function\|const\|let\|var\|=\|return\)" "$SOURCE_FILES" 2>/dev/null | \
  grep -v "// cpm:ignore\|//.*http" | head -10)
if [ -n "$COMMENTED_CODE" ]; then
  finding "clean-code:commented-code" "Commented-out code found — remove dead code"
fi

# --- 5. Return null pattern ---
RETURN_NULL=$(grep -rn "return null\|return NULL\|return Nil\|return nil" "$SOURCE_FILES" 2>/dev/null | head -10)
if [ -n "$RETURN_NULL" ]; then
  finding "clean-code:return-null" "return null detected — throw exception or return Optional"
fi

# --- 6. TODO/FIXME/HACK count ---
TODO_COUNT=$(grep -rn "TODO\|FIXME\|HACK\|XXX\|BUG" "$SOURCE_FILES" 2>/dev/null | wc -l | tr -d ' ')
if [ "$TODO_COUNT" -gt 0 ]; then
  finding "clean-code:tech-debt" "$TODO_COUNT TODO/FIXME/HACK comments found"
fi

# --- 7. Deep nesting (>4 levels) ---
DEEP_NEST=$(grep -rn "^\s*\(if\|for\|while\|switch\|{\)" "$SOURCE_FILES" 2>/dev/null | \
  awk -F: '{print $2}' | sed 's/[^ ].*//' | awk '{print length}' | sort -rn | head -1)
if [ -n "$DEEP_NEST" ] && [ "$DEEP_NEST" -gt 4 ]; then
  finding "clean-code:deep-nesting" "Code nested >4 levels deep (max found: $DEEP_NEST)"
fi

# --- 8. Long lines (>120 chars) ---
LONG_LINES=$(grep -rn "^.\{121,\}" "$SOURCE_FILES" 2>/dev/null | wc -l | tr -d ' ')
if [ "$LONG_LINES" -gt 0 ]; then
  finding "clean-code:long-lines" "$LONG_LINES lines >120 characters"
fi

# --- 9. Inconsistent indentation (mixed tabs/spaces) ---
MIXED_INDENT=$(find "$REPO" -type f \( -name "*.c" -o -name "*.cpp" -o -name "*.h" -o -name "*.js" -o -name "*.py" \) \
  -not -path "*/node_modules/*" -not -path "*/.git/*" 2>/dev/null -exec grep -l $'^\t* \t*' {} \; | head -5)
if [ -n "$MIXED_INDENT" ]; then
  finding "clean-code:mixed-indent" "Mixed tabs and spaces detected — use consistent indentation"
fi

# --- 10. Empty catch blocks ---
EMPTY_CATCH=$(grep -rn "catch\s*([^)]*)\s*{\s*}" "$SOURCE_FILES" 2>/dev/null | head -10)
if [ -n "$EMPTY_CATCH" ]; then
  finding "clean-code:empty-catch" "Empty catch block — at least log the exception"
fi

# --- 11. God files (>500 lines) ---
GOD_FILES=$(find "$REPO" -type f \( -name "*.c" -o -name "*.cpp" -o -name "*.h" -o -name "*.hpp" \
  -o -name "*.js" -o -name "*.ts" -o -name "*.py" -o -name "*.java" \) \
  -not -path "*/node_modules/*" -not -path "*/.git/*" -exec wc -l {} \; 2>/dev/null | \
  awk '$1 > 500 {print $2}' | head -5)
if [ -n "$GOD_FILES" ]; then
  finding "clean-code:god-file" "File >500 lines — consider splitting (found $(echo "$GOD_FILES" | wc -l))"
fi

# --- 12. Magic numbers ---
MAGIC_NUMBERS=$(grep -rn "^\s*\(if\|for\|while\|==\|!=\|>=\|<=\|>\|<\)" "$SOURCE_FILES" 2>/dev/null | \
  grep -E " [0-9]{2,}[^0-9]" | grep -v "0x\|0b\|'\''\|//\|error\|port\|80\|443\|404\|200\|500\|1000\|365\|12\|30" | \
  head -15)
if [ -n "$MAGIC_NUMBERS" ]; then
  finding "clean-code:magic-number" "Magic numbers detected — use named constants"
fi

[ "$FINDINGS" -eq 0 ] && echo "  ✓ Clean Code patterns OK"
exit 0