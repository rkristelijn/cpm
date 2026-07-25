#!/usr/bin/env bash
# scripts/fixes/fix-safe.sh — Apply all SAFE autofixes (won't break anything)
# Usage: bash fixes/fix-safe.sh [path] [--risky]
# --risky: also apply risky fixes (may need review)
set -o nounset -o pipefail

REPO="${1:-.}"
RISKY=0
[[ "${2:-}" == "--risky" ]] && RISKY=1

PKG="$REPO/package.json"
TSCONFIG="$REPO/tsconfig.json"
FIXED=0
SKIPPED=0

fix()  { printf "  \033[32m✓ fixed\033[0m  %-35s %s\n" "$1" "$2"; FIXED=$((FIXED+1)); }
skip() { printf "  \033[90m· skip\033[0m   %-35s %s\n" "$1" "$2"; SKIPPED=$((SKIPPED+1)); }
risky(){ printf "  \033[33m⚠ risky\033[0m  %-35s %s\n" "$1" "$2"; FIXED=$((FIXED+1)); }

echo ""
echo "  cpm fix --safe"
[ "$RISKY" -eq 1 ] && echo "  (including --risky fixes)"
echo ""

# =============================================
# PACKAGE.JSON METADATA
# =============================================

if [ -f "$PKG" ]; then
  buf=$(cat "$PKG")

  # Helper: modify package.json with node
  pkg_set() {
    local SCRIPT="$1"
    node -e "$SCRIPT" 2>/dev/null
  }

  # --- description ---
  if ! echo "$buf" | grep -q '"description"'; then
    DESC=$(basename "$(cd "$REPO" && pwd)")
    pkg_set "const fs=require('fs');const p=JSON.parse(fs.readFileSync('$PKG','utf8'));p.description='$DESC';fs.writeFileSync('$PKG',JSON.stringify(p,null,2)+'\n')" && \
      fix "no-description" "Added description: '$DESC'" || skip "no-description" "node not available"
  fi

  # --- author ---
  if ! echo "$buf" | grep -q '"author"'; then
    AUTHOR=$(git config user.name 2>/dev/null || echo "")
    EMAIL=$(git config user.email 2>/dev/null || echo "")
    if [ -n "$AUTHOR" ]; then
      pkg_set "const fs=require('fs');const p=JSON.parse(fs.readFileSync('$PKG','utf8'));p.author='$AUTHOR <$EMAIL>';fs.writeFileSync('$PKG',JSON.stringify(p,null,2)+'\n')" && \
        fix "no-author" "Added author: '$AUTHOR'" || skip "no-author" "node not available"
    fi
  fi

  # --- repository ---
  if ! echo "$buf" | grep -q '"repository"'; then
    REMOTE=$(cd "$REPO" && git remote get-url origin 2>/dev/null | sed 's/\.git$//' | sed 's|git@github.com:|https://github.com/|' || echo "")
    if [ -n "$REMOTE" ]; then
      pkg_set "const fs=require('fs');const p=JSON.parse(fs.readFileSync('$PKG','utf8'));p.repository={type:'git',url:'$REMOTE'};fs.writeFileSync('$PKG',JSON.stringify(p,null,2)+'\n')" && \
        fix "no-repository" "Added repository: $REMOTE" || skip "no-repository" "node not available"
    fi
  fi

  # --- homepage ---
  if ! echo "$buf" | grep -q '"homepage"'; then
    REMOTE=$(cd "$REPO" && git remote get-url origin 2>/dev/null | sed 's/\.git$//' | sed 's|git@github.com:|https://github.com/|' || echo "")
    if [ -n "$REMOTE" ]; then
      pkg_set "const fs=require('fs');const p=JSON.parse(fs.readFileSync('$PKG','utf8'));p.homepage='${REMOTE}#readme';fs.writeFileSync('$PKG',JSON.stringify(p,null,2)+'\n')" && \
        fix "no-homepage" "Added homepage" || skip "no-homepage" "node not available"
    fi
  fi

  # --- bugs ---
  if ! echo "$buf" | grep -q '"bugs"'; then
    REMOTE=$(cd "$REPO" && git remote get-url origin 2>/dev/null | sed 's/\.git$//' | sed 's|git@github.com:|https://github.com/|' || echo "")
    if [ -n "$REMOTE" ]; then
      pkg_set "const fs=require('fs');const p=JSON.parse(fs.readFileSync('$PKG','utf8'));p.bugs={url:'${REMOTE}/issues'};fs.writeFileSync('$PKG',JSON.stringify(p,null,2)+'\n')" && \
        fix "no-bugs-url" "Added bugs URL" || skip "no-bugs-url" "node not available"
    fi
  fi

  # --- private:true for apps ---
  if ! echo "$buf" | grep -q '"main"\|"module"\|"exports"'; then
    if ! echo "$buf" | grep -q '"private"'; then
      pkg_set "const fs=require('fs');const p=JSON.parse(fs.readFileSync('$PKG','utf8'));p.private=true;fs.writeFileSync('$PKG',JSON.stringify(p,null,2)+'\n')" && \
        fix "no-private" "Added private:true" || skip "no-private" "node not available"
    fi
  fi

  # --- engines ---
  if ! echo "$buf" | grep -q '"engines"'; then
    NODE_VER=$(node -v 2>/dev/null | tr -d 'v' | cut -d. -f1)
    if [ -n "$NODE_VER" ]; then
      pkg_set "const fs=require('fs');const p=JSON.parse(fs.readFileSync('$PKG','utf8'));p.engines={node:'>=${NODE_VER}'};fs.writeFileSync('$PKG',JSON.stringify(p,null,2)+'\n')" && \
        fix "no-engines" "Added engines.node >= $NODE_VER" || skip "no-engines" "node not available"
    fi
  fi

  # --- license ---
  if ! echo "$buf" | grep -q '"license"'; then
    pkg_set "const fs=require('fs');const p=JSON.parse(fs.readFileSync('$PKG','utf8'));p.license='MIT';fs.writeFileSync('$PKG',JSON.stringify(p,null,2)+'\n')" && \
      fix "no-license" "Added license: MIT" || skip "no-license" "node not available"
  fi

  # =============================================
  # PACKAGE.JSON SCRIPTS
  # =============================================

  # --- clean script ---
  if ! echo "$buf" | grep -q '"clean"'; then
    CLEAN_CMD="rm -rf .next dist build coverage .tmp"
    pkg_set "const fs=require('fs');const p=JSON.parse(fs.readFileSync('$PKG','utf8'));if(!p.scripts)p.scripts={};p.scripts.clean='$CLEAN_CMD';fs.writeFileSync('$PKG',JSON.stringify(p,null,2)+'\n')" && \
      fix "no-clean-script" "Added clean script" || skip "no-clean-script" "node not available"
  fi

  # --- typecheck script ---
  if [ -f "$TSCONFIG" ] && ! echo "$buf" | grep -q '"typecheck"'; then
    pkg_set "const fs=require('fs');const p=JSON.parse(fs.readFileSync('$PKG','utf8'));if(!p.scripts)p.scripts={};p.scripts.typecheck='tsc --noEmit';fs.writeFileSync('$PKG',JSON.stringify(p,null,2)+'\n')" && \
      fix "no-typecheck-script" "Added typecheck script" || skip "no-typecheck-script" "node not available"
  fi

  # --- check script ---
  if ! echo "$buf" | grep -q '"check"'; then
    pkg_set "const fs=require('fs');const p=JSON.parse(fs.readFileSync('$PKG','utf8'));if(!p.scripts)p.scripts={};p.scripts.check='npm run lint && npm run test && npm run build';fs.writeFileSync('$PKG',JSON.stringify(p,null,2)+'\n')" && \
      fix "no-check-script" "Added check script (lint+test+build)" || skip "no-check-script" "node not available"
  fi

  # =============================================
  # DEPENDENCY PLACEMENT
  # =============================================

  # --- @types/* in dependencies → devDependencies ---
  TYPES_IN_DEPS=$(pkg_set "const fs=require('fs');const p=JSON.parse(fs.readFileSync('$PKG','utf8'));const d=p.dependencies||{};const t=Object.keys(d).filter(k=>k.startsWith('@types/'));if(t.length)console.log(t.join(','))" || true)
  if [ -n "$TYPES_IN_DEPS" ]; then
    pkg_set "
      const fs=require('fs');
      const p=JSON.parse(fs.readFileSync('$PKG','utf8'));
      const deps=p.dependencies||{};
      const dev=p.devDependencies||{};
      Object.keys(deps).filter(k=>k.startsWith('@types/')).forEach(k=>{dev[k]=deps[k];delete deps[k]});
      p.devDependencies=dev;
      fs.writeFileSync('$PKG',JSON.stringify(p,null,2)+'\n');
    " && fix "types-in-prod" "Moved $TYPES_IN_DEPS to devDependencies"
  fi

  # --- duplicates in both deps and devDeps ---
  DUPES=$(pkg_set "const fs=require('fs');const p=JSON.parse(fs.readFileSync('$PKG','utf8'));const d=Object.keys(p.dependencies||{});const v=Object.keys(p.devDependencies||{});const dup=d.filter(x=>v.includes(x));if(dup.length)console.log(dup.join(','))" || true)
  if [ -n "$DUPES" ]; then
    pkg_set "
      const fs=require('fs');
      const p=JSON.parse(fs.readFileSync('$PKG','utf8'));
      const deps=Object.keys(p.dependencies||{});
      const dev=p.devDependencies||{};
      deps.filter(k=>dev[k]).forEach(k=>delete dev[k]);
      fs.writeFileSync('$PKG',JSON.stringify(p,null,2)+'\n');
    " && fix "duplicate-in-both" "Removed duplicates from devDeps: $DUPES"
  fi
