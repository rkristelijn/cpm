#!/usr/bin/env bash
# setup-pii-vault.sh — Create and configure the central PII patterns vault
#
# Creates: ~/.local/share/pii/patterns.d/
# Migrates: existing .config/.pii files from repos to the vault
#
# Usage:
#   cpm setup-pii-vault          # Interactive setup
#   cpm setup-pii-vault --check  # Verify vault health
#   cpm setup-pii-vault --migrate <repo-path>  # Migrate a repo's .pii to vault
#
# References:
#   NIST SP 800-122 — Guide to Protecting PII Confidentiality
#   ISO 27701 §7.4.5 — PII Minimization
#   ISO 27001 A.8.12 — Data Leakage Prevention
#   ISO 27001 A.8.31 — Separation of Environments

set -uo pipefail

PII_VAULT="${PII_VAULT:-$HOME/.local/share/pii}"
PATTERNS_DIR="$PII_VAULT/patterns.d"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
BOLD='\033[1m'

ok()    { echo -e "  ${GREEN}✓${NC}  $1"; }
warn()  { echo -e "  ${YELLOW}⚠${NC}  $1"; }
err()   { echo -e "  ${RED}✗${NC}  $1"; }
info()  { echo -e "  ${BLUE}ℹ${NC}  $1"; }

