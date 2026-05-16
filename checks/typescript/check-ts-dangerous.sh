#!/usr/bin/env bash
# check-ts-dangerous.sh — Detect patterns that bypass TypeScript safety.
#
# Catches: eval(), @ts-ignore, @ts-expect-error, any casts
set -o errexit
set -o nounset
set -o pipefail

if [[ ! -f "tsconfig.json" && ! -f ".config/tsconfig.json" ]]; then exit 0; fi

FAIL=0

# eval() — security risk
evals=$(find src -name '*.ts' -exec grep -ln 'eval(' {} + 2>/dev/null | grep -v '//.*eval' || true)
if [[ -n "$evals" ]]; then
  echo "  [fail] eval() found — security risk:"
  echo "$evals" | sed 's/^/    /'
  FAIL=1
fi

# @ts-ignore — hides real type errors
ignores=$(find src -name '*.ts' -exec grep -ln '@ts-ignore\|@ts-expect-error' {} + 2>/dev/null || true)
if [[ -n "$ignores" ]]; then
  echo "  [warn] @ts-ignore/@ts-expect-error found:"
  echo "$ignores" | sed 's/^/    /'
fi

# as any — defeats type system
any_casts=$(find src -name '*.ts' -exec grep -Hcn ' as any' {} + 2>/dev/null | grep -v ':0$' || true)
if [[ -n "$any_casts" ]]; then
  echo "  [warn] 'as any' casts found:"
  echo "$any_casts" | sed 's/^/    /' | head -5
fi

exit $FAIL
