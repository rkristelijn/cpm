#!/usr/bin/env bash
# scripts/classdiagram.sh — Generate mermaid class diagram from types/interfaces/structs/classes
# Usage: bash scripts/classdiagram.sh [path]
set -o nounset -o pipefail

REPO="${1:-.}"
EXCLUDE="node_modules|\.next|dist|build|\.git|coverage|vendor|target"

echo ""
echo "  Generating class diagram from: $REPO"
echo ""
echo '```mermaid'
echo "classDiagram"

# --- TypeScript/JavaScript: interface, type, class ---
TS_FILES=$(find "$REPO" -name "*.ts" -o -name "*.tsx" 2>/dev/null | grep -vE "$EXCLUDE|\.test\.|\.spec\.|\.d\.ts$" || true)

if [ -n "$TS_FILES" ]; then
  # Interfaces
  echo "$TS_FILES" | xargs grep -hn "^\s*export\s*interface\|^interface " 2>/dev/null | while IFS=: read -r file line content; do
    name=$(echo "$content" | grep -oE "interface\s+[A-Z][a-zA-Z0-9_]*" | sed 's/interface\s*//')
    [ -z "$name" ] && continue
    extends=$(echo "$content" | grep -oE "extends\s+[A-Z][a-zA-Z0-9_, ]*" | sed 's/extends\s*//')
    
    echo "    class ${name} {"
    echo "        <<interface>>"
    # Extract properties (next ~20 lines until closing brace)
    tail -n +"$line" "$file" | head -20 | grep -E "^\s+[a-zA-Z_].*:" | head -8 | \
      sed 's/^\s*/        /; s/;$//' 
    echo "    }"
    
    # Inheritance
    if [ -n "$extends" ]; then
      for parent in $(echo "$extends" | tr ',' '\n' | tr -d ' '); do
        echo "    ${parent} <|-- ${name}"
      done
    fi
  done

  # Type aliases (only object-like types)
  echo "$TS_FILES" | xargs grep -hn "^\s*export\s*type\|^type " 2>/dev/null | grep "=" | grep "{" | while IFS=: read -r file line content; do
    name=$(echo "$content" | grep -oE "type\s+[A-Z][a-zA-Z0-9_]*" | sed 's/type\s*//')
    [ -z "$name" ] && continue
    
    echo "    class ${name} {"
    echo "        <<type>>"
    tail -n +"$line" "$file" | head -15 | grep -E "^\s+[a-zA-Z_].*:" | head -6 | \
      sed 's/^\s*/        /; s/;$//'
    echo "    }"
  done

  # Classes
  echo "$TS_FILES" | xargs grep -hn "^\s*export\s*class\|^class " 2>/dev/null | while IFS=: read -r file line content; do
    name=$(echo "$content" | grep -oE "class\s+[A-Z][a-zA-Z0-9_]*" | sed 's/class\s*//')
    [ -z "$name" ] && continue
    extends=$(echo "$content" | grep -oE "extends\s+[A-Z][a-zA-Z0-9_]*" | sed 's/extends\s*//')
    implements=$(echo "$content" | grep -oE "implements\s+[A-Z][a-zA-Z0-9_, ]*" | sed 's/implements\s*//')
    
    echo "    class ${name} {"
    tail -n +"$line" "$file" | head -30 | grep -E "^\s+(public|private|protected|readonly|static|#|[a-zA-Z_])" | head -8 | \
      sed 's/^\s*/        /; s/{$//'
    echo "    }"
    
    [ -n "$extends" ] && echo "    ${extends} <|-- ${name}"
    if [ -n "$implements" ]; then
      for iface in $(echo "$implements" | tr ',' '\n' | tr -d ' '); do
        echo "    ${iface} <|.. ${name}"
      done
    fi
  done
fi

# --- C/C++: struct, class ---
C_FILES=$(find "$REPO" -name "*.h" -o -name "*.hpp" -o -name "*.cpp" -o -name "*.c" 2>/dev/null | grep -vE "$EXCLUDE" || true)

if [ -n "$C_FILES" ]; then
  # typedef struct { ... } Name;
  find "$REPO" -name "*.h" -o -name "*.hpp" 2>/dev/null | grep -vE "$EXCLUDE" | while read -r file; do
    grep -hn "^} [A-Z]" "$file" 2>/dev/null | while IFS=: read -r line content; do
      name=$(echo "$content" | grep -oE "[A-Z][a-zA-Z0-9_]*" | head -1)
      [ -z "$name" ] && continue
      echo "    class ${name} {"
      echo "        <<struct>>"
      head -n "$line" "$file" | tail -15 | grep -E "^\s+[a-zA-Z_]" | grep -v "{" | head -8 | \
        sed 's/^\s*/        /; s/;$//'
      echo "    }"
    done
    
    # struct Name { ... }
    grep -hn "^struct [A-Z]" "$file" 2>/dev/null | grep -v ";" | while IFS=: read -r line content; do
      name=$(echo "$content" | grep -oE "struct [A-Z][a-zA-Z0-9_]*" | sed 's/struct //')
      [ -z "$name" ] && continue
      parent=$(echo "$content" | grep -oE ": [A-Z][a-zA-Z0-9_]*" | sed 's/: //')
      echo "    class ${name} {"
      echo "        <<struct>>"
      tail -n +"$line" "$file" | head -15 | grep -E "^\s+[a-zA-Z_]" | grep -v "{" | head -8 | \
        sed 's/^\s*/        /; s/;$//'
      echo "    }"
      [ -n "$parent" ] && echo "    ${parent} <|-- ${name}"
    done
  done

  # C++ classes
  echo "$C_FILES" | xargs grep -hn "^class\s\|^\s*class\s" 2>/dev/null | grep -v ";" | while IFS=: read -r file line content; do
    name=$(echo "$content" | grep -oE "class\s+[A-Z][a-zA-Z0-9_]*" | sed 's/class\s*//')
    [ -z "$name" ] && continue
    parent=$(echo "$content" | grep -oE ":\s*public\s+[A-Z][a-zA-Z0-9_]*" | sed 's/.*public\s*//')
    
    echo "    class ${name} {"
    tail -n +"$line" "$file" | head -30 | grep -E "^\s+(public|private|protected|virtual|static|[a-zA-Z_])" | head -8 | \
      sed 's/^\s*/        /; s/{$//'
    echo "    }"
    
    [ -n "$parent" ] && echo "    ${parent} <|-- ${name}"
  done
fi

echo '```'
echo ""
