#!/usr/bin/env bash
# check-tf-lint.sh — Run tflint on Terraform/Terragrunt projects.
set -o errexit
set -o nounset
set -o pipefail

if [[ ! -f "main.tf" && ! -f "terragrunt.hcl" ]]; then exit 0; fi

if ! command -v tflint >/dev/null 2>&1; then
  echo "  [skip] tflint not installed"
  exit 0
fi

tflint --init >/dev/null 2>&1 || true
tflint 2>&1