fi

# =============================================
# TSCONFIG FIXES
# =============================================

if [ -f "$TSCONFIG" ]; then
  # Helper: add a compiler option
  ts_set() {
    local KEY="$1" VALUE="$2"
    if ! grep -q "\"$KEY\"" "$TSCONFIG" 2>/dev/null; then
      node -e "
        const fs=require('fs');
        const t=JSON.parse(fs.readFileSync('$TSCONFIG','utf8'));
        if(!t.compilerOptions)t.compilerOptions={};
        t.compilerOptions['$KEY']=$VALUE;
        fs.writeFileSync('$TSCONFIG',JSON.stringify(t,null,2)+'\n');
      " 2>/dev/null && fix "tsconfig-$KEY" "Set $KEY: $VALUE" && return 0
    fi
    return 1
  }

  ts_set "skipLibCheck" "true"
  ts_set "isolatedModules" "true"
  ts_set "resolveJsonModule" "true"
  ts_set "noUncheckedIndexedAccess" "true"
fi

# =============================================
# FILES
# =============================================

# --- .nvmrc ---
if [ ! -f "$REPO/.nvmrc" ] && [ ! -f "$REPO/.node-version" ]; then
  NODE_VER=$(node -v 2>/dev/null | tr -d 'v')
  if [ -n "$NODE_VER" ]; then
    echo "$NODE_VER" > "$REPO/.nvmrc"
    fix "no-node-version-file" "Created .nvmrc ($NODE_VER)"
  fi
