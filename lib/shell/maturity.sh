#!/usr/bin/env bash
# maturity.sh — Check CMMI maturity level of current repo.
#
# Usage: cpm cmmi
#
# Levels:
#   0: Nothing (no checks, no process)
#   1: Managed (formatting, secrets, hooks, tests)
#   2: Defined (architecture docs, complexity, coverage, e2e)
#   3: Quantitative (metrics, slop, research, mutation)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/init.sh" 2>/dev/null || true

score=0
total=0
details=""

check() {
  local name="$1" level="$2"
  shift 2
  total=$((total + 1))
  if "$@" >/dev/null 2>&1; then
    score=$((score + 1))
    details+="  ✓ $name\n"
  else
    details+="  ✗ $name (level $level)\n"
  fi
}

print_header "Maturity Audit (inspired by CMMI)"

# Level 1: Managed
echo "  Level 1 — Managed"
check "cpm.toml exists" 1 test -f cpm.toml
check "Makefile exists" 1 test -f Makefile
check "source formatting configured" 1 bash -c '[[ -f .config/.clang-format || -f .clang-format || -f .prettierrc* || -f biome.json || $(grep -c "format" cpm.toml 2>/dev/null) -gt 0 ]]'
check "secret scanning (gitleaks)" 1 command -v gitleaks
check "pre-commit hook" 1 test -x .git/hooks/pre-commit
check "unit tests exist" 1 bash -c 'find . -name "*test*" -not -path "./.git/*" -not -path "./node_modules/*" | grep -q .'
check "conventional commits" 1 test -x .git/hooks/commit-msg

echo ""
echo "  Level 2 — Defined"
check "architecture docs" 2 bash -c 'find docs -name "architecture*" -o -name "adr-*" 2>/dev/null | grep -q .'
check "complexity check" 2 bash -c 'grep -q "complexity" cpm.toml 2>/dev/null'
check "file size limits" 2 bash -c 'grep -q "file-size\|source-lines" cpm.toml 2>/dev/null'
check "CI pipeline" 2 bash -c '[[ -d .github/workflows || -f .gitlab-ci.yml ]]'
check "README exists" 2 test -f README.md
check "CONTRIBUTING exists" 2 test -f CONTRIBUTING.md

echo ""
echo "  Level 3 — Quantitative"
check "slop detection" 3 bash -c 'find . -path "*/check-slop*" 2>/dev/null | grep -q .'
check "research freshness" 3 bash -c 'find . -path "*check-research*" -o -path "*research-freshness*" 2>/dev/null | grep -q .'
check "timing/metrics" 3 bash -c '[[ -f .tmp/timings.jsonl ]]'
check "JUnit reports" 3 bash -c '[[ -d .tmp/reports ]]'
check "dead code detection" 3 bash -c 'find . -path "*check-dead*" -not -path "./.git/*" 2>/dev/null | grep -q .'

# Calculate level
level=0
level1_needed=5
level2_needed=10
level3_needed=14

((score >= level1_needed)) && level=1
((score >= level2_needed)) && level=2
((score >= level3_needed)) && level=3

echo ""
echo "  ─────────────────────────────────"
printf "%b" "$details"
echo "  ─────────────────────────────────"
echo ""
echo "  Score: $score/$total"
echo "  Level: $level"
echo ""

if ((level < 3)); then
  echo "  Next: fix the ✗ items above to reach level $((level + 1))"
fi
