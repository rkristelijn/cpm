#!/usr/bin/env bash
# annotate.sh — Convert cpm findings to GitHub Actions annotations
# GitHub format: ::warning file={file},line={line}::{message}
# Called by cpm-action after cpm check completes.
set -euo pipefail

# Parse findings from cpm scan output (JSON-per-line format if available)
# Fall back to text parsing from cpm findings output
emit_annotations() {
  local severity file line rule message

  # Try JUnit XML first (produced by rule-scan)
  if [ -f cpm-rule-results.xml ]; then
    # Parse testcase failures from JUnit XML
    grep -oP '<failure[^>]*message="[^"]*"' cpm-rule-results.xml 2>/dev/null | while read -r match; do
      message=$(echo "$match" | grep -oP 'message="\K[^"]*')
      echo "::warning::$message"
    done
  fi

  # Parse cpm findings text output for annotations
  # Format: "  severity  repo  category  message"
  cpm findings 2>/dev/null | while IFS= read -r line; do
    # Skip header lines and empty lines
    if [[ "$line" =~ ^[[:space:]]*(error|warning)[[:space:]] ]]; then
      severity=$(echo "$line" | awk '{print $1}')
      # Extract the finding details
      rule=$(echo "$line" | awk '{print $2}')
      category=$(echo "$line" | awk '{print $3}')
      message=$(echo "$line" | sed 's/^[[:space:]]*[a-z]*[[:space:]]*[^ ]*[[:space:]]*[^ ]*[[:space:]]*//')

      if [ "$severity" = "error" ]; then
        echo "::error title=cpm/$rule ($category)::$message"
      else
        echo "::warning title=cpm/$rule ($category)::$message"
      fi
    fi
  done
}

# Emit summary to GitHub Step Summary
emit_summary() {
  if [ -z "${GITHUB_STEP_SUMMARY:-}" ]; then return; fi

  {
    echo "## cpm Quality Gate"
    echo ""

    local score
    score=$(cpm score 2>/dev/null | grep -oP '\d+(?=/100)' || echo "?")
    echo "**Score:** ${score}/100"
    echo ""

    local exit_code="${CPM_EXIT_CODE:-0}"
    if [ "$exit_code" = "0" ]; then
      echo "✅ **Quality gate passed**"
    else
      echo "❌ **Quality gate failed** (exit code: $exit_code)"
    fi
    echo ""

    echo "<details><summary>Findings</summary>"
    echo ""
    echo '```'
    cpm findings 2>/dev/null | head -50 || echo "(no findings)"
    echo '```'
    echo "</details>"
  } >> "$GITHUB_STEP_SUMMARY"
}

emit_annotations
emit_summary