fi

# --- LICENSE ---
if [ ! -f "$REPO/LICENSE" ] && [ ! -f "$REPO/LICENSE.md" ]; then
  YEAR=$(date +%Y)
  AUTHOR=$(git config user.name 2>/dev/null || echo "Author")
  cat > "$REPO/LICENSE" << EOF
MIT License

Copyright (c) $YEAR $AUTHOR

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF
  fix "no-license-file" "Created MIT LICENSE"
fi

# --- .gitignore append node_modules ---
if [ -f "$REPO/.gitignore" ]; then
  if ! grep -q "node_modules" "$REPO/.gitignore"; then
    echo "node_modules/" >> "$REPO/.gitignore"
    fix "gitignore-no-node-modules" "Added node_modules/ to .gitignore"
  fi
fi

# --- Next.js boundary files ---
if [ -f "$PKG" ] && grep -q '"next"' "$PKG" 2>/dev/null; then
  APP_DIR=""
  [ -d "$REPO/src/app" ] && APP_DIR="$REPO/src/app"
  [ -d "$REPO/app" ] && APP_DIR="$REPO/app"

  if [ -n "$APP_DIR" ]; then
    if [ ! -f "$APP_DIR/loading.tsx" ]; then
      cat > "$APP_DIR/loading.tsx" << 'EOF'
import { Box, CircularProgress } from "@mui/material";

export default function Loading() {
  return (
    <Box sx={{ display: "flex", alignItems: "center", justifyContent: "center", height: "100vh" }}>
      <CircularProgress />
    </Box>
  );
}
EOF
      fix "nextjs-no-loading" "Created loading.tsx"
    fi

    if [ ! -f "$APP_DIR/error.tsx" ]; then
      cat > "$APP_DIR/error.tsx" << 'EOF'
"use client";

