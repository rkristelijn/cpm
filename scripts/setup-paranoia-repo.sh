#!/usr/bin/env bash
# setup-paranoia-repo.sh — Create an encrypted git repo with obfuscated filenames
#
# Uses gocryptfs for transparent encryption + filename obfuscation.
# You work in cleartext locally (FUSE mount), only encrypted blobs get pushed.
#
# Usage:
#   cpm setup-paranoia-repo                      # Interactive setup
#   cpm setup-paranoia-repo --check              # Verify health
#   cpm setup-paranoia-repo --mount <repo>       # Mount existing paranoia repo
#   cpm setup-paranoia-repo --unmount <mount>    # Unmount
#
# Requirements: gocryptfs, macFUSE (macOS) or fuse3 (Linux)
#
# Architecture:
#   ~/git/lab/my-encrypted-repo/     ← git repo (push this)
#   │  ├── .gitignore                ← blocks cleartext
#   │  ├── gocryptfs.conf            ← encryption config (safe to commit)
#   │  ├── gocryptfs.diriv           ← directory IV (needed for decrypt)
#   │  └── cipherdir/                ← encrypted blobs + obfuscated names
#   │
#   ~/mnt/my-encrypted-repo/         ← FUSE mount (work here, never committed)
#      ├── notes.md                  ← cleartext, transparent
#      └── subfolder/file.txt        ← cleartext
#
# References:
#   - ADR-150: Paranoia Mode
#   - https://github.com/rfjakob/gocryptfs
#   - NIST SP 800-122, ISO 27001 A.8.24

set -uo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

ok() { echo -e "  ${GREEN}✓${NC}  $1"; }
warn() { echo -e "  ${YELLOW}⚠${NC}  $1"; }
err() { echo -e "  ${RED}✗${NC}  $1"; }
info() { echo -e "  ${BLUE}ℹ${NC}  $1"; }

MOUNT_BASE="${PARANOIA_MOUNT_BASE:-$HOME/mnt}"

# ─────────────────────────────────────────────────────────────
# Check mode
# ─────────────────────────────────────────────────────────────
if [[ "${1:-}" == "--check" ]]; then
  echo -e "${BOLD}Paranoia Repo Health Check${NC}"
  echo ""
  errors=0

  # gocryptfs installed?
  if command -v gocryptfs >/dev/null 2>&1; then
    ok "gocryptfs $(gocryptfs --version 2>&1 | head -1)"
  else
    err "gocryptfs not installed"
    echo "    macOS: brew install gocryptfs"
    echo "    Linux: apt install gocryptfs"
    ((errors++))
  fi

  # macFUSE (macOS) or fuse3 (Linux)
  if [[ "$(uname)" == "Darwin" ]]; then
    if [[ -d "/Library/Filesystems/macfuse.fs" ]] || kextstat 2>/dev/null | grep -q macfuse; then
      ok "macFUSE installed"
    else
      err "macFUSE not installed (brew install --cask macfuse)"
      ((errors++))
    fi
  else
    if command -v fusermount3 >/dev/null 2>&1 || command -v fusermount >/dev/null 2>&1; then
      ok "FUSE available"
    else
      err "fuse3 not installed (apt install fuse3)"
      ((errors++))
    fi
  fi

  # Active mounts
  echo ""
  echo -e "${BOLD}Active Paranoia Mounts${NC}"
  MOUNTS=$(mount | grep gocryptfs || true)
  if [[ -n "$MOUNTS" ]]; then
    echo "$MOUNTS" | while read -r line; do
      ok "$line"
    done
  else
    info "No active mounts"
  fi

  echo ""
  if [[ $errors -eq 0 ]]; then
    ok "Ready for paranoia mode"
  else
    err "$errors issue(s) — fix before setup"
  fi
  exit $errors
fi

