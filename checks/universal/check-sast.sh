#!/usr/bin/env bash
# check-sast.sh — Run available SAST tools (any language).
#
# Orchestrates whichever tools are installed:
#   semgrep    — pattern-based SAST (1000+ rules, all languages)
#   trivy      — vulnerabilities in deps, containers, IaC
#   osv-scanner — Google's OSV vulnerability database
#   grype      — SBOM-based vulnerability scanner
#   checkov    — IaC security (Terraform, K8s, Docker)
#
# Install:
#   brew install semgrep trivy osv-scanner grype checkov
set -o errexit
set -o nounset
set -o pipefail

FAIL=0
RAN=0

# semgrep — works on any language with auto-config
if command -v semgrep >/dev/null 2>&1; then
  echo "  [sast] semgrep..."
  if ! semgrep scan --config auto --error --quiet 2>&1; then
    FAIL=1
  fi
  RAN=$((RAN + 1))
fi

# trivy — filesystem scan for vulnerabilities
if command -v trivy >/dev/null 2>&1; then
  echo "  [sast] trivy fs..."
  if ! trivy fs --severity HIGH,CRITICAL --exit-code 1 --quiet . 2>&1; then
    FAIL=1
  fi
  RAN=$((RAN + 1))
fi

# osv-scanner — lockfile-based vulnerability check
if command -v osv-scanner >/dev/null 2>&1; then
  echo "  [sast] osv-scanner..."
  if ! osv-scanner scan --lockfile-only . 2>&1 | tail -5; then
    FAIL=1
  fi
  RAN=$((RAN + 1))
fi

# grype — SBOM vulnerability scan
if command -v grype >/dev/null 2>&1; then
  echo "  [sast] grype..."
  if ! grype dir:. --only-fixed --fail-on high 2>&1 | tail -5; then
    FAIL=1
  fi
  RAN=$((RAN + 1))
fi

# checkov — IaC security (only if terraform/k8s/docker files exist)
if command -v checkov >/dev/null 2>&1; then
  if [[ -f "main.tf" || -f "Dockerfile" || -f "docker-compose.yml" ]]; then
    echo "  [sast] checkov..."
    if ! checkov -d . --quiet --compact 2>&1 | tail -5; then
      FAIL=1
    fi
    RAN=$((RAN + 1))
  fi
fi

if [[ $RAN -eq 0 ]]; then
  echo "  [skip] No SAST tools installed. Install:"
  echo "    brew install semgrep trivy osv-scanner grype checkov"
  exit 0
fi

echo "  $RAN SAST tool(s) ran"
exit $FAIL
