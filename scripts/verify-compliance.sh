#!/usr/bin/env bash
# verify-compliance.sh — Verify cpm compliance claims against actual check availability
#
# Parses docs/compliance/*.md tables and verifies each referenced check exists.
# Outputs: pass/fail per framework + overall score.
#
# Usage:
#   cpm compliance                    # Run verification
#   bash scripts/verify-compliance.sh # Same thing

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPLIANCE_DIR="$REPO_ROOT/docs/compliance"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

ok() { echo -e "  ${GREEN}✓${NC}  $1"; }
warn() { echo -e "  ${YELLOW}⚠${NC}  $1"; }
err() { echo -e "  ${RED}✗${NC}  $1"; }
info() { echo -e "  ${BLUE}ℹ${NC}  $1"; }

TOTAL_CONTROLS=0
COVERED=0
GAPS=0
FRAMEWORKS_PASS=0
FRAMEWORKS_TOTAL=0

echo -e "${BOLD}Compliance Verification${NC}"
echo ""

for md in "$COMPLIANCE_DIR"/*.md; do
  [[ "$(basename "$md")" == "README.md" ]] && continue
  [[ ! -f "$md" ]] && continue

  FRAMEWORK=$(head -1 "$md" | sed 's/^# //' | cut -d' ' -f1-3)
  FRAMEWORK_COVERED=0
  FRAMEWORK_TOTAL=0
  FRAMEWORK_GAPS=()

  # Parse table rows: | ... | check-name | ... |
  while IFS='|' read -r _ _ _ check _; do
    check=$(echo "$check" | xargs) # trim whitespace
    [[ -z "$check" || "$check" == "cpm check" || "$check" == "---" ]] && continue
    [[ "$check" == *"Evidence"* || "$check" == *"cpm check"* ]] && continue

    ((FRAMEWORK_TOTAL++))
    ((TOTAL_CONTROLS++))

    # Check if the referenced check/feature exists
    found=false
    for pattern in $check; do
      pattern=$(echo "$pattern" | tr -d ',')
      # Check as shell script
      if find "$REPO_ROOT/checks" -name "*${pattern}*" 2>/dev/null | grep -q .; then
        found=true
        break
      fi
      # Check as script
      if find "$REPO_ROOT/scripts" -name "*${pattern}*" 2>/dev/null | grep -q .; then
        found=true
        break
      fi
      # Check as hook
      if grep -rql "$pattern" "$REPO_ROOT/docs/checks/" 2>/dev/null; then
        found=true
        break
      fi
      # Known features (not file-based)
      case "$pattern" in
      cpm | pii-vault | paranoia-mode | paranoia-backup | global-hooks | enforcement | gitleaks | semgrep | SECURITY.md)
        found=true
        break
        ;;
      esac
    done

    if $found; then
      ((FRAMEWORK_COVERED++))
      ((COVERED++))
    else
      ((GAPS++))
      FRAMEWORK_GAPS+=("$check")
    fi
  done < <(grep "^|" "$md" | tail -n +3) # skip header + separator

  ((FRAMEWORKS_TOTAL++))
  PCTG=0
  [[ $FRAMEWORK_TOTAL -gt 0 ]] && PCTG=$((FRAMEWORK_COVERED * 100 / FRAMEWORK_TOTAL))

  if [[ $PCTG -eq 100 ]]; then
    ok "$FRAMEWORK: $FRAMEWORK_COVERED/$FRAMEWORK_TOTAL controls (${PCTG}%)"
    ((FRAMEWORKS_PASS++))
  elif [[ $PCTG -ge 75 ]]; then
    warn "$FRAMEWORK: $FRAMEWORK_COVERED/$FRAMEWORK_TOTAL controls (${PCTG}%)"
    for gap in "${FRAMEWORK_GAPS[@]}"; do
      echo -e "      missing: $gap"
    done
  else
    err "$FRAMEWORK: $FRAMEWORK_COVERED/$FRAMEWORK_TOTAL controls (${PCTG}%)"
    for gap in "${FRAMEWORK_GAPS[@]}"; do
      echo -e "      missing: $gap"
    done
  fi
done

echo ""
echo -e "${BOLD}Summary${NC}"
echo ""
TOTAL_PCTG=0
[[ $TOTAL_CONTROLS -gt 0 ]] && TOTAL_PCTG=$((COVERED * 100 / TOTAL_CONTROLS))
info "Frameworks: $FRAMEWORKS_PASS/$FRAMEWORKS_TOTAL fully covered"
info "Controls:   $COVERED/$TOTAL_CONTROLS verified ($TOTAL_PCTG%)"
info "Gaps:       $GAPS"
echo ""

if [[ $GAPS -eq 0 ]]; then
  ok "All compliance claims verified"
  exit 0
else
  warn "$GAPS control(s) reference checks that could not be found"
  exit 1
fi
