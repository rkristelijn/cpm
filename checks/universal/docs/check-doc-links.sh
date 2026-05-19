#!/usr/bin/env bash
# check-doc-links.sh — Docs should reference code, code should reference docs.
# @see ADR-129
source "$(dirname "$0")/../../../lib/shell/check.sh"

# ADRs without code references
while IFS= read -r file; do
  [[ -f "$file" ]] || continue
  name="${file#./}"
  
  # ADR should reference at least one source file
  if [[ "$name" == *adr-* ]] && ! grep -qE "src/|checks/|lib/" "$file" 2>/dev/null; then
    findings_add "info" "$name" "doc-no-code-link" \
      "ADR doesn't reference any source file" \
      "Add: @see src/... or reference implementation files" ""
  fi
done < <(find docs/adrs -name 'adr-*.md' 2>/dev/null)

# Source files without doc reference
while IFS= read -r file; do
  [[ -f "$file" ]] || continue
  name="${file#./}"
  if ! grep -q "@see\|@brief\|@file" "$file" 2>/dev/null; then
    findings_add "info" "$name" "code-no-doc-link" \
      "Source file has no documentation reference" \
      "Add @see ADR-xxx or @brief comment" ""
  fi
done < <(find src -name '*.cpp' -not -name '*test*' 2>/dev/null)
