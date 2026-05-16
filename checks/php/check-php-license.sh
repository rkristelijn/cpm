#!/usr/bin/env bash
# check-php-license.sh — Detect copyleft licenses in PHP dependencies.
set -o errexit
set -o nounset
set -o pipefail

if [[ ! -f "composer.json" ]]; then exit 0; fi

if ! command -v composer >/dev/null 2>&1; then
  echo "  [skip] composer not installed"
  exit 0
fi

BANNED="GPL-2.0|GPL-3.0|AGPL|SSPL"
violations=$(composer licenses 2>/dev/null | grep -iE "$BANNED" || true)

if [[ -n "$violations" ]]; then
  echo "  [fail] Copyleft licenses detected:"
  echo "$violations" | head -5 | sed 's/^/    /'
  exit 1
fi
echo "  ✓ No copyleft license violations"
