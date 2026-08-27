#!/usr/bin/env bash
# checks/universal/docs/check-orphan-docs.sh
# @see ADR-129
# Detect markdown files not linked from any other .md file (orphan docs)
# NOTE: Uses temp files instead of declare -A/mapfile for BusyBox compatibility
source "$(dirname "$0")/../../../lib/shell/check.sh"
cpm_check_enabled "orphan-docs" || exit 0
set -o nounset -o pipefail

REPO="${1:-.}"

# Well-known files that don't need to be linked (they're discovered by convention)
WELL_KNOWN="README.md CHANGELOG.md LICENSE.md LICENSE CONTRIBUTING.md SECURITY.md CODE_OF_CONDUCT.md CODEOWNERS"

# Find all .md files
MD_FILES=$(find "$REPO" -name '*.md' -type f \
  -not -path "*/node_modules/*" \
  -not -path "*/vendor/*" \
  -not -path "*/.git/*" \
  -not -path "*/dist/*" \
  -not -path "*/build/*" \
  -not -path "*/coverage/*" \
  -not -path "*/.cache/*" \
  -not -path "*/target/*" \
  -not -path "*/out/*" \
  -not -path "*/.next/*" \
  -not -path "*/.github/ISSUE_TEMPLATE/*" \
  -not -path "*/.github/PULL_REQUEST_TEMPLATE/*" \
  -not -path "*/.github/pull_request_template*" \
  2>/dev/null) || true

[ -z "$MD_FILES" ] && exit 0

# Build a temp file with all markdown content (for searching links)
ALL_MD_CONTENT=$(mktemp)
trap "rm -f $ALL_MD_CONTENT" EXIT

# Concatenate all .md file contents with file markers
while IFS= read -r mdfile; do
  [ -z "$mdfile" ] && continue
  [ ! -f "$mdfile" ] && continue
  cat "$mdfile" >> "$ALL_MD_CONTENT" 2>/dev/null || true
done <<< "$MD_FILES"

while IFS= read -r mdfile; do
  [ -z "$mdfile" ] && continue
  [ ! -f "$mdfile" ] && continue

  BASENAME=$(basename "$mdfile")

  # Skip well-known files
  SKIP=false
  for wk in $WELL_KNOWN; do
    if [ "$BASENAME" = "$wk" ]; then
      SKIP=true
      break
    fi
  done
  $SKIP && continue

  # Skip .github/ templates
  case "$mdfile" in
    */.github/*) continue ;;
  esac

  # Skip README.md files in any directory (they're navigation entry points)
  [ "$BASENAME" = "README.md" ] && continue

  # Get relative path from repo root (strip leading ./ if present)
  REL_PATH="${mdfile#"$REPO/"}"
  REL_PATH="${REL_PATH#./}"

  # Check if this file is referenced from any other .md file
  # Search for: the relative path, the basename, or the path without .md extension
  FOUND=false

  # Search by relative path (most reliable)
  if grep -qF "$REL_PATH" "$ALL_MD_CONTENT" 2>/dev/null; then
    FOUND=true
  fi

  # Search by basename (fallback: some links use just the filename)
  if ! $FOUND; then
    if grep -qF "$BASENAME" "$ALL_MD_CONTENT" 2>/dev/null; then
      FOUND=true
    fi
  fi

  # Search by filename without extension (for @see references like "adr-013")
  if ! $FOUND; then
    NAME_NO_EXT="${BASENAME%.md}"
    if grep -qF "$NAME_NO_EXT" "$ALL_MD_CONTENT" 2>/dev/null; then
      FOUND=true
    fi
  fi

  if ! $FOUND; then
    findings_add "info" "$mdfile" "doc-orphan" \
      "Markdown file not linked from any other .md file" \
      "Link it from a README, index, or parent doc; or remove if obsolete" \
      ""
  fi

done <<< "$MD_FILES"
