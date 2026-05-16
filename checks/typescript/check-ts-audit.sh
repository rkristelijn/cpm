#!/usr/bin/env bash
# check-ts-audit.sh — Run npm/yarn/pnpm audit for known vulnerabilities.
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
