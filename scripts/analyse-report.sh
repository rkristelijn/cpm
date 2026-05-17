#!/usr/bin/env bash
# scripts/analyse-report.sh — Run analyse and persist findings as JSONL
# Usage: bash scripts/analyse-report.sh [path] [--deep]
# Output: .cpm/findings.jsonl (per-repo) + ~/.local/share/cpm/analyse-findings.jsonl (global)
set -o nounset -o pipefail

REPO="${1:-.}"
DEEP=false
[[ "${2:-}" == "--deep" ]] && DEEP=true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK_DIR="$(cd "$SCRIPT_DIR/../checks" && pwd)"
REPO_ABS="$(cd "$REPO" && pwd)"
REPO_NAME="$(basename "$REPO_ABS")"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Output locations
REPO_DB="$REPO_ABS/.cpm/findings.jsonl"
GLOBAL_DB="${HOME}/.local/share/cpm/analyse-findings.jsonl"
MATURITY_FILE="$REPO_ABS/.cpm/maturity.json"

mkdir -p "$REPO_ABS/.cpm" "$(dirname "$GLOBAL_DB")"

# Clear previous findings for this repo
>"$REPO_DB"

# === Emit a finding in JSONL format ===
emit() {
  local sev="$1" check="$2" rule="$3" msg="$4" file="${5:-.}"
  local line="{\"repo\":\"$REPO_NAME\",\"timestamp\":\"$TIMESTAMP\",\"severity\":\"$sev\",\"check\":\"$check\",\"rule\":\"$rule\",\"message\":\"$msg\",\"file\":\"$file\"}"
  echo "$line" >>"$REPO_DB"
  echo "$line" >>"$GLOBAL_DB"
}

echo ""
echo "  cpm analyse → persisting findings"
echo ""

# === Run all checks and capture findings ===
run_checks() {
  local dir="$1"
  for f in "$dir"/*.sh; do
    [ -f "$f" ] || continue
    local check_name=$(basename "$f" .sh)
    bash "$f" "$REPO" 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | grep -E "^\s*(warning|error)" | while IFS= read -r line; do
      local sev=$(echo "$line" | awk '{print $1}')
      local rule=$(echo "$line" | awk '{print $2}')
      local msg=$(echo "$line" | awk '{$1=""; $2=""; print}' | sed 's/^\s*//')
      [ -z "$rule" ] || [ "$rule" = "$sev" ] && continue
      emit "${sev:-warning}" "$check_name" "$rule" "$msg"
    done
  done
}

# Universal
run_checks "$CHECK_DIR/universal/quality"
run_checks "$CHECK_DIR/universal/security"
run_checks "$CHECK_DIR/universal/docs"
run_checks "$CHECK_DIR/universal/deps"

# JavaScript (if applicable)
[ -f "$REPO/package.json" ] && run_checks "$CHECK_DIR/javascript"

# Testing
[ -f "$REPO/package.json" ] && run_checks "$CHECK_DIR/javascript/testing"

# Angular
[ -f "$REPO/angular.json" ] && run_checks "$CHECK_DIR/javascript/angular"

# Next.js
([ -f "$REPO/next.config.ts" ] || [ -f "$REPO/next.config.js" ] || [ -f "$REPO/next.config.mjs" ]) &&
  run_checks "$CHECK_DIR/javascript/nextjs"

# Nx
[ -f "$REPO/nx.json" ] && run_checks "$CHECK_DIR/javascript/nx"

# === Third-party security & quality tools (if installed) ===
echo "  Running third-party tools (if available)..."

# Gitleaks — secret scanning
if command -v gitleaks >/dev/null 2>&1; then
  LEAKS=$(cd "$REPO_ABS" && gitleaks detect --source . --no-banner --no-color 2>/dev/null | grep -c "Secret\|Finding" || echo "0")
  [ "${LEAKS:-0}" -gt 0 ] 2>/dev/null && emit "error" "gitleaks" "secret-detected" "$LEAKS secret(s) found in code"
  echo "    ✓ gitleaks: no secrets"
else
  echo "    · gitleaks: not installed (brew install gitleaks)"
fi

# Semgrep — SAST (static application security testing)
if command -v semgrep >/dev/null 2>&1; then
  SEMGREP_COUNT=$(cd "$REPO_ABS" && semgrep scan --config auto --quiet --json 2>/dev/null | grep -c '"check_id"' || echo "0")
  [ "${SEMGREP_COUNT:-0}" -gt 0 ] 2>/dev/null && emit "warning" "semgrep" "sast-finding" "$SEMGREP_COUNT finding(s) from semgrep"
  [ "${SEMGREP_COUNT:-0}" -eq 0 ] 2>/dev/null && echo "    ✓ semgrep: no findings"
else
  echo "    · semgrep: not installed (brew install semgrep)"
fi

