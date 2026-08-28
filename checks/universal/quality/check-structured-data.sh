#!/usr/bin/env bash
# checks/universal/quality/check-structured-data.sh
# @see ADR-129
# Structured data (JSON-LD): schema.org, breadcrumbs, organization, FAQ
source "$(dirname "$0")/../../../lib/shell/check.sh"
cpm_check_enabled "structured-data" || exit 0
set -o nounset -o pipefail

REPO="${1:-.}"

# IS_WEB detection
IS_WEB=false
[ -f "$REPO/index.html" ] && IS_WEB=true
[ -d "$REPO/public" ] && IS_WEB=true
[ -d "$REPO/app" ] && [ -f "$REPO/package.json" ] && IS_WEB=true
[ -f "$REPO/next.config.ts" ] || [ -f "$REPO/next.config.js" ] || [ -f "$REPO/next.config.mjs" ] && IS_WEB=true
[ -f "$REPO/angular.json" ] && IS_WEB=true
[ -f "$REPO/vite.config.ts" ] && IS_WEB=true
[ -f "$REPO/nuxt.config.ts" ] && IS_WEB=true
[ "$IS_WEB" = false ] && exit 0

# Exclude pattern for find
EXCLUDE_DIRS="node_modules\|\.next\|dist\|build\|vendor\|coverage\|\.git\|__pycache__\|\.cache\|target\|out"

# Collect HTML-like template files
HTML_FILES=$(find "$REPO" -type f \( \
  -name "*.html" -o -name "*.htm" -o -name "*.jsx" -o -name "*.tsx" \
  -o -name "*.vue" -o -name "*.svelte" \
  \) 2>/dev/null | grep -v "$EXCLUDE_DIRS" || true)

[ -z "$HTML_FILES" ] && exit 0

# Find files containing JSON-LD script blocks
JSONLD_FILES=$(echo "$HTML_FILES" | xargs grep -l 'application/ld+json' 2>/dev/null || true)

# Collect all JSON-LD content for schema type checks
ALL_JSONLD=""
if [ -n "$JSONLD_FILES" ]; then
  ALL_JSONLD=$(echo "$JSONLD_FILES" | xargs cat 2>/dev/null || true)
fi

# Also check JS/TS files that might contain JSON-LD as strings (common in Next.js, Nuxt, etc.)
JS_FILES=$(find "$REPO" -type f \( -name "*.js" -o -name "*.ts" -o -name "*.jsx" -o -name "*.tsx" \) 2>/dev/null | \
  grep -v "$EXCLUDE_DIRS" || true)
JS_JSONLD_FILES=""
if [ -n "$JS_FILES" ]; then
  JS_JSONLD_FILES=$(echo "$JS_FILES" | xargs grep -l 'application/ld+json\|ld+json\|@context.*schema\.org' 2>/dev/null || true)
  if [ -n "$JS_JSONLD_FILES" ]; then
    ALL_JSONLD="${ALL_JSONLD}
$(echo "$JS_JSONLD_FILES" | xargs cat 2>/dev/null || true)"
  fi
fi

# Combine all files that have JSON-LD
ALL_LD_FILES=""
[ -n "$JSONLD_FILES" ] && ALL_LD_FILES="$JSONLD_FILES"
if [ -n "$JS_JSONLD_FILES" ]; then
  ALL_LD_FILES="${ALL_LD_FILES:+$ALL_LD_FILES
}$JS_JSONLD_FILES"
fi

# --- Rule 1: seo-no-jsonld — Web project without any JSON-LD structured data ---
check_no_jsonld() {
  if [ -z "$ALL_LD_FILES" ]; then
    findings_add "warning" "$REPO" "seo-no-jsonld" \
      "Web project has no JSON-LD structured data — search engines use structured data for rich snippets" \
      "Add <script type=\"application/ld+json\">{\"@context\":\"https://schema.org\",\"@type\":\"WebSite\",...}</script> to your pages" \
      "https://developers.google.com/search/docs/appearance/structured-data/intro-structured-data"
  fi
}

# --- Rule 2: seo-no-breadcrumb-schema — No BreadcrumbList in JSON-LD ---
check_no_breadcrumb() {
  # Only relevant if there's some JSON-LD already (skip if no structured data at all — rule 1 covers that)
  [ -z "$ALL_LD_FILES" ] && return

  if ! echo "$ALL_JSONLD" | grep -q "BreadcrumbList"; then
    findings_add "info" "$REPO" "seo-no-breadcrumb-schema" \
      "No BreadcrumbList schema found — breadcrumbs in search results help users understand site hierarchy" \
      "Add BreadcrumbList JSON-LD: {\"@type\":\"BreadcrumbList\",\"itemListElement\":[{\"@type\":\"ListItem\",...}]}" \
      "https://developers.google.com/search/docs/appearance/structured-data/breadcrumb"
  fi
}

