#!/usr/bin/env bash
# check-doc-jargon.sh — Clarity score: ratio of common English vs jargon.
# @see ADR-129
source "$(dirname "$0")/../../../lib/shell/check.sh"

# Top 200 common English words (simplified check)
COMMON='the|be|to|of|and|a|in|that|have|i|it|for|not|on|with|he|as|you|do|at|this|but|his|by|from|they|we|her|she|or|an|will|my|one|all|would|there|their|what|so|up|out|if|about|who|get|which|go|me|when|make|can|like|time|no|just|him|know|take|people|into|year|your|good|some|could|them|see|other|than|then|now|look|only|come|its|over|think|also|back|after|use|two|how|our|work|first|well|way|even|new|want|because|any|these|give|day|most|us'

while IFS= read -r file; do
  [[ -f "$file" ]] || continue
  name="${file#./}"
  
  total=$(cat "$file" | tr -cs 'a-zA-Z' '\n' | grep -c . 2>/dev/null || echo 0)
  ((total < 50)) && continue
  
  common_count=$(cat "$file" | tr -cs 'a-zA-Z' '\n' | tr 'A-Z' 'a-z' | grep -cEw "$COMMON" 2>/dev/null || echo 0)
  jargon_pct=$(( (total - common_count) * 100 / total ))
  
  if ((jargon_pct > 70)); then
    findings_add "warning" "$name" "doc-high-jargon" \
      "Jargon score: ${jargon_pct}% (>70% threshold)" \
      "Simplify language or add glossary links" ""
  fi
done < <(find docs -name '*.md' -not -path '*/node_modules/*' 2>/dev/null)
