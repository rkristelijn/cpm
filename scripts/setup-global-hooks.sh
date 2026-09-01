#!/usr/bin/env bash
# cpm:ignore-file SCA-028 SH-QUAL-014 STYLE-020 — detector/test source: contains the patterns it checks for
# setup-global-hooks.sh — Install global git pre-commit security hooks
#
# Installs: gitleaks + semgrep + PII detection + filesize guard
# Method: git config --global core.hooksPath
#
# Usage:
#   cpm setup-global-hooks           # Install hooks
#   cpm setup-global-hooks --check   # Verify installation
#   cpm setup-global-hooks --remove  # Remove global hooks
#
# Requirements: git, gitleaks, semgrep (optional but recommended)

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

# Hooks location (relative to this script's repo)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CPM_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Default hooks dir — can be overridden via GLOBAL_HOOKS_DIR env var
# Falls back to XDG standard location
if [[ -n "${GLOBAL_HOOKS_DIR:-}" ]]; then
  HOOKS_DIR="$GLOBAL_HOOKS_DIR"
elif [[ -n "${XDG_CONFIG_HOME:-}" ]]; then
  HOOKS_DIR="$XDG_CONFIG_HOME/git/hooks"
else
  HOOKS_DIR="$HOME/.config/git/hooks"
fi

# ─────────────────────────────────────────────────────────────
# Check mode
# ─────────────────────────────────────────────────────────────
if [[ "${1:-}" == "--check" ]]; then
  echo -e "${BOLD}Global Hooks Health Check${NC}"
  echo ""
  errors=0

  # Git config
  CURRENT=$(git config --global core.hooksPath 2>/dev/null || true)
  if [[ -n "$CURRENT" ]]; then
    ok "core.hooksPath = $CURRENT"
  else
    err "core.hooksPath not set"
    ((errors++))
  fi

  # Hooks exist
  for hook in pre-commit commit-msg; do
    if [[ -x "${CURRENT:-/dev/null}/$hook" ]]; then
      ok "$hook hook: executable"
    else
      err "$hook hook: missing or not executable"
      ((errors++))
    fi
  done

  # Lib scripts
  for lib in fix-trailing-whitespace.sh fix-end-of-file.sh fix-mixed-endings.sh gitleaks.sh no-secrets-fast.sh semgrep.sh no-pii.sh no-large-files.sh no-dangerous-shell.sh no-missing-gitignore.sh no-main.sh no-conflict-markers.sh no-artifacts.sh no-syntax-errors.sh no-broken-symlinks.sh no-debug.sh no-binaries.sh no-empty-files.sh no-mixed-endings.sh no-dei-violations.sh; do
    if [[ -x "${CURRENT:-/dev/null}/lib/$lib" ]]; then
      ok "lib/$lib: present"
    else
      if [[ "$lib" == "no-secrets-fast.sh" ]]; then
        warn "lib/$lib: missing (regex fallback for gitleaks — optional)"
      else
        err "lib/$lib: missing"
        ((errors++))
      fi
    fi
  done

  echo ""
  echo -e "${BOLD}Tool Availability${NC}"
  echo ""

  # gitleaks
  if command -v gitleaks >/dev/null 2>&1; then
    ok "gitleaks $(gitleaks version 2>/dev/null)"
  else
    err "gitleaks not installed (brew install gitleaks)"
    ((errors++))
  fi

  # semgrep
  if command -v semgrep >/dev/null 2>&1; then
    ok "semgrep $(semgrep --version 2>/dev/null | head -1)"
  else
    warn "semgrep not installed (brew install semgrep) — hook will skip gracefully"
  fi

  # PII vault
  PII_VAULT="${PII_VAULT:-$HOME/.local/share/pii}"
  if [[ -d "$PII_VAULT/patterns.d" ]]; then
    count=$(ls "$PII_VAULT/patterns.d"/*.pii 2>/dev/null | wc -l | tr -d ' ')
    ok "PII vault: $count pattern file(s) in $PII_VAULT"
  else
    warn "PII vault not set up (run: cpm setup-pii-vault)"
  fi

  echo ""
  if [[ $errors -eq 0 ]]; then
    ok "Everything looks good"
  else
    err "$errors issue(s) found"
  fi
  exit $errors
fi

# ─────────────────────────────────────────────────────────────
# Remove mode
# ─────────────────────────────────────────────────────────────
if [[ "${1:-}" == "--remove" ]]; then
  echo -e "${BOLD}Removing global hooks${NC}"
  git config --global --unset core.hooksPath 2>/dev/null
  ok "Removed core.hooksPath from git config"
  info "Repos will now use their own .git/hooks/ as default"
  exit 0
fi

# ─────────────────────────────────────────────────────────────
# Global hooks config: ~/.config/cpm/hooks.conf
# ─────────────────────────────────────────────────────────────
HOOKS_CONF="${XDG_CONFIG_HOME:-$HOME/.config}/cpm/hooks.conf"

# All available checks with defaults
ALL_CHECKS="fix-trailing-whitespace fix-end-of-file fix-mixed-endings gitleaks semgrep no-secrets-fast no-pii no-large-files conventional-commit no-dangerous-shell no-main no-conflict-markers no-artifacts no-syntax-errors no-broken-symlinks no-missing-gitignore no-debug no-binaries no-empty-files no-mixed-endings no-wip-commit no-unconventional-casing no-typos no-dei-violations no-absolute-paths"
# Optional (off by default)
OPT_CHECKS="owasp supply-chain"

init_hooks_conf() {
  local dir
  dir=$(dirname "$HOOKS_CONF")
  [[ -d "$dir" ]] || mkdir -p "$dir"
  if [[ ! -f "$HOOKS_CONF" ]]; then
    cat >"$HOOKS_CONF" <<EOF
# cpm global hooks configuration
# Toggle checks: true = enabled, false = disabled
# Edit manually or use: cpm hook --global --enable/--disable <check>

# Autofix — fix and re-stage automatically
fix-trailing-whitespace=true
fix-end-of-file=true
fix-mixed-endings=true

[checks]
# Blocking — commit rejected if these fail
gitleaks=true
semgrep=true
no-secrets-fast=true
no-pii=true
no-large-files=true
conventional-commit=true
no-dangerous-shell=true
no-main=true
no-conflict-markers=true
no-artifacts=true
no-syntax-errors=true
no-broken-symlinks=true

# Warning — prompt to continue, don't block
no-missing-gitignore=true
no-debug=true
no-binaries=true
no-empty-files=true
no-mixed-endings=true
no-unconventional-casing=true
no-typos=true
no-dei-violations=true
no-absolute-paths=true

# Commit-msg — runs on commit message
no-wip-commit=true

# Optional checks (opt-in)
owasp=false
supply-chain=false
EOF
    info "Created $HOOKS_CONF"
  fi
}

read_check() {
  local name="$1"
  if [[ -f "$HOOKS_CONF" ]]; then
    local val
    val=$(grep -E "^${name}=" "$HOOKS_CONF" 2>/dev/null | tail -1 | cut -d= -f2 | tr -d ' ')
    echo "${val:-true}"
  else
    echo "true"
  fi
}

write_check() {
  local name="$1" val="$2"
  init_hooks_conf
  if grep -qE "^${name}=" "$HOOKS_CONF" 2>/dev/null; then
    # Update existing (portable in-place: temp file + atomic mv)
    local tmp
    tmp=$(mktemp "${HOOKS_CONF}.XXXXXX")
    sed "s/^${name}=.*/${name}=${val}/" "$HOOKS_CONF" >"$tmp"
    mv "$tmp" "$HOOKS_CONF"
  else
    # Append
    echo "${name}=${val}" >>"$HOOKS_CONF"
  fi
}

# ─────────────────────────────────────────────────────────────
# Status mode: show what's on/off
# ─────────────────────────────────────────────────────────────
if [[ "${1:-}" == "--status" ]]; then
  init_hooks_conf
  echo -e "${BOLD}Global Hook Checks${NC}  ${BLUE}${HOOKS_CONF}${NC}"
  echo ""
  echo -e "  ${BOLD}Default checks:${NC}"
  for check in $ALL_CHECKS; do
    val=$(read_check "$check")
    if [[ "$val" == "true" ]]; then
      echo -e "    ${GREEN}●${NC}  $check"
    else
      echo -e "    ${RED}○${NC}  $check  ${YELLOW}(disabled)${NC}"
    fi
  done
  echo ""
  echo -e "  ${BOLD}Optional checks:${NC}"
  for check in $OPT_CHECKS; do
    val=$(read_check "$check")
    if [[ "$val" == "true" ]]; then
      echo -e "    ${GREEN}●${NC}  $check  ${BLUE}(opt-in, enabled)${NC}"
    else
      echo -e "    ○  $check"
    fi
  done
  echo ""
  info "Toggle: cpm hook --global --enable <check>"
  info "Toggle: cpm hook --global --disable <check>"
  exit 0
fi

