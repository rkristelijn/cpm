#!/usr/bin/env bash
# wait-pipeline.sh — Poll CI pipeline until complete. Exit 0=green, 1=red.
# Throttles: checks every 15s, max 10 minutes.
# Usage: make wait (or: bash scripts/gh/wait-pipeline.sh)
set -o nounset
set -o pipefail

INTERVAL=15
MAX_WAIT=600
ELAPSED=0

BRANCH=$(git branch --show-current)
echo "  Waiting for pipeline on $BRANCH..."

while ((ELAPSED < MAX_WAIT)); do
  RUN_ID=$(gh run list --branch "$BRANCH" --limit 1 --json databaseId,status,conclusion -q '.[0]' 2>/dev/null)
  STATUS=$(echo "$RUN_ID" | python3 -c "import sys,json;d=json.load(sys.stdin);print(d.get('status',''))" 2>/dev/null)
  CONCLUSION=$(echo "$RUN_ID" | python3 -c "import sys,json;d=json.load(sys.stdin);print(d.get('conclusion',''))" 2>/dev/null)

  if [[ "$STATUS" == "completed" ]]; then
    if [[ "$CONCLUSION" == "success" ]]; then
      echo "  ✓ Pipeline green (${ELAPSED}s)"
      exit 0
    else
      echo "  ✗ Pipeline failed: $CONCLUSION (${ELAPSED}s)"
      echo "    Run: make status (for details)"
      exit 1
    fi
  fi

  printf "  … %ds (status: %s)\r" "$ELAPSED" "$STATUS"
  sleep "$INTERVAL"
  ELAPSED=$((ELAPSED + INTERVAL))
done

echo "  ⚠ Timeout after ${MAX_WAIT}s — check manually: make status"
exit 2
