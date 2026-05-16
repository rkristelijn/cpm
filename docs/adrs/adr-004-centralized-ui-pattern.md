# ADR-004: Centralized UI Pattern

**Status:** Accepted  
**Date:** 2026-05-11  
**Supersedes:** Inline ANSI codes in scripts  
**Context:** workspace-tui has proven pattern for consistent terminal output

## Problem

Scripts across repos have inconsistent output:
- Hardcoded ANSI escape codes scattered everywhere
- No NO_COLOR support (accessibility issue)
- Inconsistent formatting (some use echo, some printf)
- No terminal width awareness
- Duplicate color definitions

## Decision

**Enforce single source of truth for all terminal output via `lib/ui.sh`**

### Core Principles

1. **No raw echo/printf in scripts** — all output via print_* functions
2. **No hardcoded ANSI** — only in lib/ui.sh
3. **NO_COLOR support** — respects https://no-color.org/
4. **Terminal width aware** — adapts to narrow terminals
5. **Consistent symbols** — ✓ ✗ ⊘ for success/error/skip

### API

```bash
# Source once at script start
source scripts/lib/ui.sh

# Status output (for check loops)
print_step "01/10" "gitleaks" "success" "2s"
print_step "02/10" "shellcheck" "error"
print_step "03/10" "biome" "skip" "no .ts files"

# Messages
print_error "commit failed: invalid branch name"
print_warning "deprecated: use new API"
print_header "Running quality checks"
print_summary "5s"

# Colors (only when needed, prefer print_* functions)
echo -e "${GREEN}custom${RESET}"
```

### Implementation

```bash
#!/usr/bin/env bash
# lib/ui.sh — single source of truth for terminal output

# NO_COLOR support (https://no-color.org/)
if [[ -z "${NO_COLOR:-}" ]]; then
  RED='\033[0;91m'
  GREEN='\033[0;92m'
  YELLOW='\033[0;93m'
  GRAY='\033[0;90m'
  BOLD='\033[1m'
  RESET='\033[0m'
else
  RED='' GREEN='' YELLOW='' GRAY='' BOLD='' RESET=''
fi

CHECK="✓"
CROSS="✗"

print_step() {
  local num="$1" name="$2" status="$3" extra="${4:-}"
  local term_width="${COLUMNS:-80}"
  local name_width=$((term_width < 80 ? 18 : 22))
  
  printf "  [%s] %-${name_width}s " "$num" "$name"
  
  case "$status" in
    success) echo -e "${GREEN}${CHECK}${RESET} ${GRAY}${extra}${RESET}" ;;
    error)   echo -e "${RED}${CROSS}${RESET}" ;;
    skip)    echo -e "${GRAY}⊘ ${extra}${RESET}" ;;
  esac
}

print_error()   { echo -e "${RED}ERROR:${RESET} $1"; }
print_warning() { echo -e "${YELLOW}WARNING:${RESET} $1"; }
print_summary() { echo ""; echo -e "${GREEN}All checks passed${RESET} in ${GRAY}$1${RESET}"; }
print_header()  { echo ""; echo -e "${GREEN}$1${RESET}"; echo ""; }
```

### Enforcement

**Automated check** (scripts/checks/quality/colors.sh):
```bash
check_colors() {
  local found=0
  while IFS= read -r file; do
    [[ "$file" == *"lib/ui.sh" ]] && continue
    if grep -qn '\\033\[' "$file" 2>/dev/null; then
      print_error "$file: hardcoded ANSI — use lib/ui.sh"
      found=1
    fi
  done < <(find scripts -name '*.sh')
  return $found
}
```

Runs in:
- pre-commit (fail-fast)
- CI (gate)
- `make check`

## Consequences

### Positive
- **Consistency**: Same look across all scripts
- **Accessibility**: NO_COLOR support built-in
- **Maintainability**: Change colors once, affects all output
- **Testability**: Can mock print_* functions
- **Readability**: Scripts focus on logic, not formatting

### Negative
- **Learning curve**: Devs must learn API
- **Indirection**: One extra function call
- **Enforcement needed**: Check must run to prevent violations

### Neutral
- **Migration**: Existing scripts need refactor
- **Exceptions**: lib/ui.sh itself can have ANSI codes

## Integration with Other Patterns

### 1. Check Registry (ADR-005)
```json
{
  "checks": {
    "colors": {
      "tier": "pre-commit",
      "autofix": "none",
      "category": "quality"
    }
  }
}
```

### 2. Git Hooks
```bash
# pre-commit.sh
source scripts/lib/ui.sh

print_header "Pre-commit checks"
for check in $CHECKS; do
  print_step "$num" "$check" "success" "1s"
done
print_summary "5s"
```

### 3. Makefile Targets
```makefile
check-colors: ## Enforce no hardcoded ANSI
	@bash -c 'source scripts/lib/ui.sh; source scripts/checks/quality/colors.sh; check_colors'
```

## Examples

### Before (bad)
```bash
echo -e "\033[0;91mERROR:\033[0m commit failed"
echo -e "\033[0;92m✓\033[0m gitleaks"
printf "\033[1m%s\033[0m\n" "Running checks"
```

### After (good)
```bash
source scripts/lib/ui.sh

print_error "commit failed"
print_step "01/10" "gitleaks" "success" "2s"
print_header "Running checks"
```

## Table Support

For complex output (check matrices), use lib/table.sh:

```bash
source scripts/lib/table.sh

print_table_header
print_table_row "gitleaks" "✓" "none" "✓" "✓" "✓" "✓" "—"
print_table_separator
```

Handles:
- ANSI code width calculation
- Terminal width adaptation
- Responsive column widths

## Migration Guide

1. **Add lib/ui.sh** to repo
2. **Source in all scripts**: `source scripts/lib/ui.sh`
3. **Replace echo/printf**:
   - `echo "ERROR: ..."` → `print_error "..."`
   - `echo -e "\033[0;92m✓\033[0m"` → `print_step ... "success"`
4. **Add colors check** to pre-commit
5. **Run**: `make check-colors` to find violations

## Success Metrics

- Zero hardcoded ANSI codes outside lib/ui.sh
- NO_COLOR works in all scripts
- Consistent output format across repos
- < 5 min to add to new repo

## References

- workspace-tui: scripts/lib/ui.sh (reference implementation)
- workspace-tui: scripts/checks/quality/colors.sh (enforcement)
- https://no-color.org/ (accessibility standard)
- ADR-005: Check registry pattern
