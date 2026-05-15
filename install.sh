#!/usr/bin/env bash
# install.sh — Install cpm to ~/.local/bin + ~/.local/share/cpm
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/rkristelijn/cpm/main/install.sh | bash
#   # or locally:
#   bash install.sh
#
# Installs:
#   ~/.local/bin/cpm          ← binary (or wrapper script)
#   ~/.local/share/cpm/       ← shell libs + checks

set -o errexit
set -o nounset
set -o pipefail

BIN_DIR="${CPM_BIN_DIR:-$HOME/.local/bin}"
LIB_DIR="${CPM_LIB_DIR:-$HOME/.local/share/cpm}"

echo ""
echo "  Installing cpm..."
echo ""

# Detect source (local clone or remote)
if [[ -f "lib/shell/ui.sh" ]]; then
  SRC="."
elif [[ -f "../cpm/lib/shell/ui.sh" ]]; then
  SRC="../cpm"
else
  echo "  ERROR: Run from cpm repo root or set CPM_SRC"
  exit 1
fi

# Create dirs
mkdir -p "$BIN_DIR" "$LIB_DIR"

# Copy libs + checks
cp -R "$SRC/lib/shell" "$LIB_DIR/"
cp -R "$SRC/lib/make" "$LIB_DIR/" 2>/dev/null || true
[[ -d "$SRC/checks" ]] && cp -R "$SRC/checks" "$LIB_DIR/"
[[ -f "$SRC/VERSION" ]] && cp "$SRC/VERSION" "$LIB_DIR/"

# Create wrapper script (calls shell libs, no compile needed)
cat > "$BIN_DIR/cpm" << 'WRAPPER'
#!/usr/bin/env bash
# cpm — Compliance Process Management
CPM_HOME="${CPM_LIB_DIR:-$HOME/.local/share/cpm}"
export CPM_HOME

case "${1:-help}" in
  check)  shift; bash "$CPM_HOME/shell/cpm-check.sh" "$@" ;;
  init)   echo "TODO: generate cpm.toml" ;;
  demo)   shift; bash "$CPM_HOME/shell/demo.sh" "$@" ;;
  status) echo "cpm $(cat "$CPM_HOME/VERSION" 2>/dev/null || echo "dev")"; echo "CPM_HOME=$CPM_HOME" ;;
  help|*) echo "cpm — Compliance Process Management"
          echo ""
          echo "  cpm check [fast|default|full]"
          echo "  cpm demo [spinners|ui|timers]"
          echo "  cpm init"
          echo "  cpm status"
          echo "  cpm help"
          ;;
esac
WRAPPER
chmod +x "$BIN_DIR/cpm"

# Shorthand symlink: 'c' → 'cpm'
if [[ ! -e "$BIN_DIR/c" ]]; then
  ln -sf "$BIN_DIR/cpm" "$BIN_DIR/c"
  echo "  ✓ Symlink: c → cpm"
fi

# Verify
echo "  ✓ Installed to $BIN_DIR/cpm"
echo "  ✓ Libs in $LIB_DIR/"
echo ""

# Check PATH
if ! echo "$PATH" | grep -q "$BIN_DIR"; then
  echo "  Add to your shell profile:"
  echo "    export PATH=\"$BIN_DIR:\$PATH\""
  echo ""
fi

echo "  Test: cpm status"
