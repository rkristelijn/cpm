#!/usr/bin/env bash
# checks/universal/docs/check-markdown-quality.sh
# @see ADR-129
# Lightweight markdown quality: code block languages, trailing whitespace, blank lines
source "$(dirname "$0")/../../../lib/shell/check.sh"
cpm_check_enabled "markdown-quality" || exit 0
set -o nounset -o pipefail

REPO="${1:-.}"

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
  2>/dev/null) || true

[ -z "$MD_FILES" ] && exit 0

while IFS= read -r mdfile; do
  [ -z "$mdfile" ] && continue
  [ ! -f "$mdfile" ] && continue

  # Rule 1: md-code-block-no-lang — Fenced code block without language specifier
  # Match lines that are exactly ``` (with optional whitespace) but no language after
  LINE_NUM=0
  IN_BLOCK=false
  while IFS= read -r line; do
    LINE_NUM=$((LINE_NUM + 1))
    # Detect opening fenced code block
    if echo "$line" | grep -qE '^\s*```\s*$' 2>/dev/null; then
      if ! $IN_BLOCK; then
        # This is an opening ``` without a language
        findings_add "info" "$mdfile:$LINE_NUM" "md-code-block-no-lang" \
          "Fenced code block without language specifier" \
          "Add language after \`\`\` (e.g. \`\`\`bash, \`\`\`json)" \
          "https://docs.github.com/en/get-started/writing-on-github/working-with-advanced-formatting/creating-and-highlighting-code-blocks"
        IN_BLOCK=true
      else
        IN_BLOCK=false
      fi
    elif echo "$line" | grep -qE '^\s*```[a-zA-Z]' 2>/dev/null; then
      IN_BLOCK=true
    fi
  done < "$mdfile"

  # Rule 2: md-trailing-whitespace — Lines with trailing whitespace
  # (Intentional double-space line breaks are rare; flag them all)
  TRAILING=$(grep -nc ' $' "$mdfile" 2>/dev/null || echo "0")
  if [ "$TRAILING" -gt 0 ]; then
    findings_add "info" "$mdfile" "md-trailing-whitespace" \
      "$TRAILING line(s) with trailing whitespace" \
      "Remove trailing spaces (configure editor to strip on save)" \
      ""
  fi

  # Rule 3: md-consecutive-blank — 3+ consecutive blank lines
  CONSEC=$(awk '
    /^\s*$/ { blank++; next }
    { if (blank >= 3) { count++; printf "%d ", NR-blank; } blank = 0 }
    END { if (blank >= 3) count++; print "" > "/dev/stderr"; printf "%d", count+0 }
  ' "$mdfile" 2>/dev/null) || CONSEC=0
  if [ "$CONSEC" -gt 0 ]; then
    findings_add "info" "$mdfile" "md-consecutive-blank" \
      "$CONSEC section(s) with 3+ consecutive blank lines" \
      "Reduce to maximum 2 blank lines between sections" \
      ""
  fi

done <<< "$MD_FILES"
