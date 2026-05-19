#!/usr/bin/env bash
# check-adr-enforcement.sh — Every ADR must have an Enforcement section.
# @see ADR-130 (test architecture), ADR-129 (unified findings contract)
source "$(dirname "$0")/../../../lib/shell/check.sh"

# Required sections in every ADR
REQUIRED_SECTIONS="## Context|## Decision|## Enforcement|## Consequences"

for f in docs/adrs/adr-*.md; do
  [[ -f "$f" ]] || continue
  name=$(basename "$f")

  # Skip legacy/external ADRs (llama-cli prefix)
  [[ "$name" == llama-cli-* ]] && continue

  # Check for Enforcement section (or Acceptance Criteria)
  if ! grep -qE "^## (Enforcement|Acceptance Criteria)" "$f"; then
    findings_add "error" "$f" "missing-enforcement" \
      "ADR has no ## Enforcement or ## Acceptance Criteria section" \
      "Add ## Enforcement with detection method, or ## Acceptance Criteria with testable checks" \
      "https://cpm.dev/checks/adr-enforcement"
  fi

  # Check for frontmatter (summary + status)
  if ! grep -q "^summary:" "$f"; then
    findings_add "warning" "$f" "missing-summary" \
      "ADR has no summary in frontmatter" \
      "Add 'summary: ...' to YAML frontmatter" \
      "https://cpm.dev/checks/adr-enforcement"
  fi
  if ! grep -q "^status:" "$f"; then
    findings_add "warning" "$f" "missing-status" \
      "ADR has no status in frontmatter" \
      "Add 'status: proposed|accepted|deprecated' to frontmatter" \
      "https://cpm.dev/checks/adr-enforcement"
  fi
done
