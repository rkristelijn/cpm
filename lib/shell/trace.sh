#!/usr/bin/env bash
# trace.sh — Generate traceability matrix from @see annotations.
# Usage: cpm trace [--gaps|--stale]
set -o nounset
set -o pipefail

MODE="${1:-}"

echo ""
echo "  cpm trace — traceability matrix"
echo ""

# Collect all @see references
refs=$(grep -rn "@see" --include='*.cpp' --include='*.h' --include='*.sh' --include='*.ts' --include='*.js' --include='*.md' \
  --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=vendor --exclude-dir=.tmp \
  . 2>/dev/null | grep -v "check-stale\|check-xref" || true)

total_files=$(find src lib checks -type f \( -name '*.cpp' -o -name '*.sh' -o -name '*.h' \) 2>/dev/null | wc -l | tr -d ' ')
linked_files=$(echo "$refs" | cut -d: -f1 | sort -u | wc -l | tr -d ' ')
adr_refs=$(echo "$refs" | grep -oE "ADR-[0-9]+" | sort -u | wc -l | tr -d ' ')

case "$MODE" in
  --gaps)
    echo "  Files WITHOUT traceability (@see):"
    echo ""
    find src lib checks -type f \( -name '*.cpp' -o -name '*.sh' -o -name '*.h' \) 2>/dev/null | while read -r f; do
      grep -q "@see" "$f" 2>/dev/null || printf "    %s\n" "$f"
    done
    ;;
  --stale)
    echo "  Stale links (code newer than linked ADR):"
    echo ""
    bash checks/universal/docs/check-stale-docs.sh 2>/dev/null
    cat .tmp/findings.jsonl 2>/dev/null | grep stale | while IFS= read -r l; do
      f=$(echo "$l" | sed 's/.*"file":"//;s/".*//')
      m=$(echo "$l" | sed 's/.*"message":"//;s/".*//')
      printf "    %s — %s\n" "$f" "$m"
    done
    ;;
  *)
    printf "  Coverage: %s/%s files have @see links (%d%%)\n" "$linked_files" "$total_files" "$((linked_files * 100 / (total_files > 0 ? total_files : 1)))"
    printf "  ADRs referenced: %s\n" "$adr_refs"
    printf "  Total @see links: %s\n" "$(echo "$refs" | wc -l | tr -d ' ')"
    echo ""
    echo "  Top referenced ADRs:"
    echo "$refs" | grep -oE "ADR-[0-9]+" | sort | uniq -c | sort -rn | head -5 | sed 's/^/    /'
    echo ""
    echo "  Commands:"
    echo "    cpm trace --gaps   Show files without links"
    echo "    cpm trace --stale  Show outdated links"
    ;;
esac
echo ""
