#!/usr/bin/env bash
# check-ts-audit.sh — Run npm/yarn/pnpm audit for known vulnerabilities.
# @see ADR-129
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/shell/init.sh" 2>/dev/null || true
cpm_check_enabled "ts-audit" || exit 0
set -o errexit
set -o nounset
set -o pipefail

if [[ ! -f "package.json" ]]; then exit 0; fi

if [[ -f "pnpm-lock.yaml" ]]; then
  pnpm audit --prod 2>&1 | tail -5
elif [[ -f "yarn.lock" ]]; then
  yarn audit --groups dependencies 2>&1 | tail -5
else
  npm audit --production --audit-level=moderate 2>&1 | tail -5
fi
