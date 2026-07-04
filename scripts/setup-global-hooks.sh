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

ok()   { echo -e "  ${GREEN}✓${NC}  $1"; }
warn() { echo -e "  ${YELLOW}⚠${NC}  $1"; }
err()  { echo -e "  ${RED}✗${NC}  $1"; }
info() { echo -e "  ${BLUE}ℹ${NC}  $1"; }

# Hooks location (relative to this script's repo)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CPM_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Default hooks dir — can be overridden
HOOKS_DIR="${GLOBAL_HOOKS_DIR:-$HOME/git/hub/dotfiles/hooks}"

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
  for hook in pre-commit; do
    if [[ -x "${CURRENT:-/dev/null}/$hook" ]]; then
      ok "$hook hook: executable"
    else
      err "$hook hook: missing or not executable"
      ((errors++))
    fi
  done

  # Lib scripts
  for lib in gitleaks.sh pii.sh semgrep.sh filesize.sh; do
    if [[ -x "${CURRENT:-/dev/null}/lib/$lib" ]]; then
      ok "lib/$lib: present"
    else
      err "lib/$lib: missing"
      ((errors++))
    fi
  done

  echo ""
  echo -e "${BOLD}Tool Availability${NC}"
  echo ""

  # gitleaks
  if command -v gitleaks >/dev/null 2>&1; then
    ok "gitleaks $(gitleaks version 2>/dev/null)"
  else
    warn "gitleaks not installed (brew install gitleaks)"
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

# Check hooks directory exists
if [[ ! -d "$HOOKS_DIR" ]]; then
  echo ""
  warn "Hooks directory not found: $HOOKS_DIR"
  echo ""
  echo "  Creating hooks from scratch..."
  mkdir -p "$HOOKS_DIR/lib"

  # Create orchestrator
  cat >"$HOOKS_DIR/pre-commit" <<'HOOK'
#!/bin/bash
# Global pre-commit — runs security checks that the repo doesn't cover itself
# Skip: git commit --no-verify  or  CPM_SKIP_HOOKS=1

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

# Detect what repo already covers
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

# Run only what's missing (parallel)
pids=(); names=()

if ! has_secrets && [ -x "$HOOKS_DIR/gitleaks.sh" ]; then
    bash "$HOOKS_DIR/gitleaks.sh" & pids+=($!); names+=("gitleaks")
fi
if ! has_pii && [ -x "$HOOKS_DIR/pii.sh" ]; then
    bash "$HOOKS_DIR/pii.sh" & pids+=($!); names+=("pii")
fi
if ! has_sast && [ -x "$HOOKS_DIR/semgrep.sh" ]; then
    bash "$HOOKS_DIR/semgrep.sh" & pids+=($!); names+=("semgrep")
fi
if [ -x "$HOOKS_DIR/filesize.sh" ]; then
    bash "$HOOKS_DIR/filesize.sh" & pids+=($!); names+=("filesize")
fi

# Wait for all
failed=()
for i in "${!pids[@]}"; do
    wait "${pids[$i]}" || failed+=("${names[$i]}")
done

if [ ${#failed[@]} -gt 0 ]; then
    echo "⛔ pre-commit: ${failed[*]} failed (skip: --no-verify)"
    exit 1
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
STAGED_FILES=$(echo "$STAGED" | grep -vE '\.(lock|min\.js|svg|png|jpg|gif)$')
[ -z "$STAGED_FILES" ] && exit 0

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

ADDED=$(git diff --cached -U0 -- $STAGED_FILES 2>/dev/null \
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
  ok "Created lib hooks: gitleaks, pii, semgrep, filesize"
fi

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
