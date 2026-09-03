#!/usr/bin/env bash
# E2E test: install.sh / uninstall.sh roundtrip + backup restore
#
# Verifies:
#   1. install.sh installs binary + libs
#   2. uninstall.sh backs up to /tmp, removes files, unsets core.hooksPath
#   3. install.sh with CPM_RESTORE=1 restores config + hooks + re-hooks git
#   4. install.sh with CPM_RESTORE=0 skips restore
#
# Fully sandboxed: overrides HOME/XDG so the real machine is untouched.
set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"

REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INSTALL="$REPO_ROOT/install.sh"
UNINSTALL="$REPO_ROOT/uninstall.sh"
assert_file_exists "$INSTALL"
assert_file_exists "$UNINSTALL"

echo "=== E2E: install/uninstall roundtrip ==="

# ── Sandbox: isolated HOME + XDG under /tmp ──────────────────
SANDBOX="/tmp/cpm-e2e-instroundtrip-$$-$RANDOM"
mkdir -p "$SANDBOX"
export HOME="$SANDBOX"
export CPM_BIN_DIR="$SANDBOX/.local/bin"
export CPM_LIB_DIR="$SANDBOX/.local/share/cpm"
export XDG_CONFIG_HOME="$SANDBOX/.config"
# Hard-isolate git's global config so the real ~/.gitconfig is never touched,
# even if HOME resolution races. GIT_CONFIG_GLOBAL is git's explicit override.
export GIT_CONFIG_GLOBAL="$SANDBOX/.gitconfig"
touch "$GIT_CONFIG_GLOBAL"
CONFIG_DIR="$XDG_CONFIG_HOME/cpm"
HOOKS_DIR="$XDG_CONFIG_HOME/git/hooks"
BACKUP=""

cleanup() {
  rm -rf "$SANDBOX"
  [[ -n "$BACKUP" && -d "$BACKUP" ]] && rm -rf "$BACKUP"
}
trap cleanup EXIT

# git --global writes need an identity + our sandbox HOME
git config --global user.email "e2e@test.local" 2>/dev/null || true
git config --global user.name  "e2e" 2>/dev/null || true

# ── 1. install ───────────────────────────────────────────────
bash "$INSTALL" >/dev/null 2>&1
assert_file_exists "$CPM_BIN_DIR/cpm"
[[ -d "$CPM_LIB_DIR/shell" ]] || die "libs not installed"
echo "  ✓ install placed binary + libs"

# Simulate config + global hooks (as 'cpm hook --global' would create)
mkdir -p "$CONFIG_DIR" "$HOOKS_DIR"
echo "gitleaks=true" > "$CONFIG_DIR/hooks.conf"
printf '#!/bin/sh\n' > "$HOOKS_DIR/pre-commit"
chmod +x "$HOOKS_DIR/pre-commit"
git config --global core.hooksPath "$HOOKS_DIR"
echo "  ✓ simulated config + global hooks"

# ── 2. uninstall (backs up, removes, unsets hooksPath) ───────
UNINS_OUT=$(bash "$UNINSTALL" --yes 2>&1)
BACKUP=$(echo "$UNINS_OUT" | grep -oE '/tmp/cpm-uninstall-backup-[0-9-]+' | head -1)
[[ -n "$BACKUP" && -d "$BACKUP" ]] || die "backup dir not created"
[[ ! -e "$CPM_BIN_DIR/cpm" ]] || die "binary not removed"
[[ ! -e "$CONFIG_DIR" ]]      || die "config not removed"
[[ ! -e "$HOOKS_DIR" ]]       || die "hooks not removed"
[[ -z "$(git config --global --get core.hooksPath 2>/dev/null || true)" ]] || die "core.hooksPath not unset"
assert_file_exists "$BACKUP$CONFIG_DIR/hooks.conf"
echo "  ✓ uninstall backed up + removed + unset hooksPath"

# ── 3. reinstall with restore ────────────────────────────────
RESTORE_OUT=$(CPM_RESTORE=1 bash "$INSTALL" 2>&1)
assert_contains "$RESTORE_OUT" "Found a previous cpm backup" "detects backup"
assert_contains "$RESTORE_OUT" "Restored config"             "restores config"
assert_file_exists "$CONFIG_DIR/hooks.conf"
assert_contains "$(cat "$CONFIG_DIR/hooks.conf")" "gitleaks=true" "config content intact"
assert_file_exists "$HOOKS_DIR/pre-commit"
[[ "$(git config --global --get core.hooksPath)" == "$HOOKS_DIR" ]] || die "not re-hooked"
echo "  ✓ reinstall restored config + hooks + re-hooked git"

# ── 4. reinstall with CPM_RESTORE=0 skips ────────────────────
rm -f "$CONFIG_DIR/hooks.conf"
SKIP_OUT=$(CPM_RESTORE=0 bash "$INSTALL" 2>&1)
assert_contains "$SKIP_OUT" "Skipping restore" "honors CPM_RESTORE=0"
[[ ! -f "$CONFIG_DIR/hooks.conf" ]] || die "should not have restored when CPM_RESTORE=0"
echo "  ✓ CPM_RESTORE=0 skips restore"

echo "=== All install/uninstall roundtrip tests passed ==="