# ─────────────────────────────────────────────────────────────
# Mount mode
# ─────────────────────────────────────────────────────────────
if [[ "${1:-}" == "--mount" ]]; then
  REPO_PATH="${2:-}"
  if [[ -z "$REPO_PATH" || ! -d "$REPO_PATH" ]]; then
    err "Usage: setup-paranoia-repo --mount <repo-path>"
    exit 1
  fi

  REPO_PATH=$(cd "$REPO_PATH" && pwd)
  REPO_NAME=$(basename "$REPO_PATH")
  CIPHER_DIR="$REPO_PATH/cipherdir"
  MOUNT_POINT="$MOUNT_BASE/$REPO_NAME"

  if [[ ! -f "$REPO_PATH/gocryptfs.conf" && ! -f "$CIPHER_DIR/gocryptfs.conf" ]]; then
    err "Not a paranoia repo: no gocryptfs.conf found in $REPO_PATH"
    exit 1
  fi

  # Determine cipher dir (config might be in root or cipherdir)
  if [[ -f "$CIPHER_DIR/gocryptfs.conf" ]]; then
    CONF_DIR="$CIPHER_DIR"
  else
    CONF_DIR="$REPO_PATH"
  fi

  mkdir -p "$MOUNT_POINT"

  if mount | grep -q "$MOUNT_POINT"; then
    warn "Already mounted at $MOUNT_POINT"
    exit 0
  fi

  echo -e "${BOLD}Mounting paranoia repo${NC}"
  info "Cipher: $CONF_DIR"
  info "Mount:  $MOUNT_POINT"
  echo ""

  gocryptfs "$CONF_DIR" "$MOUNT_POINT"
  if [[ $? -eq 0 ]]; then
    ok "Mounted at $MOUNT_POINT"
    info "Work in: $MOUNT_POINT"
    info "Unmount: cpm setup-paranoia-repo --unmount $MOUNT_POINT"
  else
    err "Mount failed"
    exit 1
  fi
  exit 0
fi

# ─────────────────────────────────────────────────────────────
# Unmount mode
# ─────────────────────────────────────────────────────────────
if [[ "${1:-}" == "--unmount" ]]; then
  MOUNT_POINT="${2:-}"
  if [[ -z "$MOUNT_POINT" ]]; then
    err "Usage: setup-paranoia-repo --unmount <mount-point>"
    exit 1
  fi

  if [[ "$(uname)" == "Darwin" ]]; then
    umount "$MOUNT_POINT" 2>/dev/null || diskutil unmount "$MOUNT_POINT" 2>/dev/null
  else
    fusermount -u "$MOUNT_POINT" 2>/dev/null || fusermount3 -u "$MOUNT_POINT" 2>/dev/null
  fi

  if mount | grep -q "$MOUNT_POINT"; then
    err "Failed to unmount $MOUNT_POINT"
    exit 1
  else
    ok "Unmounted $MOUNT_POINT"
    rmdir "$MOUNT_POINT" 2>/dev/null || true
  fi
  exit 0
fi

# ─────────────────────────────────────────────────────────────
# Backup mode
# ─────────────────────────────────────────────────────────────
if [[ "${1:-}" == "--backup" ]]; then
  MOUNT_OR_REPO="${2:-}"
  BACKUP_DEST="${3:-}"

  if [[ -z "$MOUNT_OR_REPO" ]]; then
    err "Usage: setup-paranoia-repo --backup <mount-or-repo> [destination]"
    echo ""
    echo "  Examples:"
    echo "    cpm setup-paranoia-repo --backup ~/mnt/my-journal"
    echo "    cpm setup-paranoia-repo --backup ~/mnt/my-journal /Volumes/USB-DRIVE/"
    exit 1
  fi

  if [[ ! -d "$MOUNT_OR_REPO" ]]; then
    err "Directory not found: $MOUNT_OR_REPO"
    exit 1
  fi

  REPO_NAME=$(basename "$MOUNT_OR_REPO")
  TIMESTAMP=$(date +%Y%m%d-%H%M%S)
  BACKUP_FILE="paranoia-backup-${REPO_NAME}-${TIMESTAMP}.zip"

  if [[ -z "$BACKUP_DEST" ]]; then
    BACKUP_DEST="$HOME/Backups/paranoia"
    mkdir -p "$BACKUP_DEST"
  fi

  if [[ ! -d "$BACKUP_DEST" ]]; then
    err "Destination not found: $BACKUP_DEST"
    exit 1
  fi

  FULL_PATH="$BACKUP_DEST/$BACKUP_FILE"

  echo -e "${BOLD}Paranoia Backup${NC}"
  echo ""
  info "Source:  $MOUNT_OR_REPO"
  info "Dest:    $FULL_PATH"
  FILE_COUNT=$(find "$MOUNT_OR_REPO" -type f | wc -l | tr -d ' ')
  info "Files:   $FILE_COUNT"
  echo ""
  echo "  Choose a backup password (separate from your mount password!):"
  echo ""
  zip -r -e -9 "$FULL_PATH" "$MOUNT_OR_REPO" -x "*.DS_Store" 2>/dev/null

  if [[ $? -eq 0 && -f "$FULL_PATH" ]]; then
    SIZE=$(du -h "$FULL_PATH" | cut -f1)
    ok "Backup created: $FULL_PATH ($SIZE)"
    echo ""
    echo -e "  ${BOLD}Security advice:${NC}"
    echo ""
    echo "    DO:"
    echo "      • Store on hardware-encrypted USB (iStorage, Apricorn, Kingston IronKey)"
    echo "      • Use a DIFFERENT password than your mount password"
    echo "      • Keep backup + password in separate physical locations"
    echo "      • Test restore: unzip -t \"$FULL_PATH\""
    echo ""
    echo "    DON'T:"
    echo "      • Store password file next to the backup"
    echo "      • Upload to unencrypted cloud"
    echo "      • Keep only one backup copy"
    echo ""
    echo "    EXCEPTION (hardware-encrypted USB with PIN):"
    echo "      If your USB has a hardware PIN (e.g., iStorage datAshur),"
    echo "      zip password + hardware PIN = double encryption."
    echo "      Storing password ON the drive is acceptable — the drive"
    echo "      itself is the 'something you have' factor."
    echo ""
    echo "  Restore: unzip -d /tmp/restore \"$FULL_PATH\""
  else
    err "Backup failed"
    exit 1
  fi
  exit 0
