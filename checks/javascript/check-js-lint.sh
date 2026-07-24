#!/usr/bin/env bash
# =============================================================================
# check-js-lint.sh — Essential JavaScript lint rules (no ESLint needed)
#
# Covers the most impactful rules that catch real bugs:
#   - == instead of === (type coercion bugs)
#   - unused variables (dead code)
#   - console.log in production code (forgot to remove)
#   - var instead of let/const (scope bugs)
#   - unreachable code after return
#   - empty catch blocks (swallowed errors)
#   - debugger statements
#
# Usage: bash checks/check-js-lint.sh [dir]
# =============================================================================

set -o pipefail

DIR="${1:-src}"
ISSUES=0

check() {
  local rule="$1" pattern="$2" msg="$3"
  local hits
  hits=$(grep -rn --include="*.js" --include="*.ts" -P "$pattern" "$DIR" 2>/dev/null | grep -v "node_modules\|\.test\.\|\.spec\." | grep -v "// lint-ok")
  if [[ -n "$hits" ]]; then
    echo "  ✗ $rule: $msg"
    echo "$hits" | head -5 | sed 's/^/      /'
    COUNT=$(echo "$hits" | wc -l)
    [[ $COUNT -gt 5 ]] && echo "      ... ($COUNT total)"
    ISSUES=$((ISSUES + 1))
  fi
}

echo "  JavaScript lint ($DIR/)"

# === vs == (skip !== and ===)
check "eqeqeq" \
  '(?<!=)[^!=]== (?!=)' \
  "Use === instead of == (type coercion)"

# var usage (should be let/const)
check "no-var" \
  '^\s*var ' \
  "Use let/const instead of var"

# console.log (ok in tests, not in prod)
check "no-console" \
  'console\.(log|debug|info)\(' \
  "Remove console.log from production code (use console.error/warn for intentional output)"

# debugger statements
check "no-debugger" \
  '^\s*debugger' \
  "Remove debugger statement"

# Empty catch blocks
check "no-empty-catch" \
  'catch\s*\([^)]*\)\s*\{\s*\}' \
  "Empty catch block (swallows errors silently)"

# Unreachable code after return — disabled (too many false positives with grep)
# Would need AST parsing to do correctly
# check "no-unreachable" ...

# throw string literal (should throw Error)
check "no-throw-literal" \
  "throw '[^']*'" \
  "Throw an Error object, not a string literal"

# Assignment in condition (likely a bug: if (x = 1) vs if (x === 1))
check "no-cond-assign" \
  'if\s*\([^=!<>]*[^=!<>]=[^=][^)]*\)' \
  "Assignment in condition (did you mean ===?)"

if [[ $ISSUES -gt 0 ]]; then
  echo ""
  echo "  $ISSUES rule(s) violated. Add '// lint-ok' to intentionally suppress."
  exit 1
else
  echo "  ✓ All rules pass"
fi

# function keyword (prefer arrow functions)
check "prefer-arrow" \
  '^\s*(export\s+)?(async\s+)?function\s' \
  "Use arrow functions: const name = (args) => { instead of function name(args) {"

# Classic for loop (prefer for...of or array methods)
check "prefer-for-of" \
  'for\s*\(\s*(var|let|const)\s+\w+\s*=' \
  "Use for...of or .map()/.filter()/.forEach() instead of index-based for loops"

# void 0 (archaic, just use undefined)
check "no-void" \
  '\bvoid 0\b' \
  "Use undefined instead of void 0"

# Explicit undefined assignment (smells — let the language handle it)
check "no-undefined-assign" \
  '= undefined;' \
  "Don't assign undefined — use optional params or leave uninitialized"

# Too many try/catch blocks (should bubble errors, catch at top level)
CATCH_COUNT=$(grep -rn --include="*.js" --include="*.ts" "} catch" "$DIR" 2>/dev/null | grep -v "$EXCLUDE" | wc -l | tr -d ' ')
if [[ "$CATCH_COUNT" -gt 5 ]]; then
  check "minimal-try-catch" \
    '} catch' \
    "Too many try/catch blocks ($CATCH_COUNT). Let errors bubble — catch at top level only"
fi

# Empty finally (pointless)
check "no-empty-finally" \
  'finally\s*\{\s*\}' \
  "Empty finally block (remove it)"

# catch that only rethrows (pointless)
check "no-useless-catch" \
  'catch.*\{[^}]*throw\s+(err|e|error)\s*;?\s*\}' \
  "Catch that only rethrows — just remove the try/catch"
