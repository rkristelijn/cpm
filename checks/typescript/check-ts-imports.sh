#!/usr/bin/env bash
# check-ts-imports.sh — Detect deep relative imports (use path aliases).
#
# ../../.. is a code smell — use @/ path aliases instead.
set -o errexit
set -o nounset
set -o pipefail

if [[ ! -d "src" ]]; then exit 0; fi

deep=$(find src -name '*.ts' -exec grep -Hn '\.\./\.\./\.\./' {} + 2>/dev/null || true)
if [[ -n "$deep" ]]; then
  echo "  [warn] Deep relative imports (use path aliases @/):"
  echo "$deep" | head -5 | sed 's/^/    /'
  count=$(echo "$deep" | wc -l | tr -d ' ')
  echo "  $count deep import(s)"
fi
