#!/usr/bin/env bash
# checks/universal/security/check-regex-safety.sh
# @see ADR-129
# Detects dangerous regex patterns: ReDoS, catastrophic backtracking, quality issues.
# Fast file-based check — no external tools required.
source "$(dirname "$0")/../../../lib/shell/check.sh"

REPO="${1:-.}"

# Find source files containing regex patterns
FILES=$(find "$REPO" -type f \( -name "*.js" -o -name "*.ts" -o -name "*.tsx" -o -name "*.jsx" \
  -o -name "*.py" -o -name "*.rb" -o -name "*.go" -o -name "*.rs" -o -name "*.cpp" -o -name "*.h" \
  -o -name "*.sh" -o -name "*.java" \) \
  -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/dist/*" \
  -not -path "*/vendor/*" -not -path "*/build/*" 2>/dev/null)

[ -z "$FILES" ] && exit 0

# --- 1. Catastrophic backtracking: nested quantifiers ---
# Patterns: (.*)+  (.+)+  (\w*)*  (a|aa)+  (.*)*
while IFS=: read -r file linenum line; do
  findings_add "error" "$file:$linenum" "redos-nested-quantifier" \
    "Nested quantifier — exponential backtracking risk (ReDoS)" \
    "Remove nested quantifier or use atomic group/possessive quantifier"
done < <(echo "$FILES" | xargs grep -nE '\([^)]*[*+][^)]*\)[*+]' 2>/dev/null | \
  grep -v '//.*\|#.*\|/\*' | head -20)

# --- 2. Greedy .* in regex context ---
while IFS=: read -r file linenum line; do
  findings_add "warning" "$file:$linenum" "regex-greedy-wildcard" \
    "Greedy .* in regex — consider explicit character class or lazy .*?" \
    "Replace .* with specific pattern like [^/]* or .*?"
done < <(echo "$FILES" | xargs grep -nE '(new RegExp|/)\([^)]*\.\*[^?]' 2>/dev/null | \
  grep -v 'node_modules\|//.*test\|\.test\.' | head -10)

# --- 3. Regex used for HTML/XML parsing ---
while IFS=: read -r file linenum line; do
  findings_add "warning" "$file:$linenum" "regex-html-parse" \
    "Regex used for HTML/XML parsing — use a proper parser" \
    "Use DOMParser, cheerio, or similar instead of regex for HTML"
done < <(echo "$FILES" | xargs grep -nE '<[^>]*\.\*[^>]*>' 2>/dev/null | \
  grep -Ev '//|#|/\*|\.md$|\.txt$' | head -5)

# --- 4. Overly long regex (>120 chars) without comments ---
while IFS=: read -r file linenum line; do
  # Only flag if it's actually a regex literal or RegExp
  echo "$line" | grep -qE 'RegExp|/[^/]{120}/' || continue
  findings_add "info" "$file:$linenum" "regex-too-complex" \
    "Complex regex (>120 chars) — consider splitting or adding comments" \
    "Split into named parts or use verbose/extended mode"
done < <(echo "$FILES" | xargs grep -nE '(/.{120,}/|new RegExp\(.{120,}\))' 2>/dev/null | head -5)

# --- 5. Capturing groups where non-capturing would suffice ---
# Only flag in JS/TS where it matters for performance
JS_FILES=$(echo "$FILES" | grep -E '\.(js|ts|tsx|jsx)$')
if [ -n "$JS_FILES" ]; then
  count=$(echo "$JS_FILES" | xargs grep -c '([^?][^:]' 2>/dev/null | \
    awk -F: '$2 > 5 {print}' | wc -l | tr -d ' ')
  if [ "$count" -gt 0 ]; then
    findings_add "info" "$REPO" "regex-capturing-groups" \
      "$count file(s) with many capturing groups — consider (?:) for non-capturing" \
      "Use (?:pattern) when you don't need the captured value"
  fi
fi
