#!/usr/bin/env bash
# check-modern-js.sh — Detect legacy JavaScript patterns that have modern alternatives.
#
# Checks for patterns that SonarCloud and ESLint flag as outdated:
#   - var declarations (use let/const)
#   - function keyword where arrow would suffice
#   - string concatenation (use template literals)
#   - .then() chains (use async/await)
#   - require() (use ES modules import/export)
#   - .prototype manipulation (use class syntax)
#   - arguments object (use rest params)
#   - typeof x !== 'undefined' (use optional chaining ?.)
#   - apply/call for spreading (use spread operator)
#
# Not all findings are bugs — some are intentional (e.g. require in CJS-only contexts).
# This check reports counts to track modernization progress.
#
# @see https://rules.sonarsource.com/javascript/tag/es2015
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/shell/init.sh" 2>/dev/null || true
cpm_check_enabled "modern-js" || exit 0
set -o errexit -o nounset -o pipefail

SRC="${CPM_SRC:-src}"
[ -d "$SRC" ] || exit 0

FAIL=0
TOTAL=0

count() {
  local n
  if command -v rg >/dev/null 2>&1; then
    n=$( (rg -c "$1" "$SRC" -g '*.js' -g '*.ts' -g '*.mjs' \
      -g '!*.min.js' -g '!*.bundle.js' -g '!**/node_modules/**' -g '!**/dist/**' -g '!**/vendor/**' \
      2>/dev/null || true) | awk -F: '{s+=$2}END{print s+0}')
  else
    n=$( (grep -rc "$1" "$SRC" --include='*.js' --include='*.ts' --include='*.mjs' \
      --exclude='*.min.js' --exclude-dir=node_modules --exclude-dir=dist \
      2>/dev/null || true) | awk -F: '{s+=$2}END{print s+0}')
  fi
  echo "${n:-0}"
}

report() {
  local label="$1" n="$2" severity="$3" tip="$4"
  if [ "$n" -gt 0 ]; then
    printf "  [%-4s] %4d  %s\n" "$severity" "$n" "$label"
    if [ -n "$tip" ]; then printf "         %s\n" "$tip"; fi
    TOTAL=$((TOTAL + n))
    if [ "$severity" = "fail" ]; then FAIL=1; fi
  fi
}

echo "  Scanning $SRC for legacy patterns..."
echo

# --- Critical (SonarCloud flags these) ---
n_var=$(count '\bvar\s')
report "var declarations" "$n_var" "fail" "→ let/const (eslint: no-var, prefer-const)"

# --- Major ---
n_then=$(count '\.then\(')
report ".then() chains" "$n_then" "warn" "→ async/await (eslint: prefer-await-to-then)"

n_proto=$(count '\.prototype\.')
report ".prototype manipulation" "$n_proto" "warn" "→ class syntax (eslint: no-prototype-builtins)"

n_arguments=$(count '\barguments\b')
report "arguments object" "$n_arguments" "warn" "→ rest params (...args)"

n_apply=$(count '\.(apply|call)\(')
report ".apply()/.call()" "$n_apply" "info" "→ spread operator (...)"

n_typeof=$(count "typeof [a-z].*!==? ['\"]undefined['\"]")
report "typeof undefined checks" "$n_typeof" "info" "→ optional chaining (?.) or nullish coalescing (??)"

n_concat=$(count "['\"]\s*\\+\s*[a-zA-Z]|[a-zA-Z]\s*\\+\s*['\"]")
report "string concatenation" "$n_concat" "info" "→ template literals (\`\${}\`)"

# --- Info (context-dependent) ---
n_require=$(count '\brequire\(')
report "require() (CommonJS)" "$n_require" "info" "→ import/export (if package.json type:module)"

n_function=$(count '^\s*function\b|\bfunction\s*\(')
report "function keyword" "$n_function" "info" "→ arrow functions (where this-binding allows)"

echo
if [ "$TOTAL" -eq 0 ]; then
  echo "  [pass] No legacy patterns detected — modern JS ✓"
else
  echo "  Total: $TOTAL legacy pattern(s) across all categories"
fi

exit $FAIL
