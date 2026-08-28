#!/usr/bin/env bash
# checks/universal/quality/check-js-loading.sh
# @see ADR-129
# JavaScript loading: defer/async, document.write, CJS in browser, third-party, event listeners
source "$(dirname "$0")/../../../lib/shell/check.sh"
cpm_check_enabled "js-loading" || exit 0
set -o nounset -o pipefail

REPO="${1:-.}"

# IS_WEB detectie
IS_WEB=false
[ -f "$REPO/index.html" ] && IS_WEB=true
[ -d "$REPO/public" ] && IS_WEB=true
[ -d "$REPO/app" ] && [ -f "$REPO/package.json" ] && IS_WEB=true
[ -f "$REPO/next.config.ts" ] || [ -f "$REPO/next.config.js" ] || [ -f "$REPO/next.config.mjs" ] && IS_WEB=true
[ -f "$REPO/angular.json" ] && IS_WEB=true
[ -f "$REPO/vite.config.ts" ] && IS_WEB=true
[ -f "$REPO/nuxt.config.ts" ] && IS_WEB=true
[ "$IS_WEB" = false ] && exit 0

# File sets
EXCLUDE="-not -path */node_modules/* -not -path */.next/* -not -path */dist/* -not -path */build/* -not -path */vendor/* -not -path */coverage/* -not -path */.git/*"

HTML_FILES=$(find "$REPO" \( -name "*.html" -o -name "*.htm" \) \
  -not -path "*/node_modules/*" -not -path "*/.next/*" -not -path "*/dist/*" \
  -not -path "*/build/*" -not -path "*/vendor/*" -not -path "*/.git/*" 2>/dev/null || true)

JS_FILES=$(find "$REPO" \( -name "*.js" -o -name "*.ts" -o -name "*.jsx" -o -name "*.tsx" \) \
  -not -path "*/node_modules/*" -not -path "*/.next/*" -not -path "*/dist/*" \
  -not -path "*/build/*" -not -path "*/vendor/*" -not -path "*/.git/*" \
  -not -path "*/coverage/*" -not -name "*.min.js" -not -name "*.d.ts" 2>/dev/null || true)

ALL_FILES=$(printf '%s\n%s' "$HTML_FILES" "$JS_FILES" | sort -u || true)
[ -z "$ALL_FILES" ] && exit 0

# --- Rule 1: script-no-defer — <script src> in <head> without defer/async (skip type="module") ---
if [ -n "$HTML_FILES" ]; then
  while IFS= read -r file; do
    [ -z "$file" ] && continue
    # Extract content between <head> and </head>, find script tags with src
    head_content=$(sed -n '/<head/,/<\/head>/p' "$file" 2>/dev/null || true)
    [ -z "$head_content" ] && continue
    # Find script tags with src but without defer, async, or type="module"
    echo "$head_content" | grep -n '<script[^>]*src=' 2>/dev/null | \
      grep -v 'defer\|async\|type="module"\|type=.module' | while IFS=: read -r linenum line; do
      findings_add "warning" "$file" "script-no-defer" \
        "<script src> in <head> without defer or async — blocks page rendering" \
        "Add defer attribute: <script defer src=\"...\">" \
        "https://developer.mozilla.org/en-US/docs/Web/HTML/Element/script#defer"
      break
    done
  done <<< "$HTML_FILES"
fi

# --- Rule 2: script-document-write — document.write() usage ---
if [ -n "$ALL_FILES" ]; then
  while IFS= read -r file; do
    [ -z "$file" ] && continue
    DW_LINES=$(grep -nE 'document\.write\s*\(' "$file" 2>/dev/null | \
      grep -vE '^\s*[#*/]' || true)
    [ -z "$DW_LINES" ] && continue
    while IFS=: read -r linenum _rest; do
      findings_add "warning" "$file:$linenum" "script-document-write" \
        "document.write() blocks parsing and can blank the page if called after load" \
        "Use DOM methods: document.createElement(), element.appendChild()" \
        "https://developer.mozilla.org/en-US/docs/Web/API/Document/write"
    done <<< "$DW_LINES"
  done <<< "$ALL_FILES"
fi

# --- Rule 3: script-no-module — require() in browser-side code ---
BROWSER_DIRS=""
for dir in src app pages components; do
  [ -d "$REPO/$dir" ] && BROWSER_DIRS="$BROWSER_DIRS $REPO/$dir"
