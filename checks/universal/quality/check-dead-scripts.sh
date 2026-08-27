#!/usr/bin/env bash
# checks/universal/quality/check-dead-scripts.sh
# @see ADR-129
# Detect shell scripts not referenced anywhere in the repo (potential dead code)
source "$(dirname "$0")/../../../lib/shell/check.sh"
cpm_check_enabled "dead-scripts" || exit 0
set -o nounset -o pipefail

REPO="${1:-.}"

# Collect all .sh files in the repo
SCRIPTS=$(find "$REPO" -name '*.sh' -type f \
  -not -path "*/node_modules/*" \
  -not -path "*/vendor/*" \
  -not -path "*/.git/*" \
  -not -path "*/dist/*" \
  -not -path "*/build/*" \
  -not -path "*/coverage/*" \
  -not -path "*/.cache/*" \
  -not -path "*/target/*" \
  -not -path "*/out/*" \
  2>/dev/null) || true

[ -z "$SCRIPTS" ] && exit 0

# Create temp file for searchable file list
SEARCH_FILES=$(mktemp)
trap "rm -f $SEARCH_FILES" EXIT

# Build list of files to search in (all relevant source files)
find "$REPO" \( -name '*.sh' -o -name '*.md' -o -name '*.yml' -o -name '*.yaml' \
  -o -name 'Makefile' -o -name 'Dockerfile' -o -name '*.json' -o -name '*.toml' \
  -o -name '*.ts' -o -name '*.js' -o -name '*.py' -o -name '*.rb' \
  -o -name '*.go' -o -name '*.rs' -o -name '*.cpp' -o -name '*.hpp' \
  -o -name '*.c' -o -name '*.h' -o -name '*.java' -o -name '*.tf' \) \
  -type f \
  -not -path "*/node_modules/*" \
  -not -path "*/vendor/*" \
  -not -path "*/.git/*" \
  -not -path "*/dist/*" \
  -not -path "*/build/*" \
  -not -path "*/coverage/*" \
  -not -path "*/.cache/*" \
  -not -path "*/target/*" \
  -not -path "*/out/*" \
  > "$SEARCH_FILES" 2>/dev/null || true

while IFS= read -r script; do
  [ -z "$script" ] && continue
  [ ! -f "$script" ] && continue

  BASENAME=$(basename "$script")

  # Skip test scripts — they may be run by a test harness not visible in source
  case "$BASENAME" in
    test-*|*-test.sh|*_test.sh|test_*) continue ;;
  esac

  # Search for the basename in all other files (exclude the script itself)
  FOUND=false
  while IFS= read -r search_file; do
    [ -z "$search_file" ] && continue
    # Don't match the script against itself
    [ "$search_file" = "$script" ] && continue
    if grep -qF "$BASENAME" "$search_file" 2>/dev/null; then
      FOUND=true
      break
    fi
  done < "$SEARCH_FILES"

  if ! $FOUND; then
    findings_add "info" "$script" "script-unreferenced" \
      "Shell script not referenced anywhere in the repo" \
      "If unused, remove it; if needed, reference it from Makefile, docs, or another script" \
      ""
  fi
done <<< "$SCRIPTS"
