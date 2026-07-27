#!/usr/bin/env bash
# scripts/pr-status.sh — Quick PR health check (CI, Sonar, CodeRabbit)
# Usage: bash scripts/pr-status.sh [PR_NUMBER]
set -euo pipefail

PR="${1:-84}"
REPO="rkristelijn/cpm"
PROJECT_KEY="rkristelijn_cpm"

echo "=== PR #$PR Status ==="
echo ""

# CI
echo "CI:"
gh run list --limit 2 --json name,status,conclusion --jq '.[] | "  \(.name): \(.conclusion // .status)"'
echo ""

# Sonar Quality Gate
echo "Sonar Quality Gate:"
curl -s "https://sonarcloud.io/api/qualitygates/project_status?projectKey=${PROJECT_KEY}&pullRequest=${PR}" | python3 -c "
import sys, json
data = json.load(sys.stdin)
ps = data.get('projectStatus', {})
status = ps.get('status', 'unknown')
icon = '✅' if status == 'OK' else '❌'
print(f'  {icon} {status}')
for c in ps.get('conditions', []):
    ci = '✅' if c['status'] == 'OK' else '❌'
    print(f'    {ci} {c[\"metricKey\"]}: {c[\"actualValue\"]} (need {c[\"errorThreshold\"]})')
" 2>/dev/null || echo "  ⚠ Could not fetch"
echo ""

# CodeRabbit threads
echo "CodeRabbit:"
gh api graphql -f query="
{
  repository(owner: \"$(echo $REPO | cut -d/ -f1)\", name: \"$(echo $REPO | cut -d/ -f2)\") {
    pullRequest(number: $PR) {
      reviewThreads(first: 100) {
        nodes { isResolved }
      }
    }
  }
}" --jq '
  .data.repository.pullRequest.reviewThreads.nodes |
  {total: length, resolved: (map(select(.isResolved)) | length), unresolved: (map(select(.isResolved | not)) | length)} |
  "  \(.resolved)/\(.total) resolved, \(.unresolved) open"
'
echo ""

# Summary
echo "---"
echo "Resolve all:  bash scripts/pr-resolve-threads.sh $PR"
echo "Sonar detail: https://sonarcloud.io/dashboard?id=${PROJECT_KEY}&pullRequest=${PR}"
echo "PR:           https://github.com/${REPO}/pull/${PR}"
