#!/usr/bin/env bash
# scripts/pr-resolve-threads.sh — Resolve all CodeRabbit threads on a PR
# Usage: bash scripts/pr-resolve-threads.sh [PR_NUMBER]
set -euo pipefail

PR="${1:-84}"
REPO_OWNER="rkristelijn"
REPO_NAME="cpm"

echo "Resolving all open threads on PR #$PR..."

THREAD_IDS=$(gh api graphql -f query="
{
  repository(owner: \"$REPO_OWNER\", name: \"$REPO_NAME\") {
    pullRequest(number: $PR) {
      reviewThreads(first: 100) {
        nodes { id isResolved }
      }
    }
  }
}" --jq '.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved == false) | .id')

COUNT=0
for thread_id in $THREAD_IDS; do
  gh api graphql -f query="mutation { resolveReviewThread(input: {threadId: \"$thread_id\"}) { thread { isResolved } } }" --jq '.data.resolveReviewThread.thread.isResolved' >/dev/null
  COUNT=$((COUNT + 1))
done

echo "✅ Resolved $COUNT threads"
