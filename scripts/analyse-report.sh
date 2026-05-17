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
> "$REPO_DB"

# === Emit a finding in JSONL format ===
emit() {
  local sev="$1" check="$2" rule="$3" msg="$4" file="${5:-.}"
  local line="{\"repo\":\"$REPO_NAME\",\"timestamp\":\"$TIMESTAMP\",\"severity\":\"$sev\",\"check\":\"$check\",\"rule\":\"$rule\",\"message\":\"$msg\",\"file\":\"$file\"}"
  echo "$line" >> "$REPO_DB"
  echo "$line" >> "$GLOBAL_DB"
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
([ -f "$REPO/next.config.ts" ] || [ -f "$REPO/next.config.js" ] || [ -f "$REPO/next.config.mjs" ]) && \
  run_checks "$CHECK_DIR/javascript/nextjs"

# Nx
[ -f "$REPO/nx.json" ] && run_checks "$CHECK_DIR/javascript/nx"

# === Maturity score ===
MATURITY_OUTPUT=$(bash "$SCRIPT_DIR/maturity.sh" "$REPO" 2>/dev/null)
SCORE=$(echo "$MATURITY_OUTPUT" | grep "Score:" | grep -oE "[0-9]+/[0-9]+")
LEVEL=$(echo "$MATURITY_OUTPUT" | grep "Level" | grep -oE "[0-4]" | tail -1)
PCT=$(echo "$MATURITY_OUTPUT" | grep "Score:" | grep -oE "[0-9]+%")

cat > "$MATURITY_FILE" << EOF
{
  "repo": "$REPO_NAME",
  "timestamp": "$TIMESTAMP",
  "score": "$SCORE",
  "percentage": "${PCT:-0%}",
  "level": ${LEVEL:-0}
}
EOF

# === Summary ===
TOTAL=$(wc -l < "$REPO_DB" | tr -d ' ')
ERRORS=$(grep -c '"error"' "$REPO_DB" 2>/dev/null || echo 0)
WARNINGS=$(grep -c '"warning"' "$REPO_DB" 2>/dev/null || echo 0)

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
