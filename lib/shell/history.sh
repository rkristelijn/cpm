#!/usr/bin/env bash
# history.sh — Git history analysis: growth, hotspots, decisions, visualization.
#
# Usage: bash lib/shell/history.sh [--mermaid] [--json]
#
# Outputs:
#   - Growth curve (LOC per month)
#   - Hotspots (most changed files)
#   - Co-change clusters (files that always change together)
#   - Commit type breakdown (feat/fix/refactor/docs)
#   - Decision timeline (ADR commits)
#   - Mermaid timeline visualization
#
# @see ADR-137

set -o nounset
set -o pipefail

MERMAID=false
JSON=false
for arg in "$@"; do
  case "$arg" in
    --mermaid) MERMAID=true ;;
    --json) JSON=true ;;
  esac
done

# --- Growth curve ---
growth_curve() {
  echo "  Growth (LOC per month):"
  echo ""
  git log --format="%ai" --diff-filter=A -- '*.cpp' '*.h' '*.ts' '*.js' '*.py' '*.sh' 2>/dev/null \
    | cut -d- -f1-2 | sort | uniq -c | while read -r count month; do
    printf "    %s: +%d files\n" "$month" "$count"
  done
  echo ""

  # Total LOC over time (sample: first commit, midpoint, now)
  local total_commits first_hash mid_hash
  total_commits=$(git rev-list --count HEAD 2>/dev/null || echo 0)
  if [ "$total_commits" -gt 2 ]; then
    first_hash=$(git rev-list --reverse HEAD 2>/dev/null | head -1)
    mid_hash=$(git rev-list --reverse HEAD 2>/dev/null | sed -n "$((total_commits/2))p")
    local loc_first loc_mid loc_now
    loc_first=$(git show "$first_hash":. 2>/dev/null | wc -l 2>/dev/null | tr -d ' ' || echo "?")
    loc_now=$(find . -name '*.cpp' -o -name '*.h' -o -name '*.sh' -o -name '*.ts' 2>/dev/null | grep -v node_modules | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}')
    echo "    Current: ${loc_now:-?} LOC"
  fi
  echo ""
}

# --- Hotspots ---
hotspots() {
  echo "  Hotspots (most changed files, last 6 months):"
  echo ""
  git log --since="6 months ago" --name-only --pretty=format: 2>/dev/null \
    | grep -v '^$' | grep -v node_modules | sort | uniq -c | sort -rn | head -10 \
    | while read -r count file; do
    printf "    %3d commits  %s\n" "$count" "$file"
  done
  echo ""
}

# --- Co-change clusters ---
cochange() {
  echo "  Co-change clusters (files that always change together):"
  echo ""
  # Find file pairs that appear in same commit >5 times
  git log --name-only --pretty=format:"---" --since="6 months ago" 2>/dev/null \
    | awk '/^---$/{if(NR>1) for(i in files) for(j in files) if(i<j) print i"|"j; delete files; next} /^.+$/{files[$0]=1}' \
    | sort | uniq -c | sort -rn | head -5 \
    | while read -r count pair; do
    local a b
    a="${pair%%|*}"
    b="${pair##*|}"
    printf "    %3d× {%s, %s}\n" "$count" "$(basename "$a")" "$(basename "$b")"
  done
  echo ""
}

# --- Commit types ---
commit_types() {
  echo "  Commit types (conventional commits):"
  echo ""
  local total
  total=$(git rev-list --count HEAD 2>/dev/null || echo 1)
  git log --format="%s" 2>/dev/null | grep -oE '^(feat|fix|refactor|docs|chore|test|ci|style|perf)' \
    | sort | uniq -c | sort -rn | while read -r count type; do
    local pct=$((count * 100 / total))
    printf "    %-10s %3d (%d%%)\n" "$type" "$count" "$pct"
  done
  local non_conv
  non_conv=$(git log --format="%s" 2>/dev/null | grep -cvE '^(feat|fix|refactor|docs|chore|test|ci|style|perf)' || echo 0)
  [ "$non_conv" -gt 0 ] && printf "    %-10s %3d (non-conventional)\n" "other" "$non_conv"
  echo ""
}

# --- Decision timeline ---
decisions() {
  echo "  Decision timeline (ADR commits):"
  echo ""
  git log --all --format="%ai %s" -- '**/adr-*' 'docs/adrs/*' 2>/dev/null \
    | grep -iE "adr|decision|architecture" | head -15 \
    | while read -r date time tz msg; do
    printf "    %s  %s\n" "${date}" "$msg"
  done
  echo ""
}

# --- Per-commit summary (last 20) ---
recent_changes() {
  echo "  Recent changes (last 20 commits):"
  echo ""
  git log -20 --format="%h %ai %s" --stat 2>/dev/null | awk '
    /^[0-9a-f]+ / { hash=$1; date=$2; msg=substr($0, index($0,$4)); printf "    %s %s %s\n", hash, date, msg }
    /files? changed/ { printf "         %s\n", $0 }
  '
  echo ""
}

# --- Mermaid timeline ---
mermaid_timeline() {
  echo '```mermaid'
  echo "timeline"
  echo "  title Project Evolution"
  git log --format="%ai|%s" --reverse 2>/dev/null \
    | awk -F'|' '{split($1,d,"-"); month=d[1]"-"d[2]; if(month!=prev){print "  section "month; prev=month} print "    "$2}' \
    | head -60
  echo '```'
}

# --- Mermaid file heatmap (changes = size) ---
mermaid_heatmap() {
  echo '```mermaid'
  echo "graph LR"
  echo "  subgraph Hotspots"
  git log --since="3 months ago" --name-only --pretty=format: 2>/dev/null \
    | grep -v '^$' | grep -v node_modules | sort | uniq -c | sort -rn | head -15 \
    | while read -r count file; do
    local base
    base=$(basename "$file" | sed 's/[^a-zA-Z0-9]/_/g')
    if [ "$count" -gt 20 ]; then
      echo "    ${base}[\"$(basename "$file") (${count}×)\"]:::hot"
    elif [ "$count" -gt 10 ]; then
      echo "    ${base}[\"$(basename "$file") (${count}×)\"]:::warm"
    else
      echo "    ${base}[\"$(basename "$file") (${count}×)\"]:::cool"
    fi
  done
  echo "  end"
  echo "  classDef hot fill:#f66,stroke:#333"
  echo "  classDef warm fill:#fa0,stroke:#333"
  echo "  classDef cool fill:#6f6,stroke:#333"
  echo '```'
}

# --- Main ---
echo ""
echo "  cpm history — $(basename "$(git rev-parse --show-toplevel 2>/dev/null)")"
echo "  $(git rev-list --count HEAD 2>/dev/null || echo 0) commits, $(git log --format="%ai" -1 2>/dev/null | cut -d' ' -f1) latest"
echo ""

growth_curve
hotspots
cochange
commit_types
decisions
recent_changes

if [ "$MERMAID" = true ]; then
  echo "  === Mermaid Timeline ==="
  echo ""
  mermaid_timeline
  echo ""
  echo "  === Mermaid Heatmap ==="
  echo ""
  mermaid_heatmap
fi
