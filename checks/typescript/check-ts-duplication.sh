#!/usr/bin/env bash
# check-ts-duplication.sh — Detect code duplication with jscpd.
set -o errexit
set -o nounset
set -o pipefail

if [[ ! -d "src" ]]; then exit 0; fi

if ! command -v npx >/dev/null 2>&1; then
  echo "  [skip] npx not found"
  exit 0
fi

MAX_PERCENT=6
output=$(npx jscpd src --min-lines 5 --min-tokens 50 --silent 2>&1 || true)
pct=$(echo "$output" | grep -oE '[0-9]+\.[0-9]+%' | head -1 | tr -d '%' || echo "0")
int_pct="${pct%%.*}"

if [[ "${int_pct:-0}" -gt "$MAX_PERCENT" ]]; then
  echo "  [fail] Code duplication: ${pct}% (max: ${MAX_PERCENT}%)"
  exit 1
fi
echo "  ✓ Duplication: ${pct:-0}% (max: ${MAX_PERCENT}%)"
