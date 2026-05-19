#!/usr/bin/env bash
# check-doc-type.sh — Detect document type (Diátaxis) and granularity level.
# @see ADR-129
#
# Types (Diátaxis): Tutorial, How-to, Reference, Explanation (ADR)
# Granularity: coarse (overview/vision) vs fine (implementation detail)
set -o nounset
set -o pipefail

echo ""
echo "  Document Type Analysis"
echo ""
printf "  %-50s %-12s %-10s %s\n" "File" "Type" "Grain" "Diagrams"
printf "  %-50s %-12s %-10s %s\n" "----" "----" "-----" "--------"

find docs -name '*.md' -not -path '*/node_modules/*' 2>/dev/null | sort | while read -r file; do
  [[ -f "$file" ]] || continue
  name="${file#./}"
  
  # Detect type
  type="unknown"
  if [[ "$name" == *adr-* ]]; then
    type="explanation"
  elif grep -qi "^# how to\|^## steps\|^## usage\|^## quick start" "$file" 2>/dev/null; then
    type="how-to"
  elif grep -qi "^# tutorial\|^## prerequisites\|^## step 1" "$file" 2>/dev/null; then
    type="tutorial"
  elif grep -qi "^## API\|^## parameters\|^## options\|^## commands\|^## configuration" "$file" 2>/dev/null; then
    type="reference"
  elif grep -qi "^## what\|^## why\|^## context\|^## decision" "$file" 2>/dev/null; then
    type="explanation"
  fi

  # Detect granularity
  grain="coarse"
  code_lines=$(awk '/^```/{f=!f;next} f{c++} END{print c+0}' "$file")
  total_lines=$(wc -l < "$file" | tr -d ' ')
  has_impl=$(grep -ciE "function|class |import |#include|def |const |var |let " "$file" 2>/dev/null || true)
  
  if ((code_lines > 20 || has_impl > 5)); then
    grain="fine"
  elif ((total_lines > 200)); then
    grain="medium"
  fi

  # Detect diagrams
  diagrams=0
  diagrams=$((diagrams + $(grep -c '```mermaid' "$file" 2>/dev/null || true)))
  diagrams=$((diagrams + $(grep -c '```plantuml' "$file" 2>/dev/null || true)))
  diagrams=$((diagrams + $(grep -c '!\[.*\](.*\.png\|.*\.svg\|.*\.drawio)' "$file" 2>/dev/null || true)))

  printf "  %-50s %-12s %-10s %s\n" "${name:0:50}" "$type" "$grain" "$diagrams"
done

echo ""

# Summary
echo "  Summary:"
find docs -name '*.md' -not -path '*/node_modules/*' 2>/dev/null | while read -r f; do
  if [[ "$f" == *adr-* ]]; then echo "explanation"
  elif grep -qi "how to\|usage\|quick start" "$f" 2>/dev/null; then echo "how-to"
  elif grep -qi "tutorial\|step 1" "$f" 2>/dev/null; then echo "tutorial"
  elif grep -qi "API\|parameters\|commands" "$f" 2>/dev/null; then echo "reference"
  else echo "unknown"; fi
done | sort | uniq -c | sort -rn | sed 's/^/    /'

echo ""
# Diagram coverage
total=$(find docs -name '*.md' -not -path '*/node_modules/*' 2>/dev/null | wc -l | tr -d ' ')
with_diagrams=$(grep -rl '```mermaid\|```plantuml\|\.drawio\|\.png\|\.svg' docs/ --include='*.md' 2>/dev/null | wc -l | tr -d ' ')
echo "  Diagram coverage: $with_diagrams/$total docs have visuals ($(( with_diagrams * 100 / (total > 0 ? total : 1) ))%)"
echo ""
