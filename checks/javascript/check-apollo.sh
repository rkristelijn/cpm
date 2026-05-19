#!/usr/bin/env bash
# checks/javascript/check-apollo.sh
# @see ADR-129
# Apollo Client best practices: error handling, loading state, fetchPolicy, TypedDocumentNode
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/shell/init.sh" 2>/dev/null || true
cpm_check_enabled "js-apollo" || exit 0
set -o nounset -o pipefail

REPO="${1:-.}"
[ -f "$REPO/package.json" ] && grep -q '@apollo/client' "$REPO/package.json" || exit 0

FINDINGS=0
finding() { printf "  \033[33mwarning\033[0m  %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }

# Find source dirs
SRC=""
[ -d "$REPO/src" ] && SRC="$REPO/src/"
[ -d "$REPO/apps" ] && SRC="$SRC $REPO/apps/"
[ -z "$SRC" ] && exit 0

# --- useQuery without error handling ---
if cpm_grep -rn "useQuery(" $SRC 2>/dev/null | grep -v "error\s*," | head -1 | grep -q .; then
  finding "apollo-no-error" "useQuery without error destructuring — crashes silently on network/GraphQL errors"
fi

# --- useQuery without loading state ---
if cpm_grep -rn "useQuery(" $SRC 2>/dev/null | grep -v "loading\s*," | head -1 | grep -q .; then
  finding "apollo-no-loading" "useQuery without loading state — UI shows data before it's ready"
fi

# --- fetchPolicy not set (defaults to cache-first, causes stale data) ---
if cpm_grep -rn "useQuery(" $SRC 2>/dev/null | grep -v "fetchPolicy" | head -1 | grep -q .; then
  finding "apollo-no-fetchpolicy" "useQuery without fetchPolicy — defaults to cache-first, may show stale data"
fi

# --- No TypedDocumentNode (untyped queries) ---
if cpm_grep -rn "gql|useLazyQuery|useQuery" $SRC 2>/dev/null | grep -v "TypedDocumentNode\|graphql-tag" | head -1 | grep -q .; then
  finding "apollo-untyped" "Query without TypedDocumentNode — no compile-time type safety"
fi

# --- Polling without cleanup (pollInterval without stopPolling) ---
if cpm_grep -rn "pollInterval" $SRC 2>/dev/null | head -1 | grep -q .; then
  POLL_FILES=$(cpm_grep -rl "pollInterval" $SRC 2>/dev/null || true)
  if [ -n "$POLL_FILES" ]; then
    NO_CLEANUP=$(echo "$POLL_FILES" | xargs grep -L "stopPolling" 2>/dev/null | head -1 || true)
    [ -n "$NO_CLEANUP" ] && finding "apollo-poll-no-cleanup" "pollInterval without stopPolling — polling continues after unmount"
  fi
fi

# --- Direct cache.writeQuery without optimistic updates ---
if cpm_grep -rn "cache\.writeQuery\|cache\.writeData" $SRC 2>/dev/null | grep -v "optimisticResponse\|optimistic" | head -1 | grep -q .; then
  finding "apollo-cache-write" "Direct cache.writeQuery without optimistic response — UI flash on refetch"
fi

# --- No ApolloProvider in app root ---
if cpm_grep -rn "ApolloProvider" $SRC 2>/dev/null | head -1 | grep -q .; then
  : # ApolloProvider found
else
  finding "apollo-no-provider" "No ApolloProvider found — GraphQL queries will not work"
fi

[ "$FINDINGS" -eq 0 ] && echo "  ✓ Apollo patterns OK"
exit 0