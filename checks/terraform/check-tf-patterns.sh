#!/usr/bin/env bash
# check-tf-patterns.sh — Validate Terraform patterns (remote state, state locking, provider pins, etc.)
set -o errexit
set -o nounset
set -o pipefail

# Pattern checks for Terraform quality and operational excellence

check_remote_state() {
  # Pattern 1: Remote State Configuration
  if [[ ! -f "main.tf" && ! -f "backend.tf" ]]; then
    echo "  [info] no terraform files found (skipping remote state check)"
    return 0
  fi

  if grep -qE '^\s*backend\s+' main.tf backend.tf 2>/dev/null; then
    echo "  [pass] remote state backend configured"
  else
    echo "  [warn] no remote state backend found (add backend block to main.tf or backend.tf)"
  fi
  return 0
}

check_state_locking() {
  # Pattern 2: State Locking
  if [[ ! -f "main.tf" && ! -f "backend.tf" ]]; then
    return 0
  fi

  if grep -qE 'dynamodb_table' main.tf backend.tf 2>/dev/null; then
    echo "  [pass] state locking (DynamoDB) configured"
  else
    echo "  [warn] no state locking mechanism found (add dynamodb_table to backend config)"
  fi
  return 0
}

check_provider_pins() {
  # Pattern 3: Provider Version Pins
  if [[ ! -f "main.tf" && ! -f "providers.tf" ]]; then
    echo "  [info] no provider configuration found (skipping version pin check)"
    return 0
  fi

  if grep -qE 'required_providers' main.tf providers.tf 2>/dev/null; then
    if grep -A20 'required_providers' main.tf providers.tf 2>/dev/null | grep -qE 'version\s*='; then
      echo "  [pass] provider versions pinned"
    else
      echo "  [warn] providers not version-pinned (add version constraint to required_providers)"
    fi
  fi
  return 0
}

check_variable_validation() {
  # Pattern 5: Variable Validation
  if [[ ! -f "variables.tf" && ! -f "main.tf" ]]; then
    return 0
  fi

  if grep -qE '^\s*validation\s*\{' variables.tf main.tf 2>/dev/null; then
    echo "  [pass] variables have validation blocks"
  else
    echo "  [info] no variable validation blocks found (consider adding validation for critical variables)"
  fi
  return 0
}

check_output_descriptions() {
  # Pattern 6: Output Descriptions
  if [[ ! -f "outputs.tf" && ! -f "main.tf" ]]; then
    return 0
  fi

  local outputs_without_desc=0
  local total_outputs=0

  while IFS= read -r line; do
    ((total_outputs++))
    # Check if next line (or same line) has description
    if ! grep -A1 "output \"$line\"" outputs.tf main.tf 2>/dev/null | grep -qE 'description\s*='; then
      ((outputs_without_desc++))
    fi
  done < <(grep -rhE '^\s*output\s+"[^"]+"\s*\{' outputs.tf main.tf 2>/dev/null | sed -E 's/.*output\s+"([^"]+)".*/\1/')

  if [[ $total_outputs -eq 0 ]]; then
    return 0
  fi

  if [[ $outputs_without_desc -eq 0 ]]; then
    echo "  [pass] all outputs have descriptions"
  else
    echo "  [warn] $outputs_without_desc of $total_outputs outputs missing descriptions"
  fi
  return 0
}

check_hardcoded_values() {
  # Pattern 7: No Hardcoded Values (basic check for AWS credentials)
  if [[ ! -f "main.tf" ]]; then
    return 0
  fi

  if grep -qE '(access_key|secret_key|token)\s*=\s*"[^"]{20,}"' main.tf 2>/dev/null; then
    echo "  [error] potential hardcoded AWS credentials found (use variables instead)"
  else
    echo "  [pass] no obvious hardcoded credentials"
  fi
  return 0
}

check_lifecycle_rules() {
  # Pattern 8: Lifecycle Rules
  if [[ ! -f "main.tf" ]]; then
    return 0
  fi

  local resources_with_lifecycle=0
  local total_resources=0

  while IFS= read -r resource; do
    ((total_resources++))
    # Check if this resource has a lifecycle block
    if grep -A30 "^resource \"$resource\"" main.tf 2>/dev/null | grep -qE '^\s*lifecycle\s*\{'; then
      ((resources_with_lifecycle++))
    fi
  done < <(grep -rhE '^\s*resource\s+"[^"]+"\s+"[^"]+"\s*\{' main.tf 2>/dev/null | sed -E 's/.*resource\s+"([^"]+)"\s+"([^"]+)".*/\1.\2/')

  if [[ $total_resources -eq 0 ]]; then
    return 0
  fi

  if [[ $resources_with_lifecycle -gt 0 ]]; then
    echo "  [pass] $resources_with_lifecycle resources have explicit lifecycle rules"
  else
    echo "  [info] no explicit lifecycle rules found (consider adding for critical resources)"
  fi
  return 0
}

check_sensitive_variables() {
  # Pattern 10 & 14: Sensitive Variables and Outputs
  if [[ ! -f "variables.tf" && ! -f "outputs.tf" ]]; then
    return 0
  fi

  local sensitive_vars=0
  local total_sensitive_looking=0

  # Check for sensitive-looking variable names
  while IFS= read -r line; do
    ((total_sensitive_looking++))
    if grep -A2 "variable \"$line\"" variables.tf 2>/dev/null | grep -qE 'sensitive\s*=\s*true'; then
      ((sensitive_vars++))
    fi
  done < <(grep -rhE '^\s*variable\s+"[^"]*(password|secret|key|token|credential)' variables.tf 2>/dev/null | sed -E 's/.*variable\s+"([^"]+)".*/\1/')

  if [[ $total_sensitive_looking -eq 0 ]]; then
    return 0
  fi

  if [[ $sensitive_vars -eq $total_sensitive_looking ]]; then
    echo "  [pass] all sensitive-looking variables marked as sensitive"
  else
    echo "  [warn] $((total_sensitive_looking - sensitive_vars)) of $total_sensitive_looking sensitive variables not marked"
  fi
  return 0
}

# Main execution
main() {
  echo "Checking Terraform patterns..."

  check_remote_state
  check_state_locking
  check_provider_pins
  check_variable_validation
  check_output_descriptions
  check_hardcoded_values
  check_lifecycle_rules
  check_sensitive_variables
}

main "$@"