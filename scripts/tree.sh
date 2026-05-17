#!/usr/bin/env bash
# scripts/tree.sh — Clean directory tree with standard excludes
# Usage: bash scripts/tree.sh [path] [--depth N]
set -o nounset -o pipefail

REPO="${1:-.}"
DEPTH=3

for i in $(seq 1 $#); do
  arg="${!i}"
  if [[ "$arg" == "--depth" ]]; then next=$((i+1)); DEPTH="${!next:-3}"; fi
done

# Use the same excludes as cpm_grep
PRUNE="-name node_modules -o -name .next -o -name dist -o -name build -o -name .git -o -name coverage -o -name __pycache__ -o -name .cache -o -name vendor -o -name target -o -name out -o -name .tmp -o -name .idea -o -name .vscode"

find "$REPO" -maxdepth "$DEPTH" \( $PRUNE \) -prune -o -print | \
  grep -v "/\." | \
  sed -e "s|^${REPO}||" -e '/^$/d' | \
  sort | \
  awk '{
    n = split($0, parts, "/")
    indent = ""
    for (i = 1; i < n; i++) indent = indent "│   "
    if (n > 1) {
      name = parts[n]
      printf "%s├── %s\n", indent, name
    } else {
      printf "%s\n", $0
    }
  }'
