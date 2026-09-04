#!/usr/bin/env bash
# generate-baseline.sh — Create ignore baselines for gitleaks + check-pii
#
# Run in a repo AFTER rotating all secrets and reviewing all PII findings.
# Future commits will only flag NEW findings.
#
# Usage:
#   generate-baseline.sh              # Generate both baselines
#   generate-baseline.sh --gitleaks   # Only gitleaks baseline
#   generate-baseline.sh --pii        # Only PII baseline

set -uo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ok() { echo -e "  ${GREEN}✓${NC}  $1"; }
info() { echo -e "  ${BLUE}ℹ${NC}  $1"; }
warn() { echo -e "  ${YELLOW}⚠${NC}  $1"; }

MODE="${1:-all}"

# ─────────────────────────────────────────────────────────────
# Gitleaks baseline
# ─────────────────────────────────────────────────────────────
if [[ "$MODE" == "all" || "$MODE" == "--gitleaks" ]]; then
  echo ""
  echo "━━━ Gitleaks Baseline ━━━"

  if ! command -v gitleaks >/dev/null 2>&1; then
    warn "gitleaks not installed — skipping"
  else
    # gitleaks >= 8.19 uses 'git'; older releases (e.g. 8.16) use 'detect'.
    if gitleaks git --help >/dev/null 2>&1; then
      gitleaks git --report-path .gitleaks-baseline.json --report-format json --no-banner 2>/dev/null
      exit_code=$?
    else
      gitleaks detect --report-path .gitleaks-baseline.json --report-format json --no-banner 2>/dev/null
      exit_code=$?
    fi
    if [[ -f .gitleaks-baseline.json ]]; then
      COUNT=$(python3 -c "import json; print(len(json.load(open('.gitleaks-baseline.json'))))" 2>/dev/null || echo "?")
      ok "Generated .gitleaks-baseline.json ($COUNT finding(s) baselined)"
      warn "⚠ .gitleaks-baseline.json may contain secret material (commit hashes, partial values)"
      warn "  Add it to .gitignore — do NOT commit to the repo"
      info "Future gitleaks runs will ignore these findings"
    elif [[ $exit_code -eq 0 ]]; then
      ok "No secrets found — no baseline needed"
    else
      warn "gitleaks exited with code $exit_code — check for errors"
    fi
  fi
fi

# ─────────────────────────────────────────────────────────────
# PII baseline (.piiignore)
# ─────────────────────────────────────────────────────────────
if [[ "$MODE" == "all" || "$MODE" == "--pii" ]]; then
  echo ""
  echo "━━━ PII Baseline ━━━"

  PII_VAULT="${PII_VAULT:-$HOME/.local/share/pii}"
  IGNOREFILE=".config/.piiignore"
  mkdir -p .config

  # Header
  cat >"$IGNOREFILE" <<EOF
# PII baseline — generated on $(date +%Y-%m-%d)
# All findings below have been reviewed and are intentional or false positives.
# Secrets have been rotated as of this date.
#
# Format: file:pattern (exact match) or *:pattern (global ignore)
# Regenerate: generate-baseline.sh --pii
EOF

  # Collect patterns from vault
  PATTERNS=()
  if [[ -d "$PII_VAULT/patterns.d" ]]; then
    for f in "$PII_VAULT/patterns.d"/*.pii; do
      [[ ! -f "$f" ]] && continue
      while IFS= read -r line; do
        [[ "$line" =~ ^#.*$ ]] && continue
        [[ -z "$line" ]] && continue
        PATTERNS+=("$line")
      done <"$f"
    done
  fi

  if [[ ${#PATTERNS[@]} -eq 0 ]]; then
    warn "No PII patterns found in vault — run: cpm setup-pii-vault"
  else
    info "Scanning with ${#PATTERNS[@]} patterns..."

    # Determine scan directories
    SCAN_DIRS=()
    for d in src/ lib/ checks/ docs/ scripts/ tests/ config/; do
      [[ -d "$d" ]] && SCAN_DIRS+=("$d")
    done

    if [[ ${#SCAN_DIRS[@]} -eq 0 ]]; then
      # Fallback: scan all non-hidden, non-node_modules
      SCAN_DIRS=(".")
    fi

    # Build combined regex for single-pass grep (O(1) instead of O(patterns × dirs))
    COMBINED_REGEX=""
    for pattern in "${PATTERNS[@]}"; do
      if [[ -n "$COMBINED_REGEX" ]]; then
        COMBINED_REGEX="$COMBINED_REGEX|$pattern"
      else
        COMBINED_REGEX="$pattern"
      fi
    done

    TOTAL=0
    HITS=$(grep -rln -E "$COMBINED_REGEX" \
      --include="*.cpp" --include="*.h" --include="*.hpp" \
      --include="*.sh" --include="*.md" --include="*.toml" \
      --include="*.json" --include="*.yml" --include="*.yaml" \
      --include="*.ts" --include="*.js" --include="*.py" \
      --include="*.tf" --include="*.hcl" \
      --exclude-dir=node_modules --exclude-dir=.git \
      --exclude-dir=dist --exclude-dir=build \
      "${SCAN_DIRS[@]}" 2>/dev/null || true)

    # For each hit file, determine which pattern(s) matched
    while IFS= read -r file; do
      [[ -z "$file" ]] && continue
      for pattern in "${PATTERNS[@]}"; do
        if grep -qlE "$pattern" "$file" 2>/dev/null; then
          echo "$file:$pattern" >>"$IGNOREFILE"
          ((TOTAL++))
        fi
      done
    done <<<"$HITS"

    # Deduplicate
    sort -u "$IGNOREFILE" -o "$IGNOREFILE"
    UNIQUE=$(grep -cv '^\(#\|$\)' "$IGNOREFILE" 2>/dev/null || echo 0)
    ok "Generated $IGNOREFILE ($UNIQUE unique ignore rule(s))"
    info "Review the file and remove any rules that should NOT be ignored"
  fi
fi

echo ""
echo "━━━ Next Steps ━━━"
echo ""
echo "  1. Review the baseline files"
echo "  2. Commit them to the repo (or .gitignore them)"
echo "  3. Future commits will only flag NEW findings"
echo ""
echo "  Test: git add . && git commit -m 'test' (should pass clean)"
echo ""
