#!/bin/bash
# check-traceability-coverage.sh — Report traceability coverage
#
# Reports:
# - Files without @see references
# - ADRs without code links
# - Coverage percentage
#
# Exit codes: 0 = report generated, 1 = errors found

source "$(dirname "$0")/../../../lib/shell/check.sh"
set -e

REPO_ROOT="${1:-.}"
ERRORS=0

echo "=== Traceability Coverage Report ==="
echo ""

# --- Files without traceability ---
echo "Files without @see references:"
echo "--------------------------------"
files_without_trace=0
for f in $(find "$REPO_ROOT/src" -name "*.cpp" -o -name "*.h" 2>/dev/null); do
    if ! grep -q '@see' "$f" 2>/dev/null; then
        echo "  NO TRACEABILITY: $f"
        ERRORS=$((ERRORS + 1))
        files_without_trace=$((files_without_trace + 1))
    fi
done

if [ "$files_without_trace" -eq 0 ]; then
    echo "  All source files have @see references ✓"
fi

# --- ADRs without links ---
echo ""
echo "ADRs without code/design links:"
echo "--------------------------------"
adrs_without_links=0
for adr in "$REPO_ROOT/docs/adrs"/adr-*.md; do
    if [ -f "$adr" ]; then
        refs=$(grep -E '@see|Implements:|Related:' "$adr" 2>/dev/null | wc -l || echo 0)
        refs=$(echo "$refs" | tr -d ' ')
        if [ "$refs" -eq 0 ]; then
            basename_adr=$(basename "$adr")
            echo "  UNLINKED: $basename_adr"
            ERRORS=$((ERRORS + 1))
            adrs_without_links=$((adrs_without_links + 1))
        fi
    fi
done

if [ "$adrs_without_links" -eq 0 ]; then
    echo "  All ADRs have links ✓"
fi

# --- TODO items without tickets ---
echo ""
echo "TODO/FIXME without ticket references:"
echo "--------------------------------------"
todos_without_ticket=0
while IFS= read -r line; do
    file=$(echo "$line" | cut -d: -f1)
    linenum=$(echo "$line" | cut -d: -f2)
    content=$(echo "$line" | cut -d: -f3-)
    # Only match standalone TODO/FIXME comments, not Doxygen @brief or other patterns
    if echo "$content" | grep -qE '^\s*//\s*(TODO|FIXME)' && ! echo "$content" | grep -qE 'cpm-[0-9]+'; then
        echo "  NO TICKET: $file:$linenum - $content"
        ERRORS=$((ERRORS + 1))
        todos_without_ticket=$((todos_without_ticket + 1))
    fi
done < <(grep -rnsE '^\s*//\s*(TODO|FIXME)' "$REPO_ROOT/src" 2>/dev/null || true)

if [ "$todos_without_ticket" -eq 0 ]; then
    echo "  All TODO/FIXME have ticket refs ✓"
fi

# --- Summary ---
echo ""
echo "=== Summary ==="
total_files=$(find "$REPO_ROOT/src" -name "*.cpp" -o -name "*.h" 2>/dev/null | wc -l)
total_adrs=$(find "$REPO_ROOT/docs/adrs" -name "adr-*.md" 2>/dev/null | wc -l)

files_with_trace=$((total_files - files_without_trace))
adrs_with_links=$((total_adrs - adrs_without_links))

if [ "$total_files" -gt 0 ]; then
    file_pct=$((files_with_trace * 100 / total_files))
    echo "Files with traceability: $files_with_trace / $total_files ($file_pct%)"
else
    echo "Files with traceability: 0 / 0 (N/A)"
fi

if [ "$total_adrs" -gt 0 ]; then
    adr_pct=$((adrs_with_links * 100 / total_adrs))
    echo "ADRs with links: $adrs_with_links / $total_adrs ($adr_pct%)"
else
    echo "ADRs with links: 0 / 0 (N/A)"
fi

echo ""
if [ "$ERRORS" -gt 0 ]; then
    echo "=== $ERRORS traceability gap(s) found ==="
else
    echo "=== Full traceability coverage ==="
fi

# --- Feature docs ↔ command handlers ---
echo ""
echo "Feature docs coverage:"
echo "--------------------------------"
doc_total=0
doc_linked=0
for doc in docs/features/*.md; do
    [ -f "$doc" ] || continue
    cmd=$(basename "$doc" .md)
    # Skip non-command docs
    case "$cmd" in enforcement-levels|usage-modes|maturity|pii-detection|secrets|workflow|ai-workflow|config|issues) continue;; esac
    doc_total=$((doc_total + 1))
    # Check if a cmd_<name> or "cmd == \"<name>\"" exists in source
    if grep -rq "cmd_${cmd}\|\"${cmd}\"" src/ 2>/dev/null; then
        doc_linked=$((doc_linked + 1))
    else
        echo "  NO HANDLER: docs/features/$cmd.md"
        ERRORS=$((ERRORS + 1))
    fi
done
if [ "$doc_total" -gt 0 ]; then
    echo "Feature docs with handler: $doc_linked / $doc_total ($((doc_linked * 100 / doc_total))%)"
fi

exit $( [ "$ERRORS" -gt 0 ] && echo 1 || echo 0 )