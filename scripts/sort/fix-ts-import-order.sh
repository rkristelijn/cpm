#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-.}"
ALIAS_PREFIXES="${ALIAS_PREFIXES:-@/,~/,src/}"

while IFS= read -r f; do
  bash "$ROOT/scripts/sort/sortkit.sh" fix --mode ts-imports --file "$f" --alias-prefixes "$ALIAS_PREFIXES"
done < <(find "$ROOT" -type f \( -name "*.ts" -o -name "*.tsx" \) \
  -not -path "*/node_modules/*" \
  -not -path "*/vendor/*" \
  -not -path "*/.git/*")
