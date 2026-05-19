#!/usr/bin/env bash
# check-dead-links.sh — Detect broken external URLs in docs and code.
#
# Extracts URLs from markdown/code, validates with HEAD requests.
# Skips localhost, example.com, and configurable exclusions.
# Runs in --offline mode (skip HTTP) or --online mode (validate).
#
# @see ADR-130 (test architecture)
# @see ADR-129 (unified findings contract)
source "$(dirname "$0")/../../../lib/shell/check.sh"

MODE="${CPM_LINK_CHECK:-offline}"
TIMEOUT="${CPM_LINK_TIMEOUT:-5}"
EXCLUDE_DOMAINS="localhost|127\.0\.0\.1|example\.com|example\.org|cpm\.dev|xxx"

# --- Phase 1: Extract all URLs from docs and source ---
urls_file=$(mktemp)
raw_file=$(mktemp)

# Step 1: extract raw URLs
grep -rhoE 'https?://[^ "'"'"'<>)]+' \
  --include='*.md' --include='*.cpp' --include='*.h' --include='*.sh' \
  --include='*.toml' --include='*.yml' --include='*.yaml' \
  --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=vendor \
  --exclude-dir=build --exclude-dir=.tmp \
  . > "$raw_file" 2>/dev/null || true

# Step 2: clean and deduplicate
sed 's/[.,;:)]*$//' "$raw_file" \
  | grep -vE '\{|\[|%7B|\.\.|^$' \
  | awk 'length > 10' \
  | sort -u > "$urls_file" || true
rm -f "$raw_file"

total=$(wc -l < "$urls_file" | tr -d ' ')

if [[ "$total" -eq 0 ]]; then
  findings_add "pass" "" "no-urls" "No external URLs found"
  exit 0
fi

# --- Phase 2: Check for obviously broken patterns ---
while IFS= read -r url; do
  # Strip trailing punctuation
  url="${url%%.}"
  url="${url%%,}"

  # Skip excluded domains
  if echo "$url" | grep -qE "$EXCLUDE_DOMAINS"; then
    continue
  fi

  # Find which file contains this URL
  file=$(grep -rl "$url" --include='*.md' --include='*.cpp' --include='*.h' --include='*.sh' . 2>/dev/null | head -1)
  file="${file#./}"
  line=0
  if [[ -n "$file" ]]; then
    line=$(grep -n "$url" "$file" 2>/dev/null | head -1 | cut -d: -f1)
  fi

  # Structural checks (always, even offline)
  if echo "$url" | grep -qE '^http://[^l]' && ! echo "$url" | grep -qE '\{|%7B|\['; then
    # HTTP (not HTTPS) — security warning, skip templates
    findings_add "warning" "$file:$line" "insecure-url" \
      "HTTP URL (not HTTPS): $url" \
      "Change to https://" \
      "https://cpm.dev/checks/dead-links"
    continue
  fi

  # Online mode: validate with HEAD request
  if [[ "$MODE" == "online" ]]; then
    status=$(curl -sI -o /dev/null -w "%{http_code}" --max-time "$TIMEOUT" "$url" 2>/dev/null || echo "000")
    case "$status" in
      2*|3*) ;; # OK or redirect
      404)
        findings_add "error" "$file:$line" "dead-link-404" \
          "Dead link (404): $url" \
          "Remove or update the URL" \
          "https://cpm.dev/checks/dead-links"
        ;;
      000)
        findings_add "warning" "$file:$line" "unreachable-url" \
          "URL unreachable (timeout/DNS): $url" \
          "Verify URL is correct" \
          "https://cpm.dev/checks/dead-links"
        ;;
      *)
        findings_add "info" "$file:$line" "url-status-$status" \
          "URL returned $status: $url" \
          "Verify URL is accessible" \
          "https://cpm.dev/checks/dead-links"
        ;;
    esac
  fi
done < "$urls_file"

rm -f "$urls_file"
