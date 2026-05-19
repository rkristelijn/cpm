#!/usr/bin/env bash
# checks/javascript/nextjs/check-performance.sh
# @see ADR-129
# Core Web Vitals mistakes: CSS-in-JS, fonts, images, scripts, bundle size
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../../lib/shell/init.sh" 2>/dev/null || true
cpm_check_enabled "nextjs-performance" || exit 0
set -o nounset -o pipefail

REPO="${1:-.}"
[ -f "$REPO/package.json" ] && grep -q '"next"' "$REPO/package.json" || exit 0

FINDINGS=0
finding() { printf "  \033[33mwarning\033[0m  %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }

# CSS-in-JS runtime
grep -qE '"styled-components"|"@emotion/react"|"@emotion/styled"' "$REPO/package.json" && \
  finding "css-in-js-runtime" "CSS-in-JS runtime — hurts INP/FCP. Use Tailwind or CSS Modules"

# Third-party font CDN
cpm_grep -rl "fonts.googleapis.com\|fonts.gstatic.com" "$REPO/app/" "$REPO/src/" 2>/dev/null | head -1 | grep -q . && \
  finding "third-party-fonts" "Third-party font CDN — use next/font for self-hosting"

# Raw <img> tag
cpm_grep -rl '<img ' "$REPO/app/" "$REPO/src/" 2>/dev/null | head -1 | grep -q . && \
  finding "raw-img-tag" "Raw <img> tag — use next/image for optimization"

# LCP image without priority
PAGE=$(find "$REPO" -maxdepth 3 -name "page.tsx" -o -name "page.jsx" 2>/dev/null | grep "/app/page" | head -1)
[ -n "$PAGE" ] && grep -q "Image" "$PAGE" && ! grep -q "priority" "$PAGE" && \
  finding "lcp-no-priority" "Image on landing page without priority — hurts LCP"

# Raw <script> tag
cpm_grep -rl '<script ' "$REPO/app/" "$REPO/src/" 2>/dev/null | head -1 | grep -q . && \
  finding "raw-script-tag" "Raw <script> — use next/script with loading strategy"

# Heavy static imports
cpm_grep -rlE "import .* from ['\"](@mui|antd|recharts|chart\.js|moment|lodash|three)" "$REPO/app/" "$REPO/src/" 2>/dev/null | head -1 | grep -q . && \
  finding "missing-dynamic-import" "Heavy library imported statically — use next/dynamic"

# React Compiler not enabled
NEXTCFG=$(find "$REPO" -maxdepth 1 -name "next.config.*" | head -1)
[ -n "$NEXTCFG" ] && ! grep -q "reactCompiler\|experimental.*compiler" "$NEXTCFG" && \
  grep -q '"react".*"19\|"react".*"2' "$REPO/package.json" && \
  finding "no-react-compiler" "React Compiler not enabled — ~15% free perf improvement"

[ "$FINDINGS" -eq 0 ] && echo "  ✓ Next.js performance OK"
exit 0
