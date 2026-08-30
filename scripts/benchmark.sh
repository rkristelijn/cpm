#!/bin/bash
# benchmark.sh — Run cpm scan + rule-scan on all repos under a path
# Usage: bash scripts/benchmark.sh ~/git
# Output: .tmp/benchmark/
set -euo pipefail

ROOT="${1:-$HOME/git}"
CPM_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CPM="$CPM_DIR/cpm"
RULE_SCAN="$CPM_DIR/build/rule-scan"
RULES="$CPM_DIR/rules"

# Ensure rule-scan is built
if [ ! -x "$RULE_SCAN" ]; then
  echo "Building rule-scan..."
  make -C "$CPM_DIR" build/rule-scan >/dev/null 2>&1
fi
OUT=".tmp/benchmark"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
REPORT="$OUT/report-$TIMESTAMP"

mkdir -p "$REPORT"

# Discover repos (using find, like lcode/cpm scan does)
echo "Discovering repos under $ROOT..."
REPOS=()
while IFS= read -r gitdir; do
  REPOS+=("$(dirname "$gitdir")")
done < <(find "$ROOT" -maxdepth 4 -name '.git' -type d 2>/dev/null | sort)

echo "Found ${#REPOS[@]} repos"
echo ""

# Header for CSV
echo "repo,scan_sec,rule_sec,rules_loaded,findings,errors,warnings,infos" >"$REPORT/results.csv"

TOTAL_FINDINGS=0
TOTAL_ERRORS=0
TOTAL_WARNINGS=0
TOTAL_INFOS=0
TOTAL_SCAN_SEC=0
TOTAL_RULE_SEC=0

for repo in "${REPOS[@]}"; do
  name=$(basename "$repo")
  printf "  %-40s " "$name"

  # Run cpm scan (file-based checks)
  SCAN_START=$(date +%s)
  "$CPM" scan "$repo" --depth 0 >"$REPORT/${name}-scan.txt" 2>&1 || true
  SCAN_END=$(date +%s)
  SCAN_SEC=$((SCAN_END - SCAN_START))

  # Run rule-scan (regex-based checks)
  RULE_START=$(date +%s)
  "$RULE_SCAN" "$repo" --rules "$RULES" --json >"$REPORT/${name}-rules.jsonl" 2>/dev/null || true
  RULE_END=$(date +%s)
  RULE_SEC=$((RULE_END - RULE_START))

  # Count findings by severity
  FINDINGS=$(cat "$REPORT/${name}-rules.jsonl" | wc -l | xargs)
  ERRORS=$(grep -c '"severity":"error"' "$REPORT/${name}-rules.jsonl" || true)
  WARNINGS=$(grep -c '"severity":"warning"' "$REPORT/${name}-rules.jsonl" || true)
  INFOS=$(grep -c '"severity":"info"' "$REPORT/${name}-rules.jsonl" || true)

  # Unique rules that fired
  RULES_FIRED=$(grep -o '"rule":"[^"]*"' "$REPORT/${name}-rules.jsonl" 2>/dev/null | sort -u | wc -l | xargs)

  echo "  ${FINDINGS} findings (${ERRORS}e/${WARNINGS}w/${INFOS}i) scan:${SCAN_SEC}s rules:${RULE_SEC}s"

  echo "$name,$SCAN_SEC,$RULE_SEC,$RULES_FIRED,$FINDINGS,$ERRORS,$WARNINGS,$INFOS" >>"$REPORT/results.csv"

  TOTAL_FINDINGS=$((TOTAL_FINDINGS + FINDINGS))
  TOTAL_ERRORS=$((TOTAL_ERRORS + ERRORS))
  TOTAL_WARNINGS=$((TOTAL_WARNINGS + WARNINGS))
  TOTAL_INFOS=$((TOTAL_INFOS + INFOS))
  TOTAL_SCAN_SEC=$((TOTAL_SCAN_SEC + SCAN_SEC))
  TOTAL_RULE_SEC=$((TOTAL_RULE_SEC + RULE_SEC))
done

# Aggregate all findings into one JSONL for analysis
cat "$REPORT"/*-rules.jsonl >"$REPORT/all-findings.jsonl" 2>/dev/null || true

# Summary
UNIQUE_RULES=$(grep -oh '"rule":"[^"]*"' "$REPORT/all-findings.jsonl" 2>/dev/null | sort -u | wc -l | tr -d ' \n')
TOTAL_RULES=$(find "$RULES" -name '*.rule' | wc -l | tr -d ' \n')

echo ""
echo "═══════════════════════════════════════════════════"
echo "  Benchmark Report — $TIMESTAMP"
echo "═══════════════════════════════════════════════════"
echo "  Repos scanned:     ${#REPOS[@]}"
echo "  Total findings:    $TOTAL_FINDINGS ($TOTAL_ERRORS errors, $TOTAL_WARNINGS warnings, $TOTAL_INFOS info)"
echo "  Rules fired:       $UNIQUE_RULES / $TOTAL_RULES ($((UNIQUE_RULES * 100 / TOTAL_RULES))%)"
echo "  Total scan time:   ${TOTAL_SCAN_SEC}s"
echo "  Total rule time:   ${TOTAL_RULE_SEC}s"
echo "  Avg per repo:      $(((TOTAL_SCAN_SEC + TOTAL_RULE_SEC) / ${#REPOS[@]}))s"
echo ""
echo "  Top 10 rules by frequency:"
grep -oh '"rule":"[^"]*"' "$REPORT/all-findings.jsonl" 2>/dev/null |
  sort | uniq -c | sort -rn | head -10 | sed 's/^/    /'
echo ""
echo "  Top 10 noisiest repos:"
for repo in "${REPOS[@]}"; do
  name=$(basename "$repo")
  f="$REPORT/${name}-rules.jsonl"
  [ -f "$f" ] && echo "$(wc -l <"$f" | tr -d ' ') $name"
done | sort -rn | head -10 | sed 's/^/    /'
echo ""
echo "  Output: $REPORT/"
echo "  CSV:    $REPORT/results.csv"
echo "  JSONL:  $REPORT/all-findings.jsonl"
echo ""
echo "  Analyze false positives:"
echo "    grep '\"severity\":\"error\"' $REPORT/all-findings.jsonl | jq -r '.rule' | sort | uniq -c | sort -rn"
echo "    # Review specific rule: grep 'RULE-ID' $REPORT/<repo>-rules.jsonl"
