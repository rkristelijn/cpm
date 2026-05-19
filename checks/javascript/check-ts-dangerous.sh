#!/usr/bin/env bash
# check-ts-dangerous.sh — Detect patterns that bypass TypeScript safety.
# @see ADR-129
#
# Catches: eval(), @ts-ignore, @ts-expect-error, as any
# Uses rg (fast) with grep fallback. Install: brew install ripgrep
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/shell/init.sh" 2>/dev/null || true
cpm_check_enabled "ts-dangerous" || exit 0
set -o errexit
set -o nounset
set -o pipefail

if [[ ! -f "tsconfig.json" && ! -f ".config/tsconfig.json" ]]; then exit 0; fi

source "$(dirname "$0")/../../lib/shell/search.sh"

FAIL=0

# eval() — security risk
evals=$(cpm_search_files 'eval\(' src --include '*.ts' || true)
if [[ -n "$evals" ]]; then
  echo "  [fail] eval() found — security risk:"
  echo "$evals" | sed 's/^/    /'
  FAIL=1
fi

# @ts-ignore — hides real type errors
ignores=$(cpm_search_files '@ts-ignore|@ts-expect-error' src --include '*.ts' || true)
if [[ -n "$ignores" ]]; then
  echo "  [warn] @ts-ignore/@ts-expect-error found:"
  echo "$ignores" | sed 's/^/    /'
fi

# as any — defeats type system
any_count=$(cpm_search_count ' as any' src --include '*.ts' || echo "0")
if [[ "${any_count:-0}" -gt 0 ]]; then
  echo "  [warn] $any_count 'as any' cast(s) found"
fi

# --- Prototype pollution: obj[key] = value in loops ---
PROTO=$(find "$SRC" -name "*.ts" -not -name "*.spec.*" -not -name "*.test.*" -not -path "*/node_modules/*" \
  -exec grep -ln "\[key\]\s*=\|\[prop\]\s*=\|\[k\]\s*=" {} \; 2>/dev/null | \
  xargs grep -l "for\|forEach\|Object.keys\|Object.entries" 2>/dev/null | wc -l | tr -d ' ')
[ "$PROTO" -gt 0 ] && echo "  [warn] $PROTO file(s) with potential prototype pollution (obj[key]=val in loop)"

exit $FAIL
