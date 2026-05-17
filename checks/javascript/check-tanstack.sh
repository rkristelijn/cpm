#!/usr/bin/env bash
# checks/javascript/check-tanstack.sh
# TanStack (React Query + Table) best practices
# Source: rkristelijn/opennext-prototype pattern (headless table + query cache)
# Pattern: service → useQuery hook → useTable hook → pure UI component
set -o nounset -o pipefail

REPO="${1:-.}"
[ -f "$REPO/package.json" ] || exit 0
grep -q "@tanstack/react-query\|@tanstack/react-table" "$REPO/package.json" 2>/dev/null || exit 0

FINDINGS=0
finding() { printf "  \033[33mwarning\033[0m  %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }
error()   { printf "  \033[31merror\033[0m    %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }

SRC="$REPO/src"
[ -d "$SRC" ] || SRC="$REPO/app"
[ -d "$SRC" ] || exit 0

HAS_QUERY=$(grep -q "@tanstack/react-query" "$REPO/package.json" 2>/dev/null && echo 1 || echo 0)
HAS_TABLE=$(grep -q "@tanstack/react-table" "$REPO/package.json" 2>/dev/null && echo 1 || echo 0)

# --- React Query checks ---
if [ "$HAS_QUERY" = "1" ]; then
  # 1. No QueryClientProvider
  if ! grep -rq "QueryClientProvider" "$SRC" --include="*.tsx" --include="*.ts" 2>/dev/null; then
    error "tanstack-no-provider" "No QueryClientProvider — queries won't work"
  fi

  # 2. useQuery in components instead of custom hooks
  QUERY_IN_COMPONENTS=$(find "$SRC" -name "*.tsx" -not -name "*hook*" -not -name "*use*" -not -path "*/hooks/*" \
    -exec grep -l "useQuery(\|useMutation(" {} \; 2>/dev/null | grep -v node_modules | head -1 || true)
  [ -n "$QUERY_IN_COMPONENTS" ] && \
    finding "tanstack-query-in-component" "useQuery/useMutation in component — extract to custom hook for reuse"

  # 3. Missing queryKey array (stale cache)
  BAD=$(grep -rn "useQuery({" "$SRC" --include="*.ts" --include="*.tsx" 2>/dev/null | \
    grep -v "queryKey" | grep -v node_modules | head -1 || true)
  [ -n "$BAD" ] && error "tanstack-no-querykey" "useQuery without queryKey — cache won't invalidate correctly"

  # 4. No invalidateQueries after mutation
  MUTATION_FILES=$(grep -rl "useMutation" "$SRC" --include="*.ts" --include="*.tsx" 2>/dev/null | grep -v node_modules || true)
  if [ -n "$MUTATION_FILES" ]; then
    NO_INVALIDATE=$(echo "$MUTATION_FILES" | xargs grep -L "invalidateQueries\|setQueryData" 2>/dev/null | head -1 || true)
    [ -n "$NO_INVALIDATE" ] && \
      finding "tanstack-no-invalidate" "useMutation without invalidateQueries — stale data after mutation"
  fi

  # 5. fetch() used alongside react-query (mixing patterns)
  FETCH_FILES=$(grep -rl "useEffect.*fetch(\|useEffect.*axios" "$SRC" --include="*.tsx" 2>/dev/null | grep -v node_modules | head -1 || true)
  [ -n "$FETCH_FILES" ] && \
    finding "tanstack-mixed-fetch" "useEffect+fetch alongside React Query — use useQuery for all data fetching"
fi

# --- React Table checks ---
if [ "$HAS_TABLE" = "1" ]; then
  # 6. Table state not synced with URL (pagination resets on navigation)
  TABLE_FILES=$(grep -rl "useReactTable" "$SRC" --include="*.ts" --include="*.tsx" 2>/dev/null | grep -v node_modules || true)
  if [ -n "$TABLE_FILES" ]; then
    NO_URL=$(echo "$TABLE_FILES" | xargs grep -L "useSearchParams\|useRouter\|router.push\|searchParams" 2>/dev/null | head -1 || true)
    [ -n "$NO_URL" ] && \
      finding "tanstack-table-no-url" "Table state not synced with URL — pagination/sort resets on navigation"
  fi

  # 7. manualPagination not set with server-side data
  if [ "$HAS_QUERY" = "1" ] && [ -n "$TABLE_FILES" ]; then
    NO_MANUAL=$(echo "$TABLE_FILES" | xargs grep -L "manualPagination\|manualSorting" 2>/dev/null | head -1 || true)
    [ -n "$NO_MANUAL" ] && \
      finding "tanstack-no-manual-pagination" "useReactTable with server data but no manualPagination — double sorting/pagination"
  fi
fi

[ "$FINDINGS" -eq 0 ] && printf "  \033[32m✓\033[0m  TanStack patterns: all checks passed\n"
exit 0
