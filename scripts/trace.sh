#!/usr/bin/env bash
# scripts/trace.sh — Trace function calls and generate mermaid sequence diagram
# Usage: bash scripts/trace.sh <function_name> [path] [--depth N]
set -o nounset -o pipefail

FUNC="${1:-}"
REPO="${2:-.}"
MAX_DEPTH=3
VISITED=""

[[ -z "$FUNC" ]] && { echo "Usage: cpm trace <function_name> [path] [--depth N]"; exit 1; }

# Parse --depth flag
for i in $(seq 1 $#); do
  arg="${!i}"
  if [[ "$arg" == "--depth" ]]; then
    next=$((i + 1))
    MAX_DEPTH="${!next:-3}"
  fi
done

# Exclude patterns
EXCLUDE="node_modules|\.next|dist|build|\.git|coverage|vendor|target"

# --- Find where a function is defined ---
find_definition() {
  local name="$1"
  # Skip language keywords
  echo "$name" | grep -qE "^(if|else|for|while|switch|return|catch|do)$" && return
  # C/C++: return_type function_name(
  # JS/TS: function name(, const name =, name(, export function name
  grep -rnE "(^|[ \t])(function ${name}|const ${name}|let ${name}|${name}\s*\(|${name}\s*=\s*\(|[a-zA-Z_*&]+ ${name}\s*\()" "$REPO" 2>/dev/null | \
    grep -vE "$EXCLUDE|\.test\.|\.spec\.|__test__|__mocks__" | \
    grep -vE "^\s*//" | \
    head -5
}

# --- Extract function body and find calls within it ---
extract_calls() {
  local file="$1"
  local name="$2"
  local line="$3"
  
  # Get ~60 lines after the definition (rough function body)
  tail -n +"$line" "$file" | head -60 | \
    grep -oE "[a-zA-Z_][a-zA-Z0-9_]*\s*\(" | \
    sed 's/\s*($//' | sed 's/ *$//' | \
    grep -vE "^(if|else|for|while|switch|return|catch|typeof|sizeof|printf|fprintf|snprintf|sprintf|console|log|warn|error|require|import|export|const|let|var|new|throw|await|async|function|class|static|void|int|char|bool|auto|strcmp|strncmp|strlen|strcpy|memcpy|memset|malloc|calloc|free|realloc|fopen|fclose|fgets|fputs|fread|fwrite|atoi|atof|getenv|setenv|puts|gets|sscanf|NULL|true|false|this|self|super|paths|includes|push|pop|map|filter|reduce|find|forEach|then|catch|finally|from|of|in|do|case)$" | \
    sort -u
}

# --- Get the file (participant) name for mermaid ---
participant_name() {
  local file="$1"
  basename "$file" | sed 's/\.[^.]*$//'
}

# --- Recursive trace ---
DIAGRAM="sequenceDiagram"
PARTICIPANTS=""

trace() {
  local name="$1"
  local depth="$2"
  local caller_file="$3"
  
  [[ "$depth" -gt "$MAX_DEPTH" ]] && return
  
  # Prevent infinite loops
  echo "$VISITED" | grep -q "|${name}|" && return
  VISITED="${VISITED}|${name}|"
  
  # Find definition
  local defs
  defs=$(find_definition "$name")
  [[ -z "$defs" ]] && return
  
  # If multiple definitions, take first (or could prompt user)
  local def_line
  def_line=$(echo "$defs" | head -1)
  local file=$(echo "$def_line" | cut -d: -f1)
  local lineno=$(echo "$def_line" | cut -d: -f2)
  
  local callee_participant=$(participant_name "$file")
  
  # Add participant if new
  if ! echo "$PARTICIPANTS" | grep -q "|${callee_participant}|"; then
    PARTICIPANTS="${PARTICIPANTS}|${callee_participant}|"
  fi
  
  # Add arrow from caller to callee
  if [[ -n "$caller_file" ]]; then
    local caller_participant=$(participant_name "$caller_file")
    DIAGRAM="${DIAGRAM}
    ${caller_participant}->>+${callee_participant}: ${name}()"
  fi
  
  # Extract calls from this function
  local calls
  calls=$(extract_calls "$file" "$name" "$lineno")
  
  # Trace each call
  while IFS= read -r call; do
    [[ -z "$call" ]] && continue
    # Skip keywords that slipped through
    echo "$call" | grep -qE "^(if|else|for|while|switch|return|catch|do|case)$" && continue
    trace "$call" $((depth + 1)) "$file"
  done <<< "$calls"
  
  # Add return arrow
  if [[ -n "$caller_file" ]]; then
    local caller_participant=$(participant_name "$caller_file")
    DIAGRAM="${DIAGRAM}
    ${callee_participant}-->>-${caller_participant}: "
  fi
}

# --- Main ---
echo ""
echo "  Tracing: $FUNC (depth: $MAX_DEPTH)"
echo ""

# Start trace
trace "$FUNC" 0 ""

# Output mermaid
echo '```mermaid'
echo "$DIAGRAM"
echo '```'
echo ""
