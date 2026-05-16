# ADR-005: Check Registry Pattern

**Status:** Accepted  
**Date:** 2026-05-11  
**Context:** workspace-tui has proven registry-driven check system

## Problem

Quality checks are scattered and inconsistent:
- No single source of truth for what checks exist
- Unclear which checks run where (pre-commit vs CI)
- No skip mechanism for temporary issues
- Hard to see check metadata (tier, autofix, CMMI level)
- Duplicate check definitions in Makefile and git hooks

## Decision

**Use JSON registry as single source of truth for all checks**

### Registry Schema

```json
{
  "checks": {
    "check-name": {
      "tier": "pre-commit|pre-push|ci",
      "gates": ["check-fast", "check", "check-all"],
      "autofix": "full|partial|none",
      "cmmi": 0-5,
      "filetypes": ["ts", "sh", "*"],
      "category": "format|security|quality|code|structure",
      "skip": {
        "enabled": false,
        "reason": "",
        "expires": "YYYY-MM-DD"
      }
    }
  }
}
```

### Fields

- **tier**: When check runs (shift-left principle)
  - `pre-commit`: Fast (<3s), autofix available
  - `pre-push`: Slower (3-30s), structural checks
  - `ci`: Slowest (>30s), exhaustive analysis

- **gates**: Which make targets include this check
  - `check-fast`: Format + build only
  - `check`: Full quality gate
  - `check-all`: Everything including slow checks

- **autofix**: Can the check fix issues automatically?
  - `full`: Always fixes (e.g., biome --write)
  - `partial`: Fixes some cases (e.g., editorconfig)
  - `none`: Detection only (e.g., gitleaks)

- **cmmi**: Maturity level (0-5)
  - 0: Basic (format, syntax)
  - 1: Managed (security, types)
  - 2: Defined (architecture, complexity)
  - 3: Quantitatively managed (coverage, metrics)
  - 4: Optimizing (mutation, AI-assisted)

- **filetypes**: File extensions to check
  - `["ts"]`: Only TypeScript files
  - `["*"]`: All files

- **category**: Logical grouping for reporting

- **skip**: Temporary disable mechanism
  - `enabled`: true to skip
  - `reason`: Why skipped (required)
  - `expires`: Auto-unskip date (optional)

### Usage in Scripts

```bash
REGISTRY=".config/checks-registry.json"

# Get all pre-commit checks
CHECKS=$(jq -r '.checks | to_entries[] | 
  select(.value.tier == "pre-commit") | 
  .key' "$REGISTRY")

# Check if skipped
skipped=$(jq -r ".checks[\"$check\"].skip.enabled" "$REGISTRY")
if [[ "$skipped" == "true" ]]; then
  reason=$(jq -r ".checks[\"$check\"].skip.reason" "$REGISTRY")
  print_step "$num" "$check" "skip" "$reason"
  continue
fi

# File-type filter
filetypes=$(jq -r ".checks[\"$check\"].filetypes[]" "$REGISTRY")
if [[ "$filetypes" != "*" ]]; then
  # Skip if no relevant files staged
fi
```

### Skip Management

```makefile
skip: ## Skip a check: make skip check=filesize reason="..."
	@jq '.checks["$(check)"].skip = {
	  "enabled": true, 
	  "reason": "$(reason)", 
	  "expires": "'$$(date -v+30d +%Y-%m-%d)'"
	}' .config/checks-registry.json > .tmp && mv .tmp .config/checks-registry.json

unskip: ## Unskip: make unskip check=filesize
	@jq '.checks["$(check)"].skip.enabled = false' \
	  .config/checks-registry.json > .tmp && mv .tmp .config/checks-registry.json

skip-status: ## Show skipped checks
	@jq -r '.checks | to_entries[] | 
	  select(.value.skip.enabled) | 
	  "\(.key): \(.value.skip.reason) (expires: \(.value.skip.expires // "never"))"' \
	  .config/checks-registry.json
```

## Implementation

### 1. Registry File

Location: `.config/checks-registry.json`

```json
{
  "checks": {
    "biome": {
      "tier": "pre-commit",
      "gates": ["check-fast", "check", "check-all"],
      "autofix": "full",
      "cmmi": 0,
      "filetypes": ["ts"],
      "category": "format",
      "skip": {"enabled": false}
    },
    "gitleaks": {
      "tier": "pre-commit",
      "gates": ["check-fast", "check", "check-all"],
      "autofix": "none",
      "cmmi": 1,
      "filetypes": ["*"],
      "category": "security",
      "skip": {"enabled": false}
    },
    "complexity": {
      "tier": "pre-push",
      "gates": ["check", "check-all"],
      "autofix": "none",
      "cmmi": 2,
      "filetypes": ["ts", "cpp"],
      "category": "code",
      "skip": {"enabled": false}
    }
  }
}
```

