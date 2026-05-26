#!/usr/bin/env bash
# check-arrow-safety.sh — Detect unsafe arrow function patterns.
#
# Arrow functions do NOT have their own:
#   - arguments object (inherits from outer scope → silent bugs)
#   - this binding (cannot be used as constructors)
#
# This check catches code where biome/eslint converted function→arrow
# but left behind `arguments` usage, causing runtime failures.
#
# @see https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Functions/Arrow_functions
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/shell/init.sh" 2>/dev/null || true
cpm_check_enabled "arrow-safety" || exit 0
set -o errexit -o nounset -o pipefail

SRC="${CPM_SRC:-src}"
[ -d "$SRC" ] || exit 0

FAIL=0

# Pattern: files using `arguments` without any `function` keyword
# If a file only has arrow functions but uses `arguments`, it's a bug.
# Files with `function` keywords likely use arguments correctly inside those.
if command -v rg >/dev/null 2>&1; then
  args_files=$(rg -l 'arguments' "$SRC" \
    -g '*.js' -g '*.ts' -g '*.mjs' -g '!*.min.js' -g '!**/node_modules/**' \
    -g '!**/test/**' -g '!**/*.test.*' \
    2>/dev/null || true)
else
  args_files=$(grep -rl 'arguments' "$SRC" \
    --include='*.js' --include='*.ts' --include='*.mjs' \
    --exclude='*.min.js' --exclude-dir=node_modules --exclude-dir=test \
    2>/dev/null || true)
fi

if [ -n "$args_files" ]; then
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    # If file has NO function keyword but DOES use arguments → definite bug
    if ! grep -q 'function' "$f" 2>/dev/null; then
      lines=$(grep -n 'arguments' "$f" | head -5)
      echo "  [fail] arguments used but no function keyword found: $f"
      echo "$lines" | sed 's/^/    /'
      FAIL=1
    fi
  done <<< "$args_files"
fi

# Pattern: `new` on a variable that was directly assigned an arrow function
if command -v rg >/dev/null 2>&1; then
  new_arrow=$(rg -n 'const\s+\w+\s*=\s*(\([^)]*\)|[a-z_]\w*)\s*=>' "$SRC" \
    -g '*.js' -g '*.ts' -g '!*.min.js' -g '!**/node_modules/**' \
    -g '!**/test/**' -g '!**/*.test.*' -g '!**/*.spec.*' -l \
    2>/dev/null || true)
  if [ -n "$new_arrow" ]; then
    for f in $new_arrow; do
      names=$(rg 'const\s+(\w+)\s*=\s*(\([^)]*\)|[a-z_]\w*)\s*=>' "$f" -or '$1' 2>/dev/null || true)
      for name in $names; do
        if rg -q "new\s+$name\b" "$f" 2>/dev/null; then
          echo "  [fail] 'new $name()' but $name is an arrow function: $f"
          FAIL=1
        fi
      done
    done
  fi
fi

if [ "$FAIL" -eq 0 ]; then
  echo "  [pass] no unsafe arrow function patterns"
fi

exit $FAIL
