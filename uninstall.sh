#!/usr/bin/env bash
# cpm:ignore-file SH-QUAL-014 SCA-028 STYLE-020 — installer/uninstaller: references paths & patterns it manages
# uninstall.sh — Cleanly remove cpm from this machine
#
# Removes everything installed by install.sh, `make install`, and
# `cpm hook --global`. Backs up removed files to /tmp first so nothing
# is lost. Does NOT touch Homebrew/apt installs (use their own uninstall).
#
# Usage:
#   bash uninstall.sh              # back up, then remove (asks before sudo)
#   bash uninstall.sh --dry-run    # show what would happen, change nothing
#   bash uninstall.sh --yes        # no prompts (still backs up first)
#   bash uninstall.sh --no-backup  # skip the /tmp backup
#
# Env overrides (match install.sh / setup-global-hooks.sh):
#   CPM_BIN_DIR   (default ~/.local/bin)
#   CPM_LIB_DIR   (default ~/.local/share/cpm)

set -o errexit
set -o nounset
set -o pipefail

# ── Colors ───────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'
ok()   { echo -e "  ${GREEN}✓${NC}  $1"; }
warn() { echo -e "  ${YELLOW}⚠${NC}  $1"; }
err()  { echo -e "  ${RED}✗${NC}  $1"; }
info() { echo -e "  ${BLUE}ℹ${NC}  $1"; }

# ── Flags ────────────────────────────────────────────────────
DRY_RUN=false
ASSUME_YES=false
DO_BACKUP=true
for arg in "$@"; do
  case "$arg" in
    --dry-run)   DRY_RUN=true ;;
    --yes|-y)    ASSUME_YES=true ;;
    --no-backup) DO_BACKUP=false ;;
    -h|--help)   grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) err "Unknown option: $arg"; exit 1 ;;
  esac
done

# ── Paths (mirror install.sh + setup-global-hooks.sh) ────────
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
USR_LOCAL_BIN="/usr/local/bin/cpm"

BACKUP_DIR="/tmp/cpm-uninstall-backup-$(date +%Y%m%d-%H%M%S)"

echo ""
echo -e "  ${BOLD}Uninstalling cpm${NC}"
$DRY_RUN && info "DRY RUN — nothing will be changed"
echo ""

# ── Helpers ──────────────────────────────────────────────────
backup_path() {
  # $1 = source path to back up (preserving structure under BACKUP_DIR)
  local src="$1"
  [[ -e "$src" || -L "$src" ]] || return 0
  $DO_BACKUP || return 0
  local dest="$BACKUP_DIR${src}"
  if $DRY_RUN; then
    info "would back up  $src  →  $dest"
    return 0
  fi
  mkdir -p "$(dirname "$dest")"
  if cp -R "$src" "$dest" 2>/dev/null; then
    ok "backed up $src"
  else
    warn "could not back up $src"
  fi
}

remove_path() {
  # $1 = path to remove. $2 = "sudo" to use sudo.
  local target="$1"; local use_sudo="${2:-}"
  [[ -e "$target" || -L "$target" ]] || return 0
  if $DRY_RUN; then
    info "would remove   $target${use_sudo:+  (sudo)}"
    return 0
  fi
  if [[ "$use_sudo" == "sudo" ]]; then
    if sudo rm -rf "$target"; then ok "removed $target (sudo)"; else err "failed to remove $target"; fi
  else
    if rm -rf "$target"; then ok "removed $target"; else err "failed to remove $target"; fi
  fi
}

confirm() {
  $ASSUME_YES && return 0
  $DRY_RUN && return 0
  local reply
  read -r -p "  $1 [y/N] " reply
  [[ "$reply" =~ ^[Yy]$ ]]
}

# ── Detect Homebrew / apt managed installs (leave them alone) ─
if command -v brew >/dev/null 2>&1 && brew list cpm >/dev/null 2>&1; then
  warn "cpm is installed via Homebrew — run 'brew uninstall rkristelijn/tap/cpm' separately"
