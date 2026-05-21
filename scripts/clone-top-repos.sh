#!/usr/bin/env bash
# clone-top-repos.sh — Clone top 500 GitHub repos for cpm analysis
# @see ADR-138, ADR-139
#
# Usage: ./scripts/clone-top-repos.sh [count]
#   count: number of repos to clone (default: 500)
#
# Output: ~/git/hub/top-repos/<repo-name>/
# After: run `cpm scan ~/git/hub/top-repos --depth 1`

set -euo pipefail

COUNT="${1:-500}"
DEST="$HOME/git/hub/top-repos"
PAGES=$(((COUNT + 99) / 100)) # GitHub API returns 100 per page

mkdir -p "$DEST"

# --- Progress bar (hi-res UTF-8) ---
percentBar() {
  local prct totlen=$((8 * $2)) lastchar barstring blankstring
  local -a chars=('▏' '▎' '▍' '▌' '▋' '▊' '▉')
  printf -v prct %.2f "$1"
  prct=${prct/./}
  prct=$((10#$prct * totlen / 10000))
  local remainder=$((prct % 8))
  [[ $remainder -gt 0 ]] && lastchar="${chars[$((remainder - 1))]}" || lastchar=''
  printf -v barstring '%*s' $((prct / 8)) ''
  barstring="${barstring// /█}$lastchar"
  printf -v blankstring '%*s' $(((totlen - prct) / 8)) ''
  printf -v "$3" '%s%s' "$barstring" "$blankstring"
}

# --- Fetch repo list from GitHub API ---
echo "Fetching top $COUNT repos from GitHub..."
REPOS_FILE=$(mktemp)

for page in $(seq 1 "$PAGES"); do
  curl -s "https://api.github.com/search/repositories?q=stars:>10000&sort=stars&order=desc&per_page=100&page=$page" |
    grep -o '"full_name": "[^"]*"' |
    cut -d'"' -f4 \
      >>"$REPOS_FILE"
  sleep 2 # Rate limit
done

TOTAL=$(wc -l <"$REPOS_FILE" | tr -d ' ')
echo "Found $TOTAL repos. Cloning to $DEST..."
echo ""

# --- Clone with progress ---
DONE=0
SKIPPED=0
FAILED=0
START=$(date +%s)

while IFS= read -r repo; do
  DONE=$((DONE + 1))
  name=$(basename "$repo")

  # Progress
  pct=$((DONE * 100 / TOTAL))
  percentBar "$pct" 40 bar
  elapsed=$(($(date +%s) - START))
  if [ "$DONE" -gt 1 ]; then
    eta=$((elapsed * (TOTAL - DONE) / DONE))
    eta_min=$((eta / 60))
    eta_sec=$((eta % 60))
    eta_str="${eta_min}m${eta_sec}s"
  else
    eta_str="--"
  fi
  printf "\r  [%s] %3d%% (%d/%d) ETA: %s  %-30s" "$bar" "$pct" "$DONE" "$TOTAL" "$eta_str" "$name"

  # Skip if already cloned
  if [ -d "$DEST/$name/.git" ]; then
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  # Clone (depth 1 for speed, but not shallow for git-health checks)
  if git clone --depth 1 "https://github.com/$repo.git" "$DEST/$name" 2>/dev/null; then
    :
  else
    FAILED=$((FAILED + 1))
  fi
done <"$REPOS_FILE"

# --- Summary ---
elapsed=$(($(date +%s) - START))
printf "\n\n"
echo "  Done in ${elapsed}s"
echo "  Cloned: $((DONE - SKIPPED - FAILED))"
echo "  Skipped (existing): $SKIPPED"
echo "  Failed: $FAILED"
echo "  Total: $DONE"
echo ""
echo "  Next: cpm scan $DEST --depth 1"

rm -f "$REPOS_FILE"
