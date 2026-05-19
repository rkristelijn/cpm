#!/usr/bin/env bash
# lint-md.sh — Run rumdl checks on Markdown files.
# Config: .config/rumdl.toml

source "$(dirname "$0")/../../../lib/shell/check.sh"
if [[ "${TRACE-0}" == "1" ]]; then set -o xtrace; fi

if ! command -v rumdl >/dev/null; then
  print_step "" "$(basename "$0" .sh)" skip "rumdl not installed"
  exit 0
fi

print_header "linting markdown..."
rumdl check .
