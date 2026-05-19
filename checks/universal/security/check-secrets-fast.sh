#!/usr/bin/env bash
# check-secrets-fast.sh — Fast regex-based secret detection (no tools needed).
# @see ADR-129 (unified findings contract)
source "$(dirname "$0")/../../../lib/shell/check.sh"

PATTERNS='(sk-[a-zA-Z0-9]{20}|AKIA[A-Z0-9]{16}|ghp_[a-zA-Z0-9]{36}|gho_[a-zA-Z0-9]{36}|-----BEGIN (RSA |EC )?PRIVATE KEY|xox[bpras]-[a-zA-Z0-9-]+|AIza[a-zA-Z0-9_-]{35}|sk_live_[a-zA-Z0-9]{24})'

hits=$(cpm_search "$PATTERNS" src 2>/dev/null || true)

if [[ -n "$hits" ]]; then
  while IFS=: read -r file line _; do
    findings_add "error" "$file:$line" "hardcoded-secret" \
      "Potential secret/API key detected" \
      "Use environment variable or secrets manager" \
      "https://cpm.dev/checks/secrets"
  done <<< "$hits"
fi
