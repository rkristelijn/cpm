#!/usr/bin/env bash
# checks/universal/quality/check-json.sh
# JSON anti-patterns: trailing commas, comments, secrets, large integers, BOM
source "$(dirname "$0")/../../../lib/shell/check.sh"
cpm_check_enabled "json-quality" || exit 0
set -o nounset -o pipefail

REPO="${1:-.}"

# Find JSON files (skip node_modules, lockfiles, coverage)
JSON_FILES=$(find "$REPO" -name "*.json" 2>/dev/null | \
  grep -v "node_modules\|\.next\|dist\|build\|coverage\|package-lock\|pnpm-lock\|\.cache\|\.tmp" || true)
[ -z "$JSON_FILES" ] && exit 0

FINDINGS=0
finding() { printf "  \033[33mwarning\033[0m  %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }
error()   { printf "  \033[31merror\033[0m    %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }

# --- Hardcoded secrets in JSON config files ---
echo "$JSON_FILES" | grep -iE "config|settings|env" | \
  xargs grep -lE "(password|secret|api_key|token|private_key).*:.*\"[^\"]{8,}\"" 2>/dev/null | \
  grep -v "example\|template\|schema" | head -1 | grep -q . && \
  error "json-hardcoded-secret" "Possible secret in JSON config file — use environment variables"

# --- Comments in JSON (invalid syntax) ---
echo "$JSON_FILES" | xargs grep -ln "^\s*//\|^\s*/\*" 2>/dev/null | head -1 | grep -q . && \
  finding "json-has-comments" "Comments in JSON file — invalid syntax, use JSONC or remove"

# --- Trailing commas ---
echo "$JSON_FILES" | xargs grep -n ",\s*[}\]]" 2>/dev/null | head -1 | grep -q . && \
  finding "json-trailing-comma" "Trailing comma in JSON — will cause parse error"

# --- Boolean as string ("true"/"false") ---
echo "$JSON_FILES" | xargs grep -n ':\s*"true"\|:\s*"false"' 2>/dev/null | \
  grep -v "schema\|description\|label\|text\|message" | head -1 | grep -q . && \
  finding "json-bool-as-string" "Boolean stored as string (\"true\") — use native true/false"

# --- Large integers (>2^53, precision loss in JS) ---
echo "$JSON_FILES" | xargs grep -nE ":\s*[0-9]{16,}" 2>/dev/null | head -1 | grep -q . && \
  finding "json-large-integer" "Large integer (>16 digits) — may lose precision in JS. Use string"

[ "$FINDINGS" -eq 0 ] && echo "  ✓ JSON quality OK"
exit 0
