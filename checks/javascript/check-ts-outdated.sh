#!/usr/bin/env bash
# check-ts-outdated.sh — Report outdated dependencies.
# @see ADR-129
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/shell/init.sh" 2>/dev/null || true
cpm_check_enabled "ts-outdated" || exit 0
set -o errexit
set -o nounset
set -o pipefail

if [[ ! -f "package.json" ]]; then exit 0; fi

outdated=$(npm outdated --json 2>/dev/null | grep -c '"current"' || echo "0")
if [[ "$outdated" -gt 0 ]]; then
  echo "  [warn] $outdated outdated package(s):"
  npm outdated 2>/dev/null | head -10 | sed 's/^/    /'
fi
