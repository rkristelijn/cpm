#!/usr/bin/env bash
# scripts/scan-native-opportunities.sh — Fast scan for native replacement opportunities
# Reads package.json (instant) instead of grepping all source files.
# Usage: bash scripts/scan-native-opportunities.sh <path> [--depth N]
set -o nounset -o pipefail

ROOT="${1:-.}"
DEPTH="${2:-3}"
[[ "${2:-}" == "--depth" ]] && DEPTH="${3:-3}"

# Packages that have native replacements (with savings estimate)
declare -A REPLACEABLE=(
  [lodash]="70KB|Native Array/Object methods"
  [underscore]="30KB|Native Array/Object methods"
  [moment]="300KB|Temporal API (Node 26)"
  [moment - timezone]="180KB|Temporal.ZonedDateTime (Node 26)"
  [date - fns]="80KB|Temporal API (Node 26)"
  [dayjs]="7KB|Temporal API (Node 26)"
  [luxon]="70KB|Temporal API (Node 26)"
  [axios]="30KB|fetch() (Node 18+)"
  [got]="50KB|fetch() (Node 18+)"
  [node - fetch]="8KB|fetch() (Node 18+)"
  [cross - fetch]="3KB|fetch() (Node 18+)"
  [isomorphic - fetch]="2KB|fetch() (Node 18+)"
  [uuid]="9KB|crypto.randomUUID() (Node 15.6+)"
  [node - uuid]="9KB|crypto.randomUUID()"
  [nanoid]="1KB|crypto.randomUUID()"
  [query - string]="5KB|URLSearchParams"
  [form - data]="15KB|FormData (native)"
  [abort - controller]="1KB|AbortController (Node 15+)"
  [deep - clone]="3KB|structuredClone() (Node 17+)"
  [rfdc]="2KB|structuredClone() (Node 17+)"
  [lodash.clonedeep]="10KB|structuredClone()"
  [lodash.get]="5KB|Optional chaining ?."
  [lodash.merge]="10KB|structuredClone() + spread"
  [lodash.groupby]="5KB|Object.groupBy() (Node 21+)"
  [ms]="2KB|Temporal.Duration (Node 26)"
  [timeago.js]="3KB|Intl.RelativeTimeFormat"
  [numeral]="15KB|Intl.NumberFormat"
  [tough - cookie]="20KB|Undici cookie jar (Node 26)"
)

# Find all package.json files (skip node_modules) — fast with -prune
if command -v fd >/dev/null 2>&1; then
  PACKAGES=$(fd -t f "package.json" "$ROOT" --max-depth "$DEPTH" -E node_modules -E dist -E .next -E .cache 2>/dev/null)
else
  PACKAGES=$(find "$ROOT" -maxdepth "$DEPTH" \
    \( -name node_modules -o -name dist -o -name .next -o -name .cache -o -name coverage -o -name .stryker-tmp -o -name .git \) -prune \
    -o -name "package.json" -type f -print 2>/dev/null)
fi

[ -z "$PACKAGES" ] && {
  echo "No package.json found in $ROOT (depth $DEPTH)"
  exit 0
}

TOTAL_SAVINGS=0
TOTAL_FINDINGS=0
REPOS_WITH_FINDINGS=0

printf "\n  %-45s %-8s %-10s %s\n" "Repository" "Node" "Savings" "Replaceable packages"
printf "  %s\n" "$(printf '─%.0s' {1..100})"

while IFS= read -r pkg; do
  dir=$(dirname "$pkg")
  name=$(basename "$dir")
  # Get parent for context
  parent=$(basename "$(dirname "$dir")")
  [[ "$parent" != "." && "$parent" != "lab" && "$parent" != "hub" ]] && name="$parent/$name"

  # Detect Node version
  node_ver="?"
  [ -f "$dir/.nvmrc" ] && node_ver=$(cat "$dir/.nvmrc" | tr -d 'v \n')
  [ -f "$dir/.node-version" ] && node_ver=$(cat "$dir/.node-version" | tr -d 'v \n')

  # Scan deps
  found=""
  savings=0
  for dep in "${!REPLACEABLE[@]}"; do
    if grep -q "\"$dep\"" "$pkg" 2>/dev/null; then
      size=$(echo "${REPLACEABLE[$dep]}" | cut -d'|' -f1 | tr -d 'KB')
      savings=$((savings + size))
      found="$found $dep"
    fi
  done

  if [ -n "$found" ]; then
    TOTAL_SAVINGS=$((TOTAL_SAVINGS + savings))
    count=$(echo "$found" | wc -w | tr -d ' ')
    TOTAL_FINDINGS=$((TOTAL_FINDINGS + count))
    REPOS_WITH_FINDINGS=$((REPOS_WITH_FINDINGS + 1))
    printf "  %-45s %-8s %-10s%s\n" "$name" "$node_ver" "${savings}KB" "$found"
  fi
done <<<"$PACKAGES"

printf "  %s\n" "$(printf '─%.0s' {1..100})"
printf "  %d repos scanned, %d with opportunities (%d packages, ~%dKB savings)\n\n" \
  "$(echo "$PACKAGES" | wc -l | tr -d ' ')" "$REPOS_WITH_FINDINGS" "$TOTAL_FINDINGS" "$TOTAL_SAVINGS"
