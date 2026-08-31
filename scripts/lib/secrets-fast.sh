#!/bin/bash
# secrets-fast.sh — Regex-only secret detection (no gitleaks needed)
#
# Scans staged file diffs for common secret patterns using grep.
# Designed as a fallback when gitleaks is not installed.
#
# Exit codes:
#   0 — no secrets found
#   1 — potential secrets detected
#
# Suppress per-line: add 'cpm:ignore secret' comment on the line.

set -uo pipefail

# Only check staged files (passed via STAGED env var from orchestrator)
STAGED_FILES=""
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  # Skip binary/lock/generated files
  echo "$f" | grep -qE '\.(lock|min\.js|svg|png|jpg|gif|ico|woff|woff2|ttf|eot|pdf|zip|tar|gz|map)$' && continue
  [[ -f "$f" ]] && STAGED_FILES="$STAGED_FILES $f"
done <<< "${STAGED:-}"
[[ -z "$STAGED_FILES" ]] && exit 0

# Extract only added lines from staged diff
ADDED=$(git diff --cached -U0 -- $STAGED_FILES 2>/dev/null \
  | awk '/^diff --git/{f=substr($3,3)} /^@@/{split($3,a,"+"); ln=a[1]+0; sub(/,.*/,"",ln); ln--; next} /^\+[^+]/{ln++; if ($0 !~ /cpm:ignore secret/) print f":"ln":"substr($0,2)}')
[[ -z "$ADDED" ]] && exit 0

# Secret patterns — mirrors cpm's native secrets-fast check (secrets.cpp)
PATTERNS=(
  'AKIA[A-Z0-9]{16}'                         # AWS Access Key ID
  'sk-[a-zA-Z0-9]{20,}'                      # OpenAI / Stripe secret key
  'ghp_[a-zA-Z0-9]{36}'                      # GitHub personal access token
  'gho_[a-zA-Z0-9]{36}'                      # GitHub OAuth token
  'ghs_[a-zA-Z0-9]{36}'                      # GitHub app token
  'github_pat_[a-zA-Z0-9_]{22,}'             # GitHub fine-grained PAT
  'xox[bpras]-[a-zA-Z0-9-]{10,}'             # Slack token
  'AIza[a-zA-Z0-9_-]{35}'                    # Google API key
  'sk_live_[a-zA-Z0-9]{24,}'                 # Stripe live key
  'rk_live_[a-zA-Z0-9]{24,}'                 # Stripe restricted key
  'SG\.[a-zA-Z0-9_-]{22}\.[a-zA-Z0-9_-]{43}' # SendGrid API key
  'key-[a-zA-Z0-9]{32}'                      # Mailgun API key
  'sq0atp-[a-zA-Z0-9_-]{22}'                 # Square access token
  'AC[a-zA-Z0-9]{32}'                        # Twilio Account SID
  'npm_[a-zA-Z0-9]{36}'                      # npm token
  'pypi-[a-zA-Z0-9_-]{50,}'                  # PyPI token
  '-----BEGIN (RSA |EC |DSA |OPENSSH )?PRIVATE KEY' # Private keys
  'password\s*[:=]\s*["\x27][^\s"'\'']{8,}'  # Hardcoded passwords
  'secret\s*[:=]\s*["\x27][^\s"'\'']{8,}'    # Hardcoded secrets
)

# Build combined regex
COMBINED=""
for p in "${PATTERNS[@]}"; do
  if [[ -z "$COMBINED" ]]; then
    COMBINED="$p"
  else
    COMBINED="$COMBINED|$p"
  fi
done

# Scan added lines
found=0
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  file="${line%%:*}"
  rest="${line#*:}"
  lineno="${rest%%:*}"
  echo "  ⚠ secrets-fast: $file:$lineno — potential secret/key detected"
  found=$((found + 1))
done < <(echo "$ADDED" | grep -iE "$COMBINED" || true)

if [[ $found -gt 0 ]]; then
  echo ""
  echo "  $found potential secret(s) found in staged files."
  echo "  Suppress: add 'cpm:ignore secret' comment on the line."
  echo "  Skip hook: git commit --no-verify"
  exit 1
fi
exit 0
