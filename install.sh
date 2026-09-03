#!/usr/bin/env bash
# cpm:ignore-file SH-QUAL-014 — detector/test source: contains the patterns it checks for
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
#
# Restore:
#   If a previous uninstall backup exists (/tmp/cpm-uninstall-backup-*),
#   offers to restore config (~/.config/cpm), global hooks, and the git
#   core.hooksPath setting. Interactive prompt; override with
#   CPM_RESTORE=1 (always restore) or CPM_RESTORE=0 (never).

set -o errexit
set -o nounset
set -o pipefail

BIN_DIR="${CPM_BIN_DIR:-$HOME/.local/bin}"
LIB_DIR="${CPM_LIB_DIR:-$HOME/.local/share/cpm}"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/cpm"
if [[ -n "${GLOBAL_HOOKS_DIR:-}" ]]; then
  HOOKS_DIR="$GLOBAL_HOOKS_DIR"
elif [[ -n "${XDG_CONFIG_HOME:-}" ]]; then
  HOOKS_DIR="$XDG_CONFIG_HOME/git/hooks"
else
  HOOKS_DIR="$HOME/.config/git/hooks"
fi

echo ""
echo "  Installing cpm..."
echo ""

# ─────────────────────────────────────────────────────────────
# Restore from a previous uninstall backup (/tmp/cpm-uninstall-backup-*)
# Focus: config files (~/.config/cpm), global hooks dir, and the
# git core.hooksPath setting — the things `cpm hook`/`unhook` manage.
# Prompt only when interactive; override via CPM_RESTORE=1 (yes) / 0 (no).
# ─────────────────────────────────────────────────────────────
maybe_restore_backup() {
  local latest=""
  # Glob follows the /tmp → /private/tmp symlink on macOS reliably;
  # find -maxdepth 1 does not always. nullglob keeps it clean when none.
  local d
  shopt -s nullglob
  for d in /tmp/cpm-uninstall-backup-*/; do
    [[ -d "$d" ]] || continue
    latest="${d%/}"   # strip trailing slash; loop is sorted ascending
  done
  shopt -u nullglob
  [[ -n "$latest" && -d "$latest" ]] || return 0

  # Is there anything worth restoring (config / hooks / git note)?
  local has_config=false has_hooks=false
  [[ -d "$latest$CONFIG_DIR" ]] && has_config=true
  [[ -d "$latest$HOOKS_DIR"  ]] && has_hooks=true
  $has_config || $has_hooks || return 0

  echo "  Found a previous cpm backup: $latest"
  $has_config && echo "    • config: $CONFIG_DIR"
  $has_hooks  && echo "    • hooks:  $HOOKS_DIR"
  [[ -f "$latest/git-config-note.txt" ]] && echo "    • git core.hooksPath setting"

  # Decide whether to restore
  local do_restore=false
  case "${CPM_RESTORE:-}" in
    1|yes|true)  do_restore=true ;;
    0|no|false)  do_restore=false; echo "  Skipping restore (CPM_RESTORE=0)"; return 0 ;;
    *)
      if [[ -t 0 ]]; then
        local reply
        read -r -p "  Restore config + hooks from this backup? [y/N] " reply
        [[ "$reply" =~ ^[Yy]$ ]] && do_restore=true
      else
        echo "  Non-interactive shell — skipping restore."
        echo "  To restore later: CPM_RESTORE=1 bash install.sh"
        return 0
      fi
      ;;
  esac
  $do_restore || return 0

  # Restore config dir
  if $has_config; then
    mkdir -p "$(dirname "$CONFIG_DIR")"
    if cp -R "$latest$CONFIG_DIR" "$(dirname "$CONFIG_DIR")/"; then
      echo "  ✓ Restored config → $CONFIG_DIR"
    else
      echo "  ⚠ Could not restore config"
    fi
  fi

  # Restore hooks dir
  if $has_hooks; then
    mkdir -p "$(dirname "$HOOKS_DIR")"
    if cp -R "$latest$HOOKS_DIR" "$(dirname "$HOOKS_DIR")/"; then
      echo "  ✓ Restored hooks → $HOOKS_DIR"
    else
      echo "  ⚠ Could not restore hooks"
    fi
  fi

  # Restore git core.hooksPath (re-hook)
  if [[ -f "$latest/git-config-note.txt" ]]; then
    local saved_hp
    saved_hp=$(sed -n 's/^core.hooksPath=//p' "$latest/git-config-note.txt")
    if [[ -n "$saved_hp" ]]; then
      if git config --global core.hooksPath "$saved_hp"; then
        echo "  ✓ Re-hooked: git core.hooksPath = $saved_hp"
      else
        echo "  ⚠ Could not set core.hooksPath"
      fi
    fi
  elif $has_hooks; then
    # No note but hooks were restored — point git at them
    if git config --global core.hooksPath "$HOOKS_DIR"; then
      echo "  ✓ Re-hooked: git core.hooksPath = $HOOKS_DIR"
    else
      echo "  ⚠ Could not set core.hooksPath"
    fi
  fi
  echo ""
}

maybe_restore_backup

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
# cpm — code project maturity
CPM_HOME="${CPM_LIB_DIR:-$HOME/.local/share/cpm}"
export CPM_HOME

cmd_version() {
  local toml="cpm.toml"
  [[ -f "$toml" ]] || { echo "no cpm.toml found"; return 1; }
  local ver; ver=$(awk -F'"' '/^version/{print $2}' "$toml")
  case "${1:-}" in
    "") echo "$ver" ;;
    major|minor|patch)
      IFS='.' read -r ma mi pa <<< "$ver"
      case "$1" in
        major) ma=$((ma+1)); mi=0; pa=0 ;;
        minor) mi=$((mi+1)); pa=0 ;;
        patch) pa=$((pa+1)) ;;
      esac
      sed -i'' "s/version = \"$ver\"/version = \"$ma.$mi.$pa\"/" "$toml"
      echo "$ma.$mi.$pa" ;;
    *) echo "usage: cpm version [major|minor|patch]"; return 1 ;;
  esac
}

case "${1:-help}" in
  maturity) bash "$CPM_HOME/shell/maturity.sh" ;;
  version) shift; cmd_version "$@" ;;
  init)    echo "TODO: generate cpm.toml" ;;
  status)  echo "cpm $(awk -F'"' '/^version/{print $2}' cpm.toml 2>/dev/null || echo "dev")"; echo "CPM_HOME=$CPM_HOME" ;;
  help|*)  echo "cpm — code project maturity"
           echo ""
           echo "  cpm maturity"
           echo "  cpm version [major|minor|patch]"
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
