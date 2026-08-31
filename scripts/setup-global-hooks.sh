#!/usr/bin/env bash
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
  for lib in gitleaks.sh pii.sh semgrep.sh filesize.sh secrets-fast.sh dangerous-shell.sh gitignore.sh no-main.sh merge-conflicts.sh no-junk-files.sh json-yaml-valid.sh no-broken-symlinks.sh debug-statements.sh no-binaries.sh no-empty-files.sh no-mixed-line-endings.sh; do
    if [[ -x "${CURRENT:-/dev/null}/lib/$lib" ]]; then
      ok "lib/$lib: present"
    else
      if [[ "$lib" == "secrets-fast.sh" ]]; then
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
ALL_CHECKS="gitleaks semgrep secrets-fast pii filesize conventional-commit dangerous-shell gitignore no-main merge-conflicts no-junk-files json-yaml-valid no-broken-symlinks debug-statements no-binaries no-empty-files no-mixed-line-endings no-wip-commit"
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

[checks]
# Blocking — commit rejected if these fail
gitleaks=true
semgrep=true
secrets-fast=true
pii=true
filesize=true
conventional-commit=true
dangerous-shell=true
no-main=true
merge-conflicts=true
no-junk-files=true
json-yaml-valid=true
no-broken-symlinks=true

# Warning — prompt to continue, don't block
gitignore=true
debug-statements=true
no-binaries=true
no-empty-files=true
no-mixed-line-endings=true

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
    # Update existing
    sed -i '' "s/^${name}=.*/${name}=${val}/" "$HOOKS_CONF"
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

# Run repo's own pre-commit first
REPO_HOOK="$REPO_ROOT/.git/hooks/pre-commit"
if [ -x "$REPO_HOOK" ]; then
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

# gitleaks — skip if repo handles secrets OR explicitly disabled
if should_run "gitleaks"; then
    if ! has_secrets && [ -x "$HOOKS_DIR/gitleaks.sh" ]; then
        bash "$HOOKS_DIR/gitleaks.sh" & pids+=($!); names+=("gitleaks")
    fi
fi

# secrets-fast — regex fallback, runs when gitleaks is not installed
if should_run "secrets-fast"; then
    if ! command -v gitleaks >/dev/null 2>&1 && ! has_secrets && [ -x "$HOOKS_DIR/secrets-fast.sh" ]; then
        bash "$HOOKS_DIR/secrets-fast.sh" & pids+=($!); names+=("secrets-fast")
    fi
fi

# pii
if should_run "pii"; then
    if ! has_pii && [ -x "$HOOKS_DIR/pii.sh" ]; then
        bash "$HOOKS_DIR/pii.sh" & pids+=($!); names+=("pii")
    fi
fi

# semgrep
if should_run "semgrep"; then
    if ! has_sast && [ -x "$HOOKS_DIR/semgrep.sh" ]; then
        bash "$HOOKS_DIR/semgrep.sh" & pids+=($!); names+=("semgrep")
    fi
fi

# filesize — always runs unless explicitly disabled
if should_run "filesize"; then
    if [ -x "$HOOKS_DIR/filesize.sh" ]; then
        bash "$HOOKS_DIR/filesize.sh" & pids+=($!); names+=("filesize")
    fi
fi

# dangerous-shell — detect destructive bash patterns
if should_run "dangerous-shell"; then
    if [ -x "$HOOKS_DIR/dangerous-shell.sh" ]; then
        bash "$HOOKS_DIR/dangerous-shell.sh" & pids+=($!); names+=("dangerous-shell")
    fi
fi

# no-main — block commits on main/master/develop
if should_run "no-main"; then
    if [ -x "$HOOKS_DIR/no-main.sh" ]; then
        bash "$HOOKS_DIR/no-main.sh" & pids+=($!); names+=("no-main")
    fi
fi

# merge-conflicts — detect conflict markers in staged files
if should_run "merge-conflicts"; then
    if [ -x "$HOOKS_DIR/merge-conflicts.sh" ]; then
        bash "$HOOKS_DIR/merge-conflicts.sh" & pids+=($!); names+=("merge-conflicts")
    fi
fi

