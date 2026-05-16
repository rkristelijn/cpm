# Design Patterns — Enforced Conventions

**Source:** workspace-tui proven patterns  
**Status:** Reference implementation for all repos

## Overview

workspace-tui heeft een goed ontwerp met enforced patterns via automated checks. Deze patronen zijn nu gedocumenteerd voor hergebruik in alle repos.

## Core Patterns

### 1. Centralized UI (ADR-004)

**Principe:** Alle terminal output via `lib/ui.sh`, geen hardcoded ANSI codes.

**Enforcement:**
```bash
# scripts/checks/quality/colors.sh
check_colors() {
  find scripts -name '*.sh' | while read file; do
    [[ "$file" == *"lib/ui.sh" ]] && continue
    grep -qn '\\033\[' "$file" && print_error "$file: use lib/ui.sh"
  done
}
```

**Runs in:** pre-commit, CI, `make check`

**API:**
```bash
source scripts/lib/ui.sh

print_step "01/10" "gitleaks" "success" "2s"
print_error "commit failed"
print_warning "deprecated API"
print_header "Running checks"
print_summary "5s"
```

**Features:**
- NO_COLOR support (accessibility)
- Terminal width aware
- Consistent symbols (✓ ✗ ⊘)
- Responsive layout (narrow terminals)

---

### 2. Check Registry (ADR-005)

**Principe:** JSON registry als single source of truth voor alle checks.

