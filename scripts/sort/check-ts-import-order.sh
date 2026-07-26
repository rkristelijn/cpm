#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-.}"
shift || true
ALIAS_PREFIXES="${ALIAS_PREFIXES:-@/,~/,src/}"

rc=0
while IFS= read -r f; do
  if ! bash "$ROOT/scripts/sort/sortkit.sh" check --mode ts-imports --file "$f" --alias-prefixes "$ALIAS_PREFIXES"; then
    rc=1
  fi
done < <(find "$ROOT" -type f \( -name "*.ts" -o -name "*.tsx" \) \
  -not -path "*/node_modules/*" \
  -not -path "*/vendor/*" \
  -not -path "*/.git/*")

exit $rc
