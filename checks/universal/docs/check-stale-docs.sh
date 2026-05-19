#!/usr/bin/env bash
# check-stale-docs.sh — Detect ADRs/designs that may be outdated.
#
# If code references an ADR (@see ADR-xxx) and the code was modified
# more recently than the ADR, the ADR might be stale.
#
# @see ADR-126 (traceability by design)
# @see ADR-016 (traceability matrix — staleness detection)
source "$(dirname "$0")/../../../lib/shell/check.sh"

STALE_DAYS="${CPM_STALE_DAYS:-30}"

# Find all @see ADR-NNN references in code
while IFS=: read -r file _ content; do
  [[ -z "$content" ]] && continue
  file="${file#./}"

  # Extract ADR number
  adr_num=$(echo "$content" | grep -oE 'ADR-[0-9]+' | head -1)
  [[ -z "$adr_num" ]] && continue

  # Find the ADR file
  adr_file=$(find docs/adrs -name "adr-${adr_num#ADR-}*" -type f 2>/dev/null | head -1)
  [[ -z "$adr_file" || ! -f "$adr_file" ]] && continue

  # Compare last-modified dates via git
  code_date=$(git log -1 --format=%at -- "$file" 2>/dev/null || echo 0)
  adr_date=$(git log -1 --format=%at -- "$adr_file" 2>/dev/null || echo 0)

  [[ "$code_date" -eq 0 || "$adr_date" -eq 0 ]] && continue

  # If code is newer than ADR by more than STALE_DAYS
  diff_days=$(( (code_date - adr_date) / 86400 ))
  if ((diff_days > STALE_DAYS)); then
    findings_add "warning" "$adr_file" "stale-adr" \
      "ADR may be outdated — code ($file) changed ${diff_days}d after ADR" \
      "Review and update the ADR, or touch it to confirm still valid" \
      ""
  fi
done < <(grep -rn "@see ADR-" --include='*.cpp' --include='*.h' --include='*.sh' --include='*.ts' --include='*.js' . 2>/dev/null || true)
