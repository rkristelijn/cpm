#!/usr/bin/env bash
# term-index.sh — Extract technical terms and generate GLOSSARY.md
# @see ADR-019, ADR-129
set -o nounset
set -o pipefail

OUTPUT="docs/GLOSSARY.md"

echo "# Glossary (auto-generated)"
echo ""
echo "> Run: \`bash lib/shell/term-index.sh > docs/GLOSSARY.md\`"
echo ""
echo "| Term | Occurrences | Files |"
echo "|------|-------------|-------|"

# Extract: acronyms (2+ uppercase), CamelCase, and technical terms
{
  grep -rhoE '\b[A-Z]{2,}[a-z]*\b' docs/ src/ --include='*.md' --include='*.cpp' --include='*.h' 2>/dev/null
  grep -rhoE '\b[A-Z][a-z]+[A-Z][a-z]+\b' docs/ src/ --include='*.md' --include='*.cpp' 2>/dev/null
} | sort | uniq -c | sort -rn | head -50 | while read -r count term; do
  # Skip common words
  [[ ${#term} -lt 3 ]] && continue
  [[ "$term" == "The" || "$term" == "This" || "$term" == "NOT" || "$term" == "AND" || "$term" == "FOR" ]] && continue
  files=$(grep -rl "$term" docs/ src/ --include='*.md' --include='*.cpp' 2>/dev/null | wc -l | tr -d ' ')
  printf "| %s | %s | %s |\n" "$term" "$count" "$files"
done
