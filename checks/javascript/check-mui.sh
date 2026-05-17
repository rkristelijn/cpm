#!/usr/bin/env bash
# checks/javascript/check-mui.sh
# MUI best practices from eslint-plugin-mui (rkristelijn/eslint-plugin-mui)
# Rules: no-grid-alias, no-literal-colors, no-single-child-in-grid,
#        no-single-child-in-stack, prefer-named-imports, sort-sx-keys
set -o nounset -o pipefail

REPO="${1:-.}"
[ -f "$REPO/package.json" ] && grep -q "@mui/material\|@mui/core" "$REPO/package.json" || exit 0

FINDINGS=0
finding() { printf "  \033[33mwarning\033[0m  %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }

SRC=""
[ -d "$REPO/src" ] && SRC="$REPO/src"
[ -d "$REPO/app" ] && SRC="${SRC:+$SRC }$REPO/app"
[ -z "$SRC" ] && exit 0

# --- 1. no-grid-alias: Grid2 renamed on import ---
if grep -rn "Grid2 as\|as Grid2\b" $SRC --include="*.tsx" --include="*.ts" 2>/dev/null | grep -v node_modules | head -1 | grep -q .; then
  finding "mui-grid-alias" "Grid2 aliased on import — use Grid2 directly for consistency"
fi

# --- 2. no-literal-colors: hardcoded colors in sx prop ---
if grep -rn "sx={{" $SRC --include="*.tsx" --include="*.ts" 2>/dev/null | grep -v node_modules | grep -E "'#[0-9a-fA-F]{3,8}'|\"#[0-9a-fA-F]{3,8}\"|'rgb\(|\"rgb\(" | head -1 | grep -q .; then
  finding "mui-literal-color" "Literal color in sx prop — use theme.palette tokens instead"
fi

# --- 3. no-single-child-in-grid: Grid with only 1 child ---
if grep -rn "<Grid2" $SRC --include="*.tsx" 2>/dev/null | grep -v node_modules | head -1 | grep -q .; then
  # Check for Grid2 wrapping a single element (heuristic: Grid2 with no sibling Grid2 item)
  GRID_FILES=$(grep -rl "<Grid2" $SRC --include="*.tsx" 2>/dev/null | grep -v node_modules || true)
  for f in $GRID_FILES; do
    # Count Grid2 children (items) per container
    ITEMS=$(grep -c "<Grid2" "$f" 2>/dev/null || echo 0)
    [ "$ITEMS" -eq 2 ] && finding "mui-single-grid-child" "Grid2 with single child — Grid is unnecessary ($(basename $f))" && break
  done
fi

# --- 4. no-single-child-in-stack: Stack with only 1 child ---
if grep -rn "<Stack" $SRC --include="*.tsx" 2>/dev/null | grep -v node_modules | head -1 | grep -q .; then
  STACK_FILES=$(grep -rl "<Stack" $SRC --include="*.tsx" 2>/dev/null | grep -v node_modules || true)
  for f in $STACK_FILES; do
    # Heuristic: Stack immediately followed by closing with only 1 child element
    if grep -Pzo "(?s)<Stack[^>]*>\s*<[^/][^>]*/>?\s*</Stack>" "$f" 2>/dev/null | head -1 | grep -q .; then
      finding "mui-single-stack-child" "Stack with single child — Stack is unnecessary ($(basename $f))" && break
    fi
  done
fi

# --- 5. prefer-named-imports: default import for MUI icons ---
if grep -rn "from '@mui/icons-material/" $SRC --include="*.tsx" --include="*.ts" 2>/dev/null | grep "import [A-Z]" | grep -v "{ " | grep -v node_modules | head -1 | grep -q .; then
  finding "mui-icon-default-import" "Default import for MUI icon — use named import for tree-shaking"
fi

# --- 6. Barrel import from @mui/material (bundle size) ---
if grep -rn "from '@mui/material'" $SRC --include="*.tsx" --include="*.ts" 2>/dev/null | grep -v "from '@mui/material/" | grep -v node_modules | head -1 | grep -q .; then
  finding "mui-barrel-import" "Barrel import from '@mui/material' — use deep imports for smaller bundles"
fi

# --- 7. sx prop with inline styles that should be theme tokens ---
if grep -rn "fontSize:\|fontWeight:\|padding:\|margin:" $SRC --include="*.tsx" 2>/dev/null | grep "sx={{" | grep -E "[0-9]+(px|rem|em)" | grep -v node_modules | head -1 | grep -q .; then
  finding "mui-magic-spacing" "Magic px/rem values in sx — use theme.spacing() or theme tokens"
fi

# --- 8. No ThemeProvider (using MUI without theme) ---
if ! grep -rq "ThemeProvider\|createTheme" $SRC --include="*.tsx" --include="*.ts" 2>/dev/null; then
  finding "mui-no-theme" "No ThemeProvider/createTheme — MUI components use default theme"
fi

[ "$FINDINGS" -eq 0 ] && printf "  \033[32m✓\033[0m  MUI patterns: all checks passed\n"
exit 0
