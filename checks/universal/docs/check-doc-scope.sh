#!/usr/bin/env bash
# check-doc-scope.sh — Each doc should have ONE topic (single responsibility).
# @see ADR-129
source "$(dirname "$0")/../../../lib/shell/check.sh"

while IFS= read -r file; do
  [[ -f "$file" ]] || continue
  name="${file#./}"

  # Multiple H1 = multiple topics
  h1_count=$(grep -c "^# " "$file" 2>/dev/null || true)
  if ((h1_count > 1)); then
    findings_add "warning" "$name" "doc-multiple-topics" \
      "$h1_count H1 headings — should be 1 topic per file" \
      "Split into separate documents" ""
  fi

  # Too many H2 = too broad
  h2_count=$(grep -c "^## " "$file" 2>/dev/null || true)
  if ((h2_count > 10)); then
    findings_add "info" "$name" "doc-broad-scope" \
      "$h2_count sections — consider splitting" \
      "Extract sections into sub-documents" ""
  fi
done < <(find docs -name '*.md' -not -path '*/node_modules/*' 2>/dev/null)
