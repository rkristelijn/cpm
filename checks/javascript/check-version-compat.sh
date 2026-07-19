#!/usr/bin/env bash
# checks/javascript/check-version-compat.sh
# @see ADR-129
# Detects breaking changes from old versions, deprecated APIs, security vulnerabilities,
# and missing optimisations for: Next.js 15/16, MUI v7/v9, TanStack Query v5, React 19.
set -o nounset -o pipefail

REPO="${1:-.}"
[ -f "$REPO/package.json" ] || exit 0

FINDINGS=0
finding() { printf "  \033[33mwarning\033[0m  %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }
error()   { printf "  \033[31merror\033[0m    %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }

SRC=""
[ -d "$REPO/src" ] && SRC="$REPO/src"
[ -d "$REPO/app" ] && SRC="${SRC:+$SRC }$REPO/app"
[ -z "$SRC" ] && exit 0

PKG="$REPO/package.json"

# =============================================
# NEXT.JS 15/16 BREAKING CHANGES + SECURITY
# =============================================

if grep -q '"next"' "$PKG" 2>/dev/null; then
  NEXT_VER=$(grep '"next"' "$PKG" | grep -oE '[0-9]+' | head -1)

  # 1. CVE-2025-29927: middleware bypass via x-middleware-subrequest header
  if [ "${NEXT_VER:-0}" -lt 16 ]; then
    if grep -rq "middleware\.\(ts\|js\)" "$REPO/src" "$REPO" --include="*.ts" --include="*.js" 2>/dev/null; then
      if ! grep -rq "x-middleware-subrequest\|headers.*delete\|proxy\.ts" $SRC 2>/dev/null; then
        error "nextjs-cve-2025-29927" "Middleware auth bypass (CVE-2025-29927) — upgrade to Next.js 15.2.3+ or 16+"
      fi
    fi
  fi

  # 2. Next.js 16: middleware.ts renamed to proxy.ts
  if [ "${NEXT_VER:-0}" -ge 16 ]; then
    if [ -f "$REPO/src/middleware.ts" ] || [ -f "$REPO/middleware.ts" ]; then
      error "nextjs16-middleware-renamed" "middleware.ts renamed to proxy.ts in Next.js 16 — rename your file"
    fi
  fi

  # 3. Next.js 15+: fetch() no longer cached by default
  if [ "${NEXT_VER:-0}" -ge 15 ]; then
    if grep -rn "fetch(" $SRC --include="*.ts" --include="*.tsx" 2>/dev/null | grep -v node_modules | grep -v "revalidate\|cache\|no-store\|force-cache\|next:" | grep -v "test\|spec" | head -1 | grep -q .; then
      finding "nextjs15-fetch-no-cache" "fetch() without cache option — Next.js 15+ doesn't cache by default"
    fi
  fi

  # 4. Security: no CSP headers configured
  if ! grep -rq "Content-Security-Policy\|contentSecurityPolicy" $SRC "$REPO/next.config"* --include="*.ts" --include="*.js" --include="*.mjs" 2>/dev/null; then
    finding "nextjs-no-csp" "No Content-Security-Policy configured — vulnerable to XSS"
  fi

  # 5. Security: no X-Frame-Options or frame-ancestors
  if ! grep -rq "X-Frame-Options\|frame-ancestors" $SRC "$REPO/next.config"* --include="*.ts" --include="*.js" --include="*.mjs" 2>/dev/null; then
    finding "nextjs-no-xframe" "No X-Frame-Options/frame-ancestors — vulnerable to clickjacking"
  fi

  # 6. Security: auth in middleware without checking x-middleware-subrequest
  if [ -f "$REPO/src/middleware.ts" ] || [ -f "$REPO/middleware.ts" ]; then
    MW=$([ -f "$REPO/src/middleware.ts" ] && echo "$REPO/src/middleware.ts" || echo "$REPO/middleware.ts")
    if grep -q "auth\|token\|session\|cookie" "$MW" 2>/dev/null; then
      if ! grep -q "x-middleware-subrequest" "$MW" 2>/dev/null; then
        finding "nextjs-middleware-no-guard" "Auth in middleware without subrequest header check — potential bypass"
      fi
    fi
  fi

  # 7. Optimization: no Turbopack enabled (default in Next.js 16)
  if [ "${NEXT_VER:-0}" -ge 15 ] && [ "${NEXT_VER:-0}" -lt 16 ]; then
    if ! grep -q "turbo\|turbopack" "$REPO/package.json" "$REPO/next.config"* 2>/dev/null; then
      finding "nextjs-no-turbopack" "Turbopack not enabled — 10x faster dev builds (--turbopack flag)"
    fi
  fi

  # 8. Optimization: no Partial Prerendering
  if [ "${NEXT_VER:-0}" -ge 15 ]; then
    if ! grep -rq "experimental.*ppr\|partialPrerendering" "$REPO/next.config"* 2>/dev/null; then
      finding "nextjs-no-ppr" "Partial Prerendering not enabled — combine static shell + dynamic streaming"
    fi
  fi
fi

# =============================================
# MUI v7/v9 BREAKING CHANGES
# =============================================

if grep -q "@mui/material" "$PKG" 2>/dev/null; then
  MUI_VER=$(grep "@mui/material" "$PKG" | grep -oE '[0-9]+' | head -1)

  # 9. makeStyles/withStyles removed in v7+
  if grep -rn "makeStyles\|withStyles" $SRC --include="*.tsx" --include="*.ts" 2>/dev/null | grep -v node_modules | head -1 | grep -q .; then
    error "mui-makestyles-removed" "makeStyles/withStyles removed in MUI v7+ — use sx prop or styled()"
  fi

  # 10. @mui/styles package (completely removed)
  if grep -q "@mui/styles" "$PKG" 2>/dev/null; then
    error "mui-styles-removed" "@mui/styles package removed in v7+ — use @mui/material's sx/styled"
  fi

  # 11. theme.palette.mode vs theme.palette.type (v5 leftover)
  if grep -rn "palette\.type\|palette\[.type.\]" $SRC --include="*.tsx" --include="*.ts" 2>/dev/null | grep -v node_modules | head -1 | grep -q .; then
    finding "mui-palette-type" "palette.type is v4 — use palette.mode in v5+"
  fi

  # 12. Old slot prop pattern (v9 uses slots/slotProps)
  if grep -rn "componentsProps\|components=" $SRC --include="*.tsx" 2>/dev/null | grep -v node_modules | head -1 | grep -q .; then
    finding "mui-old-components-prop" "componentsProps/components deprecated — use slots={{ }} slotProps={{ }}"
  fi

  # 13. disableRipple globally (accessibility concern)
  if grep -rn "disableRipple" $SRC --include="*.tsx" --include="*.ts" 2>/dev/null | grep -v node_modules | head -1 | grep -q .; then
    finding "mui-disable-ripple" "disableRipple harms accessibility — ripple provides touch feedback"
  fi

  # 14. Optimization: no CSS theme variables (v6+ feature)
  if [ "${MUI_VER:-0}" -ge 6 ]; then
    if ! grep -rq "cssVariables\|CssVarsProvider\|extendTheme" $SRC --include="*.tsx" --include="*.ts" 2>/dev/null; then
      finding "mui-no-css-vars" "Not using MUI CSS variables — enables instant theme switching without JS"
    fi
  fi
fi

# =============================================
# TANSTACK QUERY v5 BREAKING CHANGES
# =============================================

if grep -q "@tanstack/react-query" "$PKG" 2>/dev/null; then
  # 15. cacheTime renamed to gcTime in v5
  if grep -rn "cacheTime" $SRC --include="*.ts" --include="*.tsx" 2>/dev/null | grep -v node_modules | head -1 | grep -q .; then
    error "tanstack-cachetime-removed" "cacheTime renamed to gcTime in v5 — update to gcTime"
  fi

  # 16. onSuccess/onError/onSettled removed from useQuery in v5 (still valid on useMutation)
  if grep -rn "useQuery" $SRC --include="*.ts" --include="*.tsx" 2>/dev/null | grep -v node_modules | \
    xargs grep -l "onSuccess\|onSettled" 2>/dev/null | head -1 | grep -q . 2>/dev/null; then
    error "tanstack-callbacks-removed" "onSuccess/onSettled removed from useQuery in v5 — use useEffect or global cache callbacks"
  fi

  # 17. isLoading renamed to isPending
  if grep -rn "isLoading" $SRC --include="*.tsx" 2>/dev/null | grep -v node_modules | grep -v "// \|/\*" | head -1 | grep -q .; then
    finding "tanstack-isloading-renamed" "isLoading in v5 only means 'pending + no data' — verify you mean isPending"
  fi

  # 18. keepPreviousData removed (use placeholderData)
  if grep -rn "keepPreviousData" $SRC --include="*.ts" --include="*.tsx" 2>/dev/null | grep -v node_modules | head -1 | grep -q .; then
    error "tanstack-keepprevious-removed" "keepPreviousData removed in v5 — use placeholderData: (prev) => prev"
  fi

  # 19. Optimization: no prefetching for navigation
  if ! grep -rq "prefetchQuery\|prefetchInfiniteQuery" $SRC --include="*.ts" --include="*.tsx" 2>/dev/null; then
    finding "tanstack-no-prefetch" "No prefetchQuery — prefetch on hover/focus for instant navigation"
  fi

  # 20. Optimization: no placeholder data
  if ! grep -rq "placeholderData\|initialData" $SRC --include="*.ts" --include="*.tsx" 2>/dev/null; then
    finding "tanstack-no-placeholder" "No placeholderData/initialData — users see loading spinner instead of instant UI"
  fi
fi

# =============================================
# REACT 19 BREAKING CHANGES + OPTIMIZATION
# =============================================

if grep -q '"react"' "$PKG" 2>/dev/null; then
  REACT_VER=$(grep '"react"' "$PKG" | grep -oE '[0-9]+' | head -1)

  # 21. forwardRef no longer needed in React 19
  if [ "${REACT_VER:-0}" -ge 19 ]; then
    if grep -rn "forwardRef\|React.forwardRef" $SRC --include="*.tsx" --include="*.ts" 2>/dev/null | grep -v node_modules | head -1 | grep -q .; then
      finding "react19-no-forwardref" "forwardRef unnecessary in React 19 — ref is a regular prop now"
    fi
  fi

  # 22. React.FC deprecated pattern
  if grep -rn "React\.FC\|React\.FunctionComponent" $SRC --include="*.tsx" 2>/dev/null | grep -v node_modules | head -1 | grep -q .; then
    finding "react-fc-deprecated" "React.FC is discouraged — just type props directly: function Comp(props: Props)"
  fi

  # 23. Security: React 19 RSC deserialization (React2Shell)
  if [ "${REACT_VER:-0}" -ge 19 ]; then
    if grep -rq "'use server'" $SRC --include="*.ts" --include="*.tsx" 2>/dev/null; then
      if ! grep -rq "zod\|z\.\|validate\|sanitize\|tainted" $SRC --include="*.ts" --include="*.tsx" 2>/dev/null; then
        finding "react19-server-action-no-validation" "Server Actions without input validation — React2Shell deserialization risk"
      fi
    fi
  fi

  # 24. Optimization: React Compiler not configured
  if [ "${REACT_VER:-0}" -ge 19 ]; then
    if ! grep -rq "react-compiler\|babel-plugin-react-compiler\|reactCompiler" "$REPO/package.json" "$REPO/next.config"* "$REPO/babel.config"* "$REPO/.babelrc"* 2>/dev/null; then
      finding "react19-no-compiler" "React Compiler not enabled — auto-memoizes, removes need for useMemo/useCallback"
    fi
  fi

  # 25. use() hook not adopted for data fetching in RSC
  if [ "${REACT_VER:-0}" -ge 19 ]; then
    if grep -rq "async.*function.*Page\|async.*function.*Layout" $SRC --include="*.tsx" 2>/dev/null; then
      if ! grep -rq "use(" $SRC --include="*.tsx" 2>/dev/null; then
        : # Optional: use() is new, don't enforce yet
      fi
    fi
  fi
fi

[ "$FINDINGS" -eq 0 ] && printf "  \033[32m✓\033[0m  Version compatibility: all checks passed\n"
exit 0
