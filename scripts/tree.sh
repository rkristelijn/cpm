#!/usr/bin/env bash
# scripts/tree.sh — Clean directory tree with standard excludes
# Usage: bash scripts/tree.sh [path] [--depth N] [--details]
set -o nounset -o pipefail

REPO="${1:-.}"
DEPTH=3
DETAILS=false

for i in $(seq 1 $#); do
  arg="${!i}"
  if [[ "$arg" == "--depth" ]]; then next=$((i + 1)); DEPTH="${!next:-3}"; fi
  [[ "$arg" == "--details" ]] && DETAILS=true
done

PRUNE="-name node_modules -o -name .next -o -name dist -o -name build -o -name .git -o -name coverage -o -name __pycache__ -o -name .cache -o -name vendor -o -name target -o -name out -o -name .tmp -o -name .idea -o -name .vscode"

# Stats for a directory (only when --details)
dir_stats() {
  local dir="$1"
  local files
  files=$(find "$dir" -maxdepth 1 -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \
    -o -name "*.cpp" -o -name "*.c" -o -name "*.h" -o -name "*.hpp" \
    -o -name "*.py" -o -name "*.go" -o -name "*.rs" -o -name "*.java" -o -name "*.sh" \) 2>/dev/null)
  [ -z "$files" ] && return

  local lines funcs classes interfaces types
  lines=$(echo "$files" | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}')
  funcs=$(echo "$files" | xargs grep -cE "^\s*(export\s+)?(function |async function |[a-zA-Z_*&]+ [a-zA-Z_]+\s*\()" 2>/dev/null | awk -F: '{s+=$2} END{print s+0}')
  classes=$(echo "$files" | xargs grep -cE "^\s*(export\s+)?class " 2>/dev/null | awk -F: '{s+=$2} END{print s+0}')
  interfaces=$(echo "$files" | xargs grep -cE "^\s*(export\s+)?interface " 2>/dev/null | awk -F: '{s+=$2} END{print s+0}')
  types=$(echo "$files" | xargs grep -cE "^\s*(export\s+)?type [A-Z]" 2>/dev/null | awk -F: '{s+=$2} END{print s+0}')

  local parts=""
  [ "${lines:-0}" -gt 0 ] && parts="${lines}L"
  [ "${funcs:-0}" -gt 0 ] && parts="$parts ${funcs}fn"
  [ "${classes:-0}" -gt 0 ] && parts="$parts ${classes}cls"
  [ "${interfaces:-0}" -gt 0 ] && parts="$parts ${interfaces}if"
  [ "${types:-0}" -gt 0 ] && parts="$parts ${types}T"
  [ -n "$parts" ] && printf " \033[90m(%s)\033[0m" "$parts"
}

find "$REPO" -maxdepth "$DEPTH" \( $PRUNE \) -prune -o -print |
  grep -v "/\." |
  sed -e "s|^${REPO}||" -e '/^$/d' |
  sort |
  while IFS= read -r path; do
    n=$(echo "$path" | awk -F/ '{print NF}')
    indent=""
    for ((i = 1; i < n; i++)); do indent="${indent}│   "; done
    name=$(basename "$path")

    if [ -d "${REPO}${path}" ]; then
      printf "%s├── %s/" "$indent" "$name"
      [[ "$DETAILS" == true ]] && dir_stats "${REPO}${path}"
      printf "\n"
    else
      printf "%s├── %s\n" "$indent" "$name"
    fi
  done
