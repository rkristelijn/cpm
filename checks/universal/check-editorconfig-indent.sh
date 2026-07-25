#!/usr/bin/env bash
# =============================================================================
# check-editorconfig-indent.sh — Enforce .editorconfig indent rules
# NOTE: --fix uses brace-counting to re-indent (requires node).
#
# Reads indent_style and indent_size from .editorconfig and validates all
# source files. Supports --fix to auto-correct.
#
# Part of cpm universal checks.
# =============================================================================

set -o pipefail

FIX=false
[[ "${1:-}" == "--fix" ]] && FIX=true

# Parse .editorconfig
if [[ ! -f .editorconfig ]]; then
  echo "  ⊘ No .editorconfig found"
  exit 0
fi

INDENT_STYLE=$(grep -m1 "^indent_style" .editorconfig | awk -F= '{print $2}' | tr -d ' ')
INDENT_SIZE=$(grep -m1 "^indent_size" .editorconfig | awk -F= '{print $2}' | tr -d ' ')

if [[ -z "$INDENT_STYLE" ]] || [[ -z "$INDENT_SIZE" ]]; then
  echo "  ⊘ .editorconfig missing indent_style or indent_size"
  exit 0
fi

# Source file extensions to check
EXTENSIONS="js,ts,jsx,tsx,py,java,css,html,json,yaml,yml"
ISSUES=0
FIXED=0

# Build find pattern
FIND_PATTERN=""
IFS=',' read -ra EXTS <<< "$EXTENSIONS"
for ext in "${EXTS[@]}"; do
  [[ -n "$FIND_PATTERN" ]] && FIND_PATTERN="$FIND_PATTERN -o"
  FIND_PATTERN="$FIND_PATTERN -name \"*.$ext\""
done

while IFS= read -r file; do
  [[ -f "$file" ]] || continue

  if [[ "$INDENT_STYLE" == "space" ]]; then
    # Check for tabs (should be spaces)
    if grep -qP "^\t" "$file"; then
      if $FIX; then
        sed -i "s/\t/$(printf '%*s' "$INDENT_SIZE" '')/" "$file"
        FIXED=$((FIXED + 1))
      else
        echo "  ✗ $file: contains tabs (expected spaces)"
        ISSUES=$((ISSUES + 1))
      fi
    fi

    # Check for wrong indent size (e.g., 4 spaces when 2 expected)
    WRONG_SIZE=$(grep -cP "^( {$((INDENT_SIZE * 2))})[^ ]" "$file" 2>/dev/null | tr -d '\n' || echo "0")
    if [[ "$INDENT_SIZE" == "2" ]] && [[ "$WRONG_SIZE" -gt 3 ]]; then
      if $FIX; then
        # Re-indent using brace-counting (no heuristic, structurally correct)
        node -e "
          const fs = require('fs');
          const lines = fs.readFileSync('$file', 'utf-8').split('\n');
          let level = 0;
          const SIZE = $INDENT_SIZE;
          const out = lines.map(line => {
            const trimmed = line.trim();
            if (!trimmed) return '';
            if (trimmed.match(/^[}\])/)) level = Math.max(0, level - 1);
            const result = ' '.repeat(level * SIZE) + trimmed;
            const opens = (trimmed.match(/[{(\[]\s*$/g) || []).length;
            const closes = (trimmed.match(/^[})\]]/g) || []).length;
            if (trimmed.match(/[{(\[]\s*$/)) level++;
            return result;
          });
          fs.writeFileSync('$file', out.join('\n'));
        " 2>/dev/null
        FIXED=$((FIXED + 1))
      else
        echo "  ✗ $file: $WRONG_SIZE lines appear to use $((INDENT_SIZE * 2))-space indent (expected $INDENT_SIZE)"
        ISSUES=$((ISSUES + 1))
      fi
    fi
  fi

  if [[ "$INDENT_STYLE" == "tab" ]]; then
    # Check for spaces at line start (should be tabs)
    if grep -qP "^ " "$file"; then
      if $FIX; then
        sed -i "s/^  /\t/g" "$file"
        FIXED=$((FIXED + 1))
      else
        echo "  ✗ $file: contains space indent (expected tabs)"
        ISSUES=$((ISSUES + 1))
      fi
    fi
  fi

done < <(eval "find . -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/lib/*' -not -path '*/vendor/*' -not -path '*/dist/*' \( $FIND_PATTERN \)" 2>/dev/null)

if $FIX; then
  echo "  ✓ Fixed $FIXED file(s) to ${INDENT_STYLE} (size=${INDENT_SIZE})"
else
  if [[ $ISSUES -gt 0 ]]; then
    echo ""
    echo "  $ISSUES file(s) violate .editorconfig (indent_style=$INDENT_STYLE, indent_size=$INDENT_SIZE)"
    echo "  Run with --fix to auto-correct."
    exit 1
  else
    echo "  ✓ All files match .editorconfig indent rules"
  fi
fi
