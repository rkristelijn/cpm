#!/usr/bin/env bash
# check-tf-security.sh — Run tfsec/trivy for Terraform security issues.
# @see ADR-129
set -o errexit
set -o nounset
set -o pipefail

if [[ ! -f "main.tf" && ! -f "terragrunt.hcl" ]]; then exit 0; fi

if command -v trivy >/dev/null 2>&1; then
  trivy config --severity HIGH,CRITICAL . 2>&1
elif command -v tfsec >/dev/null 2>&1; then
  tfsec . --minimum-severity HIGH 2>&1
else
  echo "  [skip] trivy/tfsec not installed"
  exit 0
fi
