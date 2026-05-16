#!/usr/bin/env bash
# check-todo.sh — Extract TODO/FIXME/HACK/XXX as findings.
#
# Reports technical debt markers so they don't get forgotten.
# Non-blocking (informational) — every project has TODOs.
set -o errexit
set -o nounset
set -o pipefail

source "$(dirname "$0")/../../lib/shell/init.sh" 2>/dev/null || true

PATTERNS="TODO|FIXME|HACK|XXX"
EXCLUDE="node_modules|.git|build|dist|vendor|.tmp"

count=$(grep -rn --include="*.cpp" --include="*.h" --include="*.ts" --include="*.js" \
  --include="*.py" --include="*.sh" --include="*.tf" --include="*.php" \
  -E "\b($PATTERNS)\b" . 2>/dev/null \
  | grep -vE "$EXCLUDE" | wc -l | tr -d ' ')

if [[ "$count" -gt 0 ]]; then
  echo "  [info] $count TODO/FIXME markers found:"
  grep -rn --include="*.cpp" --include="*.h" --include="*.ts" --include="*.js" \
    --include="*.py" --include="*.sh" --include="*.tf" --include="*.php" \
    -E "\b($PATTERNS)\b" . 2>/dev/null \
    | grep -vE "$EXCLUDE" | head -10 | sed 's/^/    /'
  [[ "$count" -gt 10 ]] && echo "    ... and $((count - 10)) more"
fi

echo "  $count technical debt marker(s)"
