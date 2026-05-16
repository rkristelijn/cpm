#!/usr/bin/env bash
# check-ts-async.sh — Enforce async/await over raw .then()/.catch().
# Uses rg (fast) with grep fallback. Install: brew install ripgrep
set -o errexit
set -o nounset
set -o pipefail

if [[ ! -d "src" ]]; then exit 0; fi

source "$(dirname "$0")/../../lib/shell/search.sh"

# .then() — prefer async/await
thens=$(cpm_search_files '\.then\(' src --include '*.ts' -g '!*.test.ts' 2>/dev/null || \
        cpm_search_files '\.then\(' src --include '*.ts' 2>/dev/null | grep -v '\.test\.ts' || true)
if [[ -n "$thens" ]]; then
  count=$(echo "$thens" | wc -l | tr -d ' ')
  echo "  [warn] $count file(s) use .then() — prefer async/await:"
  echo "$thens" | head -5 | sed 's/^/    /'
fi

# new Promise() — usually unnecessary
promises=$(cpm_search_files 'new Promise\(' src --include '*.ts' 2>/dev/null | grep -v '\.test\.ts' || true)
if [[ -n "$promises" ]]; then
  echo "  [warn] new Promise() found — consider async/await:"
  echo "$promises" | head -3 | sed 's/^/    /'
fi
