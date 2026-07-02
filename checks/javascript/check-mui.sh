#!/usr/bin/env bash
# checks/javascript/check-mui.sh
# @see ADR-129
# MUI v9 best practices (updated from v6/v7 rules)
# Based on: eslint-plugin-mui (rkristelijn/eslint-plugin-mui)
# Reference: https://mui.com/material-ui/migration/upgrade-to-v7/
# Reference: https://mui.com/blog/introducing-mui-v9
set -o nounset -o pipefail

REPO="${1:-.}"
[ -f "$REPO/package.json" ] && grep -q "@mui/material\|@mui/core" "$REPO/package.json" || exit 0

FINDINGS=0
finding() { printf "  \033[33mwarning\033[0m  %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }
blocker() { printf "  \033[31mblocking\033[0m %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }

SRC=""
[ -d "$REPO/src" ] && SRC="$REPO/src"
[ -d "$REPO/app" ] && SRC="${SRC:+$SRC }$REPO/app"
[ -z "$SRC" ] && exit 0

# --- 1. Deep imports (FORBIDDEN since MUI v7+) ---
if grep -rn "from '@mui/material/styles/\|from '@mui/material/[^']*/" $SRC --include="*.tsx" --include="*.ts" 2>/dev/null | grep -v "from '@mui/material/'" | grep -v node_modules | grep "/" | grep -E "/[a-z]" | head -1 | grep -q .; then
  blocker "mui-deep-import" "Deep import detected — MUI v7+ forbids multi-level imports (use top-level)"
fi

# --- 2. Deprecated Grid2 import (renamed to Grid in v9) ---
if grep -rn "from '@mui/material/Grid2'\|import.*Grid2.*from '@mui/material'" $SRC --include="*.tsx" --include="*.ts" 2>/dev/null | grep -v node_modules | head -1 | grep -q .; then
  finding "mui-grid2-deprecated" "Grid2 import — renamed to Grid in MUI v9 (Grid2 is now just Grid)"
fi

# --- 3. Deprecated APIs removed in v7/v9 ---
if grep -rn "createMuiTheme\|experimentalStyled\|<Hidden\b\|<PigmentHidden" $SRC --include="*.tsx" --include="*.ts" 2>/dev/null | grep -v node_modules | head -1 | grep -q .; then
  blocker "mui-deprecated-api" "Removed API detected (createMuiTheme/experimentalStyled/Hidden) — removed in v7+"
fi

# --- 4. Toolpad imports (not actively maintained) ---
if grep -rn "@toolpad/core\|from '@toolpad" $SRC --include="*.tsx" --include="*.ts" 2>/dev/null | grep -v node_modules | head -1 | grep -q .; then
  finding "mui-toolpad" "@toolpad/core import — Toolpad is not actively maintained, consider alternatives"
fi

# --- 5. Old slot pattern (TransitionComponent/TransitionProps) ---
if grep -rn "TransitionComponent=\|TransitionProps=" $SRC --include="*.tsx" 2>/dev/null | grep -v node_modules | head -1 | grep -q .; then
  finding "mui-old-slot-pattern" "TransitionComponent/Props — use slots={{ transition: ... }} slotProps={{ transition: ... }}"
fi

# --- 6. no-literal-colors: hardcoded colors in sx prop ---
if grep -rn "sx={{" $SRC --include="*.tsx" --include="*.ts" 2>/dev/null | grep -v node_modules | grep -E "'#[0-9a-fA-F]{3,8}'|\"#[0-9a-fA-F]{3,8}\"|'rgb\(|\"rgb\(" | head -1 | grep -q .; then
  finding "mui-literal-color" "Literal color in sx prop — use theme.palette tokens instead"
fi

# --- 7. no-single-child-in-grid ---
if grep -rn "<Grid " $SRC --include="*.tsx" 2>/dev/null | grep -v node_modules | head -1 | grep -q .; then
  GRID_FILES=$(grep -rl "<Grid " $SRC --include="*.tsx" 2>/dev/null | grep -v node_modules || true)
  for f in $GRID_FILES; do
    ITEMS=$(grep -c "<Grid " "$f" 2>/dev/null || echo 0)
    [ "$ITEMS" -eq 2 ] && finding "mui-single-grid-child" "Grid with single child — Grid is unnecessary ($(basename $f))" && break
  done
fi

# --- 8. no-single-child-in-stack ---
if grep -rn "<Stack" $SRC --include="*.tsx" 2>/dev/null | grep -v node_modules | head -1 | grep -q .; then
  STACK_FILES=$(grep -rl "<Stack" $SRC --include="*.tsx" 2>/dev/null | grep -v node_modules || true)
  for f in $STACK_FILES; do
    if grep -Pzo "(?s)<Stack[^>]*>\s*<[^/][^>]*/>?\s*</Stack>" "$f" 2>/dev/null | head -1 | grep -q .; then
      finding "mui-single-stack-child" "Stack with single child — Stack is unnecessary ($(basename $f))" && break
    fi
  done
fi

# --- 9. Default icon import (bad for tree-shaking) ---
if grep -rn "from '@mui/icons-material/" $SRC --include="*.tsx" --include="*.ts" 2>/dev/null | grep "import [A-Z]" | grep -v "{ " | grep -v node_modules | head -1 | grep -q .; then
  finding "mui-icon-default-import" "Default import for MUI icon — use named import: import { Icon } from '@mui/icons-material'"
fi

# --- 10. No ThemeProvider (using MUI without theme) ---
if ! grep -rq "ThemeProvider\|createTheme\|ThemeRegistry" $SRC --include="*.tsx" --include="*.ts" 2>/dev/null; then
  finding "mui-no-theme" "No ThemeProvider/createTheme — MUI components use default theme"
fi

# --- 11. sx prop with magic spacing values ---
if grep -rn "sx={{" $SRC --include="*.tsx" 2>/dev/null | grep -E "[0-9]+(px|rem|em)" | grep -v node_modules | head -1 | grep -q .; then
  finding "mui-magic-spacing" "Magic px/rem values in sx — use theme.spacing() or numeric shorthand"
fi

# --- 12. Missing AppRouterCacheProvider (Next.js + MUI SSR) ---
if [ -f "$REPO/package.json" ] && grep -q '"next"' "$REPO/package.json" 2>/dev/null; then
  if ! grep -rq "AppRouterCacheProvider" $SRC --include="*.tsx" --include="*.ts" 2>/dev/null; then
    finding "mui-no-cache-provider" "Missing AppRouterCacheProvider — required for MUI + Next.js SSR"
  fi
fi

[ "$FINDINGS" -eq 0 ] && printf "  \033[32m✓\033[0m  MUI v9 patterns: all checks passed\n"
exit 0
