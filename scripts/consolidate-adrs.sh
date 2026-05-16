#!/usr/bin/env bash
# Consolidate all ADRs from all repos into CPM
# Adds origin metadata and normalizes status to "Proposed"

set -euo pipefail

CPM_ADR_DIR="docs/adr"
TEMP_DIR=".tmp/adr-import"

mkdir -p "$TEMP_DIR"

# Source repos
REPOS=(
  "llama-cli:../llama-cli/docs/adr"
  "workspace-tui:../workspace-tui/adr"
  "dotfiles:../dotfiles/docs/adr"
)

echo "=== Consolidating ADRs ==="

total=0
for repo_spec in "${REPOS[@]}"; do
  repo="${repo_spec%%:*}"
  path="${repo_spec##*:}"
  
  if [[ ! -d "$path" ]]; then
    echo "⊘ $repo (not found)"
    continue
  fi
  
  count=$(find "$path" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
  echo "✓ $repo ($count ADRs)"
  
  # Copy ADRs with origin prefix
  find "$path" -name "*.md" 2>/dev/null | while read -r adr; do
    basename=$(basename "$adr")
    # Normalize to lowercase adr-NNN format
    normalized=$(echo "$basename" | sed 's/ADR-/adr-/g')
    # Add origin prefix: adr-NNN-title.md → llama-cli-adr-NNN-title.md
    target="$TEMP_DIR/${repo}-${normalized}"
    
    # Copy and add origin header
    {
      echo "<!-- Origin: $repo -->"
      echo "<!-- Status: Proposed (imported) -->"
      echo ""
      cat "$adr"
    } > "$target"
    
    total=$((total + 1))
  done
done

echo ""
echo "=== Normalizing format ==="

# Move to final location
if ls "$TEMP_DIR"/*.md 1> /dev/null 2>&1; then
  mv "$TEMP_DIR"/*.md "$CPM_ADR_DIR/"
  rmdir "$TEMP_DIR"
else
  echo "⚠ No files to move"
fi

echo "✓ Imported $total ADRs"
echo ""
echo "Location: $CPM_ADR_DIR/"
echo "Format: {origin}-adr-NNN-title.md"
