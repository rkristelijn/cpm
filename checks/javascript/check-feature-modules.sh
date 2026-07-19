#!/usr/bin/env bash
# checks/javascript/check-feature-modules.sh
# @see ADR-129
# Detects when a flat components/ folder should be split into feature modules.
# Threshold: 8+ files in components/ without subdirectories = smell.
set -o nounset -o pipefail

REPO="${1:-.}"
[ -f "$REPO/package.json" ] || exit 0

FINDINGS=0
finding() { printf "  \033[33mwarning\033[0m  %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }

SRC=""
[ -d "$REPO/src" ] && SRC="$REPO/src"
[ -z "$SRC" ] && exit 0

# 1. Flat components/ with too many files
COMP_DIR="$SRC/components"
if [ -d "$COMP_DIR" ]; then
  FILE_COUNT=$(find "$COMP_DIR" -maxdepth 1 -name "*.tsx" -o -name "*.ts" 2>/dev/null | grep -v index | wc -l | tr -d ' ')
  SUBDIR_COUNT=$(find "$COMP_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
  if [ "${FILE_COUNT:-0}" -gt 8 ] && [ "${SUBDIR_COUNT:-0}" -lt 2 ]; then
    finding "flat-components" "$FILE_COUNT files in components/ without subdirs — split into feature modules"
  fi
fi

# 2. No features/ directory when project is large enough
if [ ! -d "$SRC/features" ] && [ ! -d "$SRC/modules" ]; then
  TOTAL_TSX=$(find "$SRC" -name "*.tsx" -not -path "*/node_modules/*" 2>/dev/null | wc -l | tr -d ' ')
  if [ "${TOTAL_TSX:-0}" -gt 12 ]; then
    finding "no-feature-modules" "$TOTAL_TSX .tsx files but no features/ dir — group by domain for better isolation"
  fi
fi

# 3. Page component importing too many things (should delegate to feature)
if [ -d "$SRC/app" ]; then
  for page in $(find "$SRC/app" -name "page.tsx" 2>/dev/null); do
    IMPORTS=$(grep -c "^import" "$page" 2>/dev/null || echo 0)
    if [ "${IMPORTS:-0}" -gt 8 ]; then
      finding "page-too-many-imports" "$(basename "$(dirname "$page")")/page.tsx has $IMPORTS imports — delegate to feature module"
    fi
  done
fi

# 4. Shared lib importing from features (dependency inversion violation)
if [ -d "$SRC/shared" ] && [ -d "$SRC/features" ]; then
  VIOLATION=$(grep -rl "@/features\|../features" "$SRC/shared" --include="*.ts" --include="*.tsx" 2>/dev/null | head -1 || true)
  [ -n "$VIOLATION" ] && finding "shared-imports-feature" "shared/ imports from features/ — dependency inversion violation"
fi

# 5. Feature importing from another feature (should go through shared/)
if [ -d "$SRC/features" ]; then
  for feat_dir in "$SRC/features"/*/; do
    [ -d "$feat_dir" ] || continue
    FEAT_NAME=$(basename "$feat_dir")
    CROSS=$(grep -rl "@/features/" "$feat_dir" --include="*.ts" --include="*.tsx" 2>/dev/null | \
      xargs grep -l "@/features/[^${FEAT_NAME}]" 2>/dev/null | head -1 || true)
    [ -n "$CROSS" ] && finding "cross-feature-import" "$(basename "$CROSS") imports from another feature — use shared/ instead" && break
  done
fi

[ "$FINDINGS" -eq 0 ] && printf "  \033[32m✓\033[0m  Feature modules: well structured\n"
exit 0
