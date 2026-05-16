#!/usr/bin/env bash
# check-secrets-fast.sh — Fast regex-based secret detection (no tools needed).
#
# Catches common secret patterns without requiring gitleaks/trufflehog.
# Runs in <1s. Use gitleaks for deeper git-history scanning.
# Uses rg (fast) with grep fallback.
set -o errexit
set -o nounset
set -o pipefail

source "$(dirname "$0")/../../lib/shell/search.sh"

# Patterns that are almost always secrets
PATTERNS='(sk-[a-zA-Z0-9]{20}|AKIA[A-Z0-9]{16}|ghp_[a-zA-Z0-9]{36}|gho_[a-zA-Z0-9]{36}|-----BEGIN (RSA |EC )?PRIVATE KEY|xox[bpras]-[a-zA-Z0-9-]+|AIza[a-zA-Z0-9_-]{35}|sk_live_[a-zA-Z0-9]{24})'

EXCLUDE="node_modules|.git|build|dist|vendor|.tmp|*.lock"

hits=$(cpm_search "$PATTERNS" src 2>/dev/null || true)

if [[ -n "$hits" ]]; then
  count=$(echo "$hits" | wc -l | tr -d ' ')
  echo "  [fail] $count potential secret(s) detected:"
  echo "$hits" | head -5 | sed 's/^/    /'
  echo ""
  echo "  Fix: use environment variables or a secrets manager"
  echo "  Skip: add '// cpm:ignore secret' on the line"
  exit 1
fi