# no-junk-files — block .DS_Store, Thumbs.db, *.pyc, etc.
if should_run "no-junk-files"; then
    if [ -x "$HOOKS_DIR/no-junk-files.sh" ]; then
        bash "$HOOKS_DIR/no-junk-files.sh" & pids+=($!); names+=("no-junk-files")
    fi
fi

# json-yaml-valid — validate JSON and YAML syntax
if should_run "json-yaml-valid"; then
    if [ -x "$HOOKS_DIR/json-yaml-valid.sh" ]; then
        bash "$HOOKS_DIR/json-yaml-valid.sh" & pids+=($!); names+=("json-yaml-valid")
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
    exit 1
fi

# --- Warning checks (non-blocking, prompt to continue) ---
warnings=()

# gitignore — warn if .gitignore is missing security patterns
if should_run "gitignore"; then
    if [ -x "$HOOKS_DIR/gitignore.sh" ]; then
        out=$(bash "$HOOKS_DIR/gitignore.sh" 2>&1)
        if [ $? -ne 0 ]; then
            warnings+=("$out")
        fi
    fi
fi

# debug-statements — detect leftover debug code in staged diffs
if should_run "debug-statements"; then
    if [ -x "$HOOKS_DIR/debug-statements.sh" ]; then
        out=$(bash "$HOOKS_DIR/debug-statements.sh" 2>&1)
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

# no-mixed-line-endings — detect mixed CRLF/LF in staged files
if should_run "no-mixed-line-endings"; then
    if [ -x "$HOOKS_DIR/no-mixed-line-endings.sh" ]; then
        out=$(bash "$HOOKS_DIR/no-mixed-line-endings.sh" 2>&1)
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
HOOK

cat >"$HOOKS_DIR/lib/pii.sh" <<'HOOK'
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
)

PATTERNS=(); NAMES=()
for name in "${!PATTERN_MAP[@]}"; do
    echo "$DISABLED" | grep -qw "$name" && continue
    PATTERNS+=("${PATTERN_MAP[$name]}"); NAMES+=("$name")
