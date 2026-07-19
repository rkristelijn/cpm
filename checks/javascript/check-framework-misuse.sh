#!/usr/bin/env bash
# checks/javascript/check-framework-misuse.sh
# @see ADR-129
# Detects incorrect usage of React 19 + Next.js + MUI stack.
# "Read The Framework Manual" — catches common misunderstandings.
set -o nounset -o pipefail

REPO="${1:-.}"
[ -f "$REPO/package.json" ] && grep -q '"react"' "$REPO/package.json" || exit 0

FINDINGS=0
finding() { printf "  \033[33mwarning\033[0m  %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }
error()   { printf "  \033[31merror\033[0m    %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }

SRC=""
[ -d "$REPO/src" ] && SRC="$REPO/src"
[ -d "$REPO/app" ] && SRC="${SRC:+$SRC }$REPO/app"
[ -z "$SRC" ] && exit 0

IS_NEXTJS=$(grep -q '"next"' "$REPO/package.json" 2>/dev/null && echo 1 || echo 0)

# =============================================
# REACT 19 ANTI-PATTERNS
# =============================================

# 1. Derived state in useEffect (compute during render instead)
if grep -rn "useEffect.*set[A-Z]" $SRC --include="*.tsx" --include="*.ts" 2>/dev/null | grep -v node_modules | grep -v "fetch\|api\|subscribe\|addEventListener\|timer\|interval" | head -1 | grep -q .; then
  finding "react-effect-sets-state" "useEffect that sets state — likely derived state, compute during render instead"
fi

# 2. Props copied into state (two sources of truth)
if grep -rn "useState(props\.\|useState(.*prop" $SRC --include="*.tsx" 2>/dev/null | grep -v node_modules | head -1 | grep -q .; then
  finding "react-prop-to-state" "Props copied into useState — creates two sources of truth, use prop directly"
fi

# 3. useEffect for event handling (should be in event handler)
if grep -rn "useEffect.*onClick\|useEffect.*onSubmit\|useEffect.*handleClick" $SRC --include="*.tsx" 2>/dev/null | grep -v node_modules | head -1 | grep -q .; then
  finding "react-effect-for-event" "useEffect for event logic — move to the event handler directly"
fi

# 4. useCallback/useMemo everywhere (premature optimization)
MEMO_COUNT=$(grep -rn "useCallback\|useMemo" $SRC --include="*.tsx" --include="*.ts" 2>/dev/null | grep -v node_modules | wc -l)
FILE_COUNT=$(find $SRC -name "*.tsx" -not -path "*/node_modules/*" 2>/dev/null | wc -l)
if [ "$FILE_COUNT" -gt 0 ] && [ "$MEMO_COUNT" -gt "$((FILE_COUNT * 3))" ]; then
  finding "react-over-memoization" "$MEMO_COUNT useMemo/useCallback for $FILE_COUNT files — over-memoizing adds complexity"
fi

# 5. forwardRef usage (removed in React 19 — ref is a normal prop)
if grep -rn "forwardRef\|React.forwardRef" $SRC --include="*.tsx" --include="*.ts" 2>/dev/null | grep -v node_modules | head -1 | grep -q .; then
  finding "react19-forwardref" "forwardRef is unnecessary in React 19 — ref is a regular prop now"
fi

# 6. useEffect with empty deps for initialization (use useState initializer)
if grep -rn "useEffect.*\[\]" $SRC --include="*.tsx" 2>/dev/null | grep -v node_modules | grep "localStorage\|sessionStorage\|Date.now\|Math.random" | head -1 | grep -q .; then
  finding "react-effect-init" "useEffect([]) for init — use useState(() => value) lazy initializer"
fi

# 7. Prop drilling through 3+ levels (use Context or composition)
# Heuristic: component with >8 props
if grep -rn "interface.*Props" $SRC --include="*.tsx" 2>/dev/null | grep -v node_modules | while read -r line; do
  FILE=$(echo "$line" | cut -d: -f1)
  PROPS=$(grep -A20 "interface.*Props" "$FILE" 2>/dev/null | grep -c "^\s*[a-z]" || echo 0)
  [ "$PROPS" -gt 8 ] && echo "found" && break
done | grep -q "found"; then
  finding "react-prop-drilling" "Component with >8 props — consider Context, composition, or state management"
fi

# 8. async in useEffect (should use IIFE or separate function)
if grep -rn "useEffect(async\|useEffect.*async () =>" $SRC --include="*.tsx" --include="*.ts" 2>/dev/null | grep -v node_modules | head -1 | grep -q .; then
  error "react-async-effect" "async useEffect — returns Promise instead of cleanup fn. Use IIFE inside"
fi

# 9. Direct DOM manipulation with document.querySelector
if grep -rn "document\.\(querySelector\|getElementById\|getElementsBy\)" $SRC --include="*.tsx" 2>/dev/null | grep -v node_modules | head -1 | grep -q .; then
  finding "react-direct-dom" "Direct DOM access — use useRef for React-managed DOM, or refs"
fi

# 10. setState inside render (infinite loop) — only at top level of component body
if grep -rn "^  set[A-Z][a-zA-Z]*(" $SRC --include="*.tsx" 2>/dev/null | grep -v "useEffect\|useCallback\|useMemo\|onClick\|onSubmit\|onChange\|handle\|return\|=>\|if (\|else\|case \|switch" | grep -v node_modules | grep -v "//\|/\*\|ref\.\|current\." | head -1 | grep -q .; then
  finding "react-setstate-in-render" "Possible setState during render — verify it's inside a handler or effect"
fi

# =============================================
# NEXT.JS ANTI-PATTERNS
# =============================================

if [ "$IS_NEXTJS" = "1" ]; then
  # 11. Server Component fetching own API route (redundant network hop)
  if grep -rn "fetch.*['\"/]api/" $SRC --include="*.tsx" --include="*.ts" 2>/dev/null | grep -v node_modules | grep -v "'use client'\|\"use client\"" | head -1 | grep -q .; then
    # Check if the file has 'use client' — only flag server components
    for f in $(grep -rl "fetch.*['\"/]api/" $SRC --include="*.tsx" --include="*.ts" 2>/dev/null | grep -v node_modules | head -3); do
      if ! head -3 "$f" | grep -q "use client"; then
        finding "nextjs-self-fetch" "Server Component fetches own /api route — call the logic directly instead"
        break
      fi
    done
  fi

  # 12. 'use client' at layout level (makes entire subtree client)
  if grep -rn "'use client'\|\"use client\"" $SRC --include="layout.tsx" 2>/dev/null | head -1 | grep -q .; then
    error "nextjs-client-layout" "'use client' in layout — entire subtree becomes client, massive bundle impact"
  fi

  # 13. useRouter for programmatic navigation in server context
  if grep -rn "useRouter" $SRC --include="*.tsx" 2>/dev/null | grep -v node_modules | \
    xargs grep -L "'use client'\|\"use client\"" 2>/dev/null | head -1 | grep -q . 2>/dev/null; then
    error "nextjs-userouter-server" "useRouter in Server Component — only works in Client Components"
  fi

  # 14. Missing loading.tsx (no streaming/suspense fallback)
  if [ -d "$REPO/app" ] || [ -d "$REPO/src/app" ]; then
    APP_DIR=$([ -d "$REPO/src/app" ] && echo "$REPO/src/app" || echo "$REPO/app")
    if [ ! -f "$APP_DIR/loading.tsx" ] && [ ! -f "$APP_DIR/loading.ts" ]; then
      finding "nextjs-no-loading" "No loading.tsx — users see blank page during navigation"
    fi
  fi

  # 15. Missing error.tsx (unhandled errors crash the page)
  if [ -d "${APP_DIR:-}" ] && [ ! -f "$APP_DIR/error.tsx" ] && [ ! -f "$APP_DIR/error.ts" ]; then
    finding "nextjs-no-error-boundary" "No error.tsx — runtime errors will crash the entire page"
  fi

  # 16. Missing not-found.tsx
  if [ -d "${APP_DIR:-}" ] && [ ! -f "$APP_DIR/not-found.tsx" ]; then
    finding "nextjs-no-not-found" "No not-found.tsx — 404s show generic Next.js page"
  fi

  # 17. Large client component could be split (>100 lines with 'use client')
  CLIENT_FILES=$(grep -rl "'use client'\|\"use client\"" $SRC --include="*.tsx" 2>/dev/null | grep -v node_modules || true)
  if [ -n "$CLIENT_FILES" ]; then
    LARGE=$(echo "$CLIENT_FILES" | xargs wc -l 2>/dev/null | grep -v total | awk '$1 > 150 {print $2}' | head -1 || true)
    [ -n "$LARGE" ] && \
      finding "nextjs-large-client" "$(basename "$LARGE") is >150 lines as Client Component — split into smaller pieces"
  fi

  # 18. Image without next/image
  if grep -rn "<img\b" $SRC --include="*.tsx" 2>/dev/null | grep -v node_modules | head -1 | grep -q .; then
    finding "nextjs-raw-img" "Raw <img> tag — use next/image for automatic optimization and lazy loading"
  fi

  # 19. Link without next/link
  if grep -rn "<a href=\"/" $SRC --include="*.tsx" 2>/dev/null | grep -v node_modules | grep -v "download\|mailto:\|tel:\|http" | head -1 | grep -q .; then
    finding "nextjs-raw-link" "Internal <a href='/...'> — use next/link for client-side navigation"
  fi

  # 20. Metadata not exported from page (SEO)
  PAGE_FILES=$(find $SRC -name "page.tsx" 2>/dev/null | grep -v node_modules || true)
  if [ -n "$PAGE_FILES" ]; then
    NO_META=$(echo "$PAGE_FILES" | xargs grep -L "metadata\|generateMetadata" 2>/dev/null | head -1 || true)
    [ -n "$NO_META" ] && \
      finding "nextjs-no-metadata" "Page without metadata export — bad for SEO"
  fi
fi

[ "$FINDINGS" -eq 0 ] && printf "  \033[32m✓\033[0m  Framework usage: all checks passed\n"
exit 0
