#!/usr/bin/env bash
# scripts/dev/demo.sh — reproducible demo scenes for VHS tapes
# Usage: bash scripts/dev/demo.sh [scene]
set -o errexit -o nounset -o pipefail

GREEN='\033[32m'
RESET='\033[0m'

CPM="$(cd "$(dirname "$0")/../.." && pwd)/cpm"

comment() { echo -e "${GREEN}# $*${RESET}"; }

setup_demo_repos() {
  local base="$1"
  rm -rf "$base" # cpm:ignore rm-rf-unquoted-var (cleanup in demo script)
  mkdir -p "$base"

  # 1. Messy project — many errors
  local messy="$base/legacy-api"
  mkdir -p "$messy/.git" "$messy/src"
  echo '{"name":"legacy-api","dependencies":{"express":"^3.0.0","lodash":"^3.0.0"}}' >"$messy/package.json"
  echo "14" >"$messy/.nvmrc"
  # No README, no LICENSE, no lockfile, no CI, no tests

  # 2. Normal project — some warnings
  local normal="$base/user-service"
  mkdir -p "$normal/.git" "$normal/src" "$normal/.github/workflows"
  echo '{"name":"user-service","description":"User management","repository":"github:x/y","scripts":{"test":"jest"},"dependencies":{"express":"^4.18.0","typescript":"^5.0.0"}}' >"$normal/package.json"
  echo "20" >"$normal/.nvmrc"
  echo "# user-service" >"$normal/README.md"
  touch "$normal/LICENSE"
  touch "$normal/package-lock.json"
  touch "$normal/.github/workflows/ci.yml"
  # Has basics but unpinned deps, no CONTRIBUTING

  # 3. Mature project — clean
  local mature="$base/payment-gateway"
  mkdir -p "$mature/.git" "$mature/src" "$mature/.github/workflows" "$mature/.kiro"
  echo '{"name":"payment-gateway","description":"Payment processing","repository":"github:x/y","scripts":{"test":"jest","lint":"eslint ."},"dependencies":{"stripe":"4.0.0","fastify":"4.25.0"}}' >"$mature/package.json"
  echo "22" >"$mature/.nvmrc"
  printf "# payment-gateway\n\n## Install\n\n## Test\n\n## Deploy\n\n## Contributing\n" >"$mature/README.md"
  touch "$mature/LICENSE"
  touch "$mature/CONTRIBUTING.md"
  touch "$mature/package-lock.json"
  touch "$mature/.github/workflows/ci.yml"
  echo '[project]\nname = "payment-gateway"' >"$mature/cpm.toml"
}

scene_scan() {
  local base
  base=$(mktemp -d)
  trap "rm -rf $base" EXIT # cpm:ignore rm-rf-unquoted-var (cleanup in demo script)

  setup_demo_repos "$base"

  comment "Scan all repos for quality issues"
  echo ""
  "$CPM" scan "$base" --depth 1 2>&1 | grep -v "^  Scanning\|^  Findings:\|^  Query:"
}

scene_findings() {
  local base
  base=$(mktemp -d)
  trap "rm -rf $base" EXIT # cpm:ignore rm-rf-unquoted-var (cleanup in demo script)

  setup_demo_repos "$base"

  # Run scan first to populate findings
  "$CPM" scan "$base" --depth 1 >/dev/null 2>&1

  comment "Query findings for the worst repo"
  echo ""
  "$CPM" findings legacy-api 2>&1 || true
}

scene_help() {
  "$CPM" help
}

case "${1:-all}" in
scan) scene_scan ;;
findings) scene_findings ;;
help) scene_help ;;
all)
  echo "=== scene: scan ===" && scene_scan && echo ""
  echo "=== scene: findings ===" && scene_findings && echo ""
  echo "=== scene: help ===" && scene_help
  ;;
*)
  echo "Usage: $0 [scan|findings|help|all]"
  exit 1
  ;;
esac
