#!/usr/bin/env bash
# fixes/autofix.sh — Auto-fix safe findings, warn on risky ones
# Usage: bash fixes/autofix.sh [path]
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/shell/init.sh" 2>/dev/null || true
set -o nounset -o pipefail

REPO="${1:-.}"
FIXED=0
WARNED=0

fix() { printf "  \033[32m✓ fixed\033[0m  %-30s %s\n" "$1" "$2"; FIXED=$((FIXED+1)); }
risky() { printf "  \033[33m⚠ risky\033[0m  %-30s %s\n" "$1" "$2"; WARNED=$((WARNED+1)); }
skip() { printf "  \033[90m· skip\033[0m   %-30s %s\n" "$1" "$2"; }

echo ""
echo "  cpm fix — auto-fixing safe issues"
echo ""

# =============================================================================
# SAFE FIXES (low risk, won't break anything)
# =============================================================================

# --- .nvmrc ---
if [ ! -f "$REPO/.nvmrc" ] && [ ! -f "$REPO/.node-version" ]; then
  if command -v node >/dev/null 2>&1; then
    node -v | tr -d 'v' > "$REPO/.nvmrc"
    fix "no-nvmrc" "Created .nvmrc with $(cat "$REPO/.nvmrc")"
  fi
fi

# --- .gitignore ---
if [ ! -f "$REPO/.gitignore" ] && [ -f "$REPO/package.json" ]; then
  cat > "$REPO/.gitignore" << 'EOF'
node_modules/
dist/
build/
.next/
coverage/
*.log
.env
.env.local
EOF
  fix "no-gitignore" "Created .gitignore with standard entries"
fi

# --- LICENSE file ---
if [ ! -f "$REPO/LICENSE" ] && [ ! -f "$REPO/LICENSE.md" ]; then
  if [ -f "$REPO/package.json" ] && grep -q '"license".*"MIT"' "$REPO/package.json" 2>/dev/null; then
    YEAR=$(date +%Y)
    AUTHOR=$(grep -oE '"author"[^,}]*' "$REPO/package.json" 2>/dev/null | head -1 | sed 's/.*: *"//;s/".*//' || echo "")
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
    fix "no-license-file" "Created MIT LICENSE file"
  fi
fi

# --- package.json: repository field ---
if [ -f "$REPO/package.json" ] && ! grep -q '"repository"' "$REPO/package.json" 2>/dev/null; then
  REMOTE=$(cd "$REPO" && git remote get-url origin 2>/dev/null || true)
  if [ -n "$REMOTE" ]; then
    (cd "$REPO" && npm pkg set repository.type=git repository.url="$REMOTE" 2>/dev/null)
    fix "no-repository" "Set repository to $REMOTE"
  fi
fi

# --- package.json: engines field ---
if [ -f "$REPO/package.json" ] && ! grep -q '"engines"' "$REPO/package.json" 2>/dev/null; then
  if [ -f "$REPO/.nvmrc" ]; then
    MAJOR=$(cut -d. -f1 "$REPO/.nvmrc")
    (cd "$REPO" && npm pkg set engines.node=">=$MAJOR" 2>/dev/null)
    fix "no-engines" "Set engines.node to >=$MAJOR"
  fi
fi

# --- .prettierrc ---
if [ -f "$REPO/package.json" ]; then
  if [ ! -f "$REPO/.prettierrc" ] && [ ! -f "$REPO/.prettierrc.json" ] && [ ! -f "$REPO/prettier.config.js" ]; then
    if [ ! -f "$REPO/biome.json" ] && [ ! -f "$REPO/biome.jsonc" ]; then
      echo '{}' > "$REPO/.prettierrc"
      fix "no-formatter" "Created .prettierrc (empty = prettier defaults)"
    fi
  fi
fi

# --- .npmrc with save-exact ---
if [ -f "$REPO/package.json" ] && [ ! -f "$REPO/.npmrc" ]; then
  echo "save-exact=true" > "$REPO/.npmrc"
  fix "no-npmrc" "Created .npmrc with save-exact=true"
fi

# =============================================================================
# RISKY FIXES (may break things — show warning, apply only with --force)
# =============================================================================

FORCE=false
[[ "${2:-}" == "--force" ]] && FORCE=true

# --- tsconfig: strict mode ---
if [ -f "$REPO/tsconfig.json" ] && ! grep -q '"strict".*true' "$REPO/tsconfig.json" 2>/dev/null; then
  if [ "$FORCE" = true ]; then
    sed -i'' 's/"compilerOptions".*{/"compilerOptions": {\n    "strict": true,/' "$REPO/tsconfig.json" 2>/dev/null
    fix "tsconfig-no-strict" "Enabled strict mode (--force)"
  else
    risky "tsconfig-no-strict" "Enable strict: true — may surface type errors. Run with --force"
  fi
fi

# --- tsconfig: forceConsistentCasingInFileNames ---
if [ -f "$REPO/tsconfig.json" ] && ! grep -q '"forceConsistentCasingInFileNames"' "$REPO/tsconfig.json" 2>/dev/null; then
  if [ "$FORCE" = true ]; then
    sed -i'' 's/"strict".*true/"strict": true,\n    "forceConsistentCasingInFileNames": true/' "$REPO/tsconfig.json" 2>/dev/null
    fix "tsconfig-no-case-check" "Enabled forceConsistentCasingInFileNames (--force)"
  else
    risky "tsconfig-no-case-check" "Enable forceConsistentCasingInFileNames — may break imports on case-insensitive OS"
  fi
fi

# --- tsconfig: esModuleInterop ---
if [ -f "$REPO/tsconfig.json" ] && ! grep -q '"esModuleInterop".*true' "$REPO/tsconfig.json" 2>/dev/null; then
  if [ "$FORCE" = true ]; then
    risky "tsconfig-no-esmoduleinterop" "Enable esModuleInterop — may change import behavior"
  else
    risky "tsconfig-no-esmoduleinterop" "Enable esModuleInterop: true — may change CJS import behavior"
  fi
fi

# --- pin dependencies (remove ^ and ~) ---
if [ -f "$REPO/package.json" ] && grep -qE '"\^|"~' "$REPO/package.json" 2>/dev/null; then
  if [ "$FORCE" = true ]; then
    sed -i'' 's/"\^/"/g; s/"~/"/g' "$REPO/package.json" 2>/dev/null
    fix "unpinned-deps" "Removed ^ and ~ from all dependency versions (--force)"
  else
    risky "unpinned-deps" "Pin all deps (remove ^/~) — run with --force or: npm pkg fix"
  fi
fi

# =============================================================================
# Summary
# =============================================================================

echo ""
if [ "$FIXED" -eq 0 ] && [ "$WARNED" -eq 0 ]; then
  echo "  Nothing to fix — all good! ✓"
else
  echo "  $FIXED fixed, $WARNED risky (use --force to apply risky fixes)"
fi
echo ""
