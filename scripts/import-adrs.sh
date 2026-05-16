#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "=== Consolidating ADRs to CPM ==="

total=0

# llama-cli
if [[ -d ../llama-cli/docs/adr ]]; then
  for adr in ../llama-cli/docs/adr/*.md; do
    [[ -f "$adr" ]] || continue
    name=$(basename "$adr")
    {
      echo "<!-- Origin: llama-cli -->"
      echo "<!-- Status: Proposed (imported $(date +%Y-%m-%d)) -->"
      echo ""
      cat "$adr"
    } >"docs/adr/llama-cli-$name"
    total=$((total + 1))
  done
  echo "✓ llama-cli: $total ADRs"
fi

# workspace-tui
count=0
if [[ -d ../workspace-tui/adr ]]; then
  for adr in ../workspace-tui/adr/*.md; do
    [[ -f "$adr" ]] || continue
    name=$(basename "$adr")
    {
      echo "<!-- Origin: workspace-tui -->"
      echo "<!-- Status: Proposed (imported $(date +%Y-%m-%d)) -->"
      echo ""
      cat "$adr"
    } >"docs/adr/workspace-tui-$name"
    count=$((count + 1))
    total=$((total + 1))
  done
  echo "✓ workspace-tui: $count ADRs"
fi

# dotfiles
count=0
if [[ -d ../dotfiles/docs/adr ]]; then
  for adr in ../dotfiles/docs/adr/*.md; do
    [[ -f "$adr" ]] || continue
    name=$(basename "$adr")
    {
      echo "<!-- Origin: dotfiles -->"
      echo "<!-- Status: Proposed (imported $(date +%Y-%m-%d)) -->"
      echo ""
      cat "$adr"
    } >"docs/adr/dotfiles-$name"
    count=$((count + 1))
    total=$((total + 1))
  done
  echo "✓ dotfiles: $count ADRs"
fi

echo ""
echo "✅ Total: $total ADRs imported"
echo "📁 Location: docs/adr/"