fi

# ─────────────────────────────────────────────────────────────
# Default: interactive setup
# ─────────────────────────────────────────────────────────────
echo -e "${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║  Paranoia Repo Setup                                     ║${NC}"
echo -e "${BOLD}║  Encrypted git with obfuscated filenames                 ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "  Creates a git repo where:"
echo "    • File contents are AES-256 encrypted"
echo "    • Filenames are obfuscated (unreadable without key)"
echo "    • You work in cleartext via a FUSE mount"
echo "    • Only encrypted blobs get committed/pushed"
echo ""
echo "  Performance: ~5% overhead (hardware AES-NI)"
echo ""

# Check prerequisites
if ! command -v gocryptfs >/dev/null 2>&1; then
  err "gocryptfs required but not installed"
  echo ""
  echo "  Install:"
  echo "    macOS: brew install gocryptfs"
  echo "    Linux: apt install gocryptfs"
  echo ""
  echo "  macOS also needs macFUSE:"
  echo "    brew install --cask macfuse"
  exit 1
fi

# Get repo name
echo -n "  Repo name (e.g., encrypted-journal): "
read -r REPO_NAME
if [[ -z "$REPO_NAME" ]]; then
  err "Name required"
  exit 1
fi

# Get repo location
DEFAULT_REPO_DIR="$HOME/git/lab/$REPO_NAME"
echo -n "  Repo location [$DEFAULT_REPO_DIR]: "
read -r REPO_DIR
REPO_DIR="${REPO_DIR:-$DEFAULT_REPO_DIR}"

# Get mount point
DEFAULT_MOUNT="$MOUNT_BASE/$REPO_NAME"
echo -n "  Mount point (your workspace) [$DEFAULT_MOUNT]: "
read -r MOUNT_POINT
MOUNT_POINT="${MOUNT_POINT:-$DEFAULT_MOUNT}"

echo ""
echo "  Summary:"
echo "    Git repo (encrypted):  $REPO_DIR"
echo "    Workspace (cleartext): $MOUNT_POINT"
echo ""
echo -n "  Continue? [Y/n]: "
read -r CONFIRM
[[ "${CONFIRM:-y}" =~ ^[Nn] ]] && exit 0

echo ""

# Create repo
mkdir -p "$REPO_DIR/cipherdir"
cd "$REPO_DIR"

# Init git
if [[ ! -d .git ]]; then
  git init -q
  ok "Git repo initialized"
fi

# Create .gitignore (block cleartext, allow encrypted)
cat >.gitignore <<'EOF'
# Paranoia mode: only encrypted content gets committed
# Cleartext files are NEVER committed

# Block common cleartext extensions
*.md
*.txt
*.doc*
*.pdf
*.xls*
*.csv
*.json
*.yml
*.yaml
*.toml
*.sh
*.py
*.js
*.ts

# Block mount point if accidentally inside repo
/mount/
/mnt/

