#!/usr/bin/env bash
# check-doc-layering.sh — Don't mix coarse-grained with fine-grained in one doc.
# @see ADR-129
source "$(dirname "$0")/../../../lib/shell/check.sh"

while IFS= read -r file; do
  [[ -f "$file" ]] || continue
  name="${file#./}"

  # ADRs (high-level) should not contain code blocks >10 lines
  if [[ "$name" == *adr-* ]]; then
    # Count lines inside ``` blocks
    code_lines=$(awk '/^```/{f=!f;next} f{c++} END{print c+0}' "$file")
    total_lines=$(wc -l < "$file" | tr -d ' ')
    if ((total_lines > 0 && code_lines * 100 / total_lines > 50)); then
      findings_add "warning" "$name" "doc-mixed-layers" \
        "ADR is ${code_lines}/${total_lines} lines code (>50%) — too implementation-heavy" \
        "Move code examples to a separate how-to doc" ""
    fi
  fi

  # README should not have >5 code blocks (it's overview, not tutorial)
  if [[ "$(basename "$file")" == "README.md" ]]; then
    blocks=$(grep -c '```' "$file" 2>/dev/null || true)
    if ((blocks > 10)); then
      findings_add "info" "$name" "doc-readme-heavy" \
        "README has $blocks code blocks — consider extracting to docs/" \
        "Keep README as overview, link to detailed docs" ""
    fi
  fi
done < <(find docs -name '*.md' 2>/dev/null; find . -maxdepth 1 -name 'README.md' 2>/dev/null)