# --- Rule 3: seo-invalid-jsonld — JSON-LD with syntax errors ---
check_invalid_jsonld() {
  [ -z "$JSONLD_FILES" ] && return

  while IFS= read -r file; do
    [ -f "$file" ] || continue

    # Use awk to extract JSON-LD blocks and check them inline
    local issues
    issues=$(awk '
      /<script[^>]*application\/ld\+json[^>]*>/ { capture=1; block=""; start=NR; next }
      /<\/script>/ {
        if (capture) {
          # Check mismatched braces
          tmp = block
          open_b = gsub(/{/, "{", tmp)
          tmp = block
          close_b = gsub(/}/, "}", tmp)
          if (open_b != close_b) {
            printf "%d:braces:%d:%d\n", start, open_b, close_b
          }
          # Check trailing comma before } or ]
          collapsed = block
          gsub(/[[:space:]]+/, "", collapsed)
          if (collapsed ~ /,[}\]]/) {
            printf "%d:trailing-comma\n", start
          }
          # Check single quotes used as JSON keys
          if (block ~ /'\''[a-zA-Z@]+'\''[[:space:]]*:/) {
            printf "%d:single-quotes\n", start
          }
        }
        capture=0
      }
      capture { block = block "\n" $0 }
    ' "$file" 2>/dev/null || true)
    [ -z "$issues" ] && continue

    while IFS=: read -r linenum issue rest; do
      case "$issue" in
        braces)
          local open_b close_b
          open_b=$(echo "$rest" | cut -d: -f1)
          close_b=$(echo "$rest" | cut -d: -f2)
          findings_add "error" "$file:$linenum" "seo-invalid-jsonld" \
            "JSON-LD block has mismatched braces (${open_b} open, ${close_b} close) — search engines will ignore invalid JSON" \
            "Validate JSON-LD at https://validator.schema.org/ or use JSON.parse() in dev tools" \
            "https://developers.google.com/search/docs/appearance/structured-data/intro-structured-data#testing"
          ;;
        trailing-comma)
          findings_add "error" "$file:$linenum" "seo-invalid-jsonld" \
            "JSON-LD block has trailing comma — invalid JSON, search engines will skip this block" \
            "Remove trailing commas before } or ]; validate at https://validator.schema.org/" \
            "https://developers.google.com/search/docs/appearance/structured-data/intro-structured-data#testing"
          ;;
        single-quotes)
          findings_add "error" "$file:$linenum" "seo-invalid-jsonld" \
            "JSON-LD block uses single quotes — JSON requires double quotes" \
            "Replace single quotes with double quotes in JSON-LD blocks" \
            "https://developers.google.com/search/docs/appearance/structured-data/intro-structured-data#testing"
          ;;
      esac
    done <<< "$issues"
  done <<< "$JSONLD_FILES"
}

# --- Rule 4: seo-no-organization — No Organization/WebSite schema on index page ---
check_no_organization() {
  [ -z "$ALL_LD_FILES" ] && return

  # Check if Organization or WebSite schema exists anywhere
  if echo "$ALL_JSONLD" | grep -qE '"@type"\s*:\s*"(Organization|WebSite)"'; then
    return
  fi
  # Also check for variants without quotes around @type value
  if echo "$ALL_JSONLD" | grep -qE '@type.*Organization\|@type.*WebSite'; then
    return
  fi

  # Find index/home page
  local index_file=""
  for candidate in "$REPO/index.html" "$REPO/public/index.html" "$REPO/src/index.html" \
    "$REPO/app/page.tsx" "$REPO/app/page.jsx" "$REPO/pages/index.tsx" "$REPO/pages/index.jsx" \
    "$REPO/src/app/page.tsx" "$REPO/src/pages/index.tsx"; do
    if [ -f "$candidate" ]; then
      index_file="$candidate"
      break
    fi
  done
  [ -z "$index_file" ] && index_file="$REPO"

  findings_add "warning" "$index_file" "seo-no-organization" \
    "No Organization or WebSite schema found — helps Google show knowledge panels and sitelinks" \
    "Add WebSite schema to home page: {\"@context\":\"https://schema.org\",\"@type\":\"WebSite\",\"name\":\"...\",\"url\":\"...\"}" \
    "https://developers.google.com/search/docs/appearance/structured-data/sitelinks-searchbox"
}

# --- Rule 5: seo-no-faq-schema — FAQ-like content without FAQPage schema ---
check_no_faq_schema() {
  # Find files that look like FAQ pages
  local faq_files
  faq_files=$(echo "$HTML_FILES" | xargs grep -liE "faq|frequently.asked|common.questions|q&a" 2>/dev/null || true)

  # Also check JS/TS files
  if [ -n "$JS_FILES" ]; then
    local js_faq
    js_faq=$(echo "$JS_FILES" | xargs grep -liE "faq|frequently.asked|common.questions" 2>/dev/null || true)
    [ -n "$js_faq" ] && faq_files="${faq_files:+$faq_files
}$js_faq"
  fi

  [ -z "$faq_files" ] && return

  # Check if any of these FAQ files have FAQPage schema
  local has_faq_schema=false
  if [ -n "$ALL_JSONLD" ]; then
    echo "$ALL_JSONLD" | grep -q "FAQPage" && has_faq_schema=true
  fi

  if [ "$has_faq_schema" = false ]; then
    local first_faq
    first_faq=$(echo "$faq_files" | head -1)
    findings_add "info" "$first_faq" "seo-no-faq-schema" \
      "FAQ-like content found but no FAQPage schema — FAQ rich snippets can significantly increase search visibility" \
      "Add FAQPage JSON-LD: {\"@type\":\"FAQPage\",\"mainEntity\":[{\"@type\":\"Question\",\"name\":\"...\",\"acceptedAnswer\":{\"@type\":\"Answer\",\"text\":\"...\"}}]}" \
      "https://developers.google.com/search/docs/appearance/structured-data/faqpage"
  fi
}

# --- Run all checks ---
check_no_jsonld
check_no_breadcrumb
check_invalid_jsonld
check_no_organization
check_no_faq_schema
