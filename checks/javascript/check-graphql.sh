#!/usr/bin/env bash
# checks/javascript/check-graphql.sh
# GraphQL best practices from agility/frontend-apps patterns
# Pattern: codegen → typed hooks → no raw strings
set -o nounset -o pipefail

REPO="${1:-.}"
[ -f "$REPO/package.json" ] || exit 0
grep -q "graphql\|@graphql-codegen\|@apollo/client\|urql" "$REPO/package.json" 2>/dev/null || exit 0

FINDINGS=0
finding() { printf "  \033[33mwarning\033[0m  %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }
error()   { printf "  \033[31merror\033[0m    %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }

SRC="$REPO/src"
[ -d "$SRC" ] || SRC="$REPO/apps"
[ -d "$SRC" ] || exit 0

# --- 1. No codegen (hand-writing types for GraphQL) ---
if ! grep -q "@graphql-codegen" "$REPO/package.json" 2>/dev/null; then
  finding "graphql-no-codegen" "No @graphql-codegen — hand-writing types for GraphQL is error-prone"
fi

# --- 2. Raw gql strings in components (should be in .graphql files or codegen) ---
BAD=$(find "$SRC" -name "*.tsx" -not -path "*/node_modules/*" \
  -exec grep -l "gql\`\|graphql\`" {} \; 2>/dev/null | grep -v "codegen\|generated\|__generated" | head -1 || true)
[ -n "$BAD" ] && finding "graphql-inline-query" "Inline gql template in component — use .graphql files with codegen"

# --- 3. No typed document nodes (using raw strings instead of TypedDocumentNode) ---
if grep -q "@graphql-codegen" "$REPO/package.json" 2>/dev/null; then
  if ! grep -rq "TypedDocumentNode\|typed-document-node" "$SRC" --include="*.ts" --include="*.tsx" 2>/dev/null; then
    finding "graphql-no-typed-docs" "No TypedDocumentNode usage — codegen types not connected to queries"
  fi
fi

# --- 4. Direct fetch for GraphQL (should use client wrapper) ---
BAD=$(find "$SRC" -name "*.ts" -name "*.tsx" -not -path "*/node_modules/*" \
  -exec grep -l "fetch.*graphql\|fetch.*\/graphql" {} \; 2>/dev/null | head -1 || true)
[ -n "$BAD" ] && finding "graphql-raw-fetch" "Raw fetch to /graphql — use a typed client (graphql-request, Apollo, urql)"

# --- 5. No error handling on queries ---
QUERY_FILES=$(grep -rl "useQuery\|useGraphqlQuery" "$SRC" --include="*.tsx" 2>/dev/null | grep -v node_modules | head -5 || true)
if [ -n "$QUERY_FILES" ]; then
  NO_ERROR=$(echo "$QUERY_FILES" | xargs grep -L "isError\|error\|onError" 2>/dev/null | head -1 || true)
  [ -n "$NO_ERROR" ] && finding "graphql-no-error-handling" "Query used without error handling — user sees nothing on failure"
fi

[ "$FINDINGS" -eq 0 ] && printf "  \033[32m✓\033[0m  GraphQL patterns: all checks passed\n"
exit 0
