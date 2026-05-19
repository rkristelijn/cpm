#!/usr/bin/env bash
# lint-yaml.sh — Run yamllint on YAML files.
# @see ADR-129

source "$(dirname "$0")/../../lib/shell/check.sh"
if [[ "${TRACE-0}" == "1" ]]; then set -o xtrace; fi

if ! command -v yamllint >/dev/null; then
  print_step "" "$(basename "$0" .sh)" skip "yamllint not installed"
  exit 0
fi

print_header "linting yaml..."
yamllint -c .config/yamllint.yml .github/
