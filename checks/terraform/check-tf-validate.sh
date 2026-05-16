#!/usr/bin/env bash
# check-tf-validate.sh — Run terraform validate for syntax errors.
set -o errexit
set -o nounset
set -o pipefail

if [[ ! -f "main.tf" ]]; then exit 0; fi

if ! command -v terraform >/dev/null 2>&1; then
  echo "  [skip] terraform not installed"
  exit 0
fi

terraform init -backend=false >/dev/null 2>&1 || true
terraform validate 2>&1
