#!/usr/bin/env bash
# check-ts-complexity.sh — Detect god classes (>10 methods per file).
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/shell/init.sh" 2>/dev/null || true
cpm_check_enabled "ts-complexity" || exit 0
set -o errexit
set -o nounset
set -o pipefail

if [[ ! -d "src" ]]; then exit 0; fi

FAIL=0
MAX_METHODS=10

while IFS= read -r file; do
  methods=$(grep -c '^\s*async \|^\s*public \|^\s*private \|^\s*protected ' "$file" 2>/dev/null || echo "0")
  if [[ "$methods" -gt "$MAX_METHODS" ]]; then
    echo "  [warn] $file: $methods methods (max: $MAX_METHODS) — split into smaller classes"
    FAIL=1
  fi
done < <(find src -name '*.ts' ! -name '*.test.ts' ! -name '*.spec.ts' 2>/dev/null)

exit $FAIL