### 2. Check Functions

Convention: `check_<name>` function in `scripts/checks/<category>/<name>.sh`

```bash
#!/usr/bin/env bash
# scripts/checks/security/gitleaks.sh

check_gitleaks() {
  if ! command -v gitleaks > /dev/null 2>&1; then
    echo "SKIP: not installed"
    return 0
  fi
  gitleaks detect --no-git --redact --config=.config/.gitleaks.toml
}
```

### 3. Registry-Driven Runner

```bash
# pre-commit.sh
source scripts/lib/ui.sh
REGISTRY=".config/checks-registry.json"

# Load all check functions
for f in scripts/checks/*/*.sh; do source "$f"; done

# Get checks for this tier
CHECKS=$(jq -r '.checks | to_entries[] | 
  select(.value.tier == "pre-commit") | 
  .key' "$REGISTRY")

for check in $CHECKS; do
  # Skip logic
  skipped=$(jq -r ".checks[\"$check\"].skip.enabled" "$REGISTRY")
  [[ "$skipped" == "true" ]] && continue
  
  # Run check
  "check_${check//-/_}" && STATUS=0 || STATUS=$?
  
  if [[ "$STATUS" -eq 0 ]]; then
    print_step "$num" "$check" "success"
  else
    print_step "$num" "$check" "error"
    exit 1
  fi
done
```

## Consequences

### Positive
- **Single source of truth**: All check metadata in one place
- **Discoverability**: `jq .checks < .config/checks-registry.json`
- **Skip mechanism**: Temporary disable without code changes
- **Automation**: Scripts query registry, no hardcoding
- **Reporting**: Easy to generate check matrices
- **CMMI tracking**: Maturity level per check

### Negative
- **JSON dependency**: Requires jq in all environments
- **Indirection**: Check definitions separate from execution
- **Migration**: Existing checks need registry entries

### Neutral
- **Convention**: Function names must match registry keys
- **Validation**: Registry schema should be validated

## Integration Patterns

### With Makefile

```makefile
# Generate targets from registry
lint-fast: $(shell jq -r '.checks | to_entries[] | select(.value.tier == "pre-commit") | .key' .config/checks-registry.json)

# Individual check targets
gitleaks: ## Run gitleaks
	@bash -c 'source scripts/lib/ui.sh; source scripts/checks/security/gitleaks.sh; check_gitleaks'
```

### With CI

```yaml
# .github/workflows/ci.yml
- name: Run checks
  run: |
    CHECKS=$(jq -r '.checks | to_entries[] | select(.value.tier == "ci") | .key' .config/checks-registry.json)
    for check in $CHECKS; do
      make "$check"
    done
```

### With CMMI Scoring

```bash
# Calculate maturity score
total_checks=$(jq '.checks | length' .config/checks-registry.json)
cmmi_sum=$(jq '[.checks[].cmmi] | add' .config/checks-registry.json)
score=$((cmmi_sum * 100 / (total_checks * 5)))
echo "CMMI score: $score%"
```

## Migration Guide

1. **Create registry**: `.config/checks-registry.json`
2. **Add check entries**: One per existing check
3. **Create check functions**: `check_<name>` in `scripts/checks/`
4. **Update git hooks**: Query registry instead of hardcoded list
5. **Update Makefile**: Generate targets from registry
6. **Add skip targets**: `make skip/unskip/skip-status`

## Validation

```bash
# Validate registry schema
check_registry() {
  jq -e '.checks | to_entries[] | 
    select(.value.tier == null or 
           .value.autofix == null or 
           .value.cmmi == null) | 
    "Missing required field in \(.key)"' \
    .config/checks-registry.json && return 1 || return 0
}
```

## Success Metrics

- All checks defined in registry
- Zero hardcoded check lists in scripts
- Skip mechanism used for temporary issues
- CMMI score visible in CI

## References

- workspace-tui: .config/checks-registry.json (reference)
- workspace-tui: scripts/git/pre-commit.sh (registry-driven runner)
- ADR-004: Centralized UI pattern
- ADR-006: 3-tier quality gates
