#!/usr/bin/env bash
# check-ts-lint.sh — Run biome or eslint (auto-detect which is configured).
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/shell/init.sh" 2>/dev/null || true
cpm_check_enabled "ts-lint" || exit 0
set -o errexit
set -o nounset
set -o pipefail

if [[ ! -f "package.json" ]]; then exit 0; fi

if [[ -f "biome.json" || -f "biome.jsonc" ]]; then
  npx biome check . 2>&1
elif [[ -f ".eslintrc.json" || -f ".eslintrc.js" || -f "eslint.config.js" ]]; then
  npx eslint . 2>&1
else
  echo "  [skip] No linter configured (biome.json or eslint config)"
  exit 0
fi