# ─────────────────────────────────────────────────────────────
# Check mode: verify vault health
# ─────────────────────────────────────────────────────────────
if [[ "${1:-}" == "--check" ]]; then
  echo -e "${BOLD}PII Vault Health Check${NC}"
  echo ""
  errors=0

  if [[ ! -d "$PII_VAULT" ]]; then
    err "Vault directory missing: $PII_VAULT"
    echo "    Run: cpm setup-pii-vault"
    exit 1
  fi

  # Directory permissions
  vault_perms=$(stat -f "%Lp" "$PII_VAULT" 2>/dev/null || stat -c "%a" "$PII_VAULT" 2>/dev/null)
  if [[ "$vault_perms" != "700" ]]; then
    err "Vault permissions are $vault_perms (should be 700)"
    ((errors++))
  else
    ok "Vault directory: $PII_VAULT (mode 700)"
  fi

  # Pattern files
  pattern_count=0
  total_patterns=0
  shopt -s nullglob
  for f in "$PATTERNS_DIR"/*.pii; do
    ((pattern_count++))
    file_perms=$(stat -f "%Lp" "$f" 2>/dev/null || stat -c "%a" "$f" 2>/dev/null)
    lines=$(grep -cvE '^\s*(#|$)' "$f" 2>/dev/null || echo 0)
    total_patterns=$((total_patterns + lines))
    if [[ "$file_perms" != "600" ]]; then
      warn "$(basename "$f"): permissions $file_perms (should be 600)"
      ((errors++))
    else
      ok "$(basename "$f"): $lines patterns (mode 600)"
    fi
  done
  shopt -u nullglob

  if [[ $pattern_count -eq 0 ]]; then
    err "No .pii files in $PATTERNS_DIR/"
    ((errors++))
  else
    info "Total: $total_patterns patterns across $pattern_count file(s)"
  fi

  echo ""
  if [[ $errors -eq 0 ]]; then
    ok "Vault is healthy"
  else
    err "$errors issue(s) found"
    exit 1
  fi
  exit 0
fi

# ─────────────────────────────────────────────────────────────
# Migrate mode: move a repo's .pii into the vault
# ─────────────────────────────────────────────────────────────
if [[ "${1:-}" == "--migrate" ]]; then
  REPO_PATH="${2:-$(pwd)}"
  REPO_PATH=$(cd "$REPO_PATH" && pwd)
  REPO_NAME=$(basename "$REPO_PATH")

  echo -e "${BOLD}Migrating PII from: $REPO_PATH${NC}"
  echo ""

  LOCAL_PII=""
  for candidate in "$REPO_PATH/.config/.pii" "$REPO_PATH/.pii"; do
    [[ -f "$candidate" ]] && { LOCAL_PII="$candidate"; break; }
  done

  if [[ -z "$LOCAL_PII" ]]; then
    info "No .pii file found in $REPO_PATH — nothing to migrate"
    exit 0
  fi

  line_count=$(grep -cvE '^\s*(#|$)' "$LOCAL_PII" 2>/dev/null || echo 0)
  info "Found $LOCAL_PII ($line_count patterns)"

  DEST="$PATTERNS_DIR/$REPO_NAME.pii"
  if [[ -f "$DEST" ]]; then
    warn "Destination already exists: $DEST"
    echo "    Merging unique patterns..."
    # Merge: add lines from local that don't exist in dest
    added=0
    while IFS= read -r line; do
      [[ "$line" =~ ^#.*$ ]] && continue
      [[ -z "$line" ]] && continue
      if ! grep -qF "$line" "$DEST"; then
        echo "$line" >> "$DEST"
        ((added++))
      fi
    done <"$LOCAL_PII"
    ok "Merged $added new pattern(s) into $(basename "$DEST")"
  else
    cp "$LOCAL_PII" "$DEST"
    chmod 600 "$DEST"
    ok "Copied to $DEST"
  fi

  echo ""
  echo "    Next steps:"
  echo "      1. Verify: cpm setup-pii-vault --check"
  echo "      2. Remove local file: rm $LOCAL_PII"
  echo "      3. (Optional) Add to .gitignore if not already"
  exit 0
fi

# ─────────────────────────────────────────────────────────────
# Default: interactive setup
# ─────────────────────────────────────────────────────────────
echo -e "${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║  PII Vault Setup                                        ║${NC}"
echo -e "${BOLD}║  Centralized PII pattern management                     ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "  This creates a secure, centralized store for PII detection patterns."
echo "  Patterns are stored outside of any git repository."
echo ""
echo "  Location: $PII_VAULT/patterns.d/"
echo ""
echo -e "  ${BLUE}Standards:${NC}"
echo "    • NIST SP 800-122 — Minimize PII, restrict access, separate from apps"
echo "    • ISO 27001 A.8.12 — Data Leakage Prevention"
echo "    • ISO 27001 A.8.31 — Separation of Environments"
echo "    • ISO 27701 §7.4.5 — PII Minimization"
echo ""

# Create structure
if [[ -d "$PATTERNS_DIR" ]]; then
  ok "Vault already exists: $PATTERNS_DIR"
else
  mkdir -p "$PATTERNS_DIR"
  chmod 700 "$PII_VAULT"
  chmod 700 "$PATTERNS_DIR"
  ok "Created: $PATTERNS_DIR (mode 700)"
fi

# Create README
if [[ ! -f "$PII_VAULT/README.md" ]]; then
  cat >"$PII_VAULT/README.md" <<'EOF'
# PII Vault

Centralized management of PII detection patterns.
Patterns are stored OUTSIDE of any git repository.

## Structure

```
patterns.d/
├── work-<org>.pii    — Organization-specific patterns
├── personal.pii      — Personal PII (BSN, IBAN, phone, etc.)
└── generic.pii       — Generic patterns (API keys, IPs, etc.)
```

## Usage

cpm check-pii.sh reads from this location automatically.
Override with: `export PII_VAULT=/custom/path`

## File format

One grep-compatible regex per line. Lines starting with # are comments.

## Permissions

- Directories: 700 (owner rwx only)
- Files: 600 (owner rw only)

## Standards

- NIST SP 800-122: Data minimization, access control, separation
- ISO 27001 A.8.12: Data Leakage Prevention
- ISO 27001 A.8.31: Separation of Environments
- ISO 27701 §7.4.5: PII Minimization
EOF
  chmod 600 "$PII_VAULT/README.md"
  ok "Created README.md"
fi

# Create example pattern file if vault is empty
if ! ls "$PATTERNS_DIR"/*.pii >/dev/null 2>&1; then
  cat >"$PATTERNS_DIR/example.pii" <<'EOF'
# example.pii — Example PII patterns (rename to your-org.pii)
#
# One pattern per line (grep -E compatible regex)
# Lines starting with # are comments.

# === Organization ===
# your-company-name
# your-internal-domain\.com
# gitlab\.internal\.example\.com

# === Colleague emails ===
# @internal\.example\.com

# === Infrastructure ===
# SERVERNAME-[0-9]+
# 10\.0\.0\.[0-9]+

# === Financial ===
# NL[0-9]{2}\s?[A-Z]{4}\s?[0-9]{10}

# === API Keys ===
# AKIA[0-9A-Z]{16}
# ghp_[a-zA-Z0-9]{36}
EOF
  chmod 600 "$PATTERNS_DIR/example.pii"
  ok "Created example.pii template"
  info "Edit $PATTERNS_DIR/example.pii and rename to match your org"
fi

echo ""
echo -e "${BOLD}Setup complete.${NC}"
echo ""
echo "  Verify: cpm setup-pii-vault --check"
echo "  Migrate repo: cpm setup-pii-vault --migrate /path/to/repo"
echo ""
echo "  Your check-pii.sh will now read from the vault automatically."
echo "  Existing .config/.pii files in repos will trigger a deprecation warning."
echo ""