**Schema:**
```json
{
  "checks": {
    "check-name": {
      "tier": "pre-commit|pre-push|ci",
      "gates": ["check-fast", "check", "check-all"],
      "autofix": "full|partial|none",
      "cmmi": 0-5,
      "filetypes": ["ts", "*"],
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

**Usage:**
```bash
# Query registry
CHECKS=$(jq -r '.checks | to_entries[] | 
  select(.value.tier == "pre-commit") | .key' .config/checks-registry.json)

# Check skip status
skipped=$(jq -r ".checks[\"$check\"].skip.enabled" .config/checks-registry.json)
```

**Skip mechanism:**
```bash
make skip check=filesize reason="refactoring in progress"
make unskip check=filesize
make skip-status
```

---

### 3. Registry-Driven Runners

**Principe:** Git hooks en Makefile targets lezen registry, geen hardcoded lijsten.

**pre-commit.sh:**
```bash
source scripts/lib/ui.sh
REGISTRY=".config/checks-registry.json"

# Load all check functions
for f in scripts/checks/*/*.sh; do source "$f"; done

# Get checks for this tier
CHECKS=$(jq -r '.checks | to_entries[] | 
  select(.value.tier == "pre-commit") | .key' "$REGISTRY")

for check in $CHECKS; do
  # Skip if configured
  skipped=$(jq -r ".checks[\"$check\"].skip.enabled" "$REGISTRY")
  [[ "$skipped" == "true" ]] && continue
  
  # File-type filter
  filetypes=$(jq -r ".checks[\"$check\"].filetypes[]" "$REGISTRY")
  # ... filter logic
  
  # Run check
  "check_${check//-/_}" && STATUS=0 || STATUS=$?
  print_step "$num" "$check" "$([[ $STATUS -eq 0 ]] && echo success || echo error)"
done
```

**Makefile:**
```makefile
# Generate targets from registry
lint-fast: $(shell jq -r '.checks | to_entries[] | select(.value.tier == "pre-commit") | .key' .config/checks-registry.json)
```

---

### 4. Check Function Convention

**Principe:** Elke check is een `check_<name>` functie in `scripts/checks/<category>/<name>.sh`.

**Structure:**
```
scripts/checks/
├── format/
│   ├── biome.sh          → check_biome()
│   └── editorconfig.sh   → check_editorconfig()
├── security/
│   ├── gitleaks.sh       → check_gitleaks()
│   └── pii.sh            → check_pii()
├── quality/
│   ├── coverage.sh       → check_coverage()
│   └── traceability.sh   → check_traceability()
├── code/
│   ├── complexity.sh     → check_complexity()
│   └── comments.sh       → check_comments()
└── structure/
    ├── filesize.sh       → check_filesize()
    └── deps.sh           → check_deps()
```

**Template:**
```bash
#!/usr/bin/env bash
# Brief description
# @see docs/adr/xxx-check-name.md

check_<name>() {
  # Tool availability check
  if ! command -v tool > /dev/null 2>&1; then
    echo "SKIP: not installed"
    return 0
  fi
  
  # Run check
  tool --config .config/.tool.conf
}
```

---

### 5. 3-Tier Quality Gates

**Principe:** Checks georganiseerd in 3 tiers op basis van snelheid en scope.

**Tiers:**

| Tier | Speed | When | Checks |
|------|-------|------|--------|
| check-fast | <3s | AI loop | format + build |
| check | 3-30s | pre-push | format + lint + test |
| check-all | >30s | CI/PR | everything |

**Makefile:**
```makefile
check-fast: format ## Tier 1: autofix + fast lint
	@$(MAKE) format 2>&1 | tee .tmp/check-fast.log

check: ## Tier 2: full quality gate
	@$(MAKE) format lint test 2>&1 | tee .tmp/check.log

check-all: ## Tier 3: exhaustive
	@$(MAKE) format lint test sast mutation 2>&1 | tee .tmp/check-all.log
```

**Registry mapping:**
```json
{
  "checks": {
    "biome": {
      "gates": ["check-fast", "check", "check-all"]
    },
    "complexity": {
      "gates": ["check", "check-all"]
    },
    "mutation": {
      "gates": ["check-all"]
    }
  }
}
```

---

### 6. Shift-Left Principle

**Principe:** Checks zo vroeg mogelijk in de development cycle.

**Tiers:**
```
pre-commit (tier 1)
  ↓ fast checks (<3s)
  ↓ autofix available
  ↓ file-type filtered
  
pre-push (tier 2)
  ↓ structural checks (3-30s)
  ↓ architecture validation
  
CI (tier 3)
  ↓ exhaustive (>30s)
  ↓ mutation, SAST, coverage
```

**File-type filtering:**
```bash
# Only run TypeScript checks if .ts files staged
filetypes=$(jq -r ".checks[\"$check\"].filetypes[]" "$REGISTRY")
if [[ "$filetypes" != "*" ]]; then
  relevant=0
  for ext in $filetypes; do
    echo "$STAGED" | grep -q "\.$ext$" && relevant=1 && break
  done
  [[ "$relevant" -eq 0 ]] && continue
fi
```

---

### 7. Autofix Phase

**Principe:** Pre-commit heeft 2 fases: autofix (silent) → check (fail-fast).

**Phase 1: Autofix (silent, re-stage)**
```bash
# Format TypeScript files
if [[ "$HAS_TS" -gt 0 ]]; then
  TS_FILES=$(echo "$STAGED" | grep '\.ts$')
  npx biome check --write $TS_FILES 2>/dev/null
  echo "$TS_FILES" | xargs git add
fi

# Trim trailing whitespace
echo "$STAGED" | while read f; do
  sed 's/[[:space:]]*$//' "$f" > "$f.tmp" && mv "$f.tmp" "$f" && git add "$f"
done
```

**Phase 2: Check (fail-fast)**
```bash
for check in $CHECKS; do
  autofix=$(jq -r ".checks[\"$check\"].autofix" "$REGISTRY")
  [[ "$autofix" == "full" ]] && continue  # Already fixed in phase 1
  
  "check_${check//-/_}" || exit 1
done
```

---

### 8. Branch Guard

**Principe:** Enforce branch naming convention, block direct commits to main.

**Implementation:**
```bash
# pre-commit.sh
branch="$(git symbolic-ref --short HEAD)"
[[ "$branch" == "main" ]] && {
  print_error "no direct commits to main"
  exit 1
}

BRANCH_PATTERN="^(feat|fix|chore|docs|refactor|test|ci|style|perf|build)/[a-z0-9]+(-[a-z0-9]+)*$"
if ! [[ "$branch" =~ $BRANCH_PATTERN ]]; then
  print_error "branch '$branch' invalid — expected: type/description"
  exit 1
fi
```

**Valid branches:**
- `feat/add-login`
- `fix/memory-leak`
- `chore/update-deps`

**Invalid:**
- `main` (blocked)
- `feature/AddLogin` (uppercase)
- `my-branch` (no type prefix)

---

### 9. Logging & Traceability

**Principe:** Log alle check runs voor historical tracking.

**lib/log.sh:**
```bash
log_run() {
  local target="$1" status="$2"
  local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  echo "$timestamp,$target,$status" >> .tmp/check-history.csv
}
```

**Usage:**
```bash
# At end of pre-commit
source scripts/lib/log.sh
log_run "pre-commit" 0
```

**Analysis:**
```bash
# Show recent runs
tail -20 .tmp/check-history.csv | column -t -s,

# Success rate
awk -F, '$3==0' .tmp/check-history.csv | wc -l
```

---

### 10. CMMI Maturity Scoring

**Principe:** Track maturity level per check, calculate overall score.

**Levels:**
- 0: Basic (format, syntax)
- 1: Managed (security, types)
- 2: Defined (architecture, complexity)
- 3: Quantitatively managed (coverage, metrics)
- 4: Optimizing (mutation, AI-assisted)

**Calculation:**
```bash
total_checks=$(jq '.checks | length' .config/checks-registry.json)
cmmi_sum=$(jq '[.checks[].cmmi] | add' .config/checks-registry.json)
score=$((cmmi_sum * 100 / (total_checks * 5)))
echo "CMMI score: $score%"
```

**Makefile target:**
```makefile
maturity: ## Show CMMI maturity score
	@bash scripts/maturity-score.sh
```

---

## Enforcement Checklist

Voor elke repo die deze patterns gebruikt:

- [ ] `lib/ui.sh` aanwezig
- [ ] `lib/table.sh` voor complexe output
- [ ] `.config/checks-registry.json` compleet
- [ ] Alle checks hebben `check_<name>` functie
- [ ] `scripts/checks/quality/colors.sh` draait in pre-commit
- [ ] Git hooks zijn registry-driven
- [ ] Makefile targets query registry
- [ ] Skip mechanism werkt (`make skip/unskip`)
- [ ] Branch guard actief
- [ ] Logging enabled
- [ ] CMMI score zichtbaar

## Migration Checklist

Van bestaande repo naar deze patterns:

1. [ ] Kopieer `lib/ui.sh` en `lib/table.sh`
2. [ ] Maak `.config/checks-registry.json`
3. [ ] Refactor checks naar `check_<name>` functies
4. [ ] Update git hooks (registry-driven)
5. [ ] Update Makefile (query registry)
6. [ ] Add `colors` check
7. [ ] Add skip targets
8. [ ] Test pre-commit flow
9. [ ] Test skip mechanism
10. [ ] Verify CMMI score

## Success Metrics

- Zero hardcoded ANSI codes (enforced)
- Zero hardcoded check lists (registry-driven)
- Skip mechanism gebruikt voor temporary issues
- Consistent output across all repos
- < 5 min setup voor nieuwe repo

## References

- ADR-004: Centralized UI pattern
- ADR-005: Check registry pattern
- workspace-tui: Reference implementation
- llama-cli: Alternative patterns (to be migrated)
