#!/usr/bin/env bash
# check-doc-quality.sh — Documentation complexity, jargon, layering analysis.
# @see ADR-129
source "$(dirname "$0")/../../../lib/shell/check.sh"

MAX_LINES=300
MAX_HEADING_DEPTH=4
MAX_SENTENCE_WORDS=40

while IFS= read -r file; do
  [[ -f "$file" ]] || continue
  name="${file#./}"

  # 1. File size
  lines=$(wc -l < "$file" | tr -d ' ')
  if ((lines > MAX_LINES)); then
    findings_add "warning" "$name" "doc-too-long" \
      "$lines lines (max $MAX_LINES) — split into smaller docs" \
      "Break into focused sub-documents" ""
  fi

  # 2. Heading depth (#### or deeper = too complex)
  deep=$(grep -c "^#####" "$file" 2>/dev/null || true)
  if ((deep > 0)); then
    findings_add "info" "$name" "doc-deep-nesting" \
      "$deep headings at depth 5+ — consider flattening" \
      "Use separate files instead of deep nesting" ""
  fi

  # 3. Long sentences (>40 words)
  long_sentences=$(awk 'BEGIN{RS="[.!?]"} NF>40{c++} END{print c+0}' "$file")
  if ((long_sentences > 3)); then
    findings_add "info" "$name" "doc-long-sentences" \
      "$long_sentences sentences over $MAX_SENTENCE_WORDS words" \
      "Break into shorter sentences" ""
  fi

done < <(find docs -name '*.md' -not -path '*/node_modules/*' 2>/dev/null)
