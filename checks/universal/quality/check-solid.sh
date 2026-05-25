#!/usr/bin/env bash
#
# @see ADR-129
# check-solid.sh — Detect SOLID principle violations in TypeScript/JavaScript.
#
# Checks:
#   - SRP: File size, mixed concerns, god classes
#   - OCP: Switch/type-checking patterns
#   - LSP: Override without super, type narrowing
#   - ISP: God interfaces, empty implementations
#   - DIP: Concrete imports in domain, direct instantiation
#
# Usage:
#   bash checks/universal/quality/check-solid.sh [repo]
#   Default repo: current directory

source "$(dirname "$0")/../../../lib/shell/check.sh"
if [[ "${TRACE-0}" == "1" ]]; then set -o xtrace; fi

# Load CPM shell framework (with fallbacks) - compute path BEFORE changing directory
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_CPM_DIR="$_SCRIPT_DIR/../../.."

REPO="${1:-.}"
cd "$REPO"
if [[ -f "$_CPM_DIR/lib/shell/init.sh" ]]; then
  source "$_CPM_DIR/lib/shell/findings.sh" 2>/dev/null || true
fi

# Fallbacks if framework not available
print_header() { echo "==> $1"; }
print_step() { echo "  [${1}] ${2}"; }
findings_init() { :; }
findings_add() { :; }
findings_finish() { :; }
findings_summary() { :; }

FAIL=0
WARN=0
INFO=0

print_header "checking SOLID principles..."

# --- Helper: find TS/JS files ---
find_ts_files() {
  find . \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \) \
    -not -path "*/node_modules/*" -not -path "*/.next/*" -not -path "*/dist/*" \
    -not -path "*/build/*" -not -path "*/.git/*" -not -path "*/coverage/*" \
    -not -path "*/__pycache__/*" -not -path "*/.cache/*" -not -path "*/vendor/*" \
    -not -path "*/target/*" -not -path "*/out/*" -type f 2>/dev/null
}

# ============================================================
# SINGLE RESPONSIBILITY PRINCIPLE (SRP)
# ============================================================

print_step "SRP" "Checking file sizes..."

# Check 1: File size > 400 lines
while IFS= read -r file; do
  lines=$(wc -l < "$file" 2>/dev/null | tr -d ' ' || echo 0)
  lines=${lines:-0}
  if [[ "$lines" -gt 400 ]] 2>/dev/null; then
    findings_add "warning" "$file" "srp-file-size" \
      "File has $lines lines (max 400) — consider splitting" \
      "Split into smaller, focused modules" \
      "https://github.com/rkristelijn/cpm/blob/main/docs/frameworks/solid/patterns.md#srp"
    WARN=$((WARN + 1))
  fi
done < <(find_ts_files)

# Check 2: Multiple exports with unrelated concerns
print_step "SRP" "Checking mixed exports..."
while IFS= read -r file; do
  export_count=$(grep -c '^export' "$file" 2>/dev/null || echo 0)
  export_count=${export_count:-0}
  if [[ "$export_count" -gt 10 ]] 2>/dev/null; then
    findings_add "warning" "$file" "srp-many-exports" \
      "File has $export_count exports — consider splitting" \
      "Group related exports into separate modules" \
      "https://github.com/rkristelijn/cpm/blob/main/docs/frameworks/solid/patterns.md#srp"
    WARN=$((WARN + 1))
  fi
done < <(find_ts_files)

# Check 3: God class (high coupling - many imports from different modules)
print_step "SRP" "Checking god classes..."
while IFS= read -r file; do
  import_count=$(grep -c "^import.*from" "$file" 2>/dev/null || echo 0)
  import_count=${import_count:-0}
  if [[ "$import_count" -gt 15 ]] 2>/dev/null; then
    findings_add "error" "$file" "srp-god-class" \
      "File has $import_count imports — high coupling" \
      "Split into smaller modules with focused responsibilities" \
      "https://github.com/rkristelijn/cpm/blob/main/docs/frameworks/solid/patterns.md#srp"
    FAIL=$((FAIL + 1))
  fi
done < <(find_ts_files)

# ============================================================
# OPEN/CLOSED PRINCIPLE (OCP)
# ============================================================

print_step "OCP" "Checking switch/type patterns..."