# ─────────────────────────────────────────────────────────────
# Enable/disable mode
# ─────────────────────────────────────────────────────────────
if [[ "${1:-}" == "--enable" || "${1:-}" == "--disable" ]]; then
  action="${1#--}"
  check="${2:-}"
  if [[ -z "$check" ]]; then
    err "Usage: cpm hook --global --${action} <check>"
    echo ""
    echo "  Available checks: $ALL_CHECKS $OPT_CHECKS"
    exit 1
  fi
  # Validate check name
  valid=false
  for c in $ALL_CHECKS $OPT_CHECKS; do
    [[ "$c" == "$check" ]] && {
      valid=true
      break
    }
  done
  if ! $valid; then
    err "Unknown check: $check"
    echo "  Available: $ALL_CHECKS $OPT_CHECKS"
    exit 1
  fi
  val=$([[ "$action" == "enable" ]] && echo "true" || echo "false")
  write_check "$check" "$val"
  if [[ "$val" == "true" ]]; then
    ok "Enabled $check"
  else
    ok "Disabled $check"
  fi
  # Re-install hooks to pick up changes
  info "Run 'cpm hook --global' to apply changes"
  exit 0
fi

# ─────────────────────────────────────────────────────────────
# Install mode (default)
# ─────────────────────────────────────────────────────────────
echo -e "${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║  Global Git Security Hooks Setup                         ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "  This installs pre-commit hooks that run on EVERY git commit:"
echo ""
echo "    • gitleaks   — Blocks secrets (API keys, tokens, passwords)"
echo "    • check-pii  — Blocks PII leaks (names, domains, org data)"
echo "    • semgrep    — Blocks critical vulnerabilities (SAST)"
echo "    • filesize   — Blocks large files (>5MB)"
echo ""
echo "  Hooks run in parallel. Skip with: git commit --no-verify"
echo ""

# Check hooks directory exists — create or update
if [[ ! -d "$HOOKS_DIR" ]]; then
  echo ""
  info "Creating hooks directory: $HOOKS_DIR"
  mkdir -p "$HOOKS_DIR/lib"
else
  info "Updating hooks in: $HOOKS_DIR"
  mkdir -p "$HOOKS_DIR/lib"
fi

# Create orchestrator
cat >"$HOOKS_DIR/pre-commit" <<'HOOK'
#!/bin/bash
# Global pre-commit — runs security checks that the repo doesn't cover itself
# Skip: git commit --no-verify  or  CPM_SKIP_HOOKS=1
#
# Dedup logic (checked in order):
#   1. cpm.toml [hooks.global] — explicit per-check overrides (highest priority)
#   2. cpm.toml [checks] / .pre-commit-config.yaml — auto-detect repo coverage
#   3. Default: run the check

HOOKS_DIR="$(cd "$(dirname "$0")/lib" && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"

[ "$CPM_SKIP_HOOKS" = "1" ] && exit 0

STAGED=$(git diff --cached --name-only --diff-filter=ACMR 2>/dev/null)
[ -z "$STAGED" ] && exit 0
export STAGED

# ── Pre-compute shared data (avoids repeated git calls in checks) ──
# Cache the full diff once — checks read from file instead of calling git again
DIFF_CACHE=$(mktemp "${TMPDIR:-/tmp}/cpm-diff.XXXXXX")
git diff --cached -U0 2>/dev/null > "$DIFF_CACHE"
export DIFF_CACHE
trap 'rm -f "$DIFF_CACHE"' EXIT

# Pre-classify staged files by type (checks skip instantly if no relevant files)
export HAS_SHELL=$(echo "$STAGED" | grep -cE '\.(sh|bash|zsh|yml|yaml|Makefile|Dockerfile)$' || true)
export HAS_JSON=$(echo "$STAGED" | grep -cE '\.(json)$' || true)
export HAS_YAML=$(echo "$STAGED" | grep -cE '\.(ya?ml)$' || true)
export HAS_CODE=$(echo "$STAGED" | grep -cE '\.(js|ts|jsx|tsx|py|rb|go|java|cs|php|rs|c|cpp|h)$' || true)
export HAS_SYMLINKS=0
while IFS= read -r f; do [ -L "$f" ] && HAS_SYMLINKS=1; done <<< "$STAGED"
export HAS_SYMLINKS

# Run repo's own pre-commit first
# Check .git/hooks/ (standard), .githooks/ (convention), .husky/ (husky)
REPO_HOOK=""
for candidate in "$REPO_ROOT/.git/hooks/pre-commit" "$REPO_ROOT/.githooks/pre-commit" "$REPO_ROOT/.husky/pre-commit"; do
    if [ -x "$candidate" ]; then
        REPO_HOOK="$candidate"
        break
    fi
done
if [ -n "$REPO_HOOK" ]; then
    "$REPO_HOOK" || exit 1
fi