# Trivy — vulnerability scanner (containers + filesystem)
if command -v trivy >/dev/null 2>&1; then
  TRIVY_COUNT=$(cd "$REPO_ABS" && trivy fs --quiet --severity HIGH,CRITICAL --format json . 2>/dev/null | grep -c '"VulnerabilityID"' || echo "0")
  [ "${TRIVY_COUNT:-0}" -gt 0 ] 2>/dev/null && emit "error" "trivy" "vulnerability" "$TRIVY_COUNT HIGH/CRITICAL vulnerability(ies)"
  [ "${TRIVY_COUNT:-0}" -eq 0 ] 2>/dev/null && echo "    ✓ trivy: no high/critical vulns"
else
  echo "    · trivy: not installed (brew install trivy)"
fi

# OSV-Scanner — Google's open source vulnerability scanner
if command -v osv-scanner >/dev/null 2>&1; then
  OSV_COUNT=$(cd "$REPO_ABS" && osv-scanner --format json . 2>/dev/null | grep -c '"id"' || echo "0")
  [ "${OSV_COUNT:-0}" -gt 0 ] 2>/dev/null && emit "warning" "osv-scanner" "osv-vuln" "$OSV_COUNT known vulnerability(ies)"
  [ "${OSV_COUNT:-0}" -eq 0 ] 2>/dev/null && echo "    ✓ osv-scanner: clean"
else
  echo "    · osv-scanner: not installed (brew install osv-scanner)"
fi

# Snyk — security (free tier: 200 tests/month)
if command -v snyk >/dev/null 2>&1; then
  SNYK_OUT=$(cd "$REPO_ABS" && snyk test --json 2>/dev/null || true)
  SNYK_VULNS=$(echo "$SNYK_OUT" | grep -oE '"vulnerabilities":\[[^]]*\]' | grep -c '"id"' || echo "0")
  [ "${SNYK_VULNS:-0}" -gt 0 ] && emit "warning" "snyk" "snyk-vuln" "$SNYK_VULNS vulnerability(ies)"
  [ "${SNYK_VULNS:-0}" -eq 0 ] && echo "    ✓ snyk: clean"
else
  echo "    · snyk: not installed (npm install -g snyk)"
fi

# Checkov — IaC security (Terraform, CloudFormation, Docker)
if command -v checkov >/dev/null 2>&1; then
  if [ -f "$REPO/Dockerfile" ] || find "$REPO" -name "*.tf" -maxdepth 2 2>/dev/null | head -1 | grep -q .; then
    CHECKOV_FAILS=$(cd "$REPO_ABS" && checkov -d . --quiet --compact 2>/dev/null | grep -c "FAILED" || echo "0")
    [ "${CHECKOV_FAILS:-0}" -gt 0 ] && emit "warning" "checkov" "iac-misconfiguration" "$CHECKOV_FAILS IaC misconfiguration(s)"
    [ "${CHECKOV_FAILS:-0}" -eq 0 ] && echo "    ✓ checkov: IaC clean"
  fi
else
  ([ -f "$REPO/Dockerfile" ] || find "$REPO" -name "*.tf" -maxdepth 2 2>/dev/null | head -1 | grep -q .) &&
    echo "    · checkov: not installed (pip install checkov)"
fi

echo ""

# === Maturity score ===
MATURITY_OUTPUT=$(bash "$SCRIPT_DIR/assess/maturity.sh" "$REPO" 2>/dev/null)
SCORE=$(echo "$MATURITY_OUTPUT" | grep "Score:" | grep -oE "[0-9]+/[0-9]+")
LEVEL=$(echo "$MATURITY_OUTPUT" | grep "Level" | grep -oE "[0-4]" | tail -1)
PCT=$(echo "$MATURITY_OUTPUT" | grep "Score:" | grep -oE "[0-9]+%")

cat >"$MATURITY_FILE" <<EOF
{
  "repo": "$REPO_NAME",
  "timestamp": "$TIMESTAMP",
  "score": "$SCORE",
  "percentage": "${PCT:-0%}",
  "level": ${LEVEL:-0}
}
EOF

# === Summary ===
TOTAL=$(wc -l <"$REPO_DB" | tr -d ' ')
ERRORS=$(grep -c '"error"' "$REPO_DB" 2>/dev/null || echo "0")
WARNINGS=$(grep -c '"warning"' "$REPO_DB" 2>/dev/null || echo "0")

echo ""
echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Findings: $TOTAL ($ERRORS errors, $WARNINGS warnings)"
echo "  Maturity: Level ${LEVEL:-?} ($PCT)"
echo ""
echo "  Persisted to:"
echo "    $REPO_DB"
echo "    $MATURITY_FILE"
echo ""
echo "  Query findings:"
echo "    cat $REPO_DB | jq .                    # pretty print"
echo "    grep '\"error\"' $REPO_DB              # errors only"
echo "    jq -r '.rule' $REPO_DB | sort | uniq -c | sort -rn  # top rules"
echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
