#!/usr/bin/env bash
# check-ts-async.sh — Enforce async/await over raw .then()/.catch().
set -o errexit
set -o nounset
set -o pipefail

if [[ ! -d "src" ]]; then exit 0; fi

FAIL=0

# .then() — prefer async/await
thens=$(find src -name '*.ts' ! -name '*.test.ts' -exec grep -ln '\.then(' {} + 2>/dev/null || true)
if [[ -n "$thens" ]]; then
  echo "  [warn] .then() found — prefer async/await:"
  echo "$thens" | head -5 | sed 's/^/    /'
fi

# new Promise() — usually unnecessary with async/await
promises=$(find src -name '*.ts' ! -name '*.test.ts' -exec grep -ln 'new Promise(' {} + 2>/dev/null \
  | xargs grep -L 'createServer\|http\.\|on(' 2>/dev/null || true)
if [[ -n "$promises" ]]; then
  echo "  [warn] new Promise() — consider async/await:"
  echo "$promises" | head -3 | sed 's/^/    /'
fi

exit $FAIL
