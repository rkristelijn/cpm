#!/usr/bin/env bash
# scripts/findings-to-junit.sh — Convert JSONL findings to JUnit XML
# Usage: bash scripts/findings-to-junit.sh [findings.jsonl] [output.xml]
# Default: .cpm/findings.jsonl → .cpm/findings-junit.xml
set -o nounset -o pipefail

INPUT="${1:-.cpm/findings.jsonl}"
OUTPUT="${2:-.cpm/findings-junit.xml}"

[ ! -f "$INPUT" ] && { echo "No findings at $INPUT. Run analyse-report.sh first."; exit 1; }

TOTAL=$(wc -l < "$INPUT" | tr -d ' ')
ERRORS=$(grep -c '"severity":"error"' "$INPUT" 2>/dev/null || echo "0")
WARNINGS=$(grep -c '"severity":"warning"' "$INPUT" 2>/dev/null || echo "0")
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

cat > "$OUTPUT" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<testsuites name="cpm-analyse" tests="$TOTAL" failures="$ERRORS" errors="0" time="0" timestamp="$TIMESTAMP">
  <testsuite name="findings" tests="$TOTAL" failures="$ERRORS" warnings="$WARNINGS">
EOF

while IFS= read -r line; do
  RULE=$(echo "$line" | grep -oE '"rule":"[^"]*"' | sed 's/"rule":"//;s/"//')
  SEV=$(echo "$line" | grep -oE '"severity":"[^"]*"' | sed 's/"severity":"//;s/"//')
  CHECK=$(echo "$line" | grep -oE '"check":"[^"]*"' | sed 's/"check":"//;s/"//')
  MSG=$(echo "$line" | grep -oE '"message":"[^"]*"' | sed 's/"message":"//;s/"//' | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')

  echo "    <testcase name=\"$RULE\" classname=\"$CHECK\">" >> "$OUTPUT"
  if [ "$SEV" = "error" ]; then
    echo "      <failure message=\"$MSG\" type=\"$SEV\"/>" >> "$OUTPUT"
  elif [ "$SEV" = "warning" ]; then
    echo "      <system-out>$MSG</system-out>" >> "$OUTPUT"
  fi
  echo "    </testcase>" >> "$OUTPUT"
done < "$INPUT"

cat >> "$OUTPUT" << EOF
  </testsuite>
</testsuites>
EOF

echo "  ✓ JUnit XML: $OUTPUT ($TOTAL findings: $ERRORS errors, $WARNINGS warnings)"