# ── cpm.toml [hooks.global] dedup reader ──────────────────────────
# Returns: "true" if check should run, "false" if explicitly disabled,
#          empty string if not specified (fall through to auto-detect).
toml_hook_global() {
    local check="$1"
    local toml="$REPO_ROOT/cpm.toml"
    [ -f "$toml" ] || return
    # Look for [hooks.global] section and extract "check = true/false"
    awk -v key="$check" '
        /^\[hooks\.global\]/ { in_section=1; next }
        /^\[/                { in_section=0 }
        in_section && $1 == key && /=/ {
            gsub(/[" \t]/, "", $3)
            print $3
            exit
        }
    ' "$toml"
}

# Check if a specific global hook should run.
# Priority: [hooks.global] explicit > auto-detect > default (run).
should_run() {
    local check="$1"
    # 1. Explicit override in cpm.toml [hooks.global]
    local explicit
    explicit=$(toml_hook_global "$check")
    if [ "$explicit" = "false" ]; then return 1; fi
    if [ "$explicit" = "true" ]; then return 0; fi
    # 2. Fall through to auto-detect (return 0 = should run)
    return 0
}

# Auto-detect what repo already covers (used when no explicit override)
has_secrets() {
    [ -f "$REPO_ROOT/cpm.toml" ] && grep -q "secrets" "$REPO_ROOT/cpm.toml" 2>/dev/null && return 0
    [ -f "$REPO_ROOT/.pre-commit-config.yaml" ] && grep -q "gitleaks\|secrets" "$REPO_ROOT/.pre-commit-config.yaml" 2>/dev/null && return 0
    return 1
}
has_sast() {
    [ -f "$REPO_ROOT/cpm.toml" ] && grep -q "vulnerability-scan\|semgrep" "$REPO_ROOT/cpm.toml" 2>/dev/null && return 0
    [ -f "$REPO_ROOT/.pre-commit-config.yaml" ] && grep -q "semgrep" "$REPO_ROOT/.pre-commit-config.yaml" 2>/dev/null && return 0
    return 1
}
has_pii() {
    [ -f "$REPO_ROOT/cpm.toml" ] && grep -q "pii" "$REPO_ROOT/cpm.toml" 2>/dev/null && return 0
    return 1
}

# Run only what's needed (parallel)
pids=(); names=()

# ── Autofix checks (fix + re-stage) ──
fixed=0

if should_run "fix-trailing-whitespace"; then
    if [ -x "$HOOKS_DIR/fix-trailing-whitespace.sh" ]; then
        out=$(bash "$HOOKS_DIR/fix-trailing-whitespace.sh" 2>&1)
        [ $? -eq 0 ] && [ -n "$out" ] && { echo "$out"; ((fixed++)); }
    fi
fi

if should_run "fix-end-of-file"; then
    if [ -x "$HOOKS_DIR/fix-end-of-file.sh" ]; then
        out=$(bash "$HOOKS_DIR/fix-end-of-file.sh" 2>&1)
        [ $? -eq 0 ] && [ -n "$out" ] && { echo "$out"; ((fixed++)); }
    fi
fi

if should_run "fix-mixed-endings"; then
    if [ -x "$HOOKS_DIR/fix-mixed-endings.sh" ]; then
        out=$(bash "$HOOKS_DIR/fix-mixed-endings.sh" 2>&1)
        [ $? -eq 0 ] && [ -n "$out" ] && { echo "$out"; ((fixed++)); }
    fi
fi

[ $fixed -gt 0 ] && echo ""

# gitleaks — skip if repo handles secrets OR explicitly disabled
if should_run "gitleaks"; then
    if ! has_secrets && [ -x "$HOOKS_DIR/gitleaks.sh" ]; then
        bash "$HOOKS_DIR/gitleaks.sh" & pids+=($!); names+=("gitleaks")
    fi
fi

# secrets-fast — regex fallback, runs when gitleaks is not installed
if should_run "no-secrets-fast"; then
    if ! command -v gitleaks >/dev/null 2>&1 && ! has_secrets && [ -x "$HOOKS_DIR/no-secrets-fast.sh" ]; then
        bash "$HOOKS_DIR/no-secrets-fast.sh" & pids+=($!); names+=("no-secrets-fast")
    fi
fi

# pii
if should_run "no-pii"; then
    if ! has_pii && [ -x "$HOOKS_DIR/no-pii.sh" ]; then
        bash "$HOOKS_DIR/no-pii.sh" & pids+=($!); names+=("no-pii")
    fi
fi

# semgrep
if should_run "semgrep"; then
    if ! has_sast && [ -x "$HOOKS_DIR/semgrep.sh" ]; then
        bash "$HOOKS_DIR/semgrep.sh" & pids+=($!); names+=("semgrep")
    fi
fi

# filesize — always runs unless explicitly disabled
if should_run "no-large-files"; then
    if [ -x "$HOOKS_DIR/no-large-files.sh" ]; then
        bash "$HOOKS_DIR/no-large-files.sh" & pids+=($!); names+=("no-large-files")
    fi
fi

# dangerous-shell — detect destructive bash patterns
if should_run "no-dangerous-shell"; then
    if [ -x "$HOOKS_DIR/no-dangerous-shell.sh" ]; then
        bash "$HOOKS_DIR/no-dangerous-shell.sh" & pids+=($!); names+=("no-dangerous-shell")
    fi
fi

# no-main — block commits on main/master/develop
if should_run "no-main"; then
    if [ -x "$HOOKS_DIR/no-main.sh" ]; then
        bash "$HOOKS_DIR/no-main.sh" & pids+=($!); names+=("no-main")
    fi
fi

# merge-conflicts — detect conflict markers in staged files
if should_run "no-conflict-markers"; then
    if [ -x "$HOOKS_DIR/no-conflict-markers.sh" ]; then
        bash "$HOOKS_DIR/no-conflict-markers.sh" & pids+=($!); names+=("no-conflict-markers")
    fi
fi

# no-junk-files — block junk files from being committed
if should_run "no-artifacts"; then
    if [ -x "$HOOKS_DIR/no-artifacts.sh" ]; then
        bash "$HOOKS_DIR/no-artifacts.sh" & pids+=($!); names+=("no-artifacts")
    fi
fi

# json-yaml-valid — validate JSON and YAML syntax
if should_run "no-syntax-errors"; then
    if [ -x "$HOOKS_DIR/no-syntax-errors.sh" ]; then
        bash "$HOOKS_DIR/no-syntax-errors.sh" & pids+=($!); names+=("no-syntax-errors")
    fi
fi

# no-broken-symlinks — detect broken symlinks in staged files
if should_run "no-broken-symlinks"; then
    if [ -x "$HOOKS_DIR/no-broken-symlinks.sh" ]; then
        bash "$HOOKS_DIR/no-broken-symlinks.sh" & pids+=($!); names+=("no-broken-symlinks")
    fi
fi

# Wait for all blocking checks
failed=()
for i in "${!pids[@]}"; do
    wait "${pids[$i]}" || failed+=("${names[$i]}")
done

if [ ${#failed[@]} -gt 0 ]; then
    echo "⛔ pre-commit: ${failed[*]} failed (skip: --no-verify)"
    echo "   docs: https://github.com/rkristelijn/cpm/blob/main/docs/checks/hook-overview.md"
    exit 1
fi

# --- Warning checks (non-blocking, prompt to continue) ---
warnings=()

# gitignore — warn if .gitignore is missing security patterns
if should_run "no-missing-gitignore"; then
    if [ -x "$HOOKS_DIR/no-missing-gitignore.sh" ]; then
        out=$(bash "$HOOKS_DIR/no-missing-gitignore.sh" 2>&1)
        if [ $? -ne 0 ]; then
            warnings+=("$out")
        fi
    fi
fi

# debug-statements — detect leftover debug code in staged diffs
if should_run "no-debug"; then
    if [ -x "$HOOKS_DIR/no-debug.sh" ]; then
        out=$(bash "$HOOKS_DIR/no-debug.sh" 2>&1)
        if [ $? -ne 0 ]; then
            warnings+=("$out")
        fi
    fi
fi

# no-binaries — detect binary files in staged filenames
if should_run "no-binaries"; then
    if [ -x "$HOOKS_DIR/no-binaries.sh" ]; then
        out=$(bash "$HOOKS_DIR/no-binaries.sh" 2>&1)
        if [ $? -ne 0 ]; then
            warnings+=("$out")
        fi
    fi
fi

# no-empty-files — detect 0-byte staged files
if should_run "no-empty-files"; then
    if [ -x "$HOOKS_DIR/no-empty-files.sh" ]; then
        out=$(bash "$HOOKS_DIR/no-empty-files.sh" 2>&1)
        if [ $? -ne 0 ]; then
            warnings+=("$out")
        fi
    fi
fi

# no-mixed-line-endings — detect mixed CRLF/LF in staged files (skip if fix-mixed-endings autofix is enabled)
if should_run "no-mixed-endings" && ! should_run "fix-mixed-endings"; then
    if [ -x "$HOOKS_DIR/no-mixed-endings.sh" ]; then
        out=$(bash "$HOOKS_DIR/no-mixed-endings.sh" 2>&1)
        if [ $? -ne 0 ]; then
            warnings+=("$out")
        fi
    fi
fi

# no-unconventional-casing — enforce naming conventions
if should_run "no-unconventional-casing"; then
    if [ -x "$HOOKS_DIR/no-unconventional-casing.sh" ]; then
        out=$(bash "$HOOKS_DIR/no-unconventional-casing.sh" 2>&1)
        if [ $? -ne 0 ]; then
            warnings+=("$out")
        fi
    fi
fi

# no-typos — spell check staged files
if should_run "no-typos"; then
    if [ -x "$HOOKS_DIR/no-typos.sh" ]; then
        out=$(bash "$HOOKS_DIR/no-typos.sh" 2>&1)
        if [ $? -ne 0 ]; then
            warnings+=("$out")
        fi
    fi
fi

# no-dei-violations — flag non-inclusive language in staged diffs
if should_run "no-dei-violations"; then
    if [ -x "$HOOKS_DIR/no-dei-violations.sh" ]; then
        out=$(bash "$HOOKS_DIR/no-dei-violations.sh" 2>&1)
        if [ $? -ne 0 ]; then
            warnings+=("$out")
        fi
    fi
fi

# no-absolute-paths — detect hardcoded absolute paths, ~/, ../ escapes
if should_run "no-absolute-paths"; then
    if [ -x "$HOOKS_DIR/no-absolute-paths.sh" ]; then
        out=$(bash "$HOOKS_DIR/no-absolute-paths.sh" 2>&1)
        if [ $? -ne 0 ]; then
            warnings+=("$out")
        fi
    fi
fi

# Show warnings and prompt
if [ ${#warnings[@]} -gt 0 ]; then
    echo ""
    for w in "${warnings[@]}"; do
        echo "$w"
    done
    echo ""
    # Only prompt if we have a terminal (not in CI/piped)
    if [ -t 0 ]; then
        printf "Continue committing? (y/N) "
        read -r answer </dev/tty
        case "$answer" in
            [yY]|[yY]es) ;; # continue
            *) echo "Commit aborted."; exit 1 ;;
        esac
    else
        # Non-interactive (CI) — warnings don't block
        echo "   (non-interactive: warnings don't block)"
    fi
fi

exit 0
HOOK
chmod +x "$HOOKS_DIR/pre-commit"
ok "Created pre-commit orchestrator"

# Create lib hooks
cat >"$HOOKS_DIR/lib/gitleaks.sh" <<'HOOK'
#!/bin/bash
command -v gitleaks >/dev/null 2>&1 || exit 0
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
BASELINE=""
[[ -f "$REPO_ROOT/.gitleaks-baseline.json" ]] && BASELINE="--baseline-path $REPO_ROOT/.gitleaks-baseline.json"
gitleaks git --pre-commit --staged --no-banner $BASELINE 2>/dev/null
rc=$?
if [ $rc -ne 0 ]; then
  echo "   docs: https://github.com/rkristelijn/cpm/blob/main/docs/checks/hook-gitleaks.md"
fi
exit $rc
HOOK

cat >"$HOOKS_DIR/lib/no-pii.sh" <<'HOOK'
#!/bin/bash
# Staged PII check using central vault
PII_VAULT="${PII_VAULT:-$HOME/.local/share/pii}"

# Build file list safely using while-read loop
STAGED_FILES=()
while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    echo "$f" | grep -qE '\.(lock|min\.js|svg|png|jpg|gif)$' && continue
    STAGED_FILES+=("$f")
done <<< "$STAGED"
[ ${#STAGED_FILES[@]} -eq 0 ] && exit 0

DISABLED=""
for cfg in ".config/.pii-config" ".pii-config"; do
    [ -f "$cfg" ] && { DISABLED=$(grep -v '^#' "$cfg" | grep '^disable' | sed 's/^disable[[:space:]]*//'); break; }
done

declare -A PATTERN_MAP=(
    [bsn]='\b[0-9]{9}\b'
    [iban]='\b[A-Z]{2}[0-9]{2}[A-Z0-9]{4}[0-9]{7}([A-Z0-9]{0,16})\b'
    [phone-nl]='\b06[0-9]{8}\b'
    [phone-intl]='\b\+31[0-9]{9}\b'
    [nl-postcode]='\b[1-9][0-9]{3}\s?[A-Z]{2}\b'
    [nl-kenteken]='\b[A-Z]{2}-[0-9]{3}-[A-Z]\b|\b[0-9]-[A-Z]{3}-[0-9]{2}\b'
    [uk-nino]='\b[A-Z]{2}[0-9]{6}[A-Z]\b'
    [uk-phone]='\b\+44[0-9]{10}\b'
    [us-ssn]='\b[0-9]{3}-[0-9]{2}-[0-9]{4}\b'
    [us-phone]='\b\+1[0-9]{10}\b'
    [ipv4]='\b[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\b'
    # creditcard: broad pattern — catches long numbers. Luhn validation would
    # reduce false positives but is too slow for a pre-commit hook.
    [creditcard]='\b[0-9]{13,19}\b'
    # eu-iban: broader than the existing 'iban' pattern (which stays for backward
    # compat). This catches non-NL IBANs too.
    [eu-iban]='\b[A-Z]{2}[0-9]{2}[A-Z0-9]{11,30}\b'
)

PATTERNS=(); NAMES=()
for name in "${!PATTERN_MAP[@]}"; do
    echo "$DISABLED" | grep -qw "$name" && continue
    PATTERNS+=("${PATTERN_MAP[$name]}"); NAMES+=("$name")
done
[ ${#PATTERNS[@]} -eq 0 ] && exit 0

ADDED=$(cat "$DIFF_CACHE" 2>/dev/null \
  | awk '/^diff --git/{f=substr($3,3)} /^@@/{split($3,a,"+"); ln=a[1]+0; sub(/,.*/,"",ln); ln--; next} /^\+[^+]/{ln++; if ($0 !~ /cpm:ignore pii/) print f":"ln":"substr($0,2)}')
[ -z "$ADDED" ] && exit 0

found=0
for i in "${!PATTERNS[@]}"; do
    pattern="${PATTERNS[$i]}"; name="${NAMES[$i]}"
    matches=$(echo "$ADDED" | grep -E "$pattern" || true)
    # Filter out safe/private IPs for the ipv4 pattern
    if [ "$name" = "ipv4" ] && [ -n "$matches" ]; then
        matches=$(echo "$matches" | grep -v '127\.0\.0\.1\|0\.0\.0\.0\|10\.\|172\.1[6-9]\.\|172\.2[0-9]\.\|172\.3[01]\.\|192\.168\.' || true)
    fi
    while IFS= read -r hit; do
        [ -z "$hit" ] && continue
        echo "⚠ pii($name): ${hit%%:*}:$(echo "$hit" | cut -d: -f2)  pattern '$name'"
        found=$((found + 1))
    done <<< "$matches"
done

[ $found -gt 0 ] && { echo "   suppress: 'cpm:ignore pii' on line, or 'disable <name>' in .config/.pii-config"; echo "   docs: https://github.com/rkristelijn/cpm/blob/main/docs/checks/hook-no-pii.md"; exit 1; }
exit 0
HOOK

cat >"$HOOKS_DIR/lib/semgrep.sh" <<'HOOK'
#!/bin/bash
command -v semgrep >/dev/null 2>&1 || exit 0
FILES=""
while IFS= read -r f; do [ -f "$f" ] && FILES="$FILES $f"; done <<< "$STAGED"
[ -z "$FILES" ] && exit 0
timeout 5 semgrep --config=auto --severity=ERROR --quiet $FILES 2>/dev/null
rc=$?
[ $rc -eq 124 ] && exit 0
[ $rc -ge 2 ] && exit 0
if [ $rc -ne 0 ]; then
  echo "   docs: https://github.com/rkristelijn/cpm/blob/main/docs/checks/hook-semgrep.md"
fi
exit $rc
HOOK

cat >"$HOOKS_DIR/lib/no-large-files.sh" <<'HOOK'
#!/bin/bash
MAX_KB=5120
while IFS= read -r file; do
    [ -f "$file" ] || continue
    size=$(wc -c < "$file" 2>/dev/null)
    if [ "$size" -gt $((MAX_KB * 1024)) ]; then
        echo "⚠ no-large-files: $file is $(( size / 1024 / 1024 ))MB (max ${MAX_KB}KB)"
        echo "   docs: https://github.com/rkristelijn/cpm/blob/main/docs/checks/hook-no-large-files.md"
        exit 1
    fi
done <<< "$STAGED"
exit 0
HOOK

chmod +x "$HOOKS_DIR/lib"/*.sh
ok "Installed lib hooks: gitleaks, no-pii, semgrep, no-large-files"

# Install no-secrets-fast.sh from cpm's scripts/lib/ if available
SECRETS_FAST_SRC="$CPM_ROOT/scripts/lib/secrets-fast.sh"
if [[ -f "$SECRETS_FAST_SRC" ]]; then
  cp "$SECRETS_FAST_SRC" "$HOOKS_DIR/lib/no-secrets-fast.sh"
  chmod +x "$HOOKS_DIR/lib/no-secrets-fast.sh"
  ok "Installed lib/no-secrets-fast.sh (regex-only fallback for gitleaks)"
else
  warn "scripts/lib/secrets-fast.sh not found — regex fallback unavailable"
fi

# Install no-dangerous-shell.sh
cat >"$HOOKS_DIR/lib/no-dangerous-shell.sh" <<'HOOK'
#!/bin/bash
# lib/no-dangerous-shell.sh — detect destructive/evil bash patterns in staged files
[ "$HAS_SHELL" = "0" ] && exit 0

COMBINED='rm -rf /[^v]|rm -rf \$[^{]|:\(\)\{.*\|.*\};:|chmod -R 777 /[^.]|chmod.*777 /|eval "\$|eval \$[^(]|curl.*\| *[bs]h|wget.*\| *sh|wget.*-O-.*\| *sh|git push.*--force|git reset --hard|history -c|export HISTSIZE=0|unset HISTFILE|mkfs\.|find / -delete|kill -9 -1|passwd -d|iptables -F|crontab -r'

# Only scan staged shell-like files, exclude hook scripts themselves and test fixtures
SHELL_FILES=$(echo "$STAGED" | grep -E '\.(sh|bash|zsh|yml|yaml|Makefile|Dockerfile)$' | grep -v 'dangerous-shell\|no-dangerous-shell\|setup-global-hooks\|check-dangerous-shell\|cpm_rules_test\|/\.config/git/hooks/' || true)
[ -z "$SHELL_FILES" ] && exit 0

DIFF=$(cat "$DIFF_CACHE" 2>/dev/null | grep '^+[^+]' | grep -v 'cpm:ignore' || true)
[ -z "$DIFF" ] && exit 0

# Filter out comments (lines starting with +#, or + followed by whitespace then #)
hits=$(echo "$DIFF" | grep -E "$COMBINED" | grep -v '^+[[:space:]]*#' | grep -v "^+COMBINED=" | grep -v "^+.*'.*rm -rf" || true)
[ -z "$hits" ] && exit 0

echo "⚠ no-dangerous-shell: destructive patterns detected in staged files:"
echo "$hits" | head -5 | sed 's/^/   /'
echo "   docs: https://github.com/rkristelijn/cpm/blob/main/docs/checks/hook-no-dangerous-shell.md"
exit 1
HOOK

# Install no-missing-gitignore.sh
cat >"$HOOKS_DIR/lib/no-missing-gitignore.sh" <<'HOOK'
#!/bin/bash
# lib/no-missing-gitignore.sh — verify .gitignore contains mandatory security patterns
# Prevents accidental commit of secrets, keys, env files

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
GI="$REPO_ROOT/.gitignore"

# No .gitignore at all? Only warn, don't block (some repos are intentional)
[ -f "$GI" ] || exit 0

# Mandatory patterns — if ANY of these are missing, secrets can leak
MUST_HAVE=(
  ".env"
  "*.pem"
  "*.key"
  "node_modules"
  ".DS_Store"
  "*.log"
)

missing=()
for pattern in "${MUST_HAVE[@]}"; do
  grep -qF "$pattern" "$GI" 2>/dev/null || missing+=("$pattern")
done

if [ ${#missing[@]} -gt 0 ]; then
  echo "⚠ no-missing-gitignore: .gitignore is missing security patterns:"
  for m in "${missing[@]}"; do
    echo "   + $m"
  done
  echo "   Add them to prevent accidental secret commits."
  echo "   Suppress: add the patterns or use --no-verify"
  echo "   docs: https://github.com/rkristelijn/cpm/blob/main/docs/checks/hook-no-missing-gitignore.md"
  exit 1
fi
exit 0
HOOK

chmod +x "$HOOKS_DIR/lib/no-dangerous-shell.sh" "$HOOKS_DIR/lib/no-missing-gitignore.sh"
ok "Installed lib/no-dangerous-shell.sh + lib/no-missing-gitignore.sh"

# ── New shift-left lib scripts ─────────────────────────────────

# Install no-main.sh
cat >"$HOOKS_DIR/lib/no-main.sh" <<'HOOK'
#!/bin/bash
# lib/no-main.sh — block commits on protected branches
BRANCH=$(git rev-parse --abbrev-ref HEAD)
case "$BRANCH" in
  main|master|develop)
    echo "⛔ no-main: commit on $BRANCH blocked. Use a feature branch."
    echo "   docs: https://github.com/rkristelijn/cpm/blob/main/docs/checks/hook-no-main.md"
    exit 1
    ;;
esac
exit 0
HOOK

# Install no-conflict-markers.sh
cat >"$HOOKS_DIR/lib/no-conflict-markers.sh" <<'HOOK'
#!/bin/bash
# lib/no-conflict-markers.sh — detect conflict markers in staged files
DIFF=$(cat "$DIFF_CACHE" 2>/dev/null | grep -E '^\+(<{7}|={7}|>{7})' || true)
if [ -n "$DIFF" ]; then
  echo "⛔ no-conflict-markers: conflict markers found in staged files:"
  echo "$DIFF" | head -10 | sed 's/^/   /'
  echo "   docs: https://github.com/rkristelijn/cpm/blob/main/docs/checks/hook-no-conflict-markers.md"
  exit 1
fi
exit 0
HOOK

# Install no-artifacts.sh
cat >"$HOOKS_DIR/lib/no-artifacts.sh" <<'HOOK'
#!/bin/bash
# lib/no-artifacts.sh — block junk files from being committed
found=()
while IFS= read -r f; do
  [ -z "$f" ] && continue
  base="${f##*/}"
  case "$f" in
    # OS junk
    .DS_Store|*/.DS_Store) found+=("$f") ;;
    Thumbs.db|*/Thumbs.db) found+=("$f") ;;
    desktop.ini|*/desktop.ini) found+=("$f") ;;
    .Spotlight-V100|*/.Spotlight-V100) found+=("$f") ;;
    .Trashes|*/.Trashes) found+=("$f") ;;

    # Python
    *.pyc) found+=("$f") ;;
    __pycache__/*|*/__pycache__/*) found+=("$f") ;;
    *.egg-info/*|*/*.egg-info/*) found+=("$f") ;;
    .tox/*|*/.tox/*) found+=("$f") ;;
    .pytest_cache/*|*/.pytest_cache/*) found+=("$f") ;;
    .mypy_cache/*|*/.mypy_cache/*) found+=("$f") ;;
    venv/*|*/venv/*) found+=("$f") ;;
    .venv/*|*/.venv/*) found+=("$f") ;;

    # Node / JS
    node_modules/*|*/node_modules/*) found+=("$f") ;;
    .eslintcache|*/.eslintcache) found+=("$f") ;;
    .tsbuildinfo|*/.tsbuildinfo) found+=("$f") ;;
    .nyc_output/*|*/.nyc_output/*) found+=("$f") ;;
    coverage/*|*/coverage/*) found+=("$f") ;;
    bower_components/*|*/bower_components/*) found+=("$f") ;;
    *.min.js.map) found+=("$f") ;;
    *.min.css.map) found+=("$f") ;;

    # Build output
    build/*|*/build/*) found+=("$f") ;;
    dist/*|*/dist/*) found+=("$f") ;;
    target/*|*/target/*) found+=("$f") ;;

    # IDE settings
    .idea/*|*/.idea/*) found+=("$f") ;;
    .vscode/settings.json|*/.vscode/settings.json) found+=("$f") ;;
    .vscode/launch.json|*/.vscode/launch.json) found+=("$f") ;;
    *.suo) found+=("$f") ;;
    *.user) found+=("$f") ;;
    *.sln.docstates) found+=("$f") ;;

    # Sass / CSS cache
    .sass-cache/*|*/.sass-cache/*) found+=("$f") ;;

    # Package managers
    vendor/*|*/vendor/*) found+=("$f") ;;
    packages/*|*/packages/*) found+=("$f") ;;
    .gradle/*|*/.gradle/*) found+=("$f") ;;

    # Logs & databases
    *.log) found+=("$f") ;;
    *.sqlite) found+=("$f") ;;
    *.sqlite3) found+=("$f") ;;
    *.sql.bak) found+=("$f") ;;
    *.dump) found+=("$f") ;;
    *.core) found+=("$f") ;;
    *.dmp) found+=("$f") ;;

    # Temp / backup
    *.bak) found+=("$f") ;;
    *.old) found+=("$f") ;;
    *.orig) found+=("$f") ;;
    *.swp) found+=("$f") ;;
    *.swo) found+=("$f") ;;
  esac
  # Pattern matches that need prefix/suffix checks
  case "$base" in
    ._*) found+=("$f") ;;   # macOS resource forks
    *~) found+=("$f") ;;    # editor backup files
  esac
done <<< "$STAGED"

if [ ${#found[@]} -gt 0 ]; then
  echo "⛔ no-artifacts: blocked files that shouldn't be committed:"
  for f in "${found[@]}"; do
    echo "   $f"
  done
  echo "   docs: https://github.com/rkristelijn/cpm/blob/main/docs/checks/hook-no-artifacts.md"
  exit 1
fi
exit 0
HOOK

# Install no-syntax-errors.sh
cat >"$HOOKS_DIR/lib/no-syntax-errors.sh" <<'HOOK'
#!/bin/bash
# lib/no-syntax-errors.sh — validate JSON and YAML syntax in staged files
[ "$HAS_JSON$HAS_YAML" = "00" ] && exit 0
errors=0
while IFS= read -r f; do
  [ -z "$f" ] && continue
  [ -f "$f" ] || continue
  case "$f" in
    *.json)
      if ! python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$f" 2>/dev/null; then
        echo "⛔ no-syntax-errors: invalid JSON: $f"
        echo "   docs: https://github.com/rkristelijn/cpm/blob/main/docs/checks/hook-no-syntax-errors.md"
        errors=$((errors + 1))
      fi
      ;;
    *.yml|*.yaml)
      if command -v python3 >/dev/null 2>&1; then
        if python3 -c "import yaml" 2>/dev/null; then
          if ! python3 -c "import yaml,sys; yaml.safe_load(open(sys.argv[1]))" "$f" 2>/dev/null; then
            echo "⛔ no-syntax-errors: invalid YAML: $f"
            echo "   docs: https://github.com/rkristelijn/cpm/blob/main/docs/checks/hook-no-syntax-errors.md"
            errors=$((errors + 1))
          fi
        fi
      fi
      ;;
  esac
done <<< "$STAGED"
[ $errors -gt 0 ] && exit 1
exit 0
HOOK

# Install no-broken-symlinks.sh
cat >"$HOOKS_DIR/lib/no-broken-symlinks.sh" <<'HOOK'
#!/bin/bash
# lib/no-broken-symlinks.sh — detect broken symlinks in staged files
[ "$HAS_SYMLINKS" = "0" ] && exit 0
broken=()
while IFS= read -r f; do
  [ -z "$f" ] && continue
  if [ -L "$f" ] && [ ! -e "$f" ]; then
    broken+=("$f")
  fi
done <<< "$STAGED"

if [ ${#broken[@]} -gt 0 ]; then
  echo "⛔ no-broken-symlinks: broken symlinks in staged files:"
  for f in "${broken[@]}"; do
    echo "   $f → $(readlink "$f" 2>/dev/null || echo '(unreadable)')"
  done
  echo "   docs: https://github.com/rkristelijn/cpm/blob/main/docs/checks/hook-no-broken-symlinks.md"
  exit 1
fi
exit 0
HOOK

# Install no-debug.sh
cat >"$HOOKS_DIR/lib/no-debug.sh" <<'HOOK'
#!/bin/bash
# lib/no-debug.sh — detect debug/trace statements in staged diffs
# Excludes test files, spec files, and config files
[ "$HAS_CODE" = "0" ] && exit 0

DEBUG_PATTERN='console\.(log|debug)|debugger[;[:space:]]|binding\.pry|byebug|pdb\.set_trace|breakpoint()|var_dump\(|dd\(|pp\(|System\.out\.println'

# Build file list, excluding test/spec/config files
FILES=()
while IFS= read -r f; do
  [ -z "$f" ] && continue
  case "$f" in
    *test*|*spec*|*__test__*|*.test.*|*.spec.*|*.config.*|*.conf|*.cfg) continue ;;
  esac
  FILES+=("$f")
done <<< "$STAGED"
[ ${#FILES[@]} -eq 0 ] && exit 0

DIFF=$(cat "$DIFF_CACHE" 2>/dev/null | grep '^+[^+]' | grep -v 'cpm:ignore' || true)
[ -z "$DIFF" ] && exit 0

hits=$(echo "$DIFF" | grep -E "$DEBUG_PATTERN" || true)
[ -z "$hits" ] && exit 0

count=$(echo "$hits" | wc -l | tr -d ' ')
echo "⚠ no-debug: $count debug statement(s) found in staged changes:"
echo "$hits" | head -5 | sed 's/^+/   /'
echo "   Suppress: add 'cpm:ignore' comment on the line"
echo "   docs: https://github.com/rkristelijn/cpm/blob/main/docs/checks/hook-no-debug.md"
exit 1
HOOK

# Install no-binaries.sh
cat >"$HOOKS_DIR/lib/no-binaries.sh" <<'HOOK'
#!/bin/bash
# lib/no-binaries.sh — detect binary files in staged filenames
found=()
while IFS= read -r f; do
  [ -z "$f" ] && continue
  case "$f" in
    *.docx|*.xlsx|*.zip|*.jar|*.exe|*.dll|*.so|*.dylib|*.class)
      found+=("$f")
      ;;
  esac
done <<< "$STAGED"

if [ ${#found[@]} -gt 0 ]; then
  echo "⚠ no-binaries: binary files detected in staged changes:"
  for f in "${found[@]}"; do
    echo "   $f"
  done
  echo "   Consider using Git LFS or adding to .gitignore"
  echo "   docs: https://github.com/rkristelijn/cpm/blob/main/docs/checks/hook-no-binaries.md"
  exit 1
fi
exit 0
HOOK

# Install no-empty-files.sh
cat >"$HOOKS_DIR/lib/no-empty-files.sh" <<'HOOK'
#!/bin/bash
# lib/no-empty-files.sh — detect 0-byte staged files
empty=()
while IFS= read -r f; do
  [ -z "$f" ] && continue
  [ -f "$f" ] || continue
  size=$(wc -c < "$f" 2>/dev/null | tr -d ' ')
  if [ "$size" = "0" ]; then
    empty+=("$f")
  fi
done <<< "$STAGED"

if [ ${#empty[@]} -gt 0 ]; then
  echo "⚠ no-empty-files: empty (0-byte) files detected:"
  for f in "${empty[@]}"; do
    echo "   $f"
  done
  echo "   docs: https://github.com/rkristelijn/cpm/blob/main/docs/checks/hook-no-empty-files.md"
  exit 1
fi
exit 0
HOOK

# Install no-mixed-endings.sh
cat >"$HOOKS_DIR/lib/no-mixed-endings.sh" <<'HOOK'
#!/bin/bash
# lib/no-mixed-endings.sh — detect files with mixed CRLF and LF
mixed=()
while IFS= read -r f; do
  [ -z "$f" ] && continue
  [ -f "$f" ] || continue
  # Skip binary-like files
  case "$f" in
    *.png|*.jpg|*.gif|*.ico|*.woff|*.ttf|*.eot|*.zip|*.tar|*.gz) continue ;;
  esac
  # Count lines with CRLF vs total lines
  total=$(wc -l < "$f" 2>/dev/null | tr -d ' ')
  [ "$total" = "0" ] && continue
  crlf=$(grep -cP '\r$' "$f" 2>/dev/null || echo "0")
  # Mixed = has some CRLF but not all
  if [ "$crlf" -gt 0 ] && [ "$crlf" -lt "$total" ]; then
    mixed+=("$f ($crlf/$total lines have CRLF)")
  fi
done <<< "$STAGED"

if [ ${#mixed[@]} -gt 0 ]; then
  echo "⚠ no-mixed-endings: files with mixed CRLF/LF:"
  for m in "${mixed[@]}"; do
    echo "   $m"
  done
  echo "   Fix: dos2unix <file> or configure .gitattributes"
  echo "   docs: https://github.com/rkristelijn/cpm/blob/main/docs/checks/hook-no-mixed-endings.md"
  exit 1
fi
exit 0
HOOK

chmod +x "$HOOKS_DIR/lib/no-main.sh" "$HOOKS_DIR/lib/no-conflict-markers.sh" \
  "$HOOKS_DIR/lib/no-artifacts.sh" "$HOOKS_DIR/lib/no-syntax-errors.sh" \
  "$HOOKS_DIR/lib/no-broken-symlinks.sh" "$HOOKS_DIR/lib/no-debug.sh" \
  "$HOOKS_DIR/lib/no-binaries.sh" "$HOOKS_DIR/lib/no-empty-files.sh" \
  "$HOOKS_DIR/lib/no-mixed-endings.sh" "$HOOKS_DIR/lib/no-unconventional-casing.sh"
ok "Installed 10 new lib hooks (no-main, no-conflict-markers, no-artifacts, no-syntax-errors, no-broken-symlinks, no-debug, no-binaries, no-empty-files, no-mixed-endings, no-unconventional-casing)"

# ── Autofix lib scripts ─────────────────────────────────────

# Install fix-trailing-whitespace.sh
cat >"$HOOKS_DIR/lib/fix-trailing-whitespace.sh" <<'HOOK'
#!/bin/bash
# lib/fix-trailing-whitespace.sh — remove trailing whitespace from staged files (autofix)
# docs: https://github.com/rkristelijn/cpm/blob/main/docs/checks/hook-fix-trailing-whitespace.md

count=0
while IFS= read -r file; do
  [ -z "$file" ] && continue
  [ -f "$file" ] || continue
  # Skip binary files
  case "$file" in
    *.png|*.jpg|*.gif|*.ico|*.woff|*.ttf|*.zip|*.tar|*.gz|*.pdf|*.exe|*.dll|*.so|*.dylib|*.jar|*.class) continue ;;
  esac
  # Capture checksum before
  before=$(md5 -q "$file" 2>/dev/null || md5sum "$file" 2>/dev/null | cut -d' ' -f1)
  tmp=$(mktemp "${file}.XXXXXX")
  sed 's/[[:space:]]*$//' "$file" >"$tmp"
  mv "$tmp" "$file"
  after=$(md5 -q "$file" 2>/dev/null || md5sum "$file" 2>/dev/null | cut -d' ' -f1)
  if [ "$before" != "$after" ]; then
    git add "$file"
    count=$((count + 1))
  fi
done <<< "$STAGED"

if [ $count -gt 0 ]; then
  echo "✓ fix-trailing-whitespace: fixed $count file(s) (auto-staged)"
  echo "  docs: https://github.com/rkristelijn/cpm/blob/main/docs/checks/hook-fix-trailing-whitespace.md"
fi
exit 0
HOOK

# Install fix-end-of-file.sh
cat >"$HOOKS_DIR/lib/fix-end-of-file.sh" <<'HOOK'
#!/bin/bash
# lib/fix-end-of-file.sh — ensure files end with a newline (autofix)
# docs: https://github.com/rkristelijn/cpm/blob/main/docs/checks/hook-fix-end-of-file.md

count=0
while IFS= read -r file; do
  [ -z "$file" ] && continue
  [ -f "$file" ] || continue
  # Skip binary files
  case "$file" in
    *.png|*.jpg|*.gif|*.ico|*.woff|*.ttf|*.zip|*.tar|*.gz|*.pdf|*.exe|*.dll|*.so|*.dylib|*.jar|*.class) continue ;;
  esac
  # Skip empty files
  [ ! -s "$file" ] && continue
  # Check if last byte is newline
  lastbyte=$(tail -c 1 "$file" | xxd -p)
  if [ "$lastbyte" != "0a" ] && [ -n "$lastbyte" ]; then
    printf '\n' >> "$file"
    git add "$file"
    count=$((count + 1))
  fi
done <<< "$STAGED"

if [ $count -gt 0 ]; then
  echo "✓ fix-end-of-file: added newline to $count file(s) (auto-staged)"
  echo "  docs: https://github.com/rkristelijn/cpm/blob/main/docs/checks/hook-fix-end-of-file.md"
fi
exit 0
HOOK

# Install fix-mixed-endings.sh
cat >"$HOOKS_DIR/lib/fix-mixed-endings.sh" <<'HOOK'
#!/bin/bash
# lib/fix-mixed-endings.sh — normalize mixed CRLF/LF to LF (autofix)
# docs: https://github.com/rkristelijn/cpm/blob/main/docs/checks/hook-fix-mixed-endings.md

count=0
while IFS= read -r file; do
  [ -z "$file" ] && continue
  [ -f "$file" ] || continue
  # Skip binary files
  case "$file" in
    *.png|*.jpg|*.gif|*.ico|*.woff|*.ttf|*.zip|*.tar|*.gz|*.pdf|*.exe|*.dll|*.so|*.dylib|*.jar|*.class) continue ;;
  esac
  # Check if file has any CRLF (portable: BSD + GNU grep)
  if LC_ALL=C grep -q "$(printf '\r')$" "$file" 2>/dev/null; then
    tmp=$(mktemp "${file}.XXXXXX")
    LC_ALL=C sed "s/$(printf '\r')\$//" "$file" >"$tmp"
    mv "$tmp" "$file"
    git add "$file"
    count=$((count + 1))
  fi
done <<< "$STAGED"

if [ $count -gt 0 ]; then
  echo "✓ fix-mixed-endings: normalized $count file(s) to LF (auto-staged)"
  echo "  docs: https://github.com/rkristelijn/cpm/blob/main/docs/checks/hook-fix-mixed-endings.md"
fi
exit 0
HOOK

chmod +x "$HOOKS_DIR/lib/fix-trailing-whitespace.sh" "$HOOKS_DIR/lib/fix-end-of-file.sh" \
  "$HOOKS_DIR/lib/fix-mixed-endings.sh"
ok "Installed 3 autofix lib hooks (fix-trailing-whitespace, fix-end-of-file, fix-mixed-endings)"

# Install no-unconventional-casing.sh
cat >"$HOOKS_DIR/lib/no-unconventional-casing.sh" <<'HOOK'
#!/bin/bash
# lib/no-unconventional-casing.sh — enforce file/folder naming conventions
#
# Default: lower-kebab-case for files and folders
# Detects: wrong casing of known files (readme.md → README.md)
# Config: cpm.toml [hooks.global] no-unconventional-casing = false to disable
#         cpm.toml [naming] allow-pascal-case = true for React/Angular projects

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"

# ── Known files that MUST be specific casing ──
# Map: lowercase → correct casing
declare -A MUST_CASE=(
  [readme.md]="README.md"
  [readme]="README"
  [readme.txt]="README.txt"
  [changelog.md]="CHANGELOG.md"
  [changelog]="CHANGELOG"
  [contributing.md]="CONTRIBUTING.md"
  [contributing]="CONTRIBUTING"
  [security.md]="SECURITY.md"
  [security]="SECURITY"
  [license]="LICENSE"
  [license.md]="LICENSE.md"
  [license.txt]="LICENSE.txt"
  [makefile]="Makefile"
  [gnumakefile]="GNUmakefile"
  [cmakelists.txt]="CMakeLists.txt"
  [dockerfile]="Dockerfile"
  [vagrantfile]="Vagrantfile"
  [gemfile]="Gemfile"
  [gemfile.lock]="Gemfile.lock"
  [rakefile]="Rakefile"
  [procfile]="Procfile"
  [brewfile]="Brewfile"
  [codeowners]="CODEOWNERS"
  [owners]="OWNERS"
  [todo.md]="TODO.md"
  [authors.md]="AUTHORS.md"
  [authors]="AUTHORS"
  [notice]="NOTICE"
  [patents]="PATENTS"
  [install.md]="INSTALL.md"
  [install]="INSTALL"
)

# ── Known exceptions that are allowed as-is ──
KNOWN_UPPER='README|README.md|README.txt|CHANGELOG|CHANGELOG.md|CONTRIBUTING|CONTRIBUTING.md|SECURITY|SECURITY.md|LICENSE|LICENSE.md|LICENSE.txt|Makefile|GNUmakefile|CMakeLists.txt|Dockerfile|Vagrantfile|Gemfile|Gemfile.lock|Rakefile|Procfile|Brewfile|TODO|TODO.md|CODEOWNERS|OWNERS|PULL_REQUEST_TEMPLATE.md|CODE_OF_CONDUCT.md|INSTALL|INSTALL.md|AUTHORS|AUTHORS.md|NOTICE|PATENTS'

# ── Known directory exceptions ──
KNOWN_DIRS='.github|.gitlab|.vscode|.idea|__pycache__|__tests__|__mocks__|__fixtures__|node_modules|.DS_Store'

# ── Check if PascalCase is allowed (React/Angular projects) ──
allow_pascal=false
if [ -f "$REPO_ROOT/cpm.toml" ]; then
  val=$(awk '/^\[naming\]/ { in_section=1; next } /^\[/ { in_section=0 } in_section && /allow-pascal-case/ { gsub(/[" \t]/, "", $3); print $3; exit }' "$REPO_ROOT/cpm.toml" 2>/dev/null)
  [ "$val" = "true" ] && allow_pascal=true
fi
# Auto-detect React/Angular
if ! $allow_pascal; then
  if [ -f "$REPO_ROOT/package.json" ]; then
    grep -qE '"react"|"@angular/core"|"next"|"gatsby"' "$REPO_ROOT/package.json" 2>/dev/null && allow_pascal=true
  fi
fi

wrong_case=()
bad_names=()

while IFS= read -r filepath; do
  [ -z "$filepath" ] && continue

  # Extract filename and all directory components
  filename="${filepath##*/}"
  dirpath="${filepath%/*}"
  [ "$dirpath" = "$filepath" ] && dirpath=""

  # ── Check filename ──

  # Skip dotfiles
  [[ "$filename" == .* ]] && continue

  # Skip known uppercase exceptions
  echo "$filename" | grep -qxE "$KNOWN_UPPER" && continue

  # Skip .rule files (cpm convention)
  case "$filename" in *.rule|*.R|*.S|*.C) continue ;; esac

  # Check wrong casing of known files (readme.md → should be README.md)
  lower=$(echo "$filename" | tr '[:upper:]' '[:lower:]')
  if [[ -v "MUST_CASE[$lower]" ]]; then
    expected="${MUST_CASE[$lower]}"
    if [ "$filename" != "$expected" ]; then
      wrong_case+=("$filepath → should be $expected")
      continue
    fi
  fi

  # PascalCase allowed? (React components: MyComponent.tsx)
  if $allow_pascal; then
    # Allow: PascalCase, lower-kebab-case, lowercase with dots
    if echo "$filename" | grep -qxE '[A-Z][a-zA-Z0-9]*(\.[a-z]+)+'; then
      continue  # PascalCase.ext — allowed
    fi
  fi

  # Check lower-kebab-case: a-z, 0-9, hyphens, dots, underscores (for test files)
  if ! echo "$filename" | grep -qxE '[a-z0-9][a-z0-9._-]*'; then
    bad_names+=("$filepath → expected lower-kebab-case")
  fi

  # ── Check directory components ──
  if [ -n "$dirpath" ]; then
    IFS='/' read -ra parts <<< "$dirpath"
    for dir in "${parts[@]}"; do
      [ -z "$dir" ] && continue
      # Skip dotdirs and known exceptions
      [[ "$dir" == .* ]] && continue
      echo "$dir" | grep -qxE "$KNOWN_DIRS" && continue
      # Directories should be lower-kebab-case
      if ! echo "$dir" | grep -qxE '[a-z0-9][a-z0-9_-]*'; then
        bad_names+=("$filepath → directory '$dir' should be lower-kebab-case")
        break  # One warning per file is enough
      fi
    done
  fi
