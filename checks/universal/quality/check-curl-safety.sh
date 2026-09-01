#!/usr/bin/env bash
# cpm:ignore-file TRANS-002 — detector/test source: contains the patterns it checks for
# checks/universal/quality/check-curl-safety.sh
# @see ADR-129
# Check curl invocations for missing timeout, missing --fail, and --insecure usage
source "$(dirname "$0")/../../../lib/shell/check.sh"
cpm_check_enabled "curl-safety" || exit 0
set -o nounset -o pipefail

REPO="${1:-.}"

# Find all .sh files
SCRIPTS=$(find "$REPO" -name '*.sh' -type f \
  -not -path "*/node_modules/*" \
  -not -path "*/vendor/*" \
  -not -path "*/.git/*" \
  -not -path "*/dist/*" \
  -not -path "*/build/*" \
  -not -path "*/coverage/*" \
  -not -path "*/.cache/*" \
  -not -path "*/target/*" \
  -not -path "*/out/*" \
  2>/dev/null) || true

[ -z "$SCRIPTS" ] && exit 0

while IFS= read -r script; do
  [ -z "$script" ] && continue
  [ ! -f "$script" ] && continue

  LINE_NUM=0
  while IFS= read -r line; do
    LINE_NUM=$((LINE_NUM + 1))

    # Skip comments (lines starting with optional whitespace + #)
    if echo "$line" | grep -qE '^\s*#' 2>/dev/null; then
      continue
    fi

    # Only process lines that contain a curl invocation
    if ! echo "$line" | grep -qw 'curl' 2>/dev/null; then
      continue
    fi

    # For multi-line curl commands (ending with \), try to gather continuation lines
    FULL_CMD="$line"
    if echo "$line" | grep -q '\\$' 2>/dev/null; then
      # Read ahead for continuation — use the whole file context
      # For simplicity, just check the current line; multi-line is best-effort
      :
    fi

    # Rule 3: curl-insecure — -k or --insecure disables TLS verification
    if echo "$FULL_CMD" | grep -qE '\s-k\b|--insecure' 2>/dev/null; then
      findings_add "error" "$script:$LINE_NUM" "curl-insecure" \
        "curl with --insecure/-k disables TLS certificate verification" \
        "Remove -k/--insecure; fix the certificate issue instead" \
        "https://curl.se/docs/sslcerts.html"
    fi

    # Rule 1: curl-no-timeout — No --max-time or --connect-timeout
    if ! echo "$FULL_CMD" | grep -qE '--max-time|--connect-timeout|-m\s+[0-9]' 2>/dev/null; then
      findings_add "warning" "$script:$LINE_NUM" "curl-no-timeout" \
        "curl without timeout — can hang indefinitely" \
        "Add --max-time 30 --connect-timeout 10" \
        "https://curl.se/docs/manpage.html#--max-time"
    fi

    # Rule 2: curl-no-fail — No -f or --fail
    if ! echo "$FULL_CMD" | grep -qE '\s-[a-zA-Z]*f|--fail' 2>/dev/null; then
      findings_add "warning" "$script:$LINE_NUM" "curl-no-fail" \
        "curl without --fail — HTTP errors (404, 500) are silently ignored" \
        "Add -f or --fail to detect server errors" \
        "https://curl.se/docs/manpage.html#-f"
    fi

  done < "$script"
done <<< "$SCRIPTS"
