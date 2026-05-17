#!/usr/bin/env bash
# check-ts-typecheck.sh — Run tsc --noEmit to catch type errors.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/shell/init.sh" 2>/dev/null || true
cpm_check_enabled "ts-typecheck" || exit 0
set -o errexit
set -o nounset
set -o pipefail

if [[ ! -f "tsconfig.json" && ! -f ".config/tsconfig.json" ]]; then exit 0; fi

TSCONFIG="tsconfig.json"
[[ -f ".config/tsconfig.json" ]] && TSCONFIG=".config/tsconfig.json"

if command -v npx >/dev/null 2>&1; then
  npx tsc -p "$TSCONFIG" --noEmit 2>&1
elif command -v tsc >/dev/null 2>&1; then
  tsc -p "$TSCONFIG" --noEmit 2>&1
else
  echo "  [skip] tsc not found"
  exit 0
fi
