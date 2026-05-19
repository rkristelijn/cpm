#!/usr/bin/env bash
# check-php-audit.sh — Run composer audit for known vulnerabilities.
# @see ADR-129
set -o errexit
set -o nounset
set -o pipefail

if [[ ! -f "composer.json" ]]; then exit 0; fi

if ! command -v composer >/dev/null 2>&1; then
  echo "  [skip] composer not installed"
  exit 0
fi

composer audit 2>&1
