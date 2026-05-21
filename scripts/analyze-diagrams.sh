#!/usr/bin/env bash
# analyze-diagrams.sh — Scan repos for diagram usage patterns
# @see ADR-144
#
# Usage: ./scripts/analyze-diagrams.sh <repos-dir>
# Output: diagram adoption stats for trend tracking

set -euo pipefail

DIR="${1:-$HOME/git/hub/top-repos}"

if [ ! -d "$DIR" ]; then
  echo "Usage: $0 <repos-dir>"
  exit 1
fi

cd "$DIR"
TOTAL=$(ls -d */ 2>/dev/null | wc -l | tr -d ' ')

echo "=== Diagram Usage Analysis ($(date +%Y-%m-%d)) ==="
echo "  Repos scanned: $TOTAL"
echo "  Directory: $DIR"
echo ""

# Mermaid
mermaid=$(grep -rl '```mermaid' . --include='*.md' 2>/dev/null | cut -d/ -f2 | sort -u | wc -l | tr -d ' ')
echo "  Mermaid:       $mermaid repos ($((mermaid * 100 / TOTAL))%)"

# PlantUML
plantuml=$(grep -rl '```plantuml\|@startuml' . --include='*.md' --include='*.puml' 2>/dev/null | cut -d/ -f2 | sort -u | wc -l | tr -d ' ')
echo "  PlantUML:      $plantuml repos ($((plantuml * 100 / TOTAL))%)"

# DrawIO
drawio=$(find . -maxdepth 3 -name '*.drawio' 2>/dev/null | cut -d/ -f2 | sort -u | wc -l | tr -d ' ')
echo "  DrawIO:        $drawio repos ($((drawio * 100 / TOTAL))%)"

# SVG
svg=$(find . -maxdepth 3 -name '*.svg' 2>/dev/null | cut -d/ -f2 | sort -u | wc -l | tr -d ' ')
echo "  SVG:           $svg repos ($((svg * 100 / TOTAL))%)"

# PNG in docs
png=$(find . -maxdepth 4 -path '*/docs/*.png' -o -path '*/images/*.png' 2>/dev/null | cut -d/ -f2 | sort -u | wc -l | tr -d ' ')
echo "  PNG (docs):    $png repos ($((png * 100 / TOTAL))%)"

# ASCII art
ascii=$(grep -rl '┌\|├\|└\|│\|─\|+--' . --include='*.md' 2>/dev/null | cut -d/ -f2 | sort -u | wc -l | tr -d ' ')
echo "  ASCII art:     $ascii repos ($((ascii * 100 / TOTAL))%)"

# D2
d2=$(find . -maxdepth 3 -name '*.d2' 2>/dev/null | cut -d/ -f2 | sort -u | wc -l | tr -d ' ')
echo "  D2:            $d2 repos ($((d2 * 100 / TOTAL))%)"

# Graphviz
dot=$(find . -maxdepth 3 -name '*.dot' -o -name '*.gv' 2>/dev/null | cut -d/ -f2 | sort -u | wc -l | tr -d ' ')
echo "  Graphviz:      $dot repos ($((dot * 100 / TOTAL))%)"

echo ""
echo "  === Mermaid diagram types ==="
grep -rh '```mermaid' -A1 . --include='*.md' 2>/dev/null | grep -v '```' | grep -v '^--$' | awk '{print $1}' | sort | uniq -c | sort -rn | head -10 | while read count type; do
  echo "    $count  $type"
done

echo ""
echo "  === Top mermaid users ==="
for repo in */; do
  count=$(grep -rc '```mermaid' "$repo" --include='*.md' 2>/dev/null | awk -F: '{s+=$2}END{print s+0}')
  [ "$count" -gt 3 ] && printf "    %5d  %s\n" "$count" "${repo%/}"
done | sort -rn | head -10
