#!/usr/bin/env bash
# maturity.sh — Check maturity level of current repo.
# Usage: bash lib/shell/maturity.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/init.sh" 2>/dev/null || true

score=0
total=0

check() {
  local id="$1" name="$2" doc="$3" level="$4"
  shift 4
  total=$((total + 1))
  if "$@" >/dev/null 2>&1; then
    score=$((score + 1))
    printf "  ✓ %-6s %s\n" "$id" "$name"
  else
    printf "  ✗ %-6s %s\n" "$id" "$name"
    printf "         → %s\n" "$doc"
  fi
}

print_header "Maturity Audit"
echo ""

echo "  Level 1 — Managed"
echo "  ─────────────────────────────────"
check "1.1" "cpm.toml exists" \
  "Run: cpm init | docs/features/init.md" 1 \
  test -f cpm.toml
check "1.2" "Makefile exists" \
  "Run: cpm eject | docs/features/eject.md" 1 \
  test -f Makefile
check "1.3" "Source formatting configured" \
  "Add format check to cpm.toml | docs/features/check.md" 1 \
  bash -c '[[ -f .config/.clang-format || -f .clang-format || -f .prettierrc* || -f biome.json || $(grep -c "format" cpm.toml 2>/dev/null) -gt 0 ]]'
check "1.4" "Secret scanning available" \
  "Install: brew install gitleaks | docs/features/secrets.md" 1 \
  command -v gitleaks
check "1.5" "Pre-commit hook installed" \
  "Run: cpm hook | docs/features/hooks.md" 1 \
  bash -c '[[ -x .git/hooks/pre-commit ]] && grep -q "pre-commit = true" cpm.toml 2>/dev/null'
check "1.6" "Unit tests exist" \
  "Run: cpm new test <name> | docs/features/new.md" 1 \
  bash -c 'find . -name "*test*" -not -path "./.git/*" -not -path "./node_modules/*" | grep -q .'
check "1.7" "Conventional commits enforced" \
  "Run: cpm hook (commit-msg) | docs/features/commit.md" 1 \
  bash -c '[[ -x .git/hooks/commit-msg ]] && grep -q "commit-msg = true" cpm.toml 2>/dev/null'

echo ""
echo "  Level 2 — Defined"
echo "  ─────────────────────────────────"
check "2.1" "Architecture docs (ADRs)" \
  "Create docs/adrs/ with decisions | docs/adrs/" 2 \
  bash -c 'find docs -name "architecture*" -o -name "adr-*" 2>/dev/null | grep -q .'
check "2.2" "Complexity check configured" \
  "Add [checks.complexity] to cpm.toml | docs/features/check.md" 2 \
  bash -c 'grep -q "complexity" cpm.toml 2>/dev/null'
check "2.3" "File size limits configured" \
  "Add [limits] to cpm.toml | docs/features/config.md" 2 \
  bash -c 'grep -q "file-size\|source-lines" cpm.toml 2>/dev/null'
check "2.4" "CI pipeline exists" \
  "Add .github/workflows/ or .gitlab-ci.yml" 2 \
  bash -c '[[ -d .github/workflows || -f .gitlab-ci.yml ]]'
check "2.5" "README exists" \
  "Create README.md with project overview" 2 \
  test -f README.md
check "2.6" "CONTRIBUTING exists" \
  "Create CONTRIBUTING.md for contributors | docs/features/config.md" 2 \
  test -f CONTRIBUTING.md

echo ""
echo "  Level 3 — Quantitative"
echo "  ─────────────────────────────────"
check "3.1" "Slop detection" \
  "checks/universal/quality/check-slop.sh" 3 \
  bash -c 'find . -path "*check-slop*" 2>/dev/null | grep -q .'
check "3.2" "Research freshness" \
  "checks/universal/quality/check-research-freshness.sh" 3 \
  bash -c 'find . -path "*check-research*" 2>/dev/null | grep -q .'
check "3.3" "Timing & metrics" \
  "Run checks to generate .tmp/timings.jsonl" 3 \
  bash -c '[[ -f .tmp/timings.jsonl ]]'
check "3.4" "JUnit reports" \
  "Run: cpm check (generates .tmp/reports/)" 3 \
  bash -c '[[ -d .tmp/reports ]]'
check "3.5" "Dead code detection" \
  "checks/universal/docs/check-dead-docs.sh" 3 \
  bash -c 'find . -path "*check-dead*" -not -path "./.git/*" 2>/dev/null | grep -q .'

# Calculate level
level=0
((score >= 5)) && level=1
((score >= 10)) && level=2
((score >= 14)) && level=3

echo ""
echo "  ═══════════════════════════════════"
echo "  Score: $score/$total | Level: $level"
echo "  ═══════════════════════════════════"
echo ""

if ((level < 3)); then
  echo "  Next: fix the ✗ items above to reach level $((level + 1))"
  echo ""
fi
