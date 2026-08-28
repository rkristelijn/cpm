#!/usr/bin/env bash
# helpers.sh — shared e2e test utilities
set -o errexit
set -o nounset
set -o pipefail

die() { echo "FAIL: $1"; exit 1; }

# Mock mode: all external tool calls succeed instantly
export CPM_MOCK="${CPM_MOCK:-1}"

# Resolve binary to absolute path (tests cd to temp dirs)
resolve_binary() {
  local bin="$1"
  if [[ "$bin" != /* ]]; then
    bin="$(cd "$(dirname "$bin")" && pwd)/$(basename "$bin")"
  fi
  echo "$bin"
}

assert_contains() {
  local output="$1" expected="$2" label="${3:-}"
  echo "$output" | grep -q "$expected" || die "${label:-expected '$expected' in output}"
}

assert_not_contains() {
  local output="$1" unexpected="$2" label="${3:-}"
  echo "$output" | grep -q "$unexpected" && die "${label:-unexpected '$unexpected' in output}" || true
}

assert_file_exists() {
  [[ -f "$1" ]] || die "expected file $1 to exist"
}

assert_exit_zero() {
  local cmd="$1"
  bash -c "$cmd" >/dev/null 2>&1 || die "expected exit 0 from: $cmd"
}

assert_exit_nonzero() {
  local cmd="$1"
  bash -c "$cmd" >/dev/null 2>&1 && die "expected non-zero exit from: $cmd" || true
}

check_binary() {
  [[ -x "$1" ]] || die "binary not found or not executable: $1"
}

# Create isolated temp project dir
setup_project() {
  local dir="/tmp/cpm-e2e-$$-$RANDOM"
  mkdir -p "$dir"
  echo "$dir"
}

teardown_project() {
  rm -rf "$1"
}
