#!/usr/bin/env bash
# cpm:ignore-file SH-QUAL-014 — detector/test source: contains the patterns it checks for
# check-no-var.sh — Detect 'var' declarations (ES6+ should use let/const).
#
# Why no autofix by default: var has function scope, let/const have block scope.
# Blind replacement can break hoisting, closures in loops, and global access.
#
# With --fix --force: applies autofix via biome/eslint, then runs tests to verify.
# If tests fail, the fix is reverted automatically.
#
# Severity: critical (matches SonarCloud no-var rule)
# @see https://rules.sonarsource.com/javascript/RSPEC-3504
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/shell/init.sh" 2>/dev/null || true
cpm_check_enabled "no-var" || exit 0
set -o errexit -o nounset -o pipefail

SRC="${CPM_SRC:-src}"
[ -d "$SRC" ] || exit 0

FIX=false
FORCE=false
for arg in "$@"; do
  case "$arg" in
    --fix) FIX=true ;;
    --force) FORCE=true ;;
  esac
done

PATTERN='\bvar\s'

# Count var declarations
if command -v rg >/dev/null 2>&1; then
  count=$( (rg -c "$PATTERN" "$SRC" -g '*.js' -g '*.ts' -g '*.mjs' 2>/dev/null || true) \
    | awk -F: '{s+=$2}END{print s+0}')
else
  count=$( (grep -rc "$PATTERN" "$SRC" --include='*.js' --include='*.ts' --include='*.mjs' 2>/dev/null || true) \
    | awk -F: '{s+=$2}END{print s+0}')
fi

if [ "${count:-0}" -eq 0 ]; then
  echo "  [pass] no var declarations found"
  exit 0
fi

echo "  [fail] $count var declaration(s) — use let or const"
echo
echo "  Top files:"
if command -v rg >/dev/null 2>&1; then
  (rg -c "$PATTERN" "$SRC" -g '*.js' -g '*.ts' -g '*.mjs' 2>/dev/null || true) \
    | sort -t: -k2 -nr | head -10 | sed 's/^/    /'
else
  (grep -rc "$PATTERN" "$SRC" --include='*.js' --include='*.ts' --include='*.mjs' 2>/dev/null || true) \
    | grep -v ':0$' | sort -t: -k2 -nr | head -10 | sed 's/^/    /'
fi

# --- Fix mode ---
if [ "$FIX" = true ]; then
  if [ "$FORCE" = false ]; then
    echo
    echo "  [skip] --fix requires --force (autofix may change semantics)"
    echo "  Usage: $0 --fix --force"
    exit 1
  fi

  echo
  echo "  Applying fix..."

  # Detect available fixer
  FIXER=""
  if [ -f "biome.json" ] || [ -f "biome.jsonc" ]; then
    if command -v biome >/dev/null 2>&1 || npx biome --version >/dev/null 2>&1; then
      FIXER="biome"
    fi
  fi
  if [ -z "$FIXER" ] && ([ -f ".eslintrc.js" ] || [ -f ".eslintrc.json" ] || [ -f "eslint.config.js" ]); then
    FIXER="eslint"
  fi

  if [ -z "$FIXER" ]; then
    echo "  [error] No linter config found (biome.json or .eslintrc*). Cannot autofix."
    exit 1
  fi

  # Snapshot for rollback
  STASH_MSG="cpm-no-var-fix-$(date +%s)"
  git stash push -m "$STASH_MSG" --quiet 2>/dev/null && STASHED=true || STASHED=false

  # Apply fix
  if [ "$FIXER" = "biome" ]; then
    echo "  Using biome..."
    npx biome check --fix --unsafe "$SRC" 2>/dev/null || true
  else
    echo "  Using eslint..."
    npx eslint --fix --rule '{"no-var":"error","prefer-const":"error"}' "$SRC" 2>/dev/null || true
  fi

  # Verify with tests
  echo "  Running tests to verify..."
  TEST_CMD=""
  if [ -f "package.json" ]; then
    TEST_CMD=$(python3 -c "import json;d=json.load(open('package.json'));print(d.get('scripts',{}).get('test',''))" 2>/dev/null || true)
  fi
  if [ -f "Makefile" ] && grep -q '^test:' Makefile 2>/dev/null; then
    TEST_CMD="make test"
  fi

  if [ -z "$TEST_CMD" ]; then
    echo "  [warn] No test command found — fix applied but NOT verified"
    exit 0
  fi

  if eval "$TEST_CMD" >/dev/null 2>&1; then
    echo "  [pass] Tests pass — fix applied successfully"

    # Recount
    if command -v rg >/dev/null 2>&1; then
      new_count=$( (rg -c "$PATTERN" "$SRC" -g '*.js' -g '*.ts' -g '*.mjs' 2>/dev/null || true) \
        | awk -F: '{s+=$2}END{print s+0}')
    else
      new_count=$( (grep -rc "$PATTERN" "$SRC" --include='*.js' --include='*.ts' --include='*.mjs' 2>/dev/null || true) \
        | awk -F: '{s+=$2}END{print s+0}')
    fi
    echo "  Fixed: $count → ${new_count:-0} var declaration(s) remaining"
  else
    echo "  [fail] Tests failed — reverting fix"
    git checkout -- "$SRC" 2>/dev/null || true
    if [ "$STASHED" = true ]; then
      git stash pop --quiet 2>/dev/null || true
    fi
    exit 1
  fi

  exit 0
fi

echo
echo "  Tip: $0 --fix --force (applies biome/eslint fix, reverts if tests fail)"

exit 1
