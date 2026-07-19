#!/usr/bin/env bash
# checks/javascript/check-bundle-size.sh
# @see ADR-129
# Bundle size optimization: tree-shaking, dynamic imports, heavy deps
set -o nounset -o pipefail

REPO="${1:-.}"
[ -f "$REPO/package.json" ] || exit 0

FINDINGS=0
finding() { printf "  \033[33mwarning\033[0m  %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }

SRC=""
[ -d "$REPO/src" ] && SRC="$REPO/src"
[ -d "$REPO/app" ] && SRC="${SRC:+$SRC }$REPO/app"
[ -z "$SRC" ] && exit 0

PKG="$REPO/package.json"

# 1. Full lodash import (72kb)
if grep -rn "from 'lodash'\|from \"lodash\"\|require('lodash')" $SRC --include="*.ts" --include="*.tsx" 2>/dev/null | grep -v node_modules | head -1 | grep -q .; then
  finding "bundle-lodash-full" "Full lodash import (72kb) — use lodash-es or import { fn } from 'lodash/fn'"
fi

# 2. Moment.js (300kb, deprecated)
if grep -q '"moment"' "$PKG" 2>/dev/null; then
  finding "bundle-moment" "moment.js (300kb, deprecated) — use date-fns (12kb) or dayjs (2kb)"
fi

# 3. MUI icons barrel import
if grep -rn "from '@mui/icons-material'" $SRC --include="*.tsx" 2>/dev/null | grep -v node_modules | grep "{ " | head -1 | grep -q .; then
  # Check if importing many icons from barrel
  ICON_IMPORTS=$(grep -rn "from '@mui/icons-material'" $SRC --include="*.tsx" 2>/dev/null | grep -v node_modules | grep -oP '(?<=\{ )[^}]+' | tr ',' '\n' | wc -l)
  ICON_IMPORTS=$(echo "$ICON_IMPORTS" | tr -d ' ')
  [ "${ICON_IMPORTS:-0}" -gt 10 ] && finding "bundle-mui-icons" "$ICON_IMPORTS icons from barrel import — use direct: import Icon from '@mui/icons-material/Icon'"
fi

# 4. Heavy lib imported in client component without dynamic()
HEAVY_LIBS="chart.js|d3|three|monaco-editor|@monaco-editor|codemirror|@codemirror|pdfjs-dist|@mdxeditor|quill|@lexical"
if grep -rn "from '.*\($HEAVY_LIBS\)" $SRC --include="*.tsx" 2>/dev/null | grep -v node_modules | head -1 | grep -q .; then
  CLIENT_HEAVY=$(grep -rl "'use client'" $SRC --include="*.tsx" 2>/dev/null | xargs grep -l "$HEAVY_LIBS" 2>/dev/null | head -1 || true)
  if [ -n "$CLIENT_HEAVY" ]; then
    if ! grep -q "dynamic(\|React.lazy" "$CLIENT_HEAVY" 2>/dev/null; then
      finding "bundle-heavy-static" "Heavy library statically imported in client — use next/dynamic or React.lazy"
    fi
  fi
fi

# 5. No bundle analyzer configured
if ! grep -q "analyzer\|@next/bundle-analyzer\|webpack-bundle-analyzer\|source-map-explorer" "$PKG" 2>/dev/null; then
  finding "bundle-no-analyzer" "No bundle analyzer — can't identify what's bloating the bundle"
fi

# 6. CSS-in-JS runtime in production (Emotion, styled-components)
if grep -q "@emotion/react\|styled-components" "$PKG" 2>/dev/null; then
  if grep -q '"next"' "$PKG" 2>/dev/null; then
    if ! grep -q "pigment\|panda\|tailwind\|@vanilla-extract" "$PKG" 2>/dev/null; then
      finding "bundle-css-runtime" "CSS-in-JS runtime (Emotion) — adds JS cost per style. Consider Pigment CSS or Tailwind"
    fi
  fi
fi

# 7. Importing entire library when sub-path available
if grep -rn "from 'rxjs'\|from \"rxjs\"" $SRC --include="*.ts" --include="*.tsx" 2>/dev/null | grep -v "rxjs/operators\|rxjs/" | grep -v node_modules | head -1 | grep -q .; then
  finding "bundle-rxjs-full" "Importing from 'rxjs' — use sub-paths: 'rxjs/operators', 'rxjs/ajax'"
fi

# 8. Polyfills that modern browsers don't need
POLYFILLS="core-js|regenerator-runtime|whatwg-fetch|promise-polyfill|url-polyfill|abortcontroller-polyfill"
if grep -qE "\"($POLYFILLS)\"" "$PKG" 2>/dev/null; then
  finding "bundle-stale-polyfill" "Polyfill for feature supported in all modern browsers — remove if target is ES2020+"
fi

# 9. Multiple date libraries
DATE_LIBS=0
grep -q '"date-fns"' "$PKG" 2>/dev/null && DATE_LIBS=$((DATE_LIBS+1))
grep -q '"dayjs"' "$PKG" 2>/dev/null && DATE_LIBS=$((DATE_LIBS+1))
grep -q '"luxon"' "$PKG" 2>/dev/null && DATE_LIBS=$((DATE_LIBS+1))
grep -q '"moment"' "$PKG" 2>/dev/null && DATE_LIBS=$((DATE_LIBS+1))
[ "$DATE_LIBS" -gt 1 ] && finding "bundle-multiple-date" "$DATE_LIBS date libraries — pick one"

# 10. No sideEffects field in package.json (hurts tree-shaking for libraries)
if grep -q '"main"\|"module"\|"exports"' "$PKG" 2>/dev/null; then
  if ! grep -q '"sideEffects"' "$PKG" 2>/dev/null; then
    finding "bundle-no-sideeffects" "Library without sideEffects field — bundlers can't tree-shake effectively"
  fi
fi

# 11. Wildcard re-exports (kills tree-shaking)
if grep -rn "export \* from" $SRC --include="*.ts" --include="*.tsx" 2>/dev/null | grep -v node_modules | wc -l | tr -d ' ' | grep -qE "^[5-9]|^[1-9][0-9]"; then
  finding "bundle-wildcard-reexport" "Many 'export * from' — kills tree-shaking, use named exports"
fi

# 12. next/image not used (missed optimization)
if grep -q '"next"' "$PKG" 2>/dev/null; then
  if grep -rn "<img\b" $SRC --include="*.tsx" 2>/dev/null | grep -v node_modules | head -1 | grep -q .; then
    if ! grep -rq "next/image\|Image.*from.*next" $SRC --include="*.tsx" 2>/dev/null; then
      finding "bundle-no-next-image" "Using <img> without next/image — missing automatic optimization + lazy loading"
    fi
  fi
fi

[ "$FINDINGS" -eq 0 ] && printf "  \033[32m✓\033[0m  Bundle size: all checks passed\n"
exit 0
