#!/usr/bin/env bash
# checks/javascript/check-dry-patterns.sh
# @see ADR-129
# DRY (Don't Repeat Yourself) pattern detection for React/TypeScript.
# Goes beyond copy-paste: detects structural repetition that signals
# a missing abstraction (hook, component, service, util).
set -o nounset -o pipefail

REPO="${1:-.}"
[ -f "$REPO/package.json" ] || exit 0

FINDINGS=0
finding() { printf "  \033[33mwarning\033[0m  %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }

SRC=""
[ -d "$REPO/src" ] && SRC="$REPO/src"
[ -d "$REPO/app" ] && SRC="${SRC:+$SRC }$REPO/app"
[ -z "$SRC" ] && exit 0

# =============================================
# REPEATED FETCH PATTERNS (extract to service/hook)
# =============================================

# 1. Same API endpoint fetched in multiple files
if [ -d "$REPO/src" ]; then
  FETCH_URLS=$(grep -roh "fetch(['\"][^'\"]*['\"]" $SRC --include="*.ts" --include="*.tsx" 2>/dev/null | \
    grep -v node_modules | sort | uniq -c | sort -rn | awk '$1 > 1 {print $0}' | head -3 || true)
  if [ -n "$FETCH_URLS" ]; then
    finding "dry-repeated-fetch" "Same API endpoint fetched in multiple files — extract to service layer"
  fi
fi

# 2. Repeated fetch boilerplate (response.json(), error handling)
FETCH_FILES=$(grep -rl "\.then.*\.json()\|await.*\.json()" $SRC --include="*.ts" --include="*.tsx" 2>/dev/null | grep -v node_modules | wc -l)
FETCH_FILES=$(echo "$FETCH_FILES" | tr -d ' ')
[ "${FETCH_FILES:-0}" -gt 5 ] && \
  finding "dry-fetch-boilerplate" "$FETCH_FILES files with .json() boilerplate — create a typed fetchApi() wrapper"

# =============================================
# REPEATED UI PATTERNS (extract to component)
# =============================================

# 3. Same sx pattern repeated (should be a styled component or theme override)
if [ -d "$REPO/src" ]; then
  REPEATED_SX=$(grep -roh 'sx={{[^}]*}}' $SRC --include="*.tsx" 2>/dev/null | \
    grep -v node_modules | sort | uniq -c | sort -rn | awk '$1 > 3 && length($0) > 40 {print; exit}' || true)
  [ -n "$REPEATED_SX" ] && \
    finding "dry-repeated-sx" "Same sx={{...}} pattern used 4+ times — extract to styled() component or theme"
fi

# 4. Repeated loading/error UI pattern
LOADING_PATTERN=$(grep -rl "isLoading\|isPending" $SRC --include="*.tsx" 2>/dev/null | grep -v node_modules | wc -l)
LOADING_PATTERN=$(echo "$LOADING_PATTERN" | tr -d ' ')
[ "${LOADING_PATTERN:-0}" -gt 5 ] && {
  if ! grep -rq "LoadingState\|LoadingSkeleton\|QueryBoundary\|QueryWrapper" $SRC --include="*.tsx" 2>/dev/null; then
    finding "dry-loading-pattern" "$LOADING_PATTERN components handle loading state — create a <QueryBoundary> wrapper"
  fi
}

# 5. Repeated error display pattern
ERROR_DISPLAY=$(grep -rn "isError\|error &&\|error ?" $SRC --include="*.tsx" 2>/dev/null | grep -v node_modules | wc -l)
ERROR_DISPLAY=$(echo "$ERROR_DISPLAY" | tr -d ' ')
[ "${ERROR_DISPLAY:-0}" -gt 4 ] && {
  if ! grep -rq "ErrorDisplay\|ErrorMessage\|ErrorState\|QueryBoundary" $SRC --include="*.tsx" 2>/dev/null; then
    finding "dry-error-pattern" "$ERROR_DISPLAY components handle error display — create a shared <ErrorDisplay>"
  fi
}

# 6. Same Card/Paper layout used in multiple components
CARD_PATTERN=$(grep -rn "<Card\|<Paper" $SRC --include="*.tsx" 2>/dev/null | grep -v node_modules | wc -l)
CARD_PATTERN=$(echo "$CARD_PATTERN" | tr -d ' ')
[ "${CARD_PATTERN:-0}" -gt 8 ] && \
  finding "dry-card-pattern" "$CARD_PATTERN Card/Paper instances — create a <ContentCard> base component"

# =============================================
# REPEATED LOGIC PATTERNS (extract to hook/util)
# =============================================

# 7. Same useEffect pattern repeated (localStorage, eventListener, interval)
LOCALSTORAGE_EFFECTS=$(grep -rl "useEffect.*localStorage\|localStorage.*useEffect" $SRC --include="*.tsx" 2>/dev/null | grep -v node_modules | wc -l)
LOCALSTORAGE_EFFECTS=$(echo "$LOCALSTORAGE_EFFECTS" | tr -d ' ')
[ "${LOCALSTORAGE_EFFECTS:-0}" -gt 2 ] && \
  finding "dry-localstorage-effect" "$LOCALSTORAGE_EFFECTS components use localStorage in useEffect — create useLocalStorage() hook"

# 8. Repeated form validation logic
if grep -rl "\.length.*<\|\.length.*>\|\.trim()\|\.match(\|\.test(" $SRC --include="*.tsx" 2>/dev/null | grep -v node_modules | wc -l | tr -d ' ' | grep -qE "^[4-9]|^[1-9][0-9]"; then
  if ! grep -rq "zod\|yup\|useForm\|react-hook-form" $SRC --include="*.ts" --include="*.tsx" "$REPO/package.json" 2>/dev/null; then
    finding "dry-manual-validation" "Manual validation in 4+ files — use zod or react-hook-form with schema"
  fi
fi

# 9. Repeated sort/filter/search logic
FILTER_FILES=$(grep -rl "\.filter(\|\.sort(\|\.find(" $SRC --include="*.tsx" 2>/dev/null | grep -v node_modules | wc -l)
FILTER_FILES=$(echo "$FILTER_FILES" | tr -d ' ')
[ "${FILTER_FILES:-0}" -gt 6 ] && {
  if ! grep -rq "useMemo.*filter\|useFilter\|useSearch\|useSorted" $SRC --include="*.tsx" 2>/dev/null; then
    finding "dry-filter-logic" "$FILTER_FILES files with filter/sort logic — extract to useFilteredData() hook"
  fi
}

# 10. Repeated permission/auth checks
AUTH_CHECKS=$(grep -rn "role.*===\|isAdmin\|hasPermission\|canEdit\|canDelete" $SRC --include="*.tsx" --include="*.ts" 2>/dev/null | grep -v node_modules | wc -l)
AUTH_CHECKS=$(echo "$AUTH_CHECKS" | tr -d ' ')
[ "${AUTH_CHECKS:-0}" -gt 5 ] && {
  if ! grep -rq "usePermissions\|useAuth.*can\|PermissionGuard\|RoleGuard" $SRC --include="*.tsx" --include="*.ts" 2>/dev/null; then
    finding "dry-auth-checks" "$AUTH_CHECKS inline permission checks — create usePermissions() hook or <Guard> component"
  fi
}

# =============================================
# STRUCTURAL REPETITION (config-driven approach)
# =============================================

# 11. Multiple similar route handlers (should use generic handler factory)
ROUTES=$(find $SRC -name "route.ts" -o -name "route.tsx" 2>/dev/null | grep -v node_modules | wc -l)
ROUTES=$(echo "$ROUTES" | tr -d ' ')
[ "${ROUTES:-0}" -gt 5 ] && {
  # Check if they look similar (same structure)
  if find $SRC -name "route.ts" 2>/dev/null | head -6 | xargs wc -l 2>/dev/null | \
    awk 'NR>1 && !/total/{d=$1-prev; if(d<0)d=-d; if(d<10){sim++}} {prev=$1} END{if(sim>2)exit 0; exit 1}' 2>/dev/null; then
    finding "dry-similar-routes" "$ROUTES route handlers with similar structure — create a generic CRUD handler factory"
  fi
}

# 12. Repeated column definitions (TanStack Table)
if grep -rq "useReactTable\|createColumnHelper" $SRC --include="*.tsx" --include="*.ts" 2>/dev/null; then
  COL_FILES=$(grep -rl "columnHelper\|createColumnHelper\|ColumnDef" $SRC --include="*.tsx" --include="*.ts" 2>/dev/null | grep -v node_modules | wc -l)
  COL_FILES=$(echo "$COL_FILES" | tr -d ' ')
  [ "${COL_FILES:-0}" -gt 3 ] && \
    finding "dry-column-defs" "$COL_FILES files with column definitions — create reusable column builders"
fi

# 13. Repeated import blocks (same set of imports in many files)
if [ -d "$REPO/src" ]; then
  TOP_IMPORT=$(grep -rh "^import" $SRC --include="*.tsx" 2>/dev/null | grep -v node_modules | sort | uniq -c | sort -rn | head -1 | awk '{print $1}' || echo 0)
  [ "${TOP_IMPORT:-0}" -gt 10 ] && \
    finding "dry-repeated-imports" "Same import line in 10+ files — create a barrel or shared module"
fi

# 14. Repeated type definitions
if [ -d "$REPO/src" ]; then
  DUPE_TYPES=$(grep -rh "interface\|type.*=" $SRC --include="*.ts" --include="*.tsx" 2>/dev/null | \
    grep -v node_modules | grep -v "import\|export" | sort | uniq -c | sort -rn | awk '$1 > 1 && length($0) > 30 {print; exit}' || true)
  [ -n "$DUPE_TYPES" ] && \
    finding "dry-duplicate-types" "Same type/interface defined in multiple files — create shared types.ts"
fi

# 15. No shared components directory (everything inline)
if [ -d "$REPO/src" ]; then
  if [ ! -d "$REPO/src/components" ] && [ ! -d "$REPO/src/shared" ] && [ ! -d "$REPO/src/common" ]; then
    COMP_COUNT=$(find "$REPO/src" -name "*.tsx" -not -path "*/node_modules/*" 2>/dev/null | wc -l)
    COMP_COUNT=$(echo "$COMP_COUNT" | tr -d ' ')
    [ "${COMP_COUNT:-0}" -gt 5 ] && \
      finding "dry-no-shared-dir" "$COMP_COUNT .tsx files but no components/shared dir — extract reusable pieces"
  fi
fi

[ "$FINDINGS" -eq 0 ] && printf "  \033[32m✓\033[0m  DRY patterns: no structural repetition detected\n"
exit 0
