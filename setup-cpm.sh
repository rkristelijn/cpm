#!/usr/bin/env bash
# Setup CPM in existing repo via symlink
# Usage: bash setup-cpm.sh

set -euo pipefail

CPM_PATH="${CPM_PATH:-../cpm}"

if [[ ! -d "$CPM_PATH" ]]; then
  echo "ERROR: CPM not found at $CPM_PATH"
  echo "Set CPM_PATH or clone cpm to ../cpm"
  exit 1
fi

# Create symlink
mkdir -p lib
ln -sf "$CPM_PATH/lib" lib/cpm
echo "✓ Symlinked lib/cpm → $CPM_PATH/lib"

# Update Makefile
if ! grep -q "include lib/cpm/make/common.mk" Makefile 2>/dev/null; then
  cat >> Makefile << 'EOF'

# CPM integration
include lib/cpm/make/common.mk
include lib/cpm/make/quality.mk
include lib/cpm/make/git.mk
include lib/cpm/make/registry.mk
EOF
  echo "✓ Added CPM includes to Makefile"
else
  echo "⊘ Makefile already has CPM includes"
fi

# Update scripts to use CPM ui.sh
if [[ -d scripts ]]; then
  echo "✓ Scripts can now use: source lib/cpm/shell/ui.sh"
fi

echo ""
echo "Setup complete! Test with:"
echo "  make help"
echo "  make check-fast"
