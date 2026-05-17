#!/usr/bin/env bash
# scripts/generate-docs.sh — Generate up-to-date documentation from code analysis
# Usage: bash scripts/generate-docs.sh [path] > docs/ARCHITECTURE.md
set -o nounset -o pipefail

REPO="${1:-.}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATE=$(date +"%Y-%m-%d")

cat <<HEADER
# Architecture & Technical Overview
> Auto-generated on $DATE by \`cpm generate-docs\`
> Source of truth: the code itself. This document is regenerated, never manually edited.

HEADER

# Overview
echo "## Overview"
echo '```'
bash "$SCRIPT_DIR/discover/overview.sh" "$REPO" 2>/dev/null | grep -v "─\|│\|┌\|┘\|└\|═" | sed 's/^  //'
echo '```'
echo ""

# How to run
echo "## Getting Started"
echo '```'
bash "$SCRIPT_DIR/discover/howtorun.sh" "$REPO" 2>/dev/null | grep -v "^$" | sed 's/^  //'
echo '```'
echo ""

# Tech stack
echo "## Technology Stack"
echo '```'
bash "$SCRIPT_DIR/discover/techradar.sh" "$REPO" 2>/dev/null | grep "✓\|■" | sed 's/^  //'
echo '```'
echo ""

# Architecture / Patterns
echo "## Design Patterns"
echo '```'
bash "$SCRIPT_DIR/discover/patterns.sh" "$REPO" 2>/dev/null | grep "✓\|■" | sed 's/^  //'
echo '```'
echo ""

# Routes
ROUTES=$(bash "$SCRIPT_DIR/discover/routes.sh" "$REPO" 2>/dev/null | grep -v "^$\|Total:")
if echo "$ROUTES" | grep -q "/"; then
  echo "## Routes & Endpoints"
  echo '```'
  echo "$ROUTES" | sed 's/^  //'
  echo '```'
  echo ""
fi

# Data flow
echo "## Data Flow"
echo '```mermaid'
bash "$SCRIPT_DIR/discover/dataflow.sh" "$REPO" 2>/dev/null | sed -n '/flowchart/,/```/p' | grep -v '```' | sed 's/^  │ //'
echo '```'
echo ""

# Maturity
echo "## Maturity"
echo '```'
bash "$SCRIPT_DIR/assess/maturity.sh" "$REPO" 2>/dev/null | grep "✓\|·\|Score" | sed 's/^  //'
echo '```'
echo ""

# Key metrics
echo "## Key Metrics"
echo "| Metric | Value |"
echo "|--------|-------|"
TOTAL_FILES=$(find "$REPO" -type f | grep -vE "node_modules|\.git|dist|build" | wc -l | tr -d ' ')
TOTAL_LOC=$(find "$REPO" -name "*.ts" -o -name "*.js" -o -name "*.cpp" -o -name "*.java" -o -name "*.py" -o -name "*.sh" 2>/dev/null | grep -vE "node_modules|dist|build" | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}')
echo "| Total files | $TOTAL_FILES |"
echo "| Lines of code | ${TOTAL_LOC:-0} |"
echo "| Generated | $DATE |"
echo ""
echo "---"
echo "*This document is auto-generated. Run \`bash scripts/generate-docs.sh .\` to update.*"
