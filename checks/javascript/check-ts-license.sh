#!/usr/bin/env bash
# check-ts-license.sh — Detect copyleft/problematic licenses in dependencies.
# @see ADR-129
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/shell/init.sh" 2>/dev/null || true
cpm_check_enabled "ts-license" || exit 0
set -o errexit
set -o nounset
set -o pipefail

if [[ ! -f "package.json" ]]; then exit 0; fi

if ! command -v license-checker >/dev/null 2>&1; then
  echo "  [skip] license-checker not installed (npx license-checker)"
  exit 0
fi

BANNED="GPL-2.0|GPL-3.0|AGPL|SSPL|EUPL"
violations=$(npx --yes --ignore-scripts license-checker --production --csv 2>/dev/null \
  | grep -iE "$BANNED" || true)

if [[ -n "$violations" ]]; then
  echo "  [fail] Copyleft licenses detected:"
  echo "$violations" | head -5 | sed 's/^/    /'
  exit 1
fi
echo "  ✓ No copyleft license violations"
