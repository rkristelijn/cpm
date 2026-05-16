#!/usr/bin/env bash
# check-lockfile.sh — Verify lockfiles exist for dependency managers.
#
# Missing lockfiles = non-reproducible builds. This checks that if you
# have a manifest (package.json, Cargo.toml, etc.), the lockfile exists too.
set -o errexit
set -o nounset
set -o pipefail

source "$(dirname "$0")/../../lib/shell/init.sh" 2>/dev/null || true

FAIL=0

check_lock() {
  local manifest="$1" lockfile="$2" manager="$3"
  if [[ -f "$manifest" && ! -f "$lockfile" ]]; then
    echo "  [fail] $manifest exists but $lockfile missing ($manager)"
    FAIL=1
  fi
}

check_lock "package.json" "package-lock.json" "npm"
# Also accept yarn.lock or pnpm-lock.yaml
if [[ -f "package.json" && ! -f "package-lock.json" && ! -f "yarn.lock" && ! -f "pnpm-lock.yaml" ]]; then
  echo "  [fail] package.json exists but no lockfile (npm/yarn/pnpm)"
  FAIL=1
fi
check_lock "Cargo.toml" "Cargo.lock" "cargo"
check_lock "composer.json" "composer.lock" "composer"
check_lock "Gemfile" "Gemfile.lock" "bundler"
check_lock "go.mod" "go.sum" "go"
check_lock "requirements.txt" "requirements.txt" "pip"  # pip has no separate lock
check_lock "pyproject.toml" "poetry.lock" "poetry"

if [[ $FAIL -eq 0 ]]; then
  echo "  ✓ All lockfiles present"
fi
exit $FAIL
