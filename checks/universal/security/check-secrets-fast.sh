#!/usr/bin/env bash
# check-secrets-fast.sh — Fast regex-based secret detection (no tools needed).
# Patterns shared with src/checks/secrets.cpp via .config/secret-patterns.txt.
# @see ADR-129
source "$(dirname "$0")/../../../lib/shell/check.sh"

# Load patterns from shared file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATTERNS_FILE="$SCRIPT_DIR/../../../.config/secret-patterns.txt"

if [[ ! -f "$PATTERNS_FILE" ]]; then
  PATTERNS='(sk-[a-zA-Z0-9]{20}|AKIA[A-Z0-9]{16}|ghp_[a-zA-Z0-9]{36}|gho_[a-zA-Z0-9]{36}|-----BEGIN (RSA |EC )?PRIVATE KEY|xox[bpras]-[a-zA-Z0-9-]+|AIza[a-zA-Z0-9_-]{35}|sk_live_[a-zA-Z0-9]{24})'
else
  PATTERNS=$(grep -v '^#' "$PATTERNS_FILE" | grep -v '^$' | tr '\n' '|' | sed 's/|$//')
  PATTERNS="($PATTERNS)"
fi

hits=$(cpm_search "$PATTERNS" src 2>/dev/null || true)

if [[ -n "$hits" ]]; then
  while IFS=: read -r file line _; do
    findings_add "error" "$file:$line" "hardcoded-secret" \
      "Potential secret/API key detected" \
      "Use environment variable or secrets manager" \
      ""
  done <<< "$hits"
fi
