#!/usr/bin/env bash
#
# check-neglect-score.sh — Inverse maturity: how neglected is this repo?
#
# Higher neglect = higher likelihood of exploitable bugs.
# Signals: stale deps, no security commits, missing tests for security code,
# abandoned maintenance, no CODEOWNERS, high churn without review.
#
# Output: neglect score 0-100 (0 = well maintained, 100 = abandoned)
#
# @see docs/adrs/adr-008-maturity-guided-exploitation.md (apex-cli)

source "$(dirname "$0")/../../lib/shell/check.sh"

REPO_DIR="${1:-.}"
cd "$REPO_DIR" 2>/dev/null || true

NEGLECT=0
SIGNALS=0

# Helper: add neglect points
add_neglect() {
  local points="$1" reason="$2" file="${3:-.}"
  NEGLECT=$((NEGLECT + points))
  SIGNALS=$((SIGNALS + 1))
  findings_add "info" "$file" "neglect-signal" "$reason (score +$points)"
}

# ═══ Signal 1: Last security-related commit age ═══
if git rev-parse --git-dir >/dev/null 2>&1; then
  last_sec_commit=$(git log --all --oneline --grep="security\|vuln\|CVE\|fix.*auth\|patch.*xss\|sanitize" --since="365 days ago" 2>/dev/null | wc -l | tr -d ' ')
  if [[ $last_sec_commit -eq 0 ]]; then
    add_neglect 15 "No security-related commits in past year"
  fi

  # Last commit at all
  days_since_last=$(( ($(date +%s) - $(git log -1 --format=%ct 2>/dev/null || echo "$(date +%s)")) / 86400 ))
  if [[ $days_since_last -gt 180 ]]; then
    add_neglect 20 "Last commit ${days_since_last} days ago (>6 months)"
  elif [[ $days_since_last -gt 90 ]]; then
    add_neglect 10 "Last commit ${days_since_last} days ago (>3 months)"
  fi
fi

# ═══ Signal 2: Security files without tests ═══
sec_files=$(grep -rl "auth\|password\|token\|session\|encrypt\|secret" --include="*.py" --include="*.ts" --include="*.js" --include="*.go" --include="*.java" . 2>/dev/null | grep -v node_modules | grep -v test | grep -v spec | grep -v __pycache__ | wc -l | tr -d ' ')
test_files=$(find . -name "*test*" -o -name "*spec*" | grep -v node_modules | wc -l | tr -d ' ')

if [[ $sec_files -gt 0 && $test_files -eq 0 ]]; then
  add_neglect 20 "Security-related code ($sec_files files) but zero test files"
elif [[ $sec_files -gt 10 && $test_files -lt 3 ]]; then
  add_neglect 10 "Security code ($sec_files files) with minimal tests ($test_files)"
fi

# ═══ Signal 3: No CODEOWNERS / no review process ═══
if [[ ! -f "CODEOWNERS" && ! -f ".github/CODEOWNERS" && ! -f "docs/CODEOWNERS" ]]; then
  add_neglect 5 "No CODEOWNERS file (no enforced review)"
fi

# ═══ Signal 4: No security policy ═══
if [[ ! -f "SECURITY.md" && ! -f ".github/SECURITY.md" ]]; then
  add_neglect 5 "No SECURITY.md (no vulnerability disclosure process)" "SECURITY.md"
fi

# ═══ Signal 5: Dependency freshness ═══
if [[ -f "package.json" ]]; then
  # Check if lockfile is stale (>6 months old)
  lock=""
  [[ -f "package-lock.json" ]] && lock="package-lock.json"
  [[ -f "yarn.lock" ]] && lock="yarn.lock"
  [[ -f "pnpm-lock.yaml" ]] && lock="pnpm-lock.yaml"
  if [[ -n "$lock" ]]; then
    lock_age=$(( ($(date +%s) - $(stat -f %m "$lock" 2>/dev/null || stat -c %Y "$lock" 2>/dev/null || echo "$(date +%s)")) / 86400 ))
    if [[ $lock_age -gt 180 ]]; then
      add_neglect 10 "Lockfile $lock is ${lock_age} days old (>6 months)" "$lock"
    fi
  fi
fi

if [[ -f "requirements.txt" ]]; then
  pinned=$(grep -c "==" requirements.txt 2>/dev/null || echo 0)
  unpinned=$(grep -cv "==\|^#\|^$" requirements.txt 2>/dev/null || echo 0)
  if [[ $unpinned -gt $pinned && $unpinned -gt 3 ]]; then
    add_neglect 10 "requirements.txt: $unpinned unpinned deps (no version control)" "requirements.txt"
  fi
fi

# ═══ Signal 6: High contributor turnover ═══
if git rev-parse --git-dir >/dev/null 2>&1; then
  recent_authors=$(git log --since="90 days ago" --format="%ae" 2>/dev/null | sort -u | wc -l | tr -d ' ')
  total_authors=$(git log --format="%ae" 2>/dev/null | sort -u | wc -l | tr -d ' ')
  if [[ $total_authors -gt 5 && $recent_authors -le 1 ]]; then
    add_neglect 10 "Bus factor: only $recent_authors active contributor(s) in 90 days (of $total_authors total)"
  fi
fi

# ═══ Signal 7: Open security issues / advisories ═══
if [[ -d ".github" ]] && find . -name "*.md" -path "*/issues/*" 2>/dev/null | grep -qi "security\|vuln"; then
  add_neglect 5 "Open security-related issues found"
fi

# ═══ Final score ═══
# Cap at 100
[[ $NEGLECT -gt 100 ]] && NEGLECT=100

# Report
if [[ $NEGLECT -ge 50 ]]; then
  findings_add "error" "." "neglect-score" "Neglect score: $NEGLECT/100 (HIGH — likely exploitable)" "Run: cpm check --full" "docs/adrs/adr-013-product-positioning.md"
elif [[ $NEGLECT -ge 25 ]]; then
  findings_add "warning" "." "neglect-score" "Neglect score: $NEGLECT/100 (medium)" "Review security posture"
else
  findings_add "pass" "." "neglect-score" "Neglect score: $NEGLECT/100 (low — well maintained)"
fi