# Check 4: Switch/case on type
while IFS= read -r file; do
  # Look for switch statements on type-like patterns
  violations=$(grep -n "switch.*type\|switch.*kind\|switch.*category" "$file" 2>/dev/null || true)
  if [[ -n "$violations" ]]; then
    while IFS= read -r line; do
      linenum=$(echo "$line" | cut -d: -f1)
      findings_add "warning" "$file:$linenum" "ocp-switch-type" \
        "Switch on type violates OCP — use polymorphism" \
        "Create separate classes implementing a common interface" \
        "https://github.com/rkristelijn/cpm/blob/main/docs/frameworks/solid/patterns.md#ocp"
      WARN=$((WARN + 1))
    done <<< "$violations"
  fi
done < <(find_ts_files)

# Check 5: instanceof chains
print_step "OCP" "Checking instanceof patterns..."
while IFS= read -r file; do
  violations=$(grep -n "instanceof" "$file" 2>/dev/null | head -5 || true)
  if [[ -n "$violations" ]]; then
    while IFS= read -r line; do
      linenum=$(echo "$line" | cut -d: -f1)
      findings_add "warning" "$file:$linenum" "ocp-instanceof" \
        "instanceof checks suggest OCP violation — use polymorphism" \
        "Replace type checks with strategy pattern or visitor" \
        "https://github.com/rkristelijn/cpm/blob/main/docs/frameworks/solid/patterns.md#ocp"
      WARN=$((WARN + 1))
    done <<< "$violations"
  fi
done < <(find_ts_files)

# ============================================================
# LISKOV SUBSTITUTION PRINCIPLE (LSP)
# ============================================================

print_step "LSP" "Checking override patterns..."

# Check 6: Override without super call (in classes with parent)
while IFS= read -r file; do
  # Find methods that override (have same name as parent) but don't call super
  # This is a heuristic: look for methods that likely override
  violations=$(grep -n "override\|protected\|public.*method" "$file" 2>/dev/null | head -10 || true)
  if [[ -n "$violations" ]]; then
    findings_add "info" "$file" "lsp-override-check" \
      "Review method overrides for LSP compliance" \
      "Ensure subclasses can substitute parent without behavior changes" \
      "https://github.com/rkristelijn/cpm/blob/main/docs/frameworks/solid/patterns.md#lsp"
    INFO=$((INFO + 1))
  fi
done < <(find_ts_files)

# Check 7: Return type widening (any/unknown in override)
print_step "LSP" "Checking return type widening..."
while IFS= read -r file; do
  violations=$(grep -n ": any\|: unknown" "$file" 2>/dev/null | head -10 || true)
  if [[ -n "$violations" ]]; then
    while IFS= read -r line; do
      linenum=$(echo "$line" | cut -d: -f1)
      findings_add "warning" "$file:$linenum" "lsp-return-widening" \
        "Return type 'any' or 'unknown' may violate LSP" \
        "Use specific types that maintain contract" \
        "https://github.com/rkristelijn/cpm/blob/main/docs/frameworks/solid/patterns.md#lsp"
      WARN=$((WARN + 1))
    done <<< "$violations"
  fi
done < <(find_ts_files)

# ============================================================
# INTERFACE SEGREGATION PRINCIPLE (ISP)
# ============================================================

print_step "ISP" "Checking interface size..."

# Check 8: God interface (>5 methods)
while IFS= read -r file; do
  # Count interface methods
  method_count=$(grep -c "): void\|): number\|): string\|): boolean\|): any\|): Promise" "$file" 2>/dev/null || echo 0)
  method_count=${method_count:-0}
  if [[ "$method_count" -gt 8 ]] 2>/dev/null; then
    findings_add "warning" "$file" "isp-god-interface" \
      "Interface has ~$method_count methods — consider splitting" \
      "Split into focused role interfaces" \
      "https://github.com/rkristelijn/cpm/blob/main/docs/frameworks/solid/patterns.md#isp"
    WARN=$((WARN + 1))
  fi
done < <(find_ts_files)