# Allow encrypted content
!cipherdir/**
!gocryptfs.conf
!gocryptfs.diriv

# Git essentials
!.gitignore
!README.encrypted.md
EOF
ok "Created .gitignore (blocks all cleartext)"

# Create README
cat >README.encrypted.md <<EOF
# $REPO_NAME (Paranoia Mode)

This repository contains encrypted content with obfuscated filenames.

## Decrypt

\`\`\`bash
# Requires: gocryptfs + macFUSE/fuse3
mkdir -p mount
gocryptfs cipherdir mount
# Work in ./mount/ — changes auto-encrypt to cipherdir/
\`\`\`

## Architecture

- \`cipherdir/\` — Encrypted blobs (committed, pushed)
- \`mount/\` — FUSE mount point (local only, gitignored)
- \`gocryptfs.conf\` — Encryption config (safe to commit)

## Security

- AES-256-GCM content encryption
- EME wide-block filename encryption
- No cleartext ever touches git history
- Key derivation: scrypt (password → key)

Created with: \`cpm setup-paranoia-repo\`
EOF
ok "Created README.encrypted.md"

# Init gocryptfs (this prompts for password)
echo ""
info "Creating encrypted filesystem..."
info "Choose a strong password (this is your decryption key)"
echo ""
gocryptfs -init "$REPO_DIR/cipherdir"

if [[ $? -ne 0 ]]; then
  err "gocryptfs init failed"
  exit 1
fi
ok "Encrypted filesystem initialized"

# Move conf files to repo root for easier access
if [[ -f "$REPO_DIR/cipherdir/gocryptfs.conf" ]]; then
  # conf stays in cipherdir (that's where gocryptfs expects it)
  ok "Config stored in cipherdir/gocryptfs.conf"
fi

# Initial commit
git add .gitignore README.encrypted.md
git add cipherdir/gocryptfs.conf cipherdir/gocryptfs.diriv 2>/dev/null || true
git commit --no-verify -q -m "init: paranoia repo with gocryptfs encryption"
ok "Initial commit created"

# Mount
mkdir -p "$MOUNT_POINT"
echo ""
info "Mounting encrypted filesystem..."
gocryptfs "$REPO_DIR/cipherdir" "$MOUNT_POINT"

if [[ $? -eq 0 ]]; then
  ok "Mounted at $MOUNT_POINT"
else
  warn "Mount failed — you can mount later with:"
  echo "    cpm setup-paranoia-repo --mount $REPO_DIR"
fi

# Add pre-commit hook to prevent cleartext leaks
mkdir -p "$REPO_DIR/.git/hooks"
cat >"$REPO_DIR/.git/hooks/pre-commit" <<'HOOK'
#!/bin/bash
# Paranoia guard: block cleartext files from being committed
CLEARTEXT=$(git diff --cached --name-only | grep -vE '^(cipherdir/|\.gitignore|README\.encrypted\.md|gocryptfs\.)' || true)
if [[ -n "$CLEARTEXT" ]]; then
  echo "⛔ PARANOIA MODE: Cleartext files detected in commit!"
  echo "   Only cipherdir/ content should be committed."
  echo ""
  echo "   Blocked files:"
  echo "$CLEARTEXT" | sed 's/^/     /'
  echo ""
  echo "   Work in your mount point instead."
  exit 1
fi
HOOK
chmod +x "$REPO_DIR/.git/hooks/pre-commit"
ok "Pre-commit guard installed (blocks cleartext commits)"

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║  Setup complete!                                         ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "  Workspace:   $MOUNT_POINT"
echo "  Git repo:    $REPO_DIR"
echo ""
echo "  Daily workflow:"
echo "    1. Work in $MOUNT_POINT (cleartext, transparent)"
echo "    2. cd $REPO_DIR && git add cipherdir/ && git commit"
echo "    3. git push (only encrypted blobs leave your machine)"
echo ""
echo "  Commands:"
echo "    Mount:    cpm setup-paranoia-repo --mount $REPO_DIR"
echo "    Unmount:  cpm setup-paranoia-repo --unmount $MOUNT_POINT"
echo "    Backup:   cpm setup-paranoia-repo --backup $MOUNT_POINT"
echo "    Health:   cpm setup-paranoia-repo --check"
echo ""
echo "  ⚠ BACKUP YOUR PASSWORD — without it, data is unrecoverable"
echo ""
