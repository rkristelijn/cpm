#!/usr/bin/env bash
# scripts/ci/build-and-test.sh — Shared build + test steps for CI and release.
# Usage: bash scripts/ci/build-and-test.sh [--skip-self-check]
# @see https://github.com/rkristelijn/cpm/issues/93
set -o errexit
set -o nounset
set -o pipefail

SKIP_SELF_CHECK="${1:-}"
OS="${RUNNER_OS:-$(uname)}"
IS_WINDOWS=false
[[ "$OS" == "Windows" || "$OS" == "MINGW"* || "$OS" == "MSYS"* ]] && IS_WINDOWS=true

echo "==> Build cpm"
make build

if ! $IS_WINDOWS; then
  echo ""
  echo "==> Build rule-scan"
  make build/rule-scan

  echo ""
  echo "==> Rule engine tests"
  make build/test_rules build/test_tokenizer build/test_import_graph
  ./build/test_rules
  ./build/test_tokenizer
  ./build/test_import_graph

  echo ""
  echo "==> Smoke test"
  ./cpm help
  ./cpm version
  ./cpm score
  ./cpm scan . --depth 1
  ./cpm findings --learn | head -20
  ./cpm findings --compliance OWASP | head -10

  if [[ "$SKIP_SELF_CHECK" != "--skip-self-check" && "$OS" == "Linux" ]]; then
    echo ""
    echo "==> Self-check (cpm on cpm)"
    sudo apt-get install -y yamllint cppcheck shellcheck 2>/dev/null || true
    ./cpm check || true
    ./cpm scan . --depth 1
    ./cpm findings
    ./build/rule-scan --exit-zero || true
  fi
else
  echo ""
  echo "==> Smoke test (Windows)"
  ./cpm.exe help || cpm.exe help
  ./cpm.exe version || cpm.exe version
  ./cpm.exe score || cpm.exe score
fi

echo ""
echo "==> All checks passed"
