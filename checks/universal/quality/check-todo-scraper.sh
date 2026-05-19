#!/bin/bash
# check-todo-scraper.sh — Scrape TODO/FIXME comments and report
#
# Extracts all TODO(cpm-N) and FIXME(cpm-N) comments
# Outputs to: ~/.local/share/cpm/todo-items.jsonl
#
# Format: {"file":"src/parser.cpp","line":42,"type":"TODO","ticket":"cpm-42","text":"reason"}

source "$(dirname "$0")/../../../lib/shell/check.sh"
set -e

REPO_ROOT="${1:-.}"
OUTPUT_DIR="${HOME}/.local/share/cpm"
OUTPUT_FILE="${OUTPUT_DIR}/todo-items.jsonl"

mkdir -p "$OUTPUT_DIR"
> "$OUTPUT_FILE"

echo "=== TODO/FIXME Scraper ==="
echo "Output: $OUTPUT_FILE"
echo ""

# Find TODO/FIXME with ticket refs
while IFS= read -r line; do
    file=$(echo "$line" | cut -d: -f1)
    linenum=$(echo "$line" | cut -d: -f2)
    content=$(echo "$line" | cut -d: -f3-)
    
    # Extract type, ticket, and text
    type=$(echo "$content" | grep -oE '(TODO|FIXME)' | tr '[:lower:]' '[:upper:]')
    ticket=$(echo "$content" | grep -oE 'cpm-[0-9]+' | head -1)
    text=$(echo "$content" | sed -E 's/.*(TODO|FIXME)\(cpm-[0-9]+\)[: ]*//' | xargs)
    
    if [ -n "$ticket" ]; then
        # Escape JSON special chars
        file_esc=$(echo "$file" | sed 's/"/\\"/g')
        text_esc=$(echo "$text" | sed 's/"/\\"/g')
        
        echo "{\"file\":\"$file_esc\",\"line\":$linenum,\"type\":\"$type\",\"ticket\":\"$ticket\",\"text\":\"$text_esc\"}" >> "$OUTPUT_FILE"
        echo "  $ticket:$type $file:$linenum - ${text:0:50}..."
    fi
done < <(grep -rnsE '(TODO|FIXME)\(cpm-[0-9]+\)' "$REPO_ROOT/src" 2>/dev/null || true)

count=$(wc -l < "$OUTPUT_FILE")
echo ""
echo "=== Found $count TODO/FIXME items ==="
echo "Full report: $OUTPUT_FILE"