done <<< "$STAGED"

issues=("${wrong_case[@]}" "${bad_names[@]}")
if [ ${#issues[@]} -gt 0 ]; then
  echo "⚠ no-unconventional-casing: naming convention violations:"
  for issue in "${issues[@]}"; do
    echo "   $issue"
  done
  if $allow_pascal; then
    echo "   PascalCase allowed (React/Angular detected)"
  fi
  echo "   Convention: lower-kebab-case for files and folders"
  echo "   Allow PascalCase: add [naming] allow-pascal-case = true to cpm.toml"
  echo "   docs: https://github.com/rkristelijn/cpm/blob/main/docs/checks/hook-no-unconventional-casing.md"
  exit 1
fi
exit 0
HOOK

# Install no-typos.sh
cat >"$HOOKS_DIR/lib/no-typos.sh" <<'HOOK'
#!/bin/bash
# lib/no-typos.sh — spell check staged files using typos-cli
# Requires: typos (brew install typos-cli / cargo install typos-cli)
# Skips gracefully if not installed.

command -v typos >/dev/null 2>&1 || exit 0

# Build file list from staged files
FILES=()
while IFS= read -r f; do
  [ -z "$f" ] && continue
  [ -f "$f" ] || continue
  # Skip binary-like files
  case "$f" in
    *.png|*.jpg|*.gif|*.ico|*.woff|*.woff2|*.ttf|*.eot|*.zip|*.tar|*.gz|*.pdf|*.exe|*.dll|*.so|*.dylib|*.jar|*.class|*.min.js|*.min.css|*.lock|*.svg) continue ;;
  esac
  FILES+=("$f")
done <<< "$STAGED"

[ ${#FILES[@]} -eq 0 ] && exit 0

# Run typos on staged files only — capture output
# --format brief: one line per typo
# --diff: don't show suggested fix (keep it short)
out=$(typos --format brief "${FILES[@]}" 2>/dev/null || true)
[ -z "$out" ] && exit 0

count=$(echo "$out" | wc -l | tr -d ' ')
echo "⚠ no-typos: $count spelling issue(s) found:"
echo "$out" | head -10 | sed 's/^/   /'
[ "$count" -gt 10 ] && echo "   ... and $((count - 10)) more"
echo "   Fix: typos --write-changes <file>"
echo "   Suppress: add word to _typos.toml or cspell.json"
echo "   docs: https://github.com/rkristelijn/cpm/blob/main/docs/checks/hook-no-typos.md"
exit 1
HOOK
chmod +x "$HOOKS_DIR/lib/no-typos.sh"
ok "Installed lib/no-typos.sh"

# Install no-dei-violations.sh
cat >"$HOOKS_DIR/lib/no-dei-violations.sh" <<'HOOK'
#!/bin/bash
# lib/no-dei-violations.sh — flag non-inclusive language in staged diffs
# WARNING check: exits 1 if found, but does not block commit.
# Suppression: add 'cpm:ignore dei' on the line, or disable the check.
# docs: https://github.com/rkristelijn/cpm/blob/main/docs/checks/hook-no-dei-violations.md

[ ! -s "$DIFF_CACHE" ] && exit 0

# Extract added lines (skip diff headers and removed lines)
ADDED=$(grep '^+[^+]' "$DIFF_CACHE" || true)
[ -z "$ADDED" ] && exit 0

# Skip comment lines and suppressed lines
ADDED=$(echo "$ADDED" | grep -v '^\+[[:space:]]*#' | grep -v '^\+[[:space:]]*//' | grep -v 'cpm:ignore dei' || true)
[ -z "$ADDED" ] && exit 0

# DEI term list: pattern|suggested replacement
# Some terms (normal, native, guys) have high false-positive rates in code.
# This is a WARNING check precisely because of that — it flags, not blocks.
TERMS='whitelist|allowlist
blacklist|denylist
master.slave|primary/secondary
\bslave\b|replica/secondary
whitebox|open-box
blackbox|closed-box
\bnormal\b|default/standard
\babnormal\b|atypical/unexpected
sanity.check|confidence check/validation
\bsanity\b|confidence/validity
\bsane\b|sensible/reasonable
\bcrazy\b|unexpected/surprising
\binsane\b|unreasonable/extreme
\bdummy\b|placeholder/stub/mock
\bcripple[ds]?\b|disable/degrade
\blame\b|flawed/weak
blind.spot|oversight/gap
grandfathered|legacy/exempt
\bmanpower\b|workforce/staffing
man.hours|person-hours
man.in.the.middle|on-path attack/interceptor
\bguys\b|everyone/team/folks
\bmankind\b|humanity/humankind
\bchairman\b|chair/chairperson
\bmiddleman\b|intermediary/broker
\bhousekeeping\b|maintenance/cleanup
\bnative\b|built-in/default
first.class.citizen|first-class concept/entity
\btribe\b|team/group/squad
\bninja\b|expert/specialist
\brockstar\b|expert/top performer
\bguru\b|expert/specialist
\bhandicapped\b|disabled/with a disability
wheelchair.bound|wheelchair user
\bretarded\b|delayed/slow
\bnuke\b|delete/remove/clear
\bsegregate[ds]?\b|separate/isolate
\bhe\/she\b|they
\bhis\/her\b|their'

found=0
while IFS='|' read -r pattern replacement; do
    [ -z "$pattern" ] && continue
    hits=$(echo "$ADDED" | grep -iE "$pattern" || true)
    if [ -n "$hits" ]; then
        count=$(echo "$hits" | wc -l | tr -d ' ')
        # Show the pattern and suggestion
        echo "⚠ dei: '$pattern' → consider '$replacement' ($count occurrence(s))"
        echo "$hits" | head -3 | sed 's/^+/   /'
        [ "$count" -gt 3 ] && echo "   ... and $((count - 3)) more"
        found=$((found + count))
    fi
done <<< "$TERMS"

if [ $found -gt 0 ]; then
    echo ""
    echo "⚠ no-dei-violations: $found non-inclusive term(s) found in staged changes"
    echo "   Suppress: add 'cpm:ignore dei' on the line, or disable the check"
    echo "   docs: https://github.com/rkristelijn/cpm/blob/main/docs/checks/hook-no-dei-violations.md"
    exit 1
fi
exit 0
HOOK
chmod +x "$HOOKS_DIR/lib/no-dei-violations.sh"
ok "Installed lib/no-dei-violations.sh"

# Install no-absolute-paths.sh
cat >"$HOOKS_DIR/lib/no-absolute-paths.sh" <<'HOOK'
#!/bin/bash
# lib/no-absolute-paths.sh — detect hardcoded absolute paths, ~/ home refs, ../ repo escapes
# These break portability, leak usernames, and reference files outside the repo.

[ ! -s "$DIFF_CACHE" ] && exit 0

# Scan only added lines, skip comments and string imports
ADDED=$(cat "$DIFF_CACHE" | grep '^+[^+]' | grep -v 'cpm:ignore path' || true)
[ -z "$ADDED" ] && exit 0

bad=()

# 1. Unix absolute paths: /Users/..., /home/..., /etc/..., /var/..., /tmp/...
#    But NOT: /dev/null, /dev/zero, /dev/urandom (common and safe)
#    And NOT: /api/, /v1/, /v2/ (URL paths)
#    And NOT: paths in comments only
hits=$(echo "$ADDED" | grep -E '["'"'"']/(?:Users|home|root|etc|var|tmp|opt|srv|mnt|Library)/[A-Za-z]' | grep -v '/dev/null\|/dev/zero\|/dev/urandom\|http[s]?://' || true)
for h in $hits; do
  bad+=("absolute unix path")
done

# 2. Windows absolute paths: C:\, D:\, etc.
hits=$(echo "$ADDED" | grep -E '[A-Z]:\\\\(Users|Windows|Program)' || true)
[ -n "$hits" ] && bad+=("absolute windows path")

# 3. Home directory references: ~/
hits=$(echo "$ADDED" | grep -E '["'"'"']~/' | grep -v 'cpm:ignore\|#\|//' || true)
[ -n "$hits" ] && bad+=("home directory reference ~/")

# 4. Parent directory escapes: ../ (going above repo root)
#    Allow: ../ in import statements (common in JS/TS: import x from '../utils')
#    Flag: ../ in file paths, configs, shell scripts
hits=$(echo "$ADDED" | grep -E '["'"'"']\.\./|path.*\.\./|dir.*\.\./|cd \.\.' | grep -v 'import\|require\|from.*\.\.\|cpm:ignore' || true)
[ -n "$hits" ] && bad+=("parent directory escape ../")

if [ ${#bad[@]} -gt 0 ]; then
  echo "⚠ no-absolute-paths: hardcoded paths detected in staged changes:"
  # Show actual matches (deduplicated by type)
  echo "$ADDED" | grep -E '["'"'"'"]/(Users|home|root|etc|var|tmp|opt)/|[A-Z]:\\\\|["'"'"'"]~/|["'"'"'"]\.\./|path.*\.\./' | grep -v 'cpm:ignore\|/dev/null\|http[s]?://' | head -5 | sed 's/^+//' | sed 's/^/   /'
  echo ""
  echo "   Risks: breaks on other machines, leaks usernames, references outside repo"
  echo "   Fix: use relative paths, env vars, or config files"
  echo "   Suppress: add 'cpm:ignore path' comment on the line"
  echo "   docs: https://github.com/rkristelijn/cpm/blob/main/docs/checks/hook-no-absolute-paths.md"
  exit 1
fi
exit 0
HOOK
chmod +x "$HOOKS_DIR/lib/no-absolute-paths.sh"
ok "Installed lib/no-absolute-paths.sh"

# ── commit-msg hook (conventional-commit + no-wip-commit) ─────
cat >"$HOOKS_DIR/commit-msg" <<'HOOK'
#!/bin/bash
# Global commit-msg — validates commit message format
# Skip: git commit --no-verify  or  CPM_SKIP_HOOKS=1

[ "$CPM_SKIP_HOOKS" = "1" ] && exit 0

HOOKS_DIR="$(cd "$(dirname "$0")/lib" && pwd)"
HOOKS_CONF="${XDG_CONFIG_HOME:-$HOME/.config}/cpm/hooks.conf"
MSG_FILE="$1"
MSG=$(head -1 "$MSG_FILE" 2>/dev/null)

read_check() {
    local name="$1"
    if [ -f "$HOOKS_CONF" ]; then
        local val
        val=$(grep -E "^${name}=" "$HOOKS_CONF" 2>/dev/null | tail -1 | cut -d= -f2 | tr -d ' ')
        echo "${val:-true}"
    else
        echo "true"
    fi
}

# conventional-commit — enforce conventional commit format
if [ "$(read_check "conventional-commit")" = "true" ]; then
    if ! echo "$MSG" | grep -qE '^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\(.+\))?!?:\ .+'; then
        echo "⛔ conventional-commit: message must match format: type(scope): description"
        echo "   Got: $MSG"
        echo "   Types: feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert"
        echo "   docs: https://github.com/rkristelijn/cpm/blob/main/docs/checks/hook-conventional-commit.md"
        exit 1
    fi
fi

# no-wip-commit — block WIP/temp/fixup on remote-tracking branches
if [ "$(read_check "no-wip-commit")" = "true" ]; then
    BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    TRACKING=$(git rev-parse --abbrev-ref --symbolic-full-name "@{u}" 2>/dev/null || true)
    if [ -n "$TRACKING" ]; then
        if echo "$MSG" | grep -qiE '\b(WIP|wip|temp|fixup|squash)\b'; then
            echo "⚠ no-wip-commit: commit message contains WIP/temp/fixup/squash on tracked branch ($BRANCH → $TRACKING)"
            echo "   Message: $MSG"
            echo "   These should be squashed before push. Continue with --no-verify if intentional."
            echo "   docs: https://github.com/rkristelijn/cpm/blob/main/docs/checks/hook-no-wip-commit.md"
            exit 1
        fi
    fi
fi

exit 0
HOOK
chmod +x "$HOOKS_DIR/commit-msg"
ok "Installed commit-msg hook (conventional-commit + no-wip-commit)"

# Set global hooks path
git config --global core.hooksPath "$HOOKS_DIR"
ok "Set core.hooksPath = $HOOKS_DIR"

# Verify tools
echo ""
echo -e "${BOLD}Tool Status:${NC}"
if command -v gitleaks >/dev/null 2>&1; then
  ok "gitleaks $(gitleaks version 2>/dev/null)"
else
  warn "gitleaks not found — install: brew install gitleaks"
fi

if command -v semgrep >/dev/null 2>&1; then
  ok "semgrep installed"
else
  warn "semgrep not found — install: brew install semgrep (hook will skip gracefully)"
fi

PII_VAULT="${PII_VAULT:-$HOME/.local/share/pii}"
if [[ -d "$PII_VAULT/patterns.d" ]]; then
  ok "PII vault active"
else
  warn "PII vault not found — run: cpm setup-pii-vault"
fi

echo ""
ok "Global hooks installed. Every git commit now runs security checks."
echo ""
info "Skip for one commit:  git commit --no-verify"
info "Skip always:          CPM_SKIP_HOOKS=1"
info "Check health:         cpm setup-global-hooks --check"
info "Remove:               cpm setup-global-hooks --remove"
echo ""