# Check 9: Empty method implementations (throw new Error)
print_step "ISP" "Checking empty implementations..."
while IFS= read -r file; do
  violations=$(grep -n "throw new Error.*not implemented\|throw new Error.*TODO" "$file" 2>/dev/null || true)
  if [[ -n "$violations" ]]; then
    while IFS= read -r line; do
      linenum=$(echo "$line" | cut -d: -f1)
      findings_add "warning" "$file:$linenum" "isp-empty-impl" \
        "Empty implementation suggests ISP violation" \
        "Split interface into smaller, focused interfaces" \
        "https://github.com/rkristelijn/cpm/blob/main/docs/frameworks/solid/patterns.md#isp"
      WARN=$((WARN + 1))
    done <<< "$violations"
  fi
done < <(find_ts_files)

# ============================================================
# DEPENDENCY INVERSION PRINCIPLE (DIP)
# ============================================================

print_step "DIP" "Checking concrete dependencies..."

# Check 10: Concrete imports in domain files
print_step "DIP" "Checking domain layer imports..."
# Look for domain files importing infrastructure
while IFS= read -r file; do
  # Skip if not in a domain-like path
  case "$file" in
  *domain*|*service*|*usecase*|*entity*)
    # Check for concrete infrastructure imports
    violations=$(grep -n "from ['\"]\.\.\/.*\(database\|fs\|axios\|mongoose\|typeorm\|prisma\)" "$file" 2>/dev/null || true)
    if [[ -n "$violations" ]]; then
      while IFS= read -r line; do
        linenum=$(echo "$line" | cut -d: -f1)
        findings_add "error" "$file:$linenum" "dip-concrete-import" \
          "Domain code depends on concrete infrastructure" \
          "Depend on abstractions (interfaces) instead" \
          "https://github.com/rkristelijn/cpm/blob/main/docs/frameworks/solid/patterns.md#dip"
        FAIL=$((FAIL + 1))
      done <<< "$violations"
    fi
    ;;
  esac
done < <(find_ts_files)

# Check 11: Direct instantiation (new ClassName)
print_step "DIP" "Checking direct instantiation..."
while IFS= read -r file; do
  # Skip test files and factory files
  case "$file" in
  *.test.ts|*.test.tsx|*.spec.ts|*.spec.tsx|*factory*|*Factory*) continue ;;
  esac

  violations=$(grep -n "new [A-Z][a-zA-Z]*(" "$file" 2>/dev/null | head -10 || true)
  if [[ -n "$violations" ]]; then
    # Count non-trivial instantiations
    count=$(echo "$violations" | wc -l | tr -d ' ' || echo 0)
    count=${count:-0}
    findings_add "warning" "$file" "dip-direct-instantiation" \
      "Found ~$count direct instantiations — consider dependency injection" \
      "Inject dependencies via constructor or use factory pattern" \
      "https://github.com/rkristelijn/cpm/blob/main/docs/frameworks/solid/patterns.md#dip"
    WARN=$((WARN + 1))
  fi
done < <(find_ts_files)

# Check 12: Hardcoded infrastructure in domain paths
print_step "DIP" "Checking infrastructure in domain..."
while IFS= read -r dir; do
  # Check if domain dir has infrastructure imports
  for file in "$dir"/*.ts "$dir"/*.tsx; do
    [[ -f "$file" ]] || continue
    infra_refs=$(grep -l "from.*\(mysql\|postgres\|mongodb\|redis\)" "$file" 2>/dev/null || true)
    if [[ -n "$infra_refs" ]]; then
      findings_add "error" "$file" "dip-infra-in-domain" \
        "Domain file references infrastructure directly" \
        "Use repository interfaces, inject implementations" \
        "https://github.com/rkristelijn/cpm/blob/main/docs/frameworks/solid/patterns.md#dip"
      FAIL=$((FAIL + 1))
    fi
  done
done < <(find . -type d \( -name "domain" -o -name "core" -o -name "entities" \) 2>/dev/null)

# ============================================================
# SUMMARY
# ============================================================

findings_finish
findings_summary

if [[ $FAIL -gt 0 ]]; then
  echo "  ⚠ $FAIL SOLID violation(s) require attention"
fi
if [[ $WARN -gt 0 ]]; then
  echo "  ⚡ $WARN SOLID warning(s) — consider refactoring"
fi
if [[ $INFO -gt 0 ]]; then
  echo "  ℹ $INFO info message(s) — review for context"
fi

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
exit 0