fi
if command -v dpkg >/dev/null 2>&1 && dpkg -s cpm >/dev/null 2>&1; then
  warn "cpm is installed via apt — run 'sudo apt remove cpm' separately"
fi

# ── 1. Backup everything first ───────────────────────────────
if $DO_BACKUP; then
  echo -e "  ${BOLD}Backing up to $BACKUP_DIR${NC}"
  backup_path "$BIN_DIR/cpm"
  backup_path "$BIN_DIR/c"
  backup_path "$LIB_DIR"
  backup_path "$CONFIG_DIR"
  backup_path "$HOOKS_DIR"
  [[ -e "$USR_LOCAL_BIN" ]] && backup_path "$USR_LOCAL_BIN"
  # Save current git hooksPath so it can be restored if needed
  if ! $DRY_RUN; then
    hp=$(git config --global --get core.hooksPath 2>/dev/null || true)
    if [[ -n "$hp" ]]; then
      mkdir -p "$BACKUP_DIR"
      echo "core.hooksPath=$hp" > "$BACKUP_DIR/git-config-note.txt"
    fi
  fi
  echo ""
else
  warn "backup skipped (--no-backup)"
  echo ""
fi

# ── 2. Remove user-space install (install.sh) ────────────────
echo -e "  ${BOLD}User install (~/.local)${NC}"
# Only remove the 'c' symlink if it points at our cpm
if [[ -L "$BIN_DIR/c" ]]; then
  link_target="$(readlink "$BIN_DIR/c" || true)"
  if [[ "$link_target" == *"/cpm" ]]; then
    remove_path "$BIN_DIR/c"
  else
    warn "skipping $BIN_DIR/c (points elsewhere: $link_target)"
  fi
fi
remove_path "$BIN_DIR/cpm"
remove_path "$LIB_DIR"
echo ""

# ── 3. Remove global hooks + config (cpm hook --global) ──────
echo -e "  ${BOLD}Global git hooks${NC}"
current_hp="$(git config --global --get core.hooksPath 2>/dev/null || true)"
if [[ -n "$current_hp" ]]; then
  if $DRY_RUN; then
    info "would unset git config --global core.hooksPath (= $current_hp)"
  else
    if git config --global --unset core.hooksPath 2>/dev/null; then
      ok "unset core.hooksPath (was $current_hp)"
    else
      warn "could not unset core.hooksPath"
    fi
  fi
fi
remove_path "$HOOKS_DIR"
remove_path "$CONFIG_DIR"
echo ""

# ── 4. Remove system install (make install → /usr/local/bin) ─
if [[ -e "$USR_LOCAL_BIN" ]]; then
  echo -e "  ${BOLD}System install (/usr/local/bin)${NC}"
  owner="$(stat -f '%Su' "$USR_LOCAL_BIN" 2>/dev/null || stat -c '%U' "$USR_LOCAL_BIN" 2>/dev/null || echo unknown)"
  if [[ "$owner" == "$(id -un)" ]]; then
    remove_path "$USR_LOCAL_BIN"
  else
    warn "$USR_LOCAL_BIN owned by '$owner' — needs sudo"
    if confirm "Remove $USR_LOCAL_BIN with sudo?"; then
      remove_path "$USR_LOCAL_BIN" sudo
    else
      info "skipped $USR_LOCAL_BIN — remove manually: sudo rm $USR_LOCAL_BIN"
    fi
  fi
  echo ""
fi

# ── Done ─────────────────────────────────────────────────────
echo -e "  ${BOLD}Done${NC}"
if $DRY_RUN; then
  info "dry run complete — no changes made"
else
  $DO_BACKUP && info "backup saved at: $BACKUP_DIR"
  info "verify: command -v cpm  (should be empty, or a brew/apt path)"
fi
echo ""