import { Box, Button, Typography } from "@mui/material";

export default function Error({ error, reset }: { error: Error; reset: () => void }) {
  return (
    <Box sx={{ display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", height: "100vh", gap: 2 }}>
      <Typography variant="h5">Something went wrong</Typography>
      <Typography variant="body2" color="text.secondary">{error.message}</Typography>
      <Button variant="outlined" onClick={reset}>Try again</Button>
    </Box>
  );
}
EOF
      fix "nextjs-no-error-boundary" "Created error.tsx"
    fi

    if [ ! -f "$APP_DIR/not-found.tsx" ]; then
      cat > "$APP_DIR/not-found.tsx" << 'EOF'
import { Box, Button, Typography } from "@mui/material";
import Link from "next/link";

export default function NotFound() {
  return (
    <Box sx={{ display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", height: "100vh", gap: 2 }}>
      <Typography variant="h5">Page not found</Typography>
      <Button component={Link} href="/" variant="outlined">Back to home</Button>
    </Box>
  );
}
EOF
      fix "nextjs-no-not-found" "Created not-found.tsx"
    fi
  fi
fi

# =============================================
# RISKY FIXES (only with --risky flag)
# =============================================

if [ "$RISKY" -eq 1 ] && [ -f "$PKG" ]; then
  echo ""
  echo "  ⚠️  Applying risky fixes (review changes before committing):"
  echo ""

  # --- Pin dependencies (remove ^ and ~) ---
  if grep -qE '"\^|"~' "$PKG"; then
    sed -i 's/"\^/"/g; s/"~/"/g' "$PKG"
    risky "unpinned-deps" "Removed ^ and ~ from all dependency versions"
  fi

  # --- cacheTime → gcTime ---
  if grep -rq "cacheTime" "$REPO/src" --include="*.ts" --include="*.tsx" 2>/dev/null; then
    find "$REPO/src" -name "*.ts" -o -name "*.tsx" 2>/dev/null | xargs sed -i 's/cacheTime/gcTime/g' 2>/dev/null
    risky "tanstack-cachetime" "Renamed cacheTime → gcTime"
  fi

  # --- keepPreviousData → placeholderData ---
  if grep -rq "keepPreviousData" "$REPO/src" --include="*.ts" --include="*.tsx" 2>/dev/null; then
    find "$REPO/src" -name "*.ts" -o -name "*.tsx" 2>/dev/null | xargs sed -i 's/keepPreviousData: true/placeholderData: (prev) => prev/g' 2>/dev/null
    risky "tanstack-keepprevious" "Replaced keepPreviousData with placeholderData"
  fi

  # --- Grid2 → Grid ---
  if grep -rq "Grid2" "$REPO/src" --include="*.tsx" 2>/dev/null; then
    find "$REPO/src" -name "*.tsx" 2>/dev/null | xargs sed -i "s/from '@mui\/material\/Grid2'/from '@mui\/material\/Grid'/g; s/import.*Grid2/import Grid/g; s/<Grid2/<Grid/g; s/<\/Grid2>/<\/Grid>/g" 2>/dev/null
    risky "mui-grid2" "Renamed Grid2 → Grid"
  fi

  # --- componentsProps → slotProps ---
  if grep -rq "componentsProps" "$REPO/src" --include="*.tsx" 2>/dev/null; then
    find "$REPO/src" -name "*.tsx" 2>/dev/null | xargs sed -i 's/componentsProps/slotProps/g; s/components=/slots=/g' 2>/dev/null
    risky "mui-components-prop" "Renamed componentsProps→slotProps, components→slots"
  fi

  # --- middleware.ts → proxy.ts (Next.js 16) ---
  if [ -f "$REPO/src/middleware.ts" ] && grep -q '"next".*"16\|"next".*"17' "$PKG" 2>/dev/null; then
    mv "$REPO/src/middleware.ts" "$REPO/src/proxy.ts"
    risky "nextjs16-middleware" "Renamed middleware.ts → proxy.ts"
  fi
fi

# =============================================
# SUMMARY
# =============================================

echo ""
echo "  ────────────────────────────────────────"
printf "  \033[32m%d fixed\033[0m" "$FIXED"
[ "$SKIPPED" -gt 0 ] && printf ", \033[90m%d skipped\033[0m" "$SKIPPED"
echo ""
[ "$RISKY" -eq 0 ] && echo "  Run with --risky to also apply breaking-change migrations"
echo ""
