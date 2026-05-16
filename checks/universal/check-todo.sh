#!/usr/bin/env bash
# check-todo.sh — Extract TODO/FIXME/HACK/XXX as findings.
#
# Reports technical debt markers so they don't get forgotten.
# Uses rg (fast) with grep fallback. Install: brew install ripgrep
set -o errexit
set -o nounset
set -o pipefail

source "$(dirname "$0")/../../lib/shell/search.sh"

PATTERN='\b(TODO|FIXME|HACK|XXX)\b'

count=$(cpm_search_count "$PATTERN" src 2>/dev/null || echo "0")

if [[ "${count:-0}" -gt 0 ]]; then
  echo "  [info] $count TODO/FIXME marker(s):"
  cpm_search "$PATTERN" src 2>/dev/null | head -10 | sed 's/^/    /'
  [[ "$count" -gt 10 ]] && echo "    ... and $((count - 10)) more"
fi

echo "  $count technical debt marker(s)"
