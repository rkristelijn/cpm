#!/usr/bin/env bash
# init.sh — Single entry point for CPM shell integration.
#
# Scripts source this ONE file. It handles:
#   1. Load ui.sh (colors, print_*, spinner, progress)
#   2. Load timer.sh (timing + trend)
#   3. Load config.sh (cpm.toml → env vars)
#   4. Fallback: if any module is missing, define no-op stubs
#
# Usage (in any script):
#   source lib/cpm/shell/init.sh 2>/dev/null || true
#
# That's it. One line. No inline fallback blocks.
#
# @see docs/adrs/adr-121-cpm-quality-layer.md

_CPM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load modules (order matters: ui first, timer depends on ui)
source "$_CPM_DIR/ui.sh" 2>/dev/null || {
  # Minimal fallback if ui.sh is broken/missing
  print_step() { echo "  $2 $3${4:+ $4}"; }
  print_header() { echo "==> $1"; }
  print_error() { echo "  ERROR: $1"; }
  print_warning() { echo "  WARNING: $1"; }
  print_summary() { echo "  $1"; }
  spinner_start() { :; }
  spinner_stop() { :; }
  progress_bar() { :; }
  timer_start() { :; }
  timer_stop() { echo "  $1 $2"; }
}

# Load config (non-fatal if missing)
source "$_CPM_DIR/config.sh" 2>/dev/null || true

# Global exclude patterns — used by all checks
# grep: use $GREP_EXCLUDE in grep commands
# find: use $FIND_PRUNE in find commands
GREP_EXCLUDE="--exclude-dir=node_modules --exclude-dir=.next --exclude-dir=dist --exclude-dir=build --exclude-dir=.git --exclude-dir=coverage --exclude-dir=__pycache__ --exclude-dir=.cache --exclude-dir=vendor --exclude-dir=target --exclude-dir=out"
FIND_PRUNE='-not -path "*/node_modules/*" -not -path "*/.next/*" -not -path "*/dist/*" -not -path "*/build/*" -not -path "*/.git/*" -not -path "*/coverage/*" -not -path "*/__pycache__/*" -not -path "*/.cache/*" -not -path "*/vendor/*" -not -path "*/target/*" -not -path "*/out/*"'

# Helper: grep recursively with standard excludes
# Usage: cpm_grep [grep-flags] "pattern" path [path...]
# Filters out non-existent paths to avoid "No such file or directory" errors
cpm_grep() {
  local flags=() paths=()
  for arg in "$@"; do
    if [[ "$arg" == -* ]]; then
      flags+=("$arg")
    else
      paths+=("$arg")
    fi
  done
  # Separate pattern (first non-flag) from paths (rest)
  local pattern="${paths[0]}"
  local valid_paths=()
  for p in "${paths[@]:1}"; do
    [ -e "$p" ] && valid_paths+=("$p")
  done
  [ ${#valid_paths[@]} -eq 0 ] && return 1
  grep $GREP_EXCLUDE "${flags[@]}" "$pattern" "${valid_paths[@]}"
}

# Helper: check if a check is enabled in cpm.toml
# Usage: cpm_check_enabled "nextjs-performance" || exit 0
# Maps check name to CPM_CHECKS_<NAME> env var (dashes → underscores)
cpm_check_enabled() {
  local name="${1//-/_}"
  local var="CPM_CHECKS_${name^^}"
  local val="${!var:-}"
  [[ "$val" == "false" ]] && return 1
  return 0
}

