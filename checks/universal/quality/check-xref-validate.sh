#!/bin/bash
# check-xref-validate.sh — Validate all cross-references in code and docs
#
# Validates:
# - @see ADR-XXX, DES-XXX, cpm-XXX references
# - SPDX-License-Identifier patterns
# - TODO(cpm-N) and FIXME(cpm-N) patterns
#
# Exit codes: 0 = all valid, 1 = broken links found

set -e

REPO_ROOT="${1:-.}"
ERRORS=0

echo "=== Cross-Reference Validation ==="

# Check Doxygen @see references
echo ""
echo "Checking @see references..."
while IFS= read -r ref; do
    type=$(echo "$ref" | cut -d: -f1)
    id=$(echo "$ref" | cut -d: -f2)
    
    case "$type" in
        ADR-*)
            file="docs/adrs/adr-${id#ADR-}*.md"
            if ! ls $file &>/dev/null 2>&1; then
                echo "  ERROR: ADR-$id not found"
                ERRORS=$((ERRORS + 1))
            fi
            ;;
        DES-*)
            # Extract topic and number, e.g., DES-VMODEL-1 -> v-model-level-0.1.drawio
            topic=$(echo "$id" | sed 's/DES-//' | tr '[:upper:]' '[:lower:]')
            num=$(echo "$id" | grep -o '[0-9]*$')
            file="docs/designs/${topic}-level-0.${num}.drawio"
            if [ ! -f "$file" ]; then
                echo "  ERROR: $id ($file) not found"
                ERRORS=$((ERRORS + 1))
            fi
            ;;
        cpm-*)
            # Tickets may be in TODO.md or GitHub
            if ! grep -r "cpm-$id" "$REPO_ROOT/TODO.md" &>/dev/null 2>&1; then
                echo "  WARNING: cpm-$id not in TODO.md (may be GitHub issue)"
            fi
            ;;
    esac
done < <(grep -rhs '@see\s\+\(ADR-[0-9]\+\|DES-[A-Z]\+-[0-9]\+\|cpm-[0-9]\+\)' "$REPO_ROOT/src" "$REPO_ROOT/docs" 2>/dev/null | sort -u || true)

# Check SPDX identifiers
echo ""
echo "Checking SPDX licenses..."
spdx_count=$(grep -rhs 'SPDX-License-Identifier:' "$REPO_ROOT/src" 2>/dev/null | wc -l || echo 0)
if [ "$spdx_count" -gt 0 ]; then
    echo "  Found $spdx_count files with SPDX identifiers"
else
    echo "  WARNING: No SPDX identifiers found"
fi

# Check TODO/FIXME with ticket refs
echo ""
echo "Checking TODO/FIXME with ticket refs..."
while IFS= read -r line; do
    file=$(echo "$line" | cut -d: -f1)
    content=$(echo "$line" | cut -d: -f2-)
    if echo "$content" | grep -qE '(TODO|FIXME)\(cpm-[0-9]+\)'; then
        ticket=$(echo "$content" | grep -oE 'cpm-[0-9]+' | head -1)
        echo "  $file: $ticket"
    fi
done < <(grep -rnsE '(TODO|FIXME)\(cpm-[0-9]+\)' "$REPO_ROOT/src" 2>/dev/null || true)

# Check GitHub refs in commit messages (if in git repo)
if [ -d "$REPO_ROOT/.git" ]; then
    echo ""
    echo "Checking GitHub references in commits..."
    git -C "$REPO_ROOT" log --all --oneline -20 | while read commit msg; do
        if echo "$msg" | grep -qE '(closes|fixes|related)\s+(#[0-9]+|![0-9]+)'; then
            refs=$(echo "$msg" | grep -oE '(closes|fixes|related)\s+(#[0-9]+|![0-9]+)' | tr '\n' ' ')
            echo "  $commit: $refs"
        fi
    done
fi

echo ""
if [ "$ERRORS" -gt 0 ]; then
    echo "=== FAILED: $ERRORS error(s) found ==="
    exit 1
else
    echo "=== PASSED: All cross-references valid ==="
    exit 0
fi