done
[ ${#PATTERNS[@]} -eq 0 ] && exit 0

ADDED=$(git diff --cached -U0 -- "${STAGED_FILES[@]}" 2>/dev/null \
  | awk '/^diff --git/{f=substr($3,3)} /^@@/{split($3,a,"+"); ln=a[1]+0; sub(/,.*/,"",ln); ln--; next} /^\+[^+]/{ln++; if ($0 !~ /cpm:ignore pii/) print f":"ln":"substr($0,2)}')
[ -z "$ADDED" ] && exit 0

found=0
for i in "${!PATTERNS[@]}"; do
    pattern="${PATTERNS[$i]}"; name="${NAMES[$i]}"
    while IFS= read -r hit; do
        echo "⚠ pii($name): ${hit%%:*}:$(echo "$hit" | cut -d: -f2)  pattern '$name'"
        found=$((found + 1))
    done < <(echo "$ADDED" | grep -E "$pattern" || true)
done

[ $found -gt 0 ] && { echo "   suppress: 'cpm:ignore pii' on line, or 'disable <name>' in .config/.pii-config"; exit 1; }
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
exit $rc
HOOK

cat >"$HOOKS_DIR/lib/filesize.sh" <<'HOOK'
#!/bin/bash
MAX_KB=5120
while IFS= read -r file; do
    [ -f "$file" ] || continue
    size=$(wc -c < "$file" 2>/dev/null)
    if [ "$size" -gt $((MAX_KB * 1024)) ]; then
        echo "⚠ filesize: $file is $(( size / 1024 / 1024 ))MB (max ${MAX_KB}KB)"
        exit 1
    fi
done <<< "$STAGED"
exit 0
HOOK

chmod +x "$HOOKS_DIR/lib"/*.sh
ok "Installed lib hooks: gitleaks, pii, semgrep, filesize"

# Install secrets-fast.sh from cpm's scripts/lib/ if available
SECRETS_FAST_SRC="$CPM_ROOT/scripts/lib/secrets-fast.sh"
if [[ -f "$SECRETS_FAST_SRC" ]]; then
  cp "$SECRETS_FAST_SRC" "$HOOKS_DIR/lib/secrets-fast.sh"
  chmod +x "$HOOKS_DIR/lib/secrets-fast.sh"
  ok "Installed lib/secrets-fast.sh (regex-only fallback for gitleaks)"
else
  warn "scripts/lib/secrets-fast.sh not found — regex fallback unavailable"
fi

# Install dangerous-shell.sh
cat >"$HOOKS_DIR/lib/dangerous-shell.sh" <<'HOOK'
#!/bin/bash
# lib/dangerous-shell.sh — detect destructive/evil bash patterns in staged files

COMBINED='rm -rf /[^v]|rm -rf \$[^{]|:\(\)\{.*\|.*\};:|chmod -R 777 /[^.]|chmod.*777 /|eval "\$|eval \$[^(]|curl.*\| *[bs]h|wget.*\| *sh|wget.*-O-.*\| *sh|git push.*--force|git reset --hard|history -c|export HISTSIZE=0|unset HISTFILE|mkfs\.|find / -delete|kill -9 -1|passwd -d|iptables -F|crontab -r'

# Only scan staged shell-like files, exclude hook scripts themselves and test fixtures
SHELL_FILES=$(echo "$STAGED" | grep -E '\.(sh|bash|zsh|yml|yaml|Makefile|Dockerfile)$' | grep -v 'dangerous-shell\|setup-global-hooks\|check-dangerous-shell\|cpm_rules_test\|/\.config/git/hooks/' || true)
[ -z "$SHELL_FILES" ] && exit 0

DIFF=$(git diff --cached -U0 -- $SHELL_FILES 2>/dev/null | grep '^+[^+]' | grep -v 'cpm:ignore' || true)
[ -z "$DIFF" ] && exit 0

# Filter out comments (lines starting with +#, or + followed by whitespace then #)
hits=$(echo "$DIFF" | grep -E "$COMBINED" | grep -v '^+[[:space:]]*#' | grep -v "^+COMBINED=" | grep -v "^+.*'.*rm -rf" || true)
[ -z "$hits" ] && exit 0

echo "⚠ dangerous-shell: destructive patterns detected in staged files:"
echo "$hits" | head -5 | sed 's/^/   /'
exit 1
HOOK

# Install gitignore.sh
cat >"$HOOKS_DIR/lib/gitignore.sh" <<'HOOK'
#!/bin/bash
# lib/gitignore.sh — verify .gitignore contains mandatory security patterns
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
)

missing=()
for pattern in "${MUST_HAVE[@]}"; do
  grep -qF "$pattern" "$GI" 2>/dev/null || missing+=("$pattern")
done

if [ ${#missing[@]} -gt 0 ]; then
  echo "⚠ gitignore: .gitignore is missing security patterns:"
  for m in "${missing[@]}"; do
    echo "   + $m"
  done
  echo "   Add them to prevent accidental secret commits."
  echo "   Suppress: add the patterns or use --no-verify"
  exit 1
fi
exit 0
HOOK

chmod +x "$HOOKS_DIR/lib/dangerous-shell.sh" "$HOOKS_DIR/lib/gitignore.sh"
ok "Installed lib/dangerous-shell.sh + lib/gitignore.sh"

# ── New shift-left lib scripts ─────────────────────────────────

# Install no-main.sh
cat >"$HOOKS_DIR/lib/no-main.sh" <<'HOOK'
#!/bin/bash
# lib/no-main.sh — block commits on protected branches
BRANCH=$(git rev-parse --abbrev-ref HEAD)
case "$BRANCH" in
  main|master|develop)
    echo "⛔ no-main: commit on $BRANCH blocked. Use a feature branch."
    exit 1
    ;;
esac
exit 0
HOOK

# Install merge-conflicts.sh
cat >"$HOOKS_DIR/lib/merge-conflicts.sh" <<'HOOK'
#!/bin/bash
# lib/merge-conflicts.sh — detect conflict markers in staged files
DIFF=$(git diff --cached -U0 2>/dev/null | grep -E '^\+(<{7}|={7}|>{7})' || true)
if [ -n "$DIFF" ]; then
  echo "⛔ merge-conflicts: conflict markers found in staged files:"
  echo "$DIFF" | head -10 | sed 's/^/   /'
  exit 1
fi
exit 0
HOOK

# Install no-junk-files.sh
cat >"$HOOKS_DIR/lib/no-junk-files.sh" <<'HOOK'
#!/bin/bash
# lib/no-junk-files.sh — block junk files from being committed
found=()
while IFS= read -r f; do
  [ -z "$f" ] && continue
  case "$f" in
    .DS_Store|*/.DS_Store) found+=("$f") ;;
    Thumbs.db|*/Thumbs.db) found+=("$f") ;;
    *.pyc) found+=("$f") ;;
    __pycache__/*|*/__pycache__/*) found+=("$f") ;;
    node_modules/*|*/node_modules/*) found+=("$f") ;;
    build/*|*/build/*) found+=("$f") ;;
    dist/*|*/dist/*) found+=("$f") ;;
  esac
done <<< "$STAGED"

if [ ${#found[@]} -gt 0 ]; then
  echo "⛔ no-junk-files: blocked files that shouldn't be committed:"
  for f in "${found[@]}"; do
    echo "   $f"
  done
  exit 1
fi
exit 0
HOOK

# Install json-yaml-valid.sh
cat >"$HOOKS_DIR/lib/json-yaml-valid.sh" <<'HOOK'
#!/bin/bash
# lib/json-yaml-valid.sh — validate JSON and YAML syntax in staged files
errors=0
while IFS= read -r f; do
  [ -z "$f" ] && continue
  [ -f "$f" ] || continue
  case "$f" in
    *.json)
      if ! python3 -c "import json; json.load(open('$f'))" 2>/dev/null; then
        echo "⛔ json-yaml-valid: invalid JSON: $f"
        errors=$((errors + 1))
      fi
      ;;
    *.yml|*.yaml)
      if command -v python3 >/dev/null 2>&1; then
        if python3 -c "import yaml" 2>/dev/null; then
          if ! python3 -c "import yaml; yaml.safe_load(open('$f'))" 2>/dev/null; then
            echo "⛔ json-yaml-valid: invalid YAML: $f"
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
  exit 1
fi
exit 0
HOOK

# Install debug-statements.sh
cat >"$HOOKS_DIR/lib/debug-statements.sh" <<'HOOK'
#!/bin/bash
# lib/debug-statements.sh — detect debug/trace statements in staged diffs
# Excludes test files, spec files, and config files

DEBUG_PATTERN='console\.(log|debug)|debugger[;[:space:]]|binding\.pry|byebug|pdb\.set_trace|breakpoint()'

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

DIFF=$(git diff --cached -U0 -- "${FILES[@]}" 2>/dev/null | grep '^+[^+]' | grep -v 'cpm:ignore' || true)
[ -z "$DIFF" ] && exit 0

hits=$(echo "$DIFF" | grep -E "$DEBUG_PATTERN" || true)
[ -z "$hits" ] && exit 0

count=$(echo "$hits" | wc -l | tr -d ' ')
echo "⚠ debug-statements: $count debug statement(s) found in staged changes:"
echo "$hits" | head -5 | sed 's/^+/   /'
echo "   Suppress: add 'cpm:ignore' comment on the line"
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
  exit 1
fi
exit 0
HOOK

# Install no-mixed-line-endings.sh
cat >"$HOOKS_DIR/lib/no-mixed-line-endings.sh" <<'HOOK'
#!/bin/bash
# lib/no-mixed-line-endings.sh — detect files with mixed CRLF and LF
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
  echo "⚠ no-mixed-line-endings: files with mixed CRLF/LF:"
  for m in "${mixed[@]}"; do
    echo "   $m"
  done
  echo "   Fix: dos2unix <file> or configure .gitattributes"
  exit 1
fi
exit 0
HOOK

chmod +x "$HOOKS_DIR/lib/no-main.sh" "$HOOKS_DIR/lib/merge-conflicts.sh" \
         "$HOOKS_DIR/lib/no-junk-files.sh" "$HOOKS_DIR/lib/json-yaml-valid.sh" \
         "$HOOKS_DIR/lib/no-broken-symlinks.sh" "$HOOKS_DIR/lib/debug-statements.sh" \
         "$HOOKS_DIR/lib/no-binaries.sh" "$HOOKS_DIR/lib/no-empty-files.sh" \
         "$HOOKS_DIR/lib/no-mixed-line-endings.sh"
ok "Installed 9 new lib hooks (no-main, merge-conflicts, no-junk-files, json-yaml-valid, no-broken-symlinks, debug-statements, no-binaries, no-empty-files, no-mixed-line-endings)"

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
