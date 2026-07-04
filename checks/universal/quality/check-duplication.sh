#!/usr/bin/env bash
# check-duplication.sh — Detect copy-paste code duplication
# @see ADR-151 (compression-inspired duplication detection)
#
# Uses jscpd (via npx) with thresholds matching SonarCloud CPD:
#   - Min tokens: 80
#   - Min lines: 15
#   - Max duplication: 3% (warning), 5% (error)
#
# Output: unified findings format (ADR-129)

source "$(dirname "$0")/../../lib/shell/check.sh" 2>/dev/null || findings_add() { :; }

REPO="${1:-.}"
MIN_LINES="${CPM_DUP_MIN_LINES:-15}"
MIN_TOKENS="${CPM_DUP_MIN_TOKENS:-80}"
WARN_THRESHOLD="${CPM_DUP_WARN:-3}"
ERROR_THRESHOLD="${CPM_DUP_ERROR:-5}"

# Determine source directories
SCAN_DIRS=""
for d in src lib checks scripts; do
  [[ -d "$REPO/$d" ]] && SCAN_DIRS="$SCAN_DIRS $REPO/$d"
done
[[ -z "$SCAN_DIRS" ]] && SCAN_DIRS="$REPO"

# Check tool availability
if ! command -v npx >/dev/null 2>&1; then
  echo "  [duplication] skip — npx not found (install Node.js)"
  exit 0
fi

# Run jscpd
REPORT_DIR=$(mktemp -d)
npx --yes jscpd $SCAN_DIRS \
  --min-lines "$MIN_LINES" \
  --min-tokens "$MIN_TOKENS" \
  --reporters json \
  --output "$REPORT_DIR" \
  --silent 2>/dev/null

REPORT="$REPORT_DIR/jscpd-report.json"
if [[ ! -f "$REPORT" ]]; then
  echo "  [duplication] skip — jscpd failed or no supported files"
  rm -rf "$REPORT_DIR"
  exit 0
fi

# Parse results
PERCENTAGE=$(python3 -c "
import json, sys
with open('$REPORT') as f:
    data = json.load(f)
pct = data.get('statistics', {}).get('total', {}).get('percentage', 0)
print(f'{pct:.1f}')
" 2>/dev/null || echo "0.0")

CLONES=$(python3 -c "
import json, sys
with open('$REPORT') as f:
    data = json.load(f)
dupes = data.get('duplicates', [])
print(len(dupes))
for d in dupes[:10]:
    src = d.get('firstFile', {})
    dst = d.get('secondFile', {})
    lines = d.get('lines', 0)
    tokens = d.get('tokens', 0)
    print(f\"{src.get('name','')}:{src.get('start',0)} ↔ {dst.get('name','')}:{dst.get('start',0)} ({lines} lines, {tokens} tokens)\")
" 2>/dev/null)

CLONE_COUNT=$(echo "$CLONES" | head -1)
CLONE_DETAILS=$(echo "$CLONES" | tail -n +2)

# Report
if (( $(echo "$PERCENTAGE > $ERROR_THRESHOLD" | bc -l 2>/dev/null || echo 0) )); then
  findings_add "error" "project" "duplication-high" \
    "Code duplication ${PERCENTAGE}% exceeds ${ERROR_THRESHOLD}% threshold ($CLONE_COUNT clone(s))" \
    "Extract duplicated code into shared functions or modules" ""
elif (( $(echo "$PERCENTAGE > $WARN_THRESHOLD" | bc -l 2>/dev/null || echo 0) )); then
  findings_add "warning" "project" "duplication-moderate" \
    "Code duplication ${PERCENTAGE}% exceeds ${WARN_THRESHOLD}% threshold ($CLONE_COUNT clone(s))" \
    "Review and consolidate repeated code" ""
fi

# Report individual clones
if [[ -n "$CLONE_DETAILS" ]]; then
  while IFS= read -r clone; do
    [[ -z "$clone" ]] && continue
    file=$(echo "$clone" | cut -d: -f1)
    findings_add "info" "$file" "duplication-clone" \
      "$clone" \
      "Extract into shared function" ""
  done <<< "$CLONE_DETAILS"
fi

echo "  [duplication] ${PERCENTAGE}% duplication ($CLONE_COUNT clone(s), threshold: ${WARN_THRESHOLD}%/${ERROR_THRESHOLD}%)"

# Cleanup
rm -rf "$REPORT_DIR"
