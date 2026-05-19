#!/usr/bin/env bash
# check-ts-imports.sh — Detect deep relative imports (use path aliases).
# @see ADR-129
# Uses rg (fast) with grep fallback. Install: brew install ripgrep
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/shell/init.sh" 2>/dev/null || true
cpm_check_enabled "ts-imports" || exit 0
set -o errexit
set -o nounset
set -o pipefail

if [[ ! -d "src" ]]; then exit 0; fi

source "$(dirname "$0")/../../lib/shell/search.sh"

deep=$(cpm_search '\.\./\.\./\.\./' src --include '*.ts' || true)
if [[ -n "$deep" ]]; then
  count=$(echo "$deep" | wc -l | tr -d ' ')
  echo "  [warn] $count deep relative import(s) — use path aliases @/:"
  echo "$deep" | head -5 | sed 's/^/    /'
fi
