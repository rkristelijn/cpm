#!/usr/bin/env bash
# check-lockfile.sh — Verify lockfiles exist for dependency managers.
# @see ADR-129
source "$(dirname "$0")/../../../lib/shell/check.sh"

check_lock() {
  local manifest="$1" lockfile="$2" manager="$3"
  if [[ -f "$manifest" && ! -f "$lockfile" ]]; then
    findings_add "error" "$manifest" "missing-lockfile" \
      "$manager manifest without lockfile — non-reproducible builds" \
      "Run $manager install to generate $lockfile" ""
  fi
}

check_lock "package.json" "package-lock.json" "npm"
[[ -f "package.json" && -f "yarn.lock" ]] || check_lock "package.json" "yarn.lock" "yarn"
check_lock "Cargo.toml" "Cargo.lock" "cargo"
check_lock "Gemfile" "Gemfile.lock" "bundler"
check_lock "composer.json" "composer.lock" "composer"
check_lock "requirements.txt" "requirements.txt" "pip" # pip has no separate lock
check_lock "go.mod" "go.sum" "go"
