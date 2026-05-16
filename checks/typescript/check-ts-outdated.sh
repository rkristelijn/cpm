#!/usr/bin/env bash
# check-ts-outdated.sh — Report outdated dependencies.
set -o errexit
set -o nounset
set -o pipefail

if [[ ! -f "package.json" ]]; then exit 0; fi

outdated=$(npm outdated --json 2>/dev/null | grep -c '"current"' || echo "0")
if [[ "$outdated" -gt 0 ]]; then
  echo "  [warn] $outdated outdated package(s):"
  npm outdated 2>/dev/null | head -10 | sed 's/^/    /'
fi