done
if [ -n "$BROWSER_DIRS" ]; then
  # shellcheck disable=SC2086
  REQUIRE_HITS=$(grep -rnE 'require\s*\(' $BROWSER_DIRS \
    --include='*.js' --include='*.ts' --include='*.jsx' --include='*.tsx' 2>/dev/null | \
    grep -v 'node_modules\|\.test\.\|\.spec\.\|__tests__\|__mocks__\|server\.\|api/' | \
    head -10 || true)
  if [ -n "$REQUIRE_HITS" ]; then
    while IFS= read -r hit; do
      [ -z "$hit" ] && continue
      file="${hit%%:*}"; rest="${hit#*:}"
      linenum="${rest%%:*}"
      findings_add "warning" "$file:$linenum" "script-no-module" \
        "require() in browser-side code — use ES module import instead" \
        "Replace require('x') with import x from 'x'" \
        "https://developer.mozilla.org/en-US/docs/Web/JavaScript/Guide/Modules"
    done <<< "$REQUIRE_HITS"
  fi
fi

# --- Rule 4: third-party-sync — external <script> without async or defer ---
if [ -n "$HTML_FILES" ]; then
  while IFS= read -r file; do
    [ -z "$file" ] && continue
    SYNC_LINES=$(grep -n '<script[^>]*src=.http' "$file" 2>/dev/null | \
      grep -v 'defer\|async\|type="module"\|type=.module' || true)
    [ -z "$SYNC_LINES" ] && continue
    while IFS=: read -r linenum _rest; do
      findings_add "warning" "$file:$linenum" "third-party-sync" \
        "Third-party <script> without async or defer — blocks page rendering" \
        "Add async or defer: <script async src=...>" \
        "https://web.dev/efficiently-load-third-party-javascript/"
    done <<< "$SYNC_LINES"
  done <<< "$HTML_FILES"
fi

# --- Rule 5: third-party-excessive — >5 unique third-party script domains ---
if [ -n "$HTML_FILES" ]; then
  while IFS= read -r file; do
    [ -z "$file" ] && continue
    # Extract domains from script src attributes pointing to external URLs
    DOMAINS=$(grep -oE '<script[^>]*src="https?://[^"/]+' "$file" 2>/dev/null | \
      sed 's|.*src="https\?://||' | sort -u || true)
    DOMAIN_COUNT=$(echo "$DOMAINS" | grep -c . 2>/dev/null || echo 0)
    if [ "$DOMAIN_COUNT" -gt 5 ]; then
      findings_add "warning" "$file" "third-party-excessive" \
        "$DOMAIN_COUNT unique third-party script domains — each adds DNS lookup + connection overhead" \
        "Consolidate third-party scripts via a tag manager or self-host critical ones" \
        "https://web.dev/efficiently-load-third-party-javascript/"
    fi
  done <<< "$HTML_FILES"
fi

# --- Rule 6: no-passive-listener — scroll/touch/wheel listeners without {passive: true} ---
if [ -n "$JS_FILES" ]; then
  while IFS= read -r file; do
    [ -z "$file" ] && continue
    SCROLL_LINES=$(grep -nE "addEventListener\s*\(\s*['\"](scroll|touchstart|touchmove|wheel)['\"]" "$file" 2>/dev/null | \
      grep -v 'passive' || true)
    [ -z "$SCROLL_LINES" ] && continue
    while IFS=: read -r linenum _rest; do
      findings_add "warning" "$file:$linenum" "no-passive-listener" \
        "scroll/touch/wheel listener without {passive: true} — blocks scrolling on mobile" \
        "Add { passive: true } as third argument to addEventListener" \
        "https://developer.chrome.com/blog/passive-event-listeners/"
    done <<< "$SCROLL_LINES"
  done <<< "$JS_FILES"
fi

# --- Rule 7: no-event-delegation — >5 identical addEventListener calls ---
if [ -n "$JS_FILES" ]; then
  # Count occurrences of each event type in addEventListener calls
  EVENT_COUNTS=$(echo "$JS_FILES" | xargs grep -ohE "addEventListener\s*\(\s*['\"]([a-z]+)['\"]" 2>/dev/null | \
    sed "s/addEventListener\s*(\s*['\"]//;s/['\"].*//" | sort | uniq -c | sort -rn || true)
  if [ -n "$EVENT_COUNTS" ]; then
    while IFS= read -r countline; do
      [ -z "$countline" ] && continue
      count=$(echo "$countline" | awk '{print $1}')
      event=$(echo "$countline" | awk '{print $2}')
      if [ "$count" -gt 5 ]; then
        # Find the first file with this pattern for the finding
        first_file=$(echo "$JS_FILES" | xargs grep -ln "addEventListener.*['\"]${event}['\"]" 2>/dev/null | head -1 || true)
        [ -z "$first_file" ] && continue
        findings_add "info" "$first_file" "no-event-delegation" \
          "$count addEventListener('$event') calls — consider event delegation on a parent element" \
          "Use one listener on a parent: parent.addEventListener('$event', e => { if (e.target.matches(selector)) ... })" \
          "https://developer.mozilla.org/en-US/docs/Learn/JavaScript/Building_blocks/Events#event_delegation"
      fi
    done <<< "$EVENT_COUNTS"
  fi
fi
