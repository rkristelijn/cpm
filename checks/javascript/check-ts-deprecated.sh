#!/usr/bin/env bash
# check-deprecated-deps.sh — Detect deprecated npm packages before they break.
# @see ADR-129
#
# Queries npm registry for deprecation notices on your direct dependencies.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/shell/init.sh" 2>/dev/null || true
cpm_check_enabled "ts-deprecated" || exit 0
set -o errexit
set -o nounset
set -o pipefail

if [[ ! -f "package.json" ]]; then exit 0; fi
if ! command -v curl >/dev/null 2>&1; then exit 0; fi

FAIL=0
DEPRECATED=()

# Extract direct dependencies from package.json
deps=$(grep -oE '"[^"]+": "[^"]+"' package.json 2>/dev/null \
  | grep -v "name\|version\|description\|main\|scripts\|repository\|license\|engines" \
  | grep -oE '^"[^"]+"' | tr -d '"' | head -30)

for pkg in $deps; do
  # Skip scoped packages (complex to query)
  [[ "$pkg" == @* ]] && continue

  # Quick check: query npm registry
  resp=$(curl -sf "https://registry.npmjs.org/$pkg/latest" 2>/dev/null || echo "")
  if echo "$resp" | grep -q '"deprecated"'; then
    msg=$(echo "$resp" | grep -oE '"deprecated":"[^"]*"' | cut -d'"' -f4)
    echo "  [warn] $pkg is deprecated: $msg"
    DEPRECATED+=("$pkg")
  fi
done

if [[ ${#DEPRECATED[@]} -gt 0 ]]; then
  echo ""
  echo "  ${#DEPRECATED[@]} deprecated package(s) — replace before they break"
  exit 1
fi
