#!/usr/bin/env bash
# search.sh — Fast search helper (rg with grep fallback).
#
# Usage: source this file, then use cpm_search instead of grep.
#   cpm_search "pattern" [path] [--include "*.ts"]
#
# Install rg for 10-100x faster searches:
#   brew install ripgrep    # macOS
#   apt install ripgrep     # Ubuntu/Debian
#   cargo install ripgrep   # any platform

# Detect best available search tool
if command -v rg >/dev/null 2>&1; then
  CPM_SEARCH="rg"
else
  CPM_SEARCH="grep"
fi

# cpm_search "pattern" [path] — search recursively
# Respects .gitignore automatically when using rg
cpm_search() {
  local pattern="$1"
  local path="${2:-.}"
  shift 2 2>/dev/null || shift 1 2>/dev/null || true

  if [[ "$CPM_SEARCH" == "rg" ]]; then
    rg -n "$pattern" "$path" "$@" 2>/dev/null
  else
    grep -rn "$pattern" "$path" "$@" 2>/dev/null
  fi
}

# cpm_search_files "pattern" [path] — return only filenames
cpm_search_files() {
  local pattern="$1"
  local path="${2:-.}"
  shift 2 2>/dev/null || shift 1 2>/dev/null || true

  if [[ "$CPM_SEARCH" == "rg" ]]; then
    rg -l "$pattern" "$path" "$@" 2>/dev/null
  else
    grep -rl "$pattern" "$path" "$@" 2>/dev/null
  fi
}

# cpm_search_count "pattern" [path] — return match count
cpm_search_count() {
  local pattern="$1"
  local path="${2:-.}"
  shift 2 2>/dev/null || shift 1 2>/dev/null || true

  if [[ "$CPM_SEARCH" == "rg" ]]; then
    rg -c "$pattern" "$path" "$@" 2>/dev/null | awk -F: '{s+=$2}END{print s+0}'
  else
    grep -rc "$pattern" "$path" "$@" 2>/dev/null | awk -F: '{s+=$2}END{print s+0}'
  fi